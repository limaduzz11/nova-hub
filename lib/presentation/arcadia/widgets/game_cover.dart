import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Capa de jogo com placeholder e loading. Usada nos grids do Arcadia.
class GameCover extends StatelessWidget {
  const GameCover({
    super.key,
    required this.url,
    this.borderRadius = 12,
  });

  final String? url;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: url == null
            ? _placeholder()
            : Image.network(
                url!,
                fit: BoxFit.cover,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return _placeholder(loading: true);
                },
                errorBuilder: (_, __, ___) => _placeholder(),
              ),
      ),
    );
  }

  Widget _placeholder({bool loading = false}) {
    return Container(
      color: AppColors.card,
      child: Center(
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.accent),
                ),
              )
            : Icon(CupertinoIcons.gamecontroller,
                size: 32, color: AppColors.textMuted),
      ),
    );
  }
}
