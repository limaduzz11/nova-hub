import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/theme.dart';
import '../../data/models/nexus_models.dart';
import '../../data/nexus_service.dart';
import 'nexus_settings_screen.dart';
import 'widgets/nexus_summary.dart';
import 'widgets/nexus_toolbar.dart';
import 'widgets/nexus_board.dart';

/// NOVA Nexus — Centro operacional Kanban.
/// Evolução visual/UX mantendo contratos, identidade NOVA HUB e backend intactos.
class NexusScreen extends StatefulWidget {
  const NexusScreen({super.key});

  @override
  State<NexusScreen> createState() => _NexusScreenState();
}

class _NexusScreenState extends State<NexusScreen> {
  final NexusService _service = NexusService();

  List<NexusWorkspace> _workspaces = [];
  List<NexusItem> _items = [];
  String? _selectedWs;
  bool _loading = true;
  bool _offline = false;
  String? _error;

  // ── Filtros / Toolbar ──
  final TextEditingController _searchCtrl = TextEditingController();
  String _severityFilter = ''; // '' | alta | media | baixa
  String _typeFilter = ''; // '' | requisição | incidente
  NexusSort _sort = NexusSort.recent;
  bool _showOnlyOverdue = false;

  // Drag state
  String _dragOverStatus = '';
  final Set<String> _loadingIds = {};

  // Compat: mantido para editor default, mas não mais usado como tab única.
  String _workFilter = 'todo';

  NexusWorkspace? get _currentWs {
    for (final w in _workspaces) {
      if (w.id == _selectedWs) return w;
    }
    return null;
  }

  bool get _isWork => _currentWs?.kind == 'work';

  /// Itens filtrados por busca + severidade + tipo + overdue + ordenação.
  List<NexusItem> get _filteredItems {
    var list = List<NexusItem>.from(_items);

    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((it) {
        final hay = [
          it.title,
          it.displayTitle,
          it.body,
          it.tags.join(' '),
          it.clientTag ?? '',
          it.qualitorId ?? '',
          it.typeTag ?? '',
          it.severityTag ?? '',
          it.shortId,
          it.statusLabel,
        ].join(' ').toLowerCase();
        return hay.contains(q);
      }).toList();
    }
    if (_severityFilter.isNotEmpty) {
      list = list.where((it) => it.severityNormalized.contains(_severityFilter)).toList();
    }
    if (_typeFilter.isNotEmpty) {
      list = list.where((it) => (it.typeTag ?? '').toLowerCase().contains(_typeFilter)).toList();
    }
    if (_showOnlyOverdue) {
      list = list.where((it) => it.isOverdue).toList();
    }

