import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../home/home_screen.dart';
import '../arcadia/arcadia_screen.dart';
import '../cortex/cortex_screen.dart';
import '../nexus/nexus_screen.dart';

/// Metadados de uma aba da navegação inferior.
class AppTab {
  final String label;
  final IconData icon;
  final Widget screen;

  const AppTab({
    required this.label,
    required this.icon,
    required this.screen,
  });
}

/// Definição das 4 abas do NOVA HUB (ordem = índice de navegação).
///
/// [0] Nova Link  -> acesso remoto (tela já existente, vira a aba padrão)
/// [1] Arcadia    -> Video Games Tracker (placeholder)
/// [2] Cortex     -> grafo de conhecimento (Obsidian-like)
/// [3] Nexus      -> Hub de anotações PKM (placeholder)
class AppTabs {
  static final List<AppTab> tabs = [
    AppTab(
      label: 'Nova Link',
      icon: CupertinoIcons.globe,
      screen: const HomeScreen(),
    ),
    AppTab(
      label: 'Arcadia',
      icon: CupertinoIcons.gamecontroller,
      screen: const ArcadiaScreen(),
    ),
    AppTab(
      label: 'Cortex',
      // Icons.psychology = cérebro (Material, garante disponibilidade)
      icon: Icons.psychology,
      screen: const CortexScreen(),
    ),
    AppTab(
      label: 'Nexus',
      icon: CupertinoIcons.doc_text,
      screen: const NexusScreen(),
    ),
  ];
}
