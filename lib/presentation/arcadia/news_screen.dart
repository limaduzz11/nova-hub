import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/arcadia_service.dart';
import '../../data/models/news.dart';

/// Sub-tela de Notícias da Arcadia — agregador RSS de sites de games.
class NewsView extends StatefulWidget {
  const NewsView({super.key});

  @override
  State<NewsView> createState() => _NewsViewState();
}

class _NewsViewState extends State<NewsView>
    with AutomaticKeepAliveClientMixin {
  final _svc = ArcadiaService();

  List<NewsArticle> _all = [];
  bool _loading = false;
  String? _error;
  String? _lang; // null = todos os idiomas, "pt" ou "en"
  String? _source; // null = todas as fontes

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _svc.getNews(limit: 120);
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _open(NewsArticle a) async {
    final uri = Uri.tryParse(a.link);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link')),
      );
    }
  }

  /// Fontes disponíveis para o idioma atualmente selecionado.
  List<String> get _sources {
    final set = <String>{
      for (final a in _all)
        if (_lang == null || a.lang == _lang) a.source
    };
    final list = set.toList()..sort();
    return list;
  }

  /// Artigos após aplicar filtros de idioma e fonte (client-side).
  List<NewsArticle> get _articles {
    return _all.where((a) {
      if (_lang != null && a.lang != _lang) return false;
      if (_source != null && a.source != _source) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        if (_all.isNotEmpty) ...[
          _langFilter(),
          _sourceFilter(),
        ],
        Expanded(child: _body()),
      ],
    );
  }

  Widget _langFilter() {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip('Todos idiomas', _lang == null, () {
            setState(() {
              _lang = null;
              _source = null;
            });
          }),
          _chip('🇧🇷 Brasil', _lang == 'pt', () {
            setState(() {
              _lang = 'pt';
              _source = null;
            });
          }),
          _chip('🌍 Global', _lang == 'en', () {
            setState(() {
              _lang = 'en';
              _source = null;
            });
          }),
        ],
      ),
    );
  }

  Widget _sourceFilter() {
    final sources = _sources;
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip('Todas fontes', _source == null, () {
            setState(() => _source = null);
          }),
          for (final s in sources)
            _chip(s, _source == s, () {
              setState(() => _source = s);
            }),
        ],
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.glassBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.accent)),
      );
    }
    if (_error != null) {
      return _emptyState(
        icon: Icons.cloud_off,
        title: 'Ops',
        subtitle: _error!,
        action: TextButton(
          onPressed: _load,
          child: const Text('Tentar novamente',
              style: TextStyle(color: AppColors.accent)),
        ),
      );
    }
    if (_articles.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppColors.accent,
        backgroundColor: AppColors.card,
        child: ListView(
          children: [
            const SizedBox(height: 64),
            _emptyState(
              icon: CupertinoIcons.news,
              title: 'Sem notícias',
              subtitle: 'Puxe para atualizar.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      backgroundColor: AppColors.card,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _articles.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _card(_articles[i]),
      ),
    );
  }

  Widget _card(NewsArticle a) {
    return GestureDetector(
      onTap: () => _open(a),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.glassBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (a.image != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  a.image!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.cardHover,
                    child: const Icon(CupertinoIcons.photo,
                        color: AppColors.textMuted),
                  ),
                  loadingBuilder: (c, child, prog) => prog == null
                      ? child
                      : Container(
                          color: AppColors.cardHover,
                          child: const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(AppColors.accent),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          a.source,
                          style: const TextStyle(
                              color: AppColors.neonBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Spacer(),
                      if (a.timeAgo.isNotEmpty)
                        Text(a.timeAgo,
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    a.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w600),
                  ),
                  if (a.summary.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      a.summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 13, height: 1.5)),
            if (action != null) ...[const SizedBox(height: 12), action],
          ],
        ),
      ),
    );
  }
}
