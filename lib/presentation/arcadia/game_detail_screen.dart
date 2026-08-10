import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/arcadia_service.dart';
import '../../data/models/game.dart';
import 'widgets/game_cover.dart';

/// Detalhe de um jogo (IGDB) + ações da biblioteca pessoal.
///
/// Pode ser aberta a partir da busca (só `igdbId` + `fallback`) ou da
/// biblioteca (`library` preenchido). Retorna `true` no pop se a biblioteca
/// foi alterada (para a tela anterior recarregar).
class GameDetailScreen extends StatefulWidget {
  const GameDetailScreen({
    super.key,
    required this.igdbId,
    this.fallback,
    this.library,
  });

  final int igdbId;
  final Game? fallback;
  final LibraryGame? library;

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  final _svc = ArcadiaService();

  Game? _game;
  LibraryGame? _lib;
  bool _loading = true;
  bool _busy = false;
  bool _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _game = widget.fallback;
    _lib = widget.library;
    _load();
  }

  Future<void> _load() async {
    try {
      final game = await _svc.getGame(widget.igdbId);
      LibraryGame? lib = widget.library;
      lib ??= (await _svc.listLibrary())
          .where((g) => g.igdbId == widget.igdbId)
          .cast<LibraryGame?>()
          .firstWhere((g) => true, orElse: () => null);
      if (!mounted) return;
      setState(() {
        _game = game;
        _lib = lib;
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

  Future<void> _add(GameStatus status) async {
    final g = _game;
    if (g == null) return;
    setState(() => _busy = true);
    try {
      final lib = await _svc.addToLibrary(g, status: status);
      _changed = true;
      if (!mounted) return;
      setState(() => _lib = lib);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _patch(Map<String, dynamic> patch) async {
    final lib = _lib;
    if (lib == null) return;
    setState(() => _busy = true);
    try {
      final updated = await _svc.updateLibrary(lib.id, patch);
      _changed = true;
      if (!mounted) return;
      setState(() => _lib = updated);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final lib = _lib;
    if (lib == null) return;
    setState(() => _busy = true);
    try {
      await _svc.removeFromLibrary(lib.id);
      _changed = true;
      if (!mounted) return;
      setState(() => _lib = null);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _pickStatus() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Definir status',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600)),
            ),
            for (final s in GameStatus.values)
              ListTile(
                leading: Icon(_statusIcon(s), color: _statusColor(s)),
                title: Text(s.label,
                    style: const TextStyle(color: AppColors.textPrimary)),
                trailing: _lib?.status == s
                    ? const Icon(Icons.check, color: AppColors.accent)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  if (_lib == null) {
                    _add(s);
                  } else {
                    _patch({'status': s.api});
                  }
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(g?.name ?? widget.fallback?.name ?? 'Jogo',
              style: const TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ),
        body: _loading && g == null
            ? const Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppColors.accent)))
            : _error != null && g == null
                ? _errorView()
                : _content(g!),
      ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(_error ?? 'Erro',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
      );

  Widget _content(Game g) {
    final year = g.releaseYear;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: GameCover(url: g.coverUrl ?? widget.fallback?.coverUrl),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.name,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (g.rating > 0)
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 16, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Text('${g.rating.toStringAsFixed(0)}/100',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  if (year != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Lançamento: $year',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                    ),
                  if (g.playtimeLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule,
                              size: 14, color: AppColors.neonCyan),
                          const SizedBox(width: 4),
                          Text('${g.playtimeLabel} p/ zerar',
                              style: const TextStyle(
                                  color: AppColors.neonCyan, fontSize: 13)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  if (g.platforms.isNotEmpty)
                    _chips(g.platforms, AppColors.neonBlue),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _libraryCard(),
        const SizedBox(height: 16),
        if (g.timeToBeat > 0 ||
            g.timeHastily > 0 ||
            g.timeCompletely > 0) ...[
          _sectionTitle('Tempo para zerar'),
          const SizedBox(height: 8),
          _playtimeCard(g),
          const SizedBox(height: 16),
        ],
        if (g.genres.isNotEmpty) ...[
          _sectionTitle('Gêneros'),
          const SizedBox(height: 8),
          _chips(g.genres, AppColors.neonPurple),
          const SizedBox(height: 16),
        ],
        if (g.summary.isNotEmpty) ...[
          _sectionTitle('Resumo'),
          const SizedBox(height: 8),
          Text(g.summary,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
          const SizedBox(height: 16),
        ],
        if (g.companies.isNotEmpty) ...[
          _sectionTitle('Desenvolvedoras'),
          const SizedBox(height: 8),
          Text(g.companies.join(', '),
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
        ],
      ],
    );
  }

  Widget _playtimeCard(Game g) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _playtimeItem('Correndo', g.timeHastily, AppColors.neonCyan),
          _playtimeDivider(),
          _playtimeItem('História', g.timeToBeat, AppColors.accent),
          _playtimeDivider(),
          _playtimeItem('100%', g.timeCompletely, AppColors.neonPurple),
        ],
      ),
    );
  }

  Widget _playtimeItem(String label, int seconds, Color color) {
    final txt = formatPlaytime(seconds) ?? '—';
    return Expanded(
      child: Column(
        children: [
          Icon(Icons.schedule, size: 18, color: color),
          const SizedBox(height: 6),
          Text(txt,
              style: TextStyle(
                  color: color, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _playtimeDivider() => Container(
        width: 1,
        height: 40,
        color: AppColors.glassBorder,
      );

  Widget _libraryCard() {
    final lib = _lib;
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lib == null) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _pickStatus,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar à biblioteca'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                const Text('Status',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 13)),
                const Spacer(),
                ActionChip(
                  avatar: Icon(_statusIcon(lib.status),
                      size: 16, color: _statusColor(lib.status)),
                  label: Text(lib.status.label,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 13)),
                  backgroundColor: AppColors.backgroundAlt,
                  onPressed: _busy ? null : _pickStatus,
                ),
              ],
            ),
            const Divider(color: AppColors.glassBorder, height: 24),
            const Text('Sua nota',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 6),
            _ratingStars(lib.userRating),
            const Divider(color: AppColors.glassBorder, height: 24),
            _notesField(lib.notes),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _busy ? null : _confirmRemove,
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.error, size: 18),
                label: const Text('Remover da biblioteca',
                    style: TextStyle(color: AppColors.error)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ratingStars(int rating) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(10, (i) {
        final v = i + 1;
        return GestureDetector(
          onTap: _busy
              ? null
              : () => _patch({'user_rating': v == rating ? 0 : v}),
          child: Icon(
            v <= rating ? Icons.star : Icons.star_border,
            size: 24,
            color: v <= rating ? AppColors.warning : AppColors.textMuted,
          ),
        );
      }),
    );
  }

  Widget _notesField(String initial) {
    final ctrl = TextEditingController(text: initial);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Notas',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: 3,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Anotações pessoais...',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.backgroundAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) => _patch({'notes': v}),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _busy ? null : () => _patch({'notes': ctrl.text}),
            child: const Text('Salvar nota',
                style: TextStyle(color: AppColors.accent)),
          ),
        ),
      ],
    );
  }

  void _confirmRemove() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Remover jogo',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Remover este jogo da sua biblioteca?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _remove();
            },
            child: const Text('Remover',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600));

  Widget _chips(List<String> items, Color color) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: items
            .map((e) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(e,
                      style: TextStyle(color: color, fontSize: 12)),
                ))
            .toList(),
      );

  static IconData _statusIcon(GameStatus s) {
    switch (s) {
      case GameStatus.wishlist:
        return Icons.favorite_border;
      case GameStatus.backlog:
        return Icons.inventory_2_outlined;
      case GameStatus.playing:
        return Icons.sports_esports;
      case GameStatus.done:
        return Icons.check_circle_outline;
      case GameStatus.dropped:
        return Icons.cancel_outlined;
    }
  }

  static Color _statusColor(GameStatus s) {
    switch (s) {
      case GameStatus.wishlist:
        return AppColors.neonPurple;
      case GameStatus.backlog:
        return AppColors.neonBlue;
      case GameStatus.playing:
        return AppColors.neonCyan;
      case GameStatus.done:
        return AppColors.success;
      case GameStatus.dropped:
        return AppColors.error;
    }
  }
}
