import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models/game.dart';
import 'models/news.dart';
import 'nexus_service.dart';

/// Cliente da aba Arcadia — consome o proxy IGDB e a biblioteca pessoal do
/// backend Nexus. Reusa URL/API key do [NexusService].
class ArcadiaService {
  final NexusService _nexus = NexusService();

  Future<Map<String, String>> _headers() async => {
        'Content-Type': 'application/json',
        'X-API-Key': await _nexus.getApiKey(),
      };

  Uri _uri(String base, String path) => Uri.parse('$base$path');

  // ---------------- IGDB (busca / detalhe) ----------------

  /// Busca jogos na IGDB via proxy. Lança [ArcadiaException] em erro.
  Future<List<Game>> search(String term, {int limit = 30, int offset = 0}) async {
    final base = await _nexus.getUrl();
    final q = Uri.encodeQueryComponent(term);
    final r = await http
        .get(_uri(base, '/api/igdb/search?q=$q&limit=$limit&offset=$offset'),
            headers: await _headers())
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 503) {
      throw ArcadiaException(
          'IGDB não configurada no servidor. Preencha as credenciais Twitch.');
    }
    if (r.statusCode != 200) {
      throw ArcadiaException(_msg(r, 'buscar jogos'));
    }
    return (jsonDecode(r.body) as List)
        .map((e) => Game.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Game> getGame(int igdbId) async {
    final base = await _nexus.getUrl();
    final r = await http
        .get(_uri(base, '/api/igdb/games/$igdbId'), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) {
      throw ArcadiaException(_msg(r, 'carregar jogo'));
    }
    return Game.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  // ---------------- biblioteca pessoal ----------------

  Future<List<LibraryGame>> listLibrary({GameStatus? status}) async {
    final base = await _nexus.getUrl();
    final qs = status != null ? '?status=${status.api}' : '';
    final r = await http
        .get(_uri(base, '/api/library$qs'), headers: await _headers())
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) {
      throw ArcadiaException(_msg(r, 'listar biblioteca'));
    }
    return (jsonDecode(r.body) as List)
        .map((e) => LibraryGame.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Adiciona um jogo (a partir do resultado IGDB) à biblioteca. Idempotente.
  Future<LibraryGame> addToLibrary(Game g,
      {GameStatus status = GameStatus.backlog}) async {
    final base = await _nexus.getUrl();
    final r = await http
        .post(
          _uri(base, '/api/library'),
          headers: await _headers(),
          body: jsonEncode({
            'igdb_id': g.id,
            'name': g.name,
            'cover_id': g.coverId,
            'rating': g.rating,
            'release_date': g.releaseDate,
            'platforms': g.platforms,
            'genres': g.genres,
            'summary': g.summary,
            'time_to_beat': g.timeToBeat,
            'status': status.api,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 201 && r.statusCode != 200) {
      throw ArcadiaException(_msg(r, 'adicionar à biblioteca'));
    }
    return LibraryGame.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<LibraryGame> updateLibrary(String id, Map<String, dynamic> patch) async {
    final base = await _nexus.getUrl();
    final r = await http
        .patch(_uri(base, '/api/library/$id'),
            headers: await _headers(), body: jsonEncode(patch))
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) {
      throw ArcadiaException(_msg(r, 'atualizar jogo'));
    }
    return LibraryGame.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> removeFromLibrary(String id) async {
    final base = await _nexus.getUrl();
    final r = await http
        .delete(_uri(base, '/api/library/$id'), headers: await _headers())
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 204) {
      throw ArcadiaException(_msg(r, 'remover jogo'));
    }
  }

  // ---------------- notícias ----------------

  /// Lista notícias de games agregadas de feeds RSS. [source] filtra por fonte,
  /// [lang] filtra por idioma ("pt" ou "en").
  Future<List<NewsArticle>> getNews(
      {String? source, String? lang, int limit = 80}) async {
    final base = await _nexus.getUrl();
    final params = <String>['limit=$limit'];
    if (source != null && source.isNotEmpty) {
      params.add('source=${Uri.encodeQueryComponent(source)}');
    }
    if (lang != null && lang.isNotEmpty) {
      params.add('lang=$lang');
    }
    final r = await http
        .get(_uri(base, '/api/news?${params.join('&')}'),
            headers: await _headers())
        .timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) {
      throw ArcadiaException(_msg(r, 'carregar notícias'));
    }
    final m = jsonDecode(r.body) as Map<String, dynamic>;
    return (m['items'] as List? ?? [])
        .map((e) => NewsArticle.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  String _msg(http.Response r, String acao) {
    try {
      final m = jsonDecode(r.body) as Map<String, dynamic>;
      if (m['error'] is String) return m['error'] as String;
    } catch (_) {}
    return 'Erro ${r.statusCode} ao $acao';
  }
}

class ArcadiaException implements Exception {
  final String message;
  ArcadiaException(this.message);
  @override
  String toString() => message;
}
