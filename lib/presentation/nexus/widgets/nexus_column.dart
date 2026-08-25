import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../data/models/nexus_models.dart';
import 'nexus_card.dart';

/// Coluna Kanban — header sticky + lista de cards + DragTarget.
/// Cada coluna representa um `status` (todo, doing, standby, done, project).
class NexusColumn extends StatelessWidget {
  final String statusId;
  final List<NexusItem> items;
  final bool isDragOver;
  final bool isWork;
  final void Function(NexusItem item)? onCardTap;
  final void Function(NexusItem item)? onToggle;
  final void Function(NexusItem item, String newStatus)? onDrop;
  final Set<String> loadingIds;

  const NexusColumn({
    super.key,
    required this.statusId,
    required this.items,
    this.isDragOver = false,
    required this.isWork,
    this.onCardTap,
    this.onToggle,
    this.onDrop,
    this.loadingIds = const {},
  });

  @override
  Widget build(BuildContext context) {
    final color = NexusKanban.colorOf(statusId);
    final label = NexusKanban.labelOf(statusId);
    final icon = NexusKanban.iconOf(statusId);
    final count = items.length;

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDragOver ? color.withOpacity(0.55) : AppColors.glassBorder,
          width: isDragOver ? 1.2 : 0.5,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 16, offset: const Offset(0, 6)),
          if (isDragOver) BoxShadow(color: color.withOpacity(0.12), blurRadius: 20, spreadRadius: 1),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // HEADER sticky
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
            decoration: BoxDecoration(
              color: isDragOver ? color.withOpacity(0.10) : AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: color.withOpacity(0.35), width: 2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.3), width: 0.5),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
                      const SizedBox(height: 1),
                      Text(
                        count == 0 ? 'vazio' : '$count ${count == 1 ? 'item' : 'itens'}',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: count == 0 ? AppColors.surfaceLight : color.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: count == 0 ? AppColors.glassBorder : color.withOpacity(0.35)),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: count == 0 ? AppColors.textMuted : color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // BODY lista
          Expanded(
            child: DragTarget<NexusItem>(
              onWillAcceptWithDetails: (details) => details.data.status != statusId,
              onAcceptWithDetails: (details) => onDrop?.call(details.data, statusId),
              builder: (context, candidate, rejected) {
                final hovering = candidate.isNotEmpty;
                return Container(
                  decoration: BoxDecoration(
                    color: hovering ? color.withOpacity(0.05) : Colors.transparent,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                  child: items.isEmpty
                      ? _emptyState(color, label, hovering)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final it = items[i];
                            final isLoading = loadingIds.contains(it.id);
                            final card = _draggableCard(it, isLoading);
                            // Se estiver carregando, mostra overlay
                            if (isLoading) {
                              return Stack(
                                children: [
                                  Opacity(opacity: 0.6, child: card),
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(color: AppColors.surface.withOpacity(0.3), borderRadius: BorderRadius.circular(14)),
                                      child: const Center(child: CupertinoActivityIndicator(radius: 10)),
                                    ),
                                  ),
                                ],
                              );
                            }
                            return card;
                          },
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _draggableCard(NexusItem it, bool isLoading) {
    // Se estiver em done, permite arrastar de volta também.
    return LongPressDraggable<NexusItem>(
      data: it,
      delay: const Duration(milliseconds: 140),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 300,
          child: NexusCard(item: it, onTap: () {}, isDragging: true, showHandle: false),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: NexusCard(item: it, onTap: () {}, isDragging: true),
      ),
      child: NexusCard(
        item: it,
        onTap: () => onCardTap?.call(it),
        onToggleDone: isLoading ? null : () => onToggle?.call(it),
      ),
    );
  }

  Widget _emptyState(Color color, String label, bool hovering) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: hovering ? color.withOpacity(0.12) : AppColors.surfaceLight.withOpacity(0.6),
                shape: BoxShape.circle,
                border: Border.all(color: hovering ? color.withOpacity(0.4) : AppColors.glassBorder, width: 0.5),
              ),
              child: Icon(
                hovering ? Icons.move_to_inbox_rounded : CupertinoIcons.tray,
                size: 26,
                color: hovering ? color : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              hovering ? 'Soltar aqui' : 'Nenhum item',
              style: TextStyle(
                color: hovering ? color : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hovering ? 'Mover para $label' : 'Arraste um card para cá\nou crie um novo.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5, height: 1.4),
            ),
            if (!hovering && isWork) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 12, color: color),
                    const SizedBox(width: 4),
                    Text('Arraste para mover', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
