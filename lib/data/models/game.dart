// Modelos da aba Arcadia (games via IGDB + biblioteca pessoal).

/// Tamanhos de imagem da IGDB (image API).
class IgdbImage {
  static String cover(String imageId, [String size = 't_cover_big']) =>
      'https://images.igdb.com/igdb/image/upload/$size/$imageId.jpg';

  static String screenshot(String imageId) =>
      'https://images.igdb.com/igdb/image/upload/t_screenshot_med/$imageId.jpg';
}

/// Formata segundos em texto curto de horas (ex.: 23400 -> "6h 30min").
String? formatPlaytime(int seconds) {
  if (seconds <= 0) return null;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h <= 0) return '${m}min';
  if (m == 0) return '${h}h';
  return '${h}h ${m}min';
}

/// Status da biblioteca pessoal (espelha o backend).
enum GameStatus { wishlist, backlog, playing, done, dropped }

extension GameStatusX on GameStatus {
  String get api => name;

  String get label {
    switch (this) {
      case GameStatus.wishlist:
        return 'Lista de Desejos';
      case GameStatus.backlog:
        return 'Backlog';
      case GameStatus.playing:
        return 'Jogando';
      case GameStatus.done:
        return 'Zerado';
      case GameStatus.dropped:
        return 'Abandonado';
    }
  }

  static GameStatus from(String? s) {
    return GameStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => GameStatus.backlog,
    );
  }
}

/// Jogo vindo da busca IGDB (proxy /api/igdb/*).
class Game {
  final int id;
  final String name;
  final String summary;
  final String storyline;
  final double rating;
  final int releaseDate; // unix seconds
  final String coverId;
  final List<String> platforms;
  final List<String> genres;
  final List<String> companies;
  final List<String> screenshots;
  final int timeToBeat; // "normally" (história principal) em segundos
  final int timeHastily; // "rushed" (correndo)
  final int timeCompletely; // "completionist" (100%)

  Game({
    required this.id,
    required this.name,
    this.summary = '',
    this.storyline = '',
    this.rating = 0,
    this.releaseDate = 0,
    this.coverId = '',
    this.platforms = const [],
    this.genres = const [],
    this.companies = const [],
    this.screenshots = const [],
    this.timeToBeat = 0,
    this.timeHastily = 0,
    this.timeCompletely = 0,
  });

  factory Game.fromJson(Map<String, dynamic> j) => Game(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?) ?? '',
        summary: (j['summary'] as String?) ?? '',
        storyline: (j['storyline'] as String?) ?? '',
        rating: ((j['rating'] as num?) ?? 0).toDouble(),
        releaseDate: (j['release_date'] as num?)?.toInt() ?? 0,
        coverId: (j['cover_id'] as String?) ?? '',
        platforms: _strList(j['platforms']),
        genres: _strList(j['genres']),
        companies: _strList(j['companies']),
        screenshots: _strList(j['screenshots']),
        timeToBeat: (j['time_to_beat'] as num?)?.toInt() ?? 0,
        timeHastily: (j['time_hastily'] as num?)?.toInt() ?? 0,
        timeCompletely: (j['time_completely'] as num?)?.toInt() ?? 0,
      );

  String? get coverUrl => coverId.isEmpty ? null : IgdbImage.cover(coverId);

  String? get playtimeLabel => formatPlaytime(timeToBeat);

  int? get releaseYear {
    if (releaseDate <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(releaseDate * 1000, isUtc: true)
        .year;
  }
}

/// Jogo salvo na biblioteca pessoal (SQLite do backend).
class LibraryGame {
  final String id;
  final int igdbId;
  final String name;
  final String coverId;
  final double rating;
  final int releaseDate;
  final List<String> platforms;
  final List<String> genres;
  final String summary;
  final int timeToBeat; // "normally" em segundos (snapshot IGDB)
  final GameStatus status;
  final int userRating; // 0-10
  final String notes;

  LibraryGame({
    required this.id,
    required this.igdbId,
    required this.name,
    this.coverId = '',
    this.rating = 0,
    this.releaseDate = 0,
    this.platforms = const [],
    this.genres = const [],
    this.summary = '',
    this.timeToBeat = 0,
    this.status = GameStatus.backlog,
    this.userRating = 0,
    this.notes = '',
  });

  factory LibraryGame.fromJson(Map<String, dynamic> j) => LibraryGame(
        id: (j['id'] as String?) ?? '',
        igdbId: (j['igdb_id'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?) ?? '',
        coverId: (j['cover_id'] as String?) ?? '',
        rating: ((j['rating'] as num?) ?? 0).toDouble(),
        releaseDate: (j['release_date'] as num?)?.toInt() ?? 0,
        platforms: _strList(j['platforms']),
        genres: _strList(j['genres']),
        summary: (j['summary'] as String?) ?? '',
        timeToBeat: (j['time_to_beat'] as num?)?.toInt() ?? 0,
        status: GameStatusX.from(j['status'] as String?),
        userRating: (j['user_rating'] as num?)?.toInt() ?? 0,
        notes: (j['notes'] as String?) ?? '',
      );

  String? get coverUrl => coverId.isEmpty ? null : IgdbImage.cover(coverId);

  String? get playtimeLabel => formatPlaytime(timeToBeat);

  int? get releaseYear {
    if (releaseDate <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(releaseDate * 1000, isUtc: true)
        .year;
  }
}

List<String> _strList(dynamic raw) {
  if (raw is List) {
    return raw.map((e) => e.toString()).toList();
  }
  return const [];
}
