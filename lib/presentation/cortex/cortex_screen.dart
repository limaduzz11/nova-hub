import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/theme.dart';
import '../../data/nexus_service.dart';
import 'graph_model.dart';
import 'graph_view.dart';

/// Aba Nova Cortex — grafo de conhecimento (Obsidian-like) com filtros e físicas.
class CortexScreen extends StatefulWidget {
  const CortexScreen({super.key});

  @override
  State<CortexScreen> createState() => _CortexScreenState();
}

class _CortexScreenState extends State<CortexScreen> {
  List<GraphNode> _nodes = const [];
  List<GraphEdge> _edges = const [];
  bool _loading = true;

  // Filtros
  final Set<String> _selectedGroups = {};
  final Set<String> _selectedTags = {};
  // Físicas (0-100%) — padrão: bola (repulsão + centrípeta no máx., links 21%)
  int _repelPct = 100; // repulsão
  int _linkForcePct = 21; // força das molas
  int _linkDistPct = 100; // distância das molas
  int _centriPct = 100; // força centrípeta
  bool _showFilters = false;
  String? _selectedId;
  bool _fromNetwork = false; // true = veio do backend; false = asset offline
  String? _error;

  double get _kRepel => _repelPct / 100 * 20000;
  double get _kSpring => _linkForcePct / 100 * 0.08;
  double get _rest => 20 + _linkDistPct / 100 * 280;
  double get _kCenter => _centriPct / 100 * 0.04;

