import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models/nexus_models.dart';

/// Cliente + configuração do NOVA Nexus.
///
/// Config (URL + API key) em [FlutterSecureStorage].
/// Cache de leitura (workspaces/itens) em [SharedPreferences] para fallback
/// offline (a sincronização completa via sqflite fica para fase futura).
class NexusService {
  static const _storage = FlutterSecureStorage();
  static const _kUrl = 'nexus_url';
  static const _kApiKey = 'nexus_api_key';

  static const _cacheWorkspaces = 'nexus_cache_workspaces';
  static const _cacheItemsPrefix = 'nexus_cache_items_';

  /// Padrões que já apontam para o backend implantado (Tailscale).
  static const String defaultUrl = 'http://localhost:8080';
  static const String defaultApiKey =
      '';

  Future<String> getUrl() async =>
      (await _storage.read(key: _kUrl))?.trim().isNotEmpty == true
          ? (await _storage.read(key: _kUrl))!.trim()
          : defaultUrl;

  Future<String> getApiKey() async =>
      (await _storage.read(key: _kApiKey))?.isNotEmpty == true
          ? (await _storage.read(key: _kApiKey))!
          : defaultApiKey;

  Future<void> saveConfig({required String url, required String apiKey}) async {
    await _storage.write(key: _kUrl, value: url.trim());
    await _storage.write(key: _kApiKey, value: apiKey.trim());
  }

  Future<Map<String, String>> _headers() async => {
        'Content-Type': 'application/json',
        'X-API-Key': await getApiKey(),
      };

  Uri _uri(String base, String path) => Uri.parse('$base$path');

  // ---------------- Graph (Cortex) ----------------

  /// Busca o grafo do Vault ao vivo (nós = .md, arestas = wikilinks).
  /// Lança [Exception] se falhar (ex.: offline) — use o asset como fallback.
  Future<Map<String, dynamic>> fetchGraph() async {
    final base = await getUrl();
    final r = await http
        .get(_uri(base, '/api/graph'), headers: await _headers())
        .timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) {
      throw Exception('Erro ${r.statusCode} ao buscar grafo');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ---------------- Health ----------------

  Future<bool> ping({String? url}) async {
    try {
      final base = url ?? await getUrl();
      final r = await http
          .get(_uri(base, '/health'))
          .timeout(const Duration(seconds: 6));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ---------------- Workspaces ----------------

  Future<List<NexusWorkspace>> listWorkspaces() async {
    final base = await getUrl();
    final r = await http
        .get(_uri(base, '/api/workspaces'), headers: await _headers())
        .timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) {
      throw Exception('Erro ${r.statusCode} ao listar workspaces');
    }
    final list = (jsonDecode(r.body) as List)
        .map((e) => NexusWorkspace.fromJson(e as Map<String, dynamic>))
        .toList();
    await _cacheWrite(_cacheWorkspaces, r.body);
    return list;
  }

  Future<List<NexusWorkspace>> cachedWorkspaces() async {
    final raw = await _cacheRead(_cacheWorkspaces);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => NexusWorkspace.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<NexusWorkspace> createWorkspace({
    required String name,
    String kind = 'custom',
    String color = '',
    String icon = '',
  }) async {
    final base = await getUrl();
    final r = await http
        .post(
          _uri(base, '/api/workspaces'),
          headers: await _headers(),
          body: jsonEncode({
            'name': name,
            'kind': kind,
            'color': color,
            'icon': icon,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (r.statusCode != 201) {
      throw Exception('Erro ${r.statusCode} ao criar workspace');
    }
    return NexusWorkspace.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deleteWorkspace(String id) async {
    final base = await getUrl();
    final r = await http
        .delete(_uri(base, '/api/workspaces/$id'), headers: await _headers())
        .timeout(const Duration(seconds: 8));
    if (r.statusCode != 204) {
      throw Exception('Erro ${r.statusCode} ao excluir workspace');
    }
  }

  // ---------------- Items ----------------

  Future<List<NexusItem>> listItems(String workspaceId) async {
    final base = await getUrl();
    final r = await http
        .get(_uri(base, '/api/workspaces/$workspaceId/items'),
            headers: await _headers())
        .timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) {
      throw Exception('Erro ${r.statusCode} ao listar itens');
    }
    final list = (jsonDecode(r.body) as List)
        .map((e) => NexusItem.fromJson(e as Map<String, dynamic>))
        .toList();
    await _cacheWrite('$_cacheItemsPrefix$workspaceId', r.body);
    return list;
  }

  /// Lista TODOS os itens (todos os workspaces). Usado pelo Centro de Alertas
  /// para detectar prazos vencendo.
  Future<List<NexusItem>> listAllItems() async {
    final base = await getUrl();
    final r = await http
        .get(_uri(base, '/api/items'), headers: await _headers())
        .timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) {
      throw Exception('Erro ${r.statusCode} ao listar itens');
    }
    return (jsonDecode(r.body) as List)
        .map((e) => NexusItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<NexusItem>> cachedItems(String workspaceId) async {
    final raw = await _cacheRead('$_cacheItemsPrefix$workspaceId');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => NexusItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<NexusItem> createItem({
    required String workspaceId,
    required String type,
    required String title,
    String body = '',
    String status = 'todo',
    List<String> tags = const [],
    String? dueDate,
  }) async {
    final base = await getUrl();
    final r = await http
        .post(
          _uri(base, '/api/items'),
          headers: await _headers(),
          body: jsonEncode({
            'workspace_id': workspaceId,
            'type': type,
            'title': title,
            'body': body,
            'status': status,
            'tags': tags,
            if (dueDate != null && dueDate.isNotEmpty) 'due_date': dueDate,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (r.statusCode != 201) {
      throw Exception('Erro ${r.statusCode} ao criar item');
    }
    return NexusItem.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<NexusItem> updateItem(String id, Map<String, dynamic> patch) async {
    final base = await getUrl();
    final r = await http
        .patch(
          _uri(base, '/api/items/$id'),
          headers: await _headers(),
          body: jsonEncode(patch),
        )
        .timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) {
      throw Exception('Erro ${r.statusCode} ao atualizar item');
    }
    return NexusItem.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deleteItem(String id) async {
    final base = await getUrl();
    final r = await http
        .delete(_uri(base, '/api/items/$id'), headers: await _headers())
        .timeout(const Duration(seconds: 8));
    if (r.statusCode != 204) {
      throw Exception('Erro ${r.statusCode} ao excluir item');
    }
  }

  // ---------------- Cache helpers ----------------

  Future<void> _cacheWrite(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<String?> _cacheRead(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }
}
