import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../core/ui_log.dart';
import '../../data/arcadia_service.dart';
import '../../data/models/game.dart';
import 'game_detail_screen.dart';
import 'news_screen.dart';
import 'widgets/game_cover.dart';

enum _ArcadiaMode { library, search, news }

/// Aba Nova Arcadia — Video Games Tracker (IGDB + biblioteca pessoal).
class ArcadiaScreen extends StatefulWidget {
  const ArcadiaScreen({super.key});

  @override
  State<ArcadiaScreen> createState() => _ArcadiaScreenState();
}

class _ArcadiaScreenState extends State<ArcadiaScreen>
    with SingleTickerProviderStateMixin {
  final _svc = ArcadiaService();
  final _searchCtrl = TextEditingController();

  // Abas da biblioteca por categoria (label, status; null = todos).
  static const List<(String, GameStatus?)> _tabs = [
    ('Todos', null),
    ('Jogando', GameStatus.playing),
    ('Backlog', GameStatus.backlog),
    ('Zerado', GameStatus.done),
    ('Desejos', GameStatus.wishlist),
    ('Abandonado', GameStatus.dropped),
  ];

  late final TabController _tab;

  _ArcadiaMode _mode = _ArcadiaMode.library;

  List<Game> _results = [];
  List<LibraryGame> _library = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
    _loadLibrary();
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLibrary() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lib = await _svc.listLibrary();
      if (!mounted) return;
      setState(() {
        _library = lib;
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

  Future<void> _search() async {
    final term = _searchCtrl.text.trim();
    if (term.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _svc.search(term);
      if (!mounted) return;
      setState(() {
        _results = res;
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

  Future<void> _openGame({Game? game, LibraryGame? lib}) async {
    final id = game?.id ?? lib!.igdbId;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GameDetailScreen(
          igdbId: id,
          fallback: game,
          library: lib,
        ),
      ),
    );
    if (changed == true) _loadLibrary();
  }

  int _countFor(GameStatus? status) {
    if (status == null) return _library.length;
    return _library.where((g) => g.status == status).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Nova Arcadia',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _modeToggle(),
            ...switch (_mode) {
              _ArcadiaMode.search => [
                  _searchBar(),
                  Expanded(child: _searchBody()),
                ],
              _ArcadiaMode.news => [
                  const Expanded(child: NewsView()),
                ],
              _ArcadiaMode.library => [
                  _libraryTabBar(),
                  Expanded(child: _libraryBody()),
                ],
            },
          ],
        ),
      ),
    );
  }

  Widget _modeToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _toggleBtn('Biblioteca', _mode == _ArcadiaMode.library, () {
            setState(() => _mode = _ArcadiaMode.library);
            _loadLibrary();
          }),
          const SizedBox(width: 8),
          _toggleBtn('Buscar', _mode == _ArcadiaMode.search, () {
            setState(() => _mode = _ArcadiaMode.search);
          }),
          const SizedBox(width: 8),
          _toggleBtn('Notícias', _mode == _ArcadiaMode.news, () {
            setState(() => _mode = _ArcadiaMode.news);
          }),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: _openMoonlight,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.neonPurple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.neonPurple),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.open_in_new, size: 14, color: AppColors.neonPurple),
                    SizedBox(width: 4),
                    Text(
                      'Moonlight',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.neonPurple,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _launchChannel = MethodChannel('nova/launch');

  Future<void> _openMoonlight() async {
    uiLog('Arcadia', 'Abrindo Moonlight...');
    const moonlightPackage = 'com.limelight';
    try {
      await _launchChannel.invokeMethod('launchPackage', {
        'packageName': moonlightPackage,
      });
    } on PlatformException catch (e) {
      uiLog('Arcadia', 'Moonlight não instalado: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moonlight não instalado. Instale pela Play Store.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          uiLog('Arcadia', 'aba selecionada: $label');
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.glassBorder,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _searchCtrl,
        textInputAction: TextInputAction.search,
        style: const TextStyle(color: AppColors.textPrimary),
        onSubmitted: (_) => _search(),
        decoration: InputDecoration(
          hintText: 'Buscar na IGDB...',
          hintStyle: const TextStyle(color: AppColors.textMuted),
          prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
          suffixIcon: IconButton(
            icon: const Icon(Icons.arrow_forward, color: AppColors.accent),
            onPressed: _search,
          ),
          filled: true,
          fillColor: AppColors.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _libraryTabBar() {
    return TabBar(
      controller: _tab,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      indicatorColor: AppColors.accent,
      indicatorSize: TabBarIndicatorSize.label,
      labelColor: AppColors.accent,
      unselectedLabelColor: AppColors.textSecondary,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 13),
      dividerColor: AppColors.glassBorder,
      tabs: [
        for (final t in _tabs) Tab(text: '${t.$1} (${_countFor(t.$2)})'),
      ],
    );
  }

  Widget _libraryBody() {
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
          onPressed: _loadLibrary,
          child: const Text('Tentar novamente',
              style: TextStyle(color: AppColors.accent)),
        ),
      );
    }
    return TabBarView(
      controller: _tab,
      children: [for (final t in _tabs) _libGrid(t.$2)],
    );
  }

  Widget _libGrid(GameStatus? status) {
    final items = status == null
        ? _library
        : _library.where((g) => g.status == status).toList();
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadLibrary,
        color: AppColors.accent,
        backgroundColor: AppColors.card,
        child: ListView(
          children: [
            const SizedBox(height: 64),
            _emptyState(
              icon: CupertinoIcons.gamecontroller,
              title: status == null ? 'Biblioteca vazia' : 'Nada aqui',
              subtitle: status == null
                  ? 'Use "Buscar Jogos" para adicionar títulos.'
                  : 'Nenhum jogo com este status ainda.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadLibrary,
      color: AppColors.accent,
      backgroundColor: AppColors.card,
      child: _grid(items.length, (i) => _cell(lib: items[i])),
    );
  }

  Widget _searchBody() {
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
          onPressed: _search,
          child: const Text('Tentar novamente',
              style: TextStyle(color: AppColors.accent)),
        ),
      );
    }
    if (_results.isEmpty) {
      return _emptyState(
        icon: CupertinoIcons.search,
        title: 'Buscar jogos',
        subtitle: 'Digite o nome de um jogo para buscar na IGDB.',
      );
    }
    return _grid(_results.length, (i) => _cell(game: _results[i]));
  }

  Widget _grid(int count, Widget Function(int) builder) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.52,
      ),
      itemCount: count,
      itemBuilder: (_, i) => builder(i),
    );
  }

  Widget _cell({Game? game, LibraryGame? lib}) {
    final name = game?.name ?? lib!.name;
    final coverUrl = game?.coverUrl ?? lib?.coverUrl;
    final status = lib?.status;
    final playtime = game?.playtimeLabel ?? lib?.playtimeLabel;
    return GestureDetector(
      onTap: () => _openGame(game: game, lib: lib),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: GameCover(url: coverUrl)),
                if (status != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        GameDetailStatusIcon.of(status),
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (playtime != null)
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule,
                              size: 10, color: AppColors.neonCyan),
                          const SizedBox(width: 3),
                          Text(playtime,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12, height: 1.2),
          ),
        ],
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

/// Ícone do status (compartilhado com o detalhe).
class GameDetailStatusIcon {
  static IconData of(GameStatus s) {
    switch (s) {
      case GameStatus.wishlist:
        return Icons.favorite;
      case GameStatus.backlog:
        return Icons.inventory_2;
      case GameStatus.playing:
        return Icons.sports_esports;
      case GameStatus.done:
        return Icons.check_circle;
      case GameStatus.dropped:
        return Icons.cancel;
    }
  }
}
