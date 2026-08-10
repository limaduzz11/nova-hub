import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../core/theme.dart';
import 'app_tabs.dart';

/// Barra de navegação inferior com efeito Glassmorphism (estilo iOS).
///
/// - Fundo desfocado (BackdropFilter) com borda suave e brilho interno neon.
/// - Aba selecionada: ícone ampliado (scale), cor de destaque e leve glow.
/// - Abas inativas: opacidade reduzida (sutis), seguindo o comportamento iOS.
/// - Flutuante (margens laterais + inferior) com elevação via BoxShadow.
class NovaBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const NovaBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        // Margens laterais e inferior => visual flutuante / semi-flutuante
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: AppColors.glassBorder,
            width: 0.5,
          ),
          boxShadow: [
            // Brilho interno + elevação neon
            BoxShadow(
              color: AppColors.primary.withOpacity(0.28),
              blurRadius: 26,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.glass,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: AppTabs.tabs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final tab = entry.value;
                  return _NavItem(
                    tab: tab,
                    selected: index == currentIndex,
                    onTap: () => onTap(index),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Item individual da barra (ícone + label) com animação de seleção.
class _NavItem extends StatelessWidget {
  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.textMuted;

    return Expanded(
      child: Semantics(
        label: tab.label,
        button: true,
        selected: selected,
        onTap: onTap,
        child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glow suave atrás do ícone quando selecionado
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 40,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? AppColors.accent.withOpacity(0.16)
                      : Colors.transparent,
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.5),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: AnimatedScale(
                    scale: selected ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      tab.icon,
                      size: 24,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
                child: Text(tab.label),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
