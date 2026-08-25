import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../data/models/nexus_models.dart';
import 'nexus_column.dart';

/// Board Kanban horizontal — row de colunas com scroll.
/// Responsivo: largura coluna clamp 280–320, scroll horizontal com scrollbar.
class NexusBoard extends StatefulWidget {
  final Map<String, List<NexusItem>> grouped;
  final List<String> columnOrder;
  final bool isWork;
  final Set<String> loadingIds;
  final String? dragOverStatus;
  final void Function(NexusItem item) onCardTap;
  final void Function(NexusItem item) onToggle;
  final void Function(NexusItem item, String newStatus) onDrop;
  final ValueChanged<String> onDragOverChanged;

  const NexusBoard({
    super.key,
    required this.grouped,
    required this.columnOrder,
    required this.isWork,
    this.loadingIds = const {},
    this.dragOverStatus,
    required this.onCardTap,
    required this.onToggle,
    required this.onDrop,
    required this.onDragOverChanged,
  });

  @override
  State<NexusBoard> createState() => _NexusBoardState();
}

class _NexusBoardState extends State<NexusBoard> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Em telas muito estreitas, ainda horizontal com bounce.
        // Coluna 300 fixa garante densidade Jira/ClickUp, não empilha vertical.
        const gap = 12.0;

        // Se couber tudo, mantém left aligned com padding.
        return Scrollbar(
          controller: _scroll,
          thumbVisibility: true,
          trackVisibility: false,
          thickness: 6,
          radius: const Radius.circular(3),
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < widget.columnOrder.length; i++) ...[
                  SizedBox(
                    height: constraints.maxHeight - 16,
                    child: DragTarget<NexusItem>(
                      onWillAcceptWithDetails: (d) {
                        widget.onDragOverChanged(widget.columnOrder[i]);
                        return d.data.status != widget.columnOrder[i];
                      },
                      onLeave: (_) => widget.onDragOverChanged(''),
                      onAcceptWithDetails: (d) {
                        widget.onDragOverChanged('');
                        widget.onDrop(d.data, widget.columnOrder[i]);
                      },
                      builder: (ctx, cand, rej) {
                        final isOver = widget.dragOverStatus == widget.columnOrder[i] || cand.isNotEmpty;
                        final list = widget.grouped[widget.columnOrder[i]] ?? const [];
                        return NexusColumn(
                          statusId: widget.columnOrder[i],
                          items: list,
                          isDragOver: isOver,
                          isWork: widget.isWork,
                          onCardTap: widget.onCardTap,
                          onToggle: widget.onToggle,
                          onDrop: widget.onDrop,
                          loadingIds: widget.loadingIds,
                        );
                      },
                    ),
                  ),
                  if (i != widget.columnOrder.length - 1) const SizedBox(width: gap),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Fallback lista vertical (para workspace não-work, ex Rotina)
class NexusListView extends StatelessWidget {
  final List<NexusItem> items;
  final void Function(NexusItem) onCardTap;
  final void Function(NexusItem) onToggle;
  final Set<String> loadingIds;

  const NexusListView({
    super.key,
    required this.items,
    required this.onCardTap,
    required this.onToggle,
    this.loadingIds = const {},
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.glassBorder, width: 0.5),
                ),
                child: const Icon(Icons.note_outlined, size: 32, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              const Text('Nenhum item aqui ainda.', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text('Toque em + para criar sua primeira nota ou tarefa.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final it = items[i];
        final isLoading = loadingIds.contains(it.id);
        return Opacity(
          opacity: isLoading ? 0.6 : 1,
          child: Stack(
            children: [
              // Reusa card mas sem drag, com clique
              _SimpleCard(item: it, onTap: () => onCardTap(it), onToggle: () => onToggle(it)),
              if (isLoading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(color: AppColors.surface.withOpacity(0.4), borderRadius: BorderRadius.circular(14)),
                    child: const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SimpleCard extends StatelessWidget {
  final NexusItem item;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  const _SimpleCard({required this.item, required this.onTap, required this.onToggle});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(children: [
          Positioned(left: 0, top: 0, bottom: 0, child: Container(width: 3.5, color: item.statusColor)),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 10, 10, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: item.statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(item.statusIcon, size: 10, color: item.statusColor),
                        const SizedBox(width: 4),
                        Text(item.statusLabel.toUpperCase(), style: TextStyle(color: item.statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    const Spacer(),
                    if (item.isTask)
                      InkWell(
                        onTap: onToggle,
                        child: Icon(item.isDone ? Icons.check_circle : Icons.radio_button_unchecked, size: 20, color: item.isDone ? AppColors.success : AppColors.textMuted),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  Text(item.displayTitle.isEmpty ? '(sem título)' : item.displayTitle, style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600, decoration: item.isDone ? TextDecoration.lineThrough : null)),
                  if (item.body.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(item.body.replaceAll('\n', ' ').trim(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                  if (item.tags.isNotEmpty || item.dueDate != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (item.dueDate != null) _pill(Icons.event, item.dueDate!, item.isOverdue ? AppColors.error : AppColors.neonPurple),
                        ...item.tags.take(3).map((t) => _pill(Icons.tag, t, AppColors.neonBlue)),
                      ],
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _pill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 11, color: color), const SizedBox(width: 4), Text(text, style: TextStyle(color: color, fontSize: 11))]),
    );
  }
}
