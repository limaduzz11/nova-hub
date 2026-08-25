import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/theme.dart';

/// Toolbar centralizada do Kanban — busca + filtros + ordenação.
/// Mantém estado local via callbacks, sem persistência por enquanto.
enum NexusSort { recent, oldest, titleAZ, dueDate, priority }

class NexusToolbar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String severityFilter; // '' = todos, 'alta'|'media'|'baixa'
  final String typeFilter; // '' = todos, 'requisição'|'incidente' etc.
  final NexusSort sort;
  final bool showOnlyOverdue;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSeverityChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<NexusSort> onSortChanged;
  final ValueChanged<bool> onOverdueChanged;
  final VoidCallback onClear;
  final int filteredCount;
  final int totalCount;

  const NexusToolbar({
    super.key,
    required this.searchCtrl,
    required this.severityFilter,
    required this.typeFilter,
    required this.sort,
    required this.showOnlyOverdue,
    required this.onSearchChanged,
    required this.onSeverityChanged,
    required this.onTypeChanged,
    required this.onSortChanged,
    required this.onOverdueChanged,
    required this.onClear,
    required this.filteredCount,
    required this.totalCount,
  });

  bool get hasActiveFilters =>
      searchCtrl.text.isNotEmpty ||
      severityFilter.isNotEmpty ||
      typeFilter.isNotEmpty ||
      showOnlyOverdue ||
      sort != NexusSort.recent;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Linha 1: Busca + contador
          Row(
            children: [
              Expanded(child: _searchField()),
              const SizedBox(width: 10),
              _counter(),
              if (hasActiveFilters) ...[
                const SizedBox(width: 8),
                _clearBtn(),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // Linha 2: Filtros + Ordenação (scroll horizontal)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('Todas severidades', severityFilter.isEmpty, () => onSeverityChanged('')),
                _filterChip('Alta', severityFilter == 'alta', () => onSeverityChanged(severityFilter == 'alta' ? '' : 'alta'), color: AppColors.error),
                _filterChip('Média', severityFilter == 'media', () => onSeverityChanged(severityFilter == 'media' ? '' : 'media'), color: AppColors.warning),
                _filterChip('Baixa', severityFilter == 'baixa', () => onSeverityChanged(severityFilter == 'baixa' ? '' : 'baixa'), color: AppColors.success),
                Container(width: 1, height: 24, color: AppColors.glassBorder, margin: const EdgeInsets.symmetric(horizontal: 8)),
                _filterChip('Todos tipos', typeFilter.isEmpty, () => onTypeChanged('')),
                _filterChip('Requisição', typeFilter == 'requisição', () => onTypeChanged(typeFilter == 'requisição' ? '' : 'requisição'), color: AppColors.neonBlue),
                _filterChip('Incidente', typeFilter == 'incidente', () => onTypeChanged(typeFilter == 'incidente' ? '' : 'incidente'), color: AppColors.errorLight),
                Container(width: 1, height: 24, color: AppColors.glassBorder, margin: const EdgeInsets.symmetric(horizontal: 8)),
                _overdueChip(),
                Container(width: 1, height: 24, color: AppColors.glassBorder, margin: const EdgeInsets.symmetric(horizontal: 8)),
                _sortMenu(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: searchCtrl,
        onChanged: onSearchChanged,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Buscar tarefa, cliente, #ID…',
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          prefixIcon: const Icon(CupertinoIcons.search, size: 18, color: AppColors.textMuted),
          suffixIcon: searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: AppColors.textMuted),
                  onPressed: () {
                    searchCtrl.clear();
                    onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.backgroundAlt,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.glassBorder, width: 0.5)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.glassBorder, width: 0.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1)),
        ),
      ),
    );
  }

  Widget _counter() {
    final isFiltered = filteredCount != totalCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isFiltered ? AppColors.primary.withOpacity(0.15) : AppColors.backgroundAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isFiltered ? AppColors.primary.withOpacity(0.4) : AppColors.glassBorder, width: 0.5),
      ),
      child: Text(
        isFiltered ? '$filteredCount de $totalCount' : '$totalCount itens',
        style: TextStyle(
          color: isFiltered ? AppColors.primary : AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _clearBtn() {
    return InkWell(
      onTap: onClear,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.error.withOpacity(0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_off, size: 14, color: AppColors.error),
            SizedBox(width: 4),
            Text('Limpar', style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap, {Color? color}) {
    final c = color ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          fontSize: 11.5,
        ),
        backgroundColor: AppColors.backgroundAlt,
        selectedColor: c,
        side: BorderSide(color: c.withOpacity(selected ? 0 : 0.35)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }

  Widget _overdueChip() {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.error),
            SizedBox(width: 4),
            Text('Atrasados'),
          ],
        ),
        selected: showOnlyOverdue,
        onSelected: onOverdueChanged,
        labelStyle: TextStyle(
          color: showOnlyOverdue ? Colors.white : AppColors.textSecondary,
          fontWeight: showOnlyOverdue ? FontWeight.w600 : FontWeight.w400,
          fontSize: 11.5,
        ),
        backgroundColor: AppColors.backgroundAlt,
        selectedColor: AppColors.error,
        side: BorderSide(color: AppColors.error.withOpacity(showOnlyOverdue ? 0 : 0.35)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }

  Widget _sortMenu() {
    const labels = {
      NexusSort.recent: 'Recentes',
      NexusSort.oldest: 'Antigos',
      NexusSort.titleAZ: 'A–Z',
      NexusSort.dueDate: 'Prazo',
      NexusSort.priority: 'Prioridade',
    };
    return PopupMenuButton<NexusSort>(
      onSelected: onSortChanged,
      color: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.backgroundAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(labels[sort]!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textMuted),
          ],
        ),
      ),
      itemBuilder: (_) => labels.entries.map((e) {
        final sel = e.key == sort;
        return PopupMenuItem<NexusSort>(
          value: e.key,
          child: Row(
            children: [
              Icon(sel ? Icons.check : Icons.circle_outlined, size: 16, color: sel ? AppColors.primary : AppColors.textMuted),
              const SizedBox(width: 8),
              Text(e.value, style: TextStyle(color: sel ? AppColors.primary : AppColors.textSecondary, fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
