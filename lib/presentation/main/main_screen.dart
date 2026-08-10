import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/ui_log.dart';
import '../../data/alert_service.dart';
import 'app_tabs.dart';
import 'nova_bottom_nav_bar.dart';

/// Tela principal do NOVA HUB.
///
/// Implementa a navegação por 4 abas inferiores (Glassmorphism) com:
/// - [IndexedStack] para manter o estado de cada aba viva (melhor performance).
/// - Um [Navigator] próprio por aba (nested navigation), permitindo navegação
///   interna (ex.: abrir SSH a partir do Nova Link) sem perder a bottom bar.
/// - Toque na aba já selecionada => volta ao topo da pilha daquela aba.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Um NavigatorState por aba, para navegação aninhada independente.
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    AppTabs.tabs.length,
    (_) => GlobalKey<NavigatorState>(),
  );

  @override
  void initState() {
    super.initState();
    AlertService.instance.start();
  }

  void _onTap(int index) {
    uiLog('MainNav', 'aba inferior=$index (${AppTabs.tabs[index].label})');
    if (index == _currentIndex) {
      // Já está na aba: volta ao início da pilha dela.
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() => _currentIndex = index);
    }
  }

  /// Constrói o Navigator raiz de cada aba.
  Widget _buildTab(int index) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => AppTabs.tabs[index].screen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Fundo galáctico compartilhado por todas as abas
          Positioned.fill(
            child: Opacity(
              opacity: 0.35,
              child: const GalaxyAnimation(),
            ),
          ),
          // Todas as abas ficam montadas (IndexedStack) preservando estado
          IndexedStack(
            index: _currentIndex,
            children: List.generate(
              AppTabs.tabs.length,
              (i) => _buildTab(i),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NovaBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTap,
      ),
    );
  }
}