  // Contagem de tags (para os chips)
  Map<String, int> _tagCounts = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _loading = true);
    VaultGraph graph;
    bool fromNetwork = false;
    String? err;
    try {
      // Fonte primária: backend Nexus (/api/graph) — grafo ao vivo do Vault.
      final data = await NexusService().fetchGraph();
      graph = VaultGraph.fromJson(data);
      fromNetwork = true;
    } catch (e) {
      // Fallback: asset embutido (modo offline / backend indisponível).
      err = e.toString();
      graph = await VaultGraph.loadAsset();
      fromNetwork = false;
    }
    if (!mounted) return;
    final counts = <String, int>{};
    for (final n in graph.nodes) {
      for (final t in n.tags) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    setState(() {
      _nodes = graph.nodes;
      _edges = graph.edges;
      _tagCounts = counts;
      _fromNetwork = fromNetwork;
      _error = fromNetwork ? null : err;
      _loading = false;
    });
  }

  List<GraphNode> get _visibleNodes {
    return _nodes.where((n) {
      if (_selectedGroups.isNotEmpty && !_selectedGroups.contains(n.group)) {
        return false;
      }
      if (_selectedTags.isNotEmpty &&
          !n.tags.any((t) => _selectedTags.contains(t))) {
        return false;
      }
      return true;
    }).toList();
  }

  List<GraphEdge> get _visibleEdges {
    final ids = _visibleNodes.map((n) => n.id).toSet();
    return _edges
        .where((e) => ids.contains(e.from) && ids.contains(e.to))
        .toList();
  }

  bool get _hasFilters =>
      _selectedGroups.isNotEmpty || _selectedTags.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final visible = _visibleNodes;
    final selected = visible.where((n) => n.id == _selectedId).isEmpty
        ? null
        : visible.firstWhere((n) => n.id == _selectedId);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Nova Cortex',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.accent),
                  )
                : const Icon(Icons.refresh, color: AppColors.accent),
            onPressed: _loading ? null : () => _load(force: true),
            tooltip: 'Sincronizar grafo',
          ),
          IconButton(
            icon: Icon(
              Icons.filter_alt_outlined,
              color: _hasFilters ? AppColors.accent : AppColors.accent,
            ),
            onPressed: () => setState(() => _showFilters = !_showFilters),
            tooltip: 'Filtros',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: AppColors.accent),
            onPressed: () => _showHelp(context),
            tooltip: 'Como usar',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : Stack(
              children: [
                GraphView(
                  nodes: visible,
                  edges: _visibleEdges,
                  selectedId: selected?.id,
                  initialScale: 0.27, // equivale a 7x zoom-out (0.83^7)
                  repelStrength: _kRepel,
                  linkStrength: _kSpring,
                  linkDistance: _rest,
                  centripetalStrength: _kCenter,
                  onSelect: (id) {
                    setState(() => _selectedId = id);
                    if (id != null) {
                      final node = visible.where((n) => n.id == id).isEmpty
                          ? null
                          : visible.firstWhere((n) => n.id == id);
                      if (node != null) _openNote(node);
                    }
                  },
                ),

                // Painel de filtros (topo)
                if (_showFilters)
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.72,
                      ),
                      child: _FilterPanel(
                        selectedGroups: _selectedGroups,
                        selectedTags: _selectedTags,
                        tagCounts: _tagCounts,
                        repelPct: _repelPct,
                        linkForcePct: _linkForcePct,
                        linkDistPct: _linkDistPct,
                        centriPct: _centriPct,
                        onToggleGroup: (g) => setState(() {
                          _selectedGroups.contains(g)
                              ? _selectedGroups.remove(g)
                              : _selectedGroups.add(g);
                        }),
                        onToggleTag: (t) => setState(() {
                          _selectedTags.contains(t)
                              ? _selectedTags.remove(t)
                              : _selectedTags.add(t);
                        }),
                        onRepel: (v) => setState(() => _repelPct = v),
                        onLinkForce: (v) => setState(() => _linkForcePct = v),
                        onLinkDist: (v) => setState(() => _linkDistPct = v),
                        onCentri: (v) => setState(() => _centriPct = v),
                        onClear: _clearFilters,
                      ),
                    ),
                  ),

                // Contador de nós visíveis
                if (!_showFilters)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: GlassContainer(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Tooltip(
                            message: _fromNetwork
                                ? 'Grafo sincronizado (backend)'
                                : 'Offline — usando cópia embutida',
                            child: Icon(
                              _fromNetwork ? Icons.cloud_done : Icons.cloud_off,
                              size: 13,
                              color: _fromNetwork
                                  ? AppColors.neonCyan
                                  : AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${visible.length} / ${_nodes.length} nós',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedGroups.clear();
      _selectedTags.clear();
      _repelPct = 100;
      _linkForcePct = 21;
      _linkDistPct = 100;
      _centriPct = 100;
    });
  }

  void _openNote(GraphNode node) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scroll) => GlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.all(0),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: AppColors.glassBorder,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: graphColor(node.group),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        node.label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.glassBorder, height: 1),
              if (node.tags.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: node.tags
                        .map((t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: AppColors.backgroundAlt,
                                border:
                                    Border.all(color: AppColors.glassBorder),
                              ),
                              child: Text(
                                '#$t',
                                style: const TextStyle(
                                  color: AppColors.neonCyan,
                                  fontSize: 11,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              Expanded(
                child: Markdown(
                  data: node.content ?? '_Sem conteúdo._',
                  controller: scroll,
                  padding: const EdgeInsets.all(16),
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(color: AppColors.textSecondary, height: 1.5),
                    h1: const TextStyle(color: AppColors.textPrimary, fontSize: 22),
                    h2: const TextStyle(color: AppColors.textPrimary, fontSize: 19),
                    h3: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                    code: TextStyle(
                      color: AppColors.neonCyan,
                      backgroundColor: AppColors.backgroundAlt,
                    ),
                    a: const TextStyle(color: AppColors.accent),
                    listBullet: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Nova Cortex', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          '• Arraste o fundo para navegar (pan).\n'
          '• Pinça ou os botões para zoom.\n'
          '• Arraste um nó para repositioná-lo.\n'
          '• Toque em um nó para abrir a nota.\n'
          '• Filtros (tags e grupos) no ícone de filtro.\n'
          '• Ajuste repulsão, links, distância e centrípeta para moldar o grafo (padrão forma uma bola).',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }
}

/// Painel de filtros + físicas (Obsidian-like): órfãos, grupos, tags e forças.
class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.selectedGroups,
    required this.selectedTags,
    required this.tagCounts,
    required this.repelPct,
    required this.linkForcePct,
    required this.linkDistPct,
    required this.centriPct,
    required this.onToggleGroup,
    required this.onToggleTag,
    required this.onRepel,
    required this.onLinkForce,
    required this.onLinkDist,
    required this.onCentri,
    required this.onClear,
  });

  final Set<String> selectedGroups;
  final Set<String> selectedTags;
  final Map<String, int> tagCounts;
  final int repelPct;
  final int linkForcePct;
  final int linkDistPct;
  final int centriPct;
  final ValueChanged<String> onToggleGroup;
  final ValueChanged<String> onToggleTag;
  final ValueChanged<int> onRepel;
  final ValueChanged<int> onLinkForce;
  final ValueChanged<int> onLinkDist;
  final ValueChanged<int> onCentri;
  final VoidCallback onClear;

  static const _groups = [
    ('root', 'Raiz'),
    ('hub', 'Hub'),
    ('knowledge', 'Conhecimento'),
    ('skill', 'Skill'),
    ('memory', 'Memória'),
    ('project', 'Projeto'),
  ];

  Widget _slider(String label, int value, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            Text('$value%',
                style: const TextStyle(color: AppColors.accent, fontSize: 12)),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: 100,
          divisions: 100,
          activeColor: AppColors.accent,
          inactiveColor: AppColors.glassBorder,
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topTags = tags.take(24).toList();

    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(14),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Filtros & Física',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(
                  onPressed: onClear,
                  child: const Text('Redefinir',
                      style: TextStyle(color: AppColors.accent, fontSize: 12)),
                ),
              ],
            ),
            const Divider(color: AppColors.glassBorder, height: 16),
            const Text('Físicas',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 2),
            _slider('Força de repulsão', repelPct, onRepel),
            _slider('Força dos links', linkForcePct, onLinkForce),
            _slider('Distância dos links', linkDistPct, onLinkDist),
            _slider('Força centrípeta', centriPct, onCentri),
            const Divider(color: AppColors.glassBorder, height: 16),
            const Text('Grupos',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _groups.map((g) {
                final active = selectedGroups.contains(g.$1);
                return FilterChip(
                  label: Text(g.$2),
                  selected: active,
                  onSelected: (_) => onToggleGroup(g.$1),
                  backgroundColor: AppColors.backgroundAlt,
                  selectedColor: graphColor(g.$1).withOpacity(0.25),
                  checkmarkColor: AppColors.textPrimary,
                  labelStyle: TextStyle(
                    color: active ? AppColors.textPrimary : AppColors.textMuted,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                    color: active ? graphColor(g.$1) : AppColors.glassBorder,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            const Text('Tags',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 6),
            if (topTags.isEmpty)
              const Text('Nenhuma tag encontrada.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: topTags.map((e) {
                  final active = selectedTags.contains(e.key);
                  return FilterChip(
                    label: Text('#${e.key} (${e.value})'),
                    selected: active,
                    onSelected: (_) => onToggleTag(e.key),
                    backgroundColor: AppColors.backgroundAlt,
                    selectedColor: AppColors.accent.withOpacity(0.2),
                    checkmarkColor: AppColors.textPrimary,
                    labelStyle: TextStyle(
                      color: active ? AppColors.textPrimary : AppColors.textMuted,
                      fontSize: 11,
                    ),
                    side: BorderSide(
                      color: active ? AppColors.accent : AppColors.glassBorder,
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
