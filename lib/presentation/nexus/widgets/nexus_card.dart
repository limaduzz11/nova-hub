import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../data/models/nexus_models.dart';

/// Card rico do Kanban — camada 1 (essencial) + camada 2 (hover/meta).
/// Mantém glassmorphism NOVA HUB, com faixa lateral por severidade e dots status.
class NexusCard extends StatelessWidget {
  final NexusItem item;
  final VoidCallback onTap;
  final VoidCallback? onToggleDone;
  final bool isDragging;
  final bool isDropTarget;
  final bool showHandle;

  const NexusCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onToggleDone,
    this.isDragging = false,
    this.isDropTarget = false,
    this.showHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    final qId = item.qualitorId;
    final isQ = item.isQualitor;
    final client = item.clientLabel;
    final sev = item.severityLabel;
    final isOverdue = item.isOverdue;
    final isSoon = item.isDueSoon;
    final sevColor = item.severityColor;
    final statusColor = item.statusColor;

    return Opacity(
      opacity: isDragging ? 0.55 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDropTarget ? statusColor.withOpacity(0.6) : AppColors.glassBorder,
            width: isDropTarget ? 1.2 : 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDropTarget ? statusColor.withOpacity(0.15) : Colors.black.withOpacity(0.18),
              blurRadius: isDropTarget ? 16 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              // Faixa lateral severidade/prioridade (3px)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 3.5, color: isQ ? sevColor : statusColor),
              ),
              // Conteúdo glass
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.surface.withOpacity(0.98),
                      AppColors.backgroundAlt.withOpacity(0.92),
                    ],
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(13, 10, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // HEADER: id + severidade + drag handle
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Qualitor badge ou tipo
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (isQ ? sevColor : AppColors.neonBlue).withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: (isQ ? sevColor : AppColors.neonBlue).withOpacity(0.25), width: 0.5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isQ ? CupertinoIcons.tag_fill : (item.isTask ? Icons.task_alt : CupertinoIcons.doc_text),
                                      size: 10,
                                      color: isQ ? sevColor : AppColors.neonBlue,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isQ ? (qId != null ? '#$qId' : item.shortId) : item.type.toUpperCase(),
                                      style: TextStyle(
                                        color: isQ ? sevColor : AppColors.neonBlue,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Severidade pill se houver
                              if (sev.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: sevColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: sevColor.withOpacity(0.3), width: 0.5),
                                  ),
                                  child: Text(
                                    sev.toUpperCase(),
                                    style: TextStyle(color: sevColor, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.4),
                                  ),
                                ),
                              const Spacer(),
                              // Tarefa checkbox
                              if (item.isTask && onToggleDone != null)
                                InkWell(
                                  onTap: onToggleDone,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: Icon(
                                      item.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                                      size: 18,
                                      color: item.isDone ? AppColors.success : AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              if (showHandle) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.drag_indicator, size: 14, color: AppColors.textMuted),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          // TÍTULO (2 linhas max)
                          Text(
                            item.displayTitle.isEmpty ? '(sem título)' : item.displayTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                              decoration: item.isDone ? TextDecoration.lineThrough : null,
                              decorationColor: AppColors.textMuted,
                            ),
                          ),
                          // BODY preview 1 linha se existir
                          if (item.body.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              // remove frontmatter para preview limpo
                              _cleanBodyPreview(item.body),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5, height: 1.3),
                            ),
                          ],
                          const SizedBox(height: 8),
                          // META: cliente + tipo + due
                          Wrap(
                            spacing: 6,
                            runSpacing: 5,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (client.isNotEmpty)
                                _metaPill(
                                  icon: Icons.business_outlined,
                                  label: client,
                                  color: AppColors.neonPurple,
                                ),
                              if (item.typeTag != null && item.typeTag!.isNotEmpty && !isQ)
                                _metaPill(icon: Icons.category_outlined, label: item.typeTag!, color: AppColors.neonBlue),
                              if (item.dueDate != null && item.dueDate!.isNotEmpty)
                                _metaPill(
                                  icon: Icons.event_outlined,
                                  label: item.dueDate!,
                                  color: isOverdue ? AppColors.error : (isSoon ? AppColors.warning : AppColors.neonPurple),
                                ),
                              if (isOverdue)
                                _metaPill(icon: Icons.warning_amber_rounded, label: 'ATRASADO', color: AppColors.error),
                              ...item.tags
                                  .where((t) => !t.startsWith('qualitor') && !t.toLowerCase().startsWith('cliente:') && !t.toLowerCase().startsWith('severidade:') && !t.toLowerCase().startsWith('tipo:') && t != 'qualitor')
                                  .take(2)
                                  .map((t) => _metaPill(icon: Icons.tag, label: t, color: AppColors.neonBlue)),
                            ],
                          ),
                          // FOOTER: atualização + posição
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(item.statusIcon, size: 12, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                item.statusLabel,
                                style: TextStyle(color: statusColor, fontSize: 10.5, fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              if (item.updatedShort.isNotEmpty) ...[
                                const Icon(CupertinoIcons.clock, size: 11, color: AppColors.textMuted),
                                const SizedBox(width: 3),
                                Text(item.updatedShort, style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Overlay arrastando indicação
              if (isDropTarget)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: statusColor.withOpacity(0.4), width: 1, style: BorderStyle.solid),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaPill({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label.length > 18 ? '${label.substring(0, 18)}…' : label,
            style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _cleanBodyPreview(String body) {
    var s = body.trim();
    // Se tiver frontmatter --- ... --- remove
    if (s.startsWith('---')) {
      final end = s.indexOf('\n---', 3);
      if (end != -1) s = s.substring(end + 4).trim();
    }
    // Remove markdown headers e blockquotes para preview
    s = s.replaceAll(RegExp(r'^#+\s*', multiLine: true), '');
    s = s.replaceAll(RegExp(r'^>\s*', multiLine: true), '');
    s = s.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.length > 80) s = '${s.substring(0, 80)}…';
    return s;
  }
}
