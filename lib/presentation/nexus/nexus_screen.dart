import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/theme.dart';
import '../../data/models/nexus_models.dart';
import '../../data/nexus_service.dart';
import 'nexus_settings_screen.dart';

/// Aba Nova Nexus — Hub de anotações/tarefas (Workspaces: Rotina, Work).
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

  // Mini-abas do workspace "Work" (label, status).
  static const List<(String, String)> _workTabs = [
    ('A Fazer', 'todo'),
    ('Em Andamento', 'doing'),
    ('Concluído', 'done'),
    ('Projetos', 'project'),
    ('StandBy', 'standby'),
  ];
  String _workFilter = 'todo';

  NexusWorkspace? get _currentWs {
    for (final w in _workspaces) {
      if (w.id == _selectedWs) return w;
    }
    return null;
  }

  bool get _isWork => _currentWs?.kind == 'work';

  /// Itens visíveis: no Work, filtra pela mini-aba ativa; senão, todos.
  List<NexusItem> get _visibleItems {
    if (!_isWork) return _items;
    return _items.where((it) => it.status == _workFilter).toList();
  }

  int _countForStatus(String status) =>
      _items.where((it) => it.status == status).length;

  @override
  void initState() {
    super.initState();
    _bootstrap();
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
    final newStatus = it.isDone ? 'todo' : 'done';
    try {
      await _service.updateItem(it.id, {'status': newStatus});
      if (_selectedWs != null) _items = await _service.listItems(_selectedWs!);
      if (mounted) setState(() {});
    } catch (e) {
      _snack('Falha ao atualizar: $e', error: true);
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
        backgroundColor:
            (error ? AppColors.error : AppColors.success).withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        title: const Text(
          'Nova Nexus',
          style: TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_offline)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.cloud_off,
                  color: AppColors.warning, size: 20),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: _bootstrap,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: AppColors.textSecondary),
            onPressed: _openSettings,
          ),
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
              const Icon(Icons.cloud_off,
                  size: 56, color: AppColors.warning),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _openSettings,
                child: const Text('Configurar'),
              ),
            ],
          ),
        ),
      );
    }
    final items = _visibleItems;
    return Column(
      children: [
        _buildWorkspaceBar(),
        if (_isWork) _buildWorkTabs(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _bootstrap,
            color: AppColors.primary,
            backgroundColor: AppColors.card,
            child: _loading
                ? const Center(child: CupertinoActivityIndicator())
                : items.isEmpty
                    ? _emptyItems()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: items.length,
                        itemBuilder: (_, i) => _itemCard(items[i]),
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkTabs() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: _workTabs.map((t) {
          final label = t.$1;
          final status = t.$2;
          final sel = _workFilter == status;
          final count = _countForStatus(status);
          final color = _statusColor(status);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(count > 0 ? '$label ($count)' : label),
              selected: sel,
              onSelected: (_) => setState(() => _workFilter = status),
              labelStyle: TextStyle(
                color: sel ? Colors.white : AppColors.textSecondary,
                fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                fontSize: 12,
              ),
              backgroundColor: AppColors.card,
              selectedColor: color,
              side: BorderSide(color: color.withOpacity(sel ? 0 : 0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'todo':
        return AppColors.neonBlue;
      case 'doing':
        return AppColors.warning;
      case 'done':
        return AppColors.success;
      case 'project':
        return AppColors.neonPurple;
      case 'standby':
        return AppColors.textMuted;
      default:
        return AppColors.primary;
    }
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
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(w.name),
                selected: sel,
                onSelected: (_) => _selectWorkspace(w.id),
                labelStyle: TextStyle(
                  color: sel ? Colors.white : AppColors.textSecondary,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 13,
                ),
                backgroundColor: AppColors.card,
                selectedColor: color,
                side: BorderSide(color: color.withOpacity(sel ? 0 : 0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            );
          }),
          ActionChip(
            avatar: const Icon(Icons.add, size: 16, color: AppColors.neonBlue),
            label: const Text('Workspace'),
            labelStyle:
                const TextStyle(color: AppColors.neonBlue, fontSize: 13),
            backgroundColor: AppColors.card,
            side: BorderSide(color: AppColors.neonBlue.withOpacity(0.4)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onPressed: _createWorkspaceDialog,
          ),
        ],
      ),
    );
  }

  Widget _emptyItems() {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(CupertinoIcons.tray, size: 56, color: AppColors.textMuted),
        const SizedBox(height: 16),
        const Center(
          child: Text('Nenhum item aqui ainda.\nToque em + para criar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, height: 1.5)),
        ),
      ],
    );
  }

  Widget _itemCard(NexusItem it) {
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetail(it),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (it.isTask)
              GestureDetector(
                onTap: () => _toggleTask(it),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, right: 10),
                  child: Icon(
                    it.isDone
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: it.isDone
                        ? AppColors.success
                        : AppColors.textSecondary,
                    size: 22,
                  ),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 2, right: 10),
                child: Icon(CupertinoIcons.doc_text,
                    color: AppColors.neonCyan, size: 20),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    it.title.isEmpty ? '(sem título)' : it.title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration:
                          it.isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (it.body.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        it.body.replaceAll('\n', ' ').trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                    ),
                  if (it.tags.isNotEmpty || it.dueDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (it.dueDate != null)
                            _pill(Icons.event, it.dueDate!,
                                AppColors.neonPurple),
                          ...it.tags.map((t) =>
                              _pill(Icons.tag, t, AppColors.neonBlue)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 11)),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, scroll) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scroll,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    it.isTask
                        ? Icons.check_circle_outline
                        : CupertinoIcons.doc_text,
                    color: AppColors.neonCyan,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      it.title.isEmpty ? '(sem título)' : it.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (it.tags.isNotEmpty || it.dueDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (it.dueDate != null)
                        _pill(Icons.event, it.dueDate!, AppColors.neonPurple),
                      ...it.tags
                          .map((t) => _pill(Icons.tag, t, AppColors.neonBlue)),
                    ],
                  ),
                ),
              const Divider(height: 28, color: AppColors.glassBorder),
              if (it.body.trim().isEmpty)
                const Text('(sem conteúdo)',
                    style: TextStyle(color: AppColors.textMuted))
              else
                MarkdownBody(
                  data: it.body,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 14),
                    h1: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                    h2: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold),
                    code: const TextStyle(
                        color: AppColors.neonCyan, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 24),
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
                        side: BorderSide(
                            color: AppColors.neonBlue.withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                        side:
                            BorderSide(color: AppColors.error.withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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

  // ---------------- Editor (create/update) ----------------

  void _openEditor({NexusItem? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final bodyCtrl = TextEditingController(text: existing?.body ?? '');
    final tagsCtrl =
        TextEditingController(text: existing?.tags.join(', ') ?? '');
    final dueCtrl = TextEditingController(text: existing?.dueDate ?? '');
    String type = existing?.type ?? 'task';
    String status = existing?.status ?? (_isWork ? _workFilter : 'todo');
    bool saving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  existing == null ? 'Novo item' : 'Editar item',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'task',
                        label: Text('Tarefa'),
                        icon: Icon(Icons.check_circle_outline, size: 16)),
                    ButtonSegment(
                        value: 'note',
                        label: Text('Nota'),
                        icon: Icon(CupertinoIcons.doc_text, size: 16)),
                  ],
                  selected: {type},
                  onSelectionChanged: (s) => setSheet(() => type = s.first),
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.resolveWith((st) =>
                        st.contains(WidgetState.selected)
                            ? Colors.white
                            : AppColors.textSecondary),
                    backgroundColor: WidgetStateProperty.resolveWith((st) =>
                        st.contains(WidgetState.selected)
                            ? AppColors.primary
                            : AppColors.backgroundAlt),
                  ),
                ),
                if (_isWork) ...[
                  const SizedBox(height: 16),
                  const Text('Situação',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _workTabs.map((t) {
                      final sel = status == t.$2;
                      final color = _statusColor(t.$2);
                      return ChoiceChip(
                        label: Text(t.$1),
                        selected: sel,
                        onSelected: (_) => setSheet(() => status = t.$2),
                        labelStyle: TextStyle(
                          color: sel ? Colors.white : AppColors.textSecondary,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 12,
                        ),
                        backgroundColor: AppColors.backgroundAlt,
                        selectedColor: color,
                        side: BorderSide(
                            color: color.withOpacity(sel ? 0 : 0.4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
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
                            final tags = tagsCtrl.text
                                .split(',')
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .toList();
                            try {
                              final effStatus = _isWork
                                  ? status
                                  : (type == 'task' ? 'todo' : 'none');
                              if (existing == null) {
                                await _service.createItem(
                                  workspaceId: _selectedWs!,
                                  type: type,
                                  title: titleCtrl.text.trim(),
                                  body: bodyCtrl.text,
                                  status: effStatus,
                                  tags: tags,
                                  dueDate: dueCtrl.text.trim(),
                                );
                                if (_isWork) _workFilter = effStatus;
                              } else {
                                await _service.updateItem(existing.id, {
                                  'type': type,
                                  'title': titleCtrl.text.trim(),
                                  'body': bodyCtrl.text,
                                  if (_isWork) 'status': effStatus,
                                  'tags': tags,
                                  'due_date': dueCtrl.text.trim(),
                                });
                                if (_isWork) _workFilter = effStatus;
                              }
                              if (_selectedWs != null) {
                                _items =
                                    await _service.listItems(_selectedWs!);
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) setState(() {});
                              _snack(existing == null
                                  ? 'Item criado'
                                  : 'Item atualizado');
                            } catch (e) {
                              setSheet(() => saving = false);
                              _snack('Falha: $e', error: true);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: saving
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : Text(existing == null ? 'Criar' : 'Salvar',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Future<void> _createWorkspaceDialog() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Novo Workspace',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Nome',
            hintStyle: TextStyle(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Criar'),
          ),
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