    // Ordenação
    switch (_sort) {
      case NexusSort.recent:
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case NexusSort.oldest:
        list.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        break;
      case NexusSort.titleAZ:
        list.sort((a, b) => a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase()));
        break;
      case NexusSort.dueDate:
        list.sort((a, b) {
          final da = a.dueDateParsed;
          final db = b.dueDateParsed;
          if (da == null && db == null) return b.updatedAt.compareTo(a.updatedAt);
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
        });
        break;
      case NexusSort.priority:
        int rank(NexusItem it) {
          if (it.isDone) return 99;
          if (it.isHighPriority) return 0;
          if (it.isMediumPriority) return 1;
          if (it.isLowPriority) return 2;
          if ((it.typeTag ?? '').toLowerCase().contains('incidente')) return 3;
          return 4;
        }
        list.sort((a, b) {
          final ra = rank(a), rb = rank(b);
          if (ra != rb) return ra.compareTo(rb);
          return b.updatedAt.compareTo(a.updatedAt);
        });
        break;
    }
    return list;
  }

  /// Agrupa filtrados por status, normalizando legados (concluded→done, none→todo).
  Map<String, List<NexusItem>> get _grouped {
    final map = <String, List<NexusItem>>{
      for (final id in NexusKanban.order) id: [],
    };
    for (final it in _filteredItems) {
      var s = it.status;
      if (s == 'concluded' || s == 'encerrado') s = 'done';
      if (s == 'none' || s.isEmpty) s = 'todo';
      if (!map.containsKey(s)) s = 'todo';
      map[s]!.add(it);
    }
    return map;
  }

  List<String> get _columnOrder {
    if (!_isWork) return NexusKanban.order;
    // Sempre 5 para manter compatibilidade com _workTabs originais; board lida com vazio elegante.
    return NexusKanban.order;
  }

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ws = await _service.listWorkspaces();
      _workspaces = ws;
      _offline = false;
      _selectedWs ??= ws.isNotEmpty ? ws.first.id : null;
      if (_selectedWs != null) {
        _items = await _service.listItems(_selectedWs!);
      }
    } catch (_) {
      _offline = true;
      _workspaces = await _service.cachedWorkspaces();
      _selectedWs ??= _workspaces.isNotEmpty ? _workspaces.first.id : null;
      if (_selectedWs != null) {
        _items = await _service.cachedItems(_selectedWs!);
      }
      if (_workspaces.isEmpty) {
        _error = 'Sem conexão com o backend Nexus.';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectWorkspace(String id) async {
    setState(() {
      _selectedWs = id;
      _workFilter = 'todo';
      _loading = true;
      _searchCtrl.clear();
      _severityFilter = '';
      _typeFilter = '';
      _showOnlyOverdue = false;
      _sort = NexusSort.recent;
    });
    try {
      _items = await _service.listItems(id);
      _offline = false;
    } catch (_) {
      _offline = true;
      _items = await _service.cachedItems(id);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openSettings() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NexusSettingsScreen()),
    );
    if (changed == true) _bootstrap();
  }

  Future<void> _toggleTask(NexusItem it) async {
    if (_loadingIds.contains(it.id)) return;
    final newStatus = it.isDone ? 'todo' : 'done';
    setState(() => _loadingIds.add(it.id));
    // otimismo local
    final idx = _items.indexWhere((e) => e.id == it.id);
    NexusItem? backup;
    if (idx != -1) {
      backup = _items[idx];
      _items[idx] = NexusItem(
        id: backup.id,
        workspaceId: backup.workspaceId,
        parentId: backup.parentId,
        type: backup.type,
        title: backup.title,
        body: backup.body,
        status: newStatus,
        tags: backup.tags,
        dueDate: backup.dueDate,
        position: backup.position,
        timeSpent: backup.timeSpent,
        createdAt: backup.createdAt,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      );
      setState(() {});
    }
    try {
      await _service.updateItem(it.id, {'status': newStatus});
      if (_selectedWs != null) _items = await _service.listItems(_selectedWs!);
      if (mounted) setState(() => _loadingIds.remove(it.id));
    } catch (e) {
      // rollback
      if (idx != -1 && backup != null) {
        _items[idx] = backup;
      }
      if (mounted) setState(() => _loadingIds.remove(it.id));
      _snack('Falha ao atualizar: $e', error: true);
    }
  }

  Future<void> _moveItem(NexusItem it, String newStatus) async {
    if (it.status == newStatus) return;
    if (_loadingIds.contains(it.id)) return;
    setState(() {
      _loadingIds.add(it.id);
      _dragOverStatus = '';
    });
    // otimismo: atualiza localmente
    final idx = _items.indexWhere((e) => e.id == it.id);
    NexusItem? backup;
    if (idx != -1) {
      backup = _items[idx];
      _items[idx] = NexusItem(
        id: backup.id,
        workspaceId: backup.workspaceId,
        parentId: backup.parentId,
        type: backup.type,
        title: backup.title,
        body: backup.body,
        status: newStatus,
        tags: backup.tags,
        dueDate: backup.dueDate,
        position: backup.position,
        timeSpent: backup.timeSpent,
        createdAt: backup.createdAt,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      );
      setState(() {});
    }
    try {
      await _service.updateItem(it.id, {'status': newStatus});
      if (_selectedWs != null) {
        _items = await _service.listItems(_selectedWs!);
      }
      if (mounted) {
        setState(() => _loadingIds.remove(it.id));
        _snack('Movido para ${NexusKanban.labelOf(newStatus)}');
      }
    } catch (e) {
      // rollback visual
      if (idx != -1 && backup != null) {
        _items[idx] = backup;
      } else {
        try {
          if (_selectedWs != null) _items = await _service.cachedItems(_selectedWs!);
        } catch (_) {}
      }
      if (mounted) {
        setState(() => _loadingIds.remove(it.id));
        _snack('Falha ao mover: $e', error: true);
      }
    }
  }

  Future<void> _deleteItem(NexusItem it) async {
    try {
      await _service.deleteItem(it.id);
      _items.removeWhere((e) => e.id == it.id);
      if (mounted) setState(() {});
      _snack('Item excluído');
    } catch (e) {
      _snack('Falha ao excluir: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 13)),
        backgroundColor: (error ? AppColors.error : AppColors.success).withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _offline ? AppColors.warning : AppColors.success,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: (_offline ? AppColors.warning : AppColors.success).withOpacity(0.5), blurRadius: 6, spreadRadius: 1),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text('Nova Nexus', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.3)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
              child: const Text('KANBAN', style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
            ),
          ],
        ),
        actions: [
          if (_offline)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.cloud_off, color: AppColors.warning, size: 20),
            ),
          IconButton(icon: const Icon(Icons.refresh, color: AppColors.textSecondary), onPressed: _bootstrap, tooltip: 'Atualizar'),
          IconButton(icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary), onPressed: _openSettings, tooltip: 'Configurar'),
        ],
      ),
      floatingActionButton: _selectedWs == null
          ? null
          : FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: () => _openEditor(),
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading && _workspaces.isEmpty) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_error != null && _workspaces.isEmpty) {
      return Center(
        child: GlassContainer(
          padding: const EdgeInsets.all(28),
          margin: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 56, color: AppColors.warning),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _openSettings, child: const Text('Configurar')),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        _buildWorkspaceBar(),
        // Resumo operacional
        NexusSummary(items: _filteredItems.isEmpty && _searchCtrl.text.isEmpty && _severityFilter.isEmpty && _typeFilter.isEmpty && !_showOnlyOverdue ? _items : _filteredItems, isWork: _isWork),
        // Toolbar centralizada
        NexusToolbar(
          searchCtrl: _searchCtrl,
          severityFilter: _severityFilter,
          typeFilter: _typeFilter,
          sort: _sort,
          showOnlyOverdue: _showOnlyOverdue,
          onSearchChanged: (v) => setState(() {}),
          onSeverityChanged: (v) => setState(() => _severityFilter = v),
          onTypeChanged: (v) => setState(() => _typeFilter = v),
          onSortChanged: (v) => setState(() => _sort = v),
          onOverdueChanged: (v) => setState(() => _showOnlyOverdue = v),
          onClear: () => setState(() {
            _searchCtrl.clear();
            _severityFilter = '';
            _typeFilter = '';
            _showOnlyOverdue = false;
            _sort = NexusSort.recent;
          }),
          filteredCount: _filteredItems.length,
          totalCount: _items.length,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _bootstrap,
            color: AppColors.primary,
            backgroundColor: AppColors.card,
            child: _loading
                ? const Center(child: CupertinoActivityIndicator())
                : _isWork
                    ? _buildKanban()
                    : NexusListView(
                        items: _filteredItems,
                        onCardTap: _openDetail,
                        onToggle: _toggleTask,
                        loadingIds: _loadingIds,
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildKanban() {
    final grouped = _grouped;
    final cols = _columnOrder;
    // Se busca filtra tudo, mostra empty central
    if (_filteredItems.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 96),
        children: [
          const Icon(CupertinoIcons.search, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Center(child: Text('Nenhum item corresponde aos filtros.', style: TextStyle(color: AppColors.textMuted))),
          const SizedBox(height: 8),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => setState(() {
                _searchCtrl.clear();
                _severityFilter = '';
                _typeFilter = '';
                _showOnlyOverdue = false;
              }),
              icon: const Icon(Icons.filter_alt_off, size: 16),
              label: const Text('Limpar filtros'),
            ),
          ),
        ],
      );
    }
    return NexusBoard(
      grouped: grouped,
      columnOrder: cols,
      isWork: _isWork,
      loadingIds: _loadingIds,
      dragOverStatus: _dragOverStatus,
      onCardTap: _openDetail,
      onToggle: _toggleTask,
      onDrop: _moveItem,
      onDragOverChanged: (s) => setState(() => _dragOverStatus = s),
    );
  }

  Widget _buildWorkspaceBar() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          ..._workspaces.map((w) {
            final sel = w.id == _selectedWs;
            final color = _wsColor(w);
            // Para workspace atual, mostra count total; para outros, sem count
            final label = sel ? '${w.name}  •  ${_filteredItems.length}/${_items.length}' : w.name;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: sel,
                onSelected: (_) => _selectWorkspace(w.id),
                labelStyle: TextStyle(
                  color: sel ? Colors.white : AppColors.textSecondary,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 13,
                ),
                backgroundColor: AppColors.card,
                selectedColor: color,
                side: BorderSide(color: color.withOpacity(sel ? 0 : 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            );
          }),
          ActionChip(
            avatar: const Icon(Icons.add, size: 16, color: AppColors.neonBlue),
            label: const Text('Workspace'),
            labelStyle: const TextStyle(color: AppColors.neonBlue, fontSize: 13),
            backgroundColor: AppColors.card,
            side: BorderSide(color: AppColors.neonBlue.withOpacity(0.4)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            onPressed: _createWorkspaceDialog,
          ),
        ],
      ),
    );
  }

  Color _wsColor(NexusWorkspace w) {
    if (w.color.isNotEmpty) {
      final hex = w.color.replaceAll('#', '');
      final v = int.tryParse('FF$hex', radix: 16);
      if (v != null) return Color(v);
    }
    return AppColors.primary;
  }

  // ---------------- Detail ----------------

  void _openDetail(NexusItem it) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        maxChildSize: 0.92,
        builder: (_, scroll) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: ListView(
            controller: scroll,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              // Header meta
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: it.statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: it.statusColor.withOpacity(0.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(it.statusIcon, size: 14, color: it.statusColor),
                      const SizedBox(width: 4),
                      Text(it.statusLabel, style: TextStyle(color: it.statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  if (it.isQualitor && it.qualitorId != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: it.severityColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: Text('#${it.qualitorId}', style: TextStyle(color: it.severityColor, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(it.displayTitle.isEmpty ? '(sem título)' : it.displayTitle,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700, height: 1.3)),
              const SizedBox(height: 8),
              // Meta grid
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (it.clientLabel.isNotEmpty) _detailPill(Icons.business_outlined, it.clientLabel, AppColors.neonPurple),
                  if (it.severityLabel.isNotEmpty) _detailPill(Icons.flag_outlined, it.severityLabel, it.severityColor),
                  if (it.typeTag != null) _detailPill(Icons.category_outlined, it.typeTag!, AppColors.neonBlue),
                  if (it.dueDate != null) _detailPill(Icons.event_outlined, it.dueDate!, it.isOverdue ? AppColors.error : AppColors.neonPurple),
                  if (it.updatedShort.isNotEmpty) _detailPill(CupertinoIcons.clock, 'Atualizado ${it.updatedShort}', AppColors.textMuted),
                  _detailPill(it.isTask ? Icons.task_alt : CupertinoIcons.doc_text, it.isTask ? 'Tarefa' : 'Nota', AppColors.neonCyan),
                ],
              ),
              if (it.tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: it.tags.map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.backgroundAlt, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.glassBorder)),
                    child: Text(t, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  )).toList(),
                ),
              ],
              const Divider(height: 28, color: AppColors.glassBorder),
              if (it.body.trim().isEmpty)
                const Text('(sem conteúdo)', style: TextStyle(color: AppColors.textMuted))
              else
                MarkdownBody(
                  data: it.body,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                    h1: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                    h2: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                    h3: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                    code: const TextStyle(color: AppColors.neonCyan, fontSize: 13),
                    blockquote: const TextStyle(color: AppColors.textMuted, fontStyle: FontStyle.italic),
                    listBullet: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              const SizedBox(height: 24),
              // Ações rápidas de status (Kanban)
              if (_isWork) ...[
                const Text('Mover para', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: NexusKanban.order.map((sid) {
                    final sel = it.status == sid;
                    final col = NexusKanban.colorOf(sid);
                    final lab = NexusKanban.labelOf(sid);
                    return ChoiceChip(
                      label: Text(lab),
                      selected: sel,
                      onSelected: sel ? null : (_) {
                        Navigator.pop(context);
                        _moveItem(it, sid);
                      },
                      labelStyle: TextStyle(color: sel ? Colors.white : AppColors.textSecondary, fontWeight: sel ? FontWeight.w700 : FontWeight.w400, fontSize: 12),
                      backgroundColor: AppColors.backgroundAlt,
                      selectedColor: col,
                      side: BorderSide(color: col.withOpacity(sel ? 0 : 0.35)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openEditor(existing: it);
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Editar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.neonBlue,
                        side: BorderSide(color: AppColors.neonBlue.withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteItem(it);
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Excluir'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error.withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ---------------- Editor (create/update) ----------------

  void _openEditor({NexusItem? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final bodyCtrl = TextEditingController(text: existing?.body ?? '');
    final tagsCtrl = TextEditingController(text: existing?.tags.join(', ') ?? '');
    final dueCtrl = TextEditingController(text: existing?.dueDate ?? '');
    String type = existing?.type ?? 'task';
    String status = existing?.status ?? (_isWork ? _workFilter : 'todo');
    bool saving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(existing == null ? 'Novo item' : 'Editar item', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'task', label: Text('Tarefa'), icon: Icon(Icons.check_circle_outline, size: 16)),
                    ButtonSegment(value: 'note', label: Text('Nota'), icon: Icon(CupertinoIcons.doc_text, size: 16)),
                  ],
                  selected: {type},
                  onSelectionChanged: (s) => setSheet(() => type = s.first),
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? Colors.white : AppColors.textSecondary),
                    backgroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? AppColors.primary : AppColors.backgroundAlt),
                  ),
                ),
                if (_isWork) ...[
                  const SizedBox(height: 16),
                  const Text('Situação', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: NexusKanban.order.map((sid) {
                      final lab = NexusKanban.labelOf(sid);
                      final sel = status == sid;
                      final color = NexusKanban.colorOf(sid);
                      return ChoiceChip(
                        label: Text(lab),
                        selected: sel,
                        onSelected: (_) => setSheet(() => status = sid),
                        labelStyle: TextStyle(color: sel ? Colors.white : AppColors.textSecondary, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, fontSize: 12),
                        backgroundColor: AppColors.backgroundAlt,
                        selectedColor: color,
                        side: BorderSide(color: color.withOpacity(sel ? 0 : 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 16),
                _sheetField(titleCtrl, 'Título'),
                const SizedBox(height: 12),
                _sheetField(bodyCtrl, 'Conteúdo (markdown)', maxLines: 5),
                const SizedBox(height: 12),
                _sheetField(tagsCtrl, 'Tags (separadas por vírgula)'),
                const SizedBox(height: 12),
                _sheetField(dueCtrl, 'Prazo (AAAA-MM-DD, opcional)'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (titleCtrl.text.trim().isEmpty) {
                              _snack('Informe um título', error: true);
                              return;
                            }
                            setSheet(() => saving = true);
                            final tags = tagsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                            try {
                              final effStatus = _isWork ? status : (type == 'task' ? 'todo' : 'none');
                              if (existing == null) {
                                await _service.createItem(workspaceId: _selectedWs!, type: type, title: titleCtrl.text.trim(), body: bodyCtrl.text, status: effStatus, tags: tags, dueDate: dueCtrl.text.trim());
                                if (_isWork) _workFilter = effStatus;
                              } else {
                                await _service.updateItem(existing.id, {'type': type, 'title': titleCtrl.text.trim(), 'body': bodyCtrl.text, if (_isWork) 'status': effStatus, 'tags': tags, 'due_date': dueCtrl.text.trim()});
                                if (_isWork) _workFilter = effStatus;
                              }
                              if (_selectedWs != null) _items = await _service.listItems(_selectedWs!);
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) setState(() {});
                              _snack(existing == null ? 'Item criado' : 'Item atualizado');
                            } catch (e) {
                              setSheet(() => saving = false);
                              _snack('Falha: $e', error: true);
                            }
                          },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: saving ? const CupertinoActivityIndicator(color: Colors.white) : Text(existing == null ? 'Criar' : 'Salvar', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetField(TextEditingController c, String hint, {int maxLines = 1}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        filled: true,
        fillColor: AppColors.backgroundAlt,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.glassBorder, width: 0.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.glassBorder, width: 0.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Future<void> _createWorkspaceDialog() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Novo Workspace', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: TextField(controller: ctrl, autofocus: true, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(hintText: 'Nome', hintStyle: TextStyle(color: AppColors.textMuted))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Criar')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      final ws = await _service.createWorkspace(name: name);
      _workspaces.add(ws);
      await _selectWorkspace(ws.id);
      _snack('Workspace criado');
    } catch (e) {
      _snack('Falha: $e', error: true);
    }
  }
}
