/// Notícia de games agregada de feeds RSS/Atom públicos via backend Nexus.
class NewsArticle {
  final String title;
  final String link;
  final String source;
  final String lang; // "pt" ou "en"
  final String author;
  final String summary;
  final String? image;
  final DateTime? published;

  NewsArticle({
    required this.title,
    required this.link,
    required this.source,
    required this.lang,
    required this.author,
    required this.summary,
    this.image,
    this.published,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> j) {
    DateTime? pub;
    final raw = j['published'] as String?;
    if (raw != null && raw.isNotEmpty) {
      pub = DateTime.tryParse(raw)?.toLocal();
    }
    final img = j['image'] as String?;
    return NewsArticle(
      title: (j['title'] as String?) ?? '',
      link: (j['link'] as String?) ?? '',
      source: (j['source'] as String?) ?? '',
      lang: (j['lang'] as String?) ?? '',
      author: (j['author'] as String?) ?? '',
      summary: (j['summary'] as String?) ?? '',
      image: (img != null && img.isNotEmpty) ? img : null,
      published: pub,
    );
  }

  /// Rótulo relativo simples ("agora", "3h", "2d") a partir de [published].
  String get timeAgo {
    if (published == null) return '';
    final d = DateTime.now().difference(published!);
    if (d.inMinutes < 1) return 'agora';
    if (d.inMinutes < 60) return '${d.inMinutes}min';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 30) return '${d.inDays}d';
    return '${(d.inDays / 30).floor()}mês';
  }
}
