import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../data/models/nexus_models.dart';

/// Resumo operacional do board — camada superior do Kanban.
/// Mostra contadores por status com cor semântica, estilo glass.
class NexusSummary extends StatelessWidget {
  final List<NexusItem> items;
  final bool isWork;

  const NexusSummary({super.key, required this.items, required this.isWork});

  @override
  Widget build(BuildContext context) {
    final total = items.length;
    final todo = items.where((e) => e.status == 'todo').length;
    final doing = items.where((e) => e.status == 'doing').length;
    final standby = items.where((e) => e.status == 'standby').length;
    final done = items.where((e) => e.status == 'done').length;
    final project = items.where((e) => e.status == 'project').length;
    final overdue = items.where((e) => e.isOverdue).length;
    final high = items.where((e) => e.isHighPriority && !e.isDone).length;

    // Se não for work, mostra resumo genérico.
    if (!isWork) {
      return _wrap([
        _cell('Total', total, Icons.layers_outlined, AppColors.neonBlue, total > 0),
        _cell('Tarefas', items.where((e) => e.isTask).length, Icons.check_circle_outline, AppColors.success, true),
        _cell('Notas', items.where((e) => !e.isTask).length, Icons.note_outlined, AppColors.neonCyan, true),
        if (overdue > 0) _cell('Atrasados', overdue, Icons.warning_amber_rounded, AppColors.error, true),
      ]);
    }

    return _wrap([
      _cell('Total', total, Icons.dashboard_outlined, AppColors.primary, true),
      _cell('Na Fila', todo, Icons.inbox_outlined, AppColors.neonBlue, todo > 0 || total == 0),
      _cell('Atuando', doing, Icons.play_circle_outline, AppColors.warning, doing > 0),
      _cell('StandBy', standby, Icons.pause_circle_outline, AppColors.textMuted, standby > 0),
      _cell('Concluído', done, Icons.check_circle_outline, AppColors.success, done > 0),
      if (project > 0) _cell('Projetos', project, Icons.folder_outlined, AppColors.neonPurple, true),
      if (overdue > 0) _cell('Atrasados', overdue, Icons.error_outline, AppColors.error, true),
      if (high > 0) _cell('Prioritários', high, Icons.flag_outlined, AppColors.error, true),
    ]);
  }

  Widget _wrap(List<Widget> children) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }

  Widget _cell(String label, int count, IconData icon, Color color, bool active) {
    final show = active;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: show ? color.withOpacity(0.10) : AppColors.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: show ? color.withOpacity(0.35) : AppColors.glassBorder.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: show ? color.withOpacity(0.18) : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: show ? color : AppColors.textMuted),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  color: show ? AppColors.textPrimary : AppColors.textMuted,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: show ? color : AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
