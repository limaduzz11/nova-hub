import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'graph_model.dart';

/// Cor do nó — toda a paleta é azul (escuro -> claro) conforme o grupo.
Color graphColor(String group) {
  switch (group) {
    case 'root':
      return const Color(0xFF1E3A8A); // azul escuro
    case 'hub':
      return const Color(0xFF1D4ED8); // azul
    case 'knowledge':
      return const Color(0xFF2563EB); // azul
    case 'skill':
      return const Color(0xFF3B82F6); // azul meio claro
    case 'memory':
      return const Color(0xFF60A5FA); // azul claro
    case 'project':
      return const Color(0xFF93C5FD); // azul bem claro
    default:
      return const Color(0xFF3B82F6);
  }
}

/// Grafo de conhecimento interativo estilo Obsidian.
///
/// Recursos:
/// - Simulação de físicas (repulsão de nós + molas nas arestas + centro).
/// - Pan (arrastar fundo), Zoom (pinça ou botões) e Drag de nós individuais.
/// - Seleção por toque -> destaca o nó e mostra o nome (via [onSelect]).
/// - Labels só para hubs (grau alto) ou nó selecionado (grafo grande).
/// - Físicas ajustáveis (repulsão, força/link distance das molas, centrípeta).
class GraphView extends StatefulWidget {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  /// Força de repulsão entre nós (Coulomb). 0 = nenhuma.
  final double repelStrength;
  /// Constante elástica das molas (atração das arestas). 0 = sem atração.
  final double linkStrength;
  /// Distância de repouso das molas (comprimento ideal da aresta).
  final double linkDistance;
  /// Força centrípeta (puxa os nós para o centro). 0 = espalha livre.
  final double centripetalStrength;

  /// Zoom inicial (escala da "câmera"). Padrão 1.0.
  final double initialScale;

  const GraphView({
    super.key,
    required this.nodes,
    required this.edges,
    this.selectedId,
    required this.onSelect,
    this.repelStrength = 9000,
    this.linkStrength = 0.02,
    this.linkDistance = 120,
    this.centripetalStrength = 0.01,
    this.initialScale = 1.0,
  });

  @override
  State<GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends State<GraphView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Transformação da "câmera" (visor)
  Offset _offset = Offset.zero;
  double _scale = 1.0;
  late final double _initialScale;

  // Estado de gesto
  String? _draggingId; // nó sendo arrastado (ou null)
  String? _gestureNodeId; // nó onde o gesto começou (p/ detectar toque)
  bool _dragMoved = false; // o gesto se moveu além do limite (arrasto vs toque)
  Offset _startFocal = Offset.zero; // focal global no início do gesto
  double _startScale = 1.0;
  Offset _startOffset = Offset.zero;
  bool _centered = false;
  late double _kRepel;
  late double _kSpring;
  late double _rest;
  late double _kCenter;

  // Física
  final Map<String, Offset> _velocities = {};
  final Map<String, Offset> _forces = {};

  final GlobalKey _areaKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initialScale = widget.initialScale;
    _scale = _initialScale;
    _syncForces();
    for (final n in widget.nodes) {
      _velocities[n.id] = Offset.zero;
      _forces[n.id] = Offset.zero;
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_tick);
    _controller.repeat();

    // Centraliza o grafo na primeira renderização
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _areaKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.size != Size.zero && mounted) {
        setState(() => _offset = Offset(box.size.width / 2, box.size.height / 2));
        _centered = true;
      }
    });
  }

  void _tick() {
    _stepSimulation();
    if (mounted) setState(() {});
  }

  void _syncForces() {
    _kRepel = widget.repelStrength;
    _kSpring = widget.linkStrength;
    _rest = widget.linkDistance;
    _kCenter = widget.centripetalStrength;
  }

  @override
  void didUpdateWidget(covariant GraphView old) {
    super.didUpdateWidget(old);
    if (old.repelStrength != widget.repelStrength ||
        old.linkStrength != widget.linkStrength ||
        old.linkDistance != widget.linkDistance ||
        old.centripetalStrength != widget.centripetalStrength) {
      _syncForces();
      _restartSim(); // re-settle com os novos parâmetros
    }
    // Se a lista de nós mudou (filtro), garante maps e reinicia
    if (old.nodes != widget.nodes) {
      for (final n in widget.nodes) {
        _velocities.putIfAbsent(n.id, () => Offset.zero);
        _forces.putIfAbsent(n.id, () => Offset.zero);
      }
      _restartSim();
    }
  }

  /// Passo da simulação de físicas (force-directed).
  void _stepSimulation() {
    if (_draggingId != null) return; // não simula enquanto arrasta um nó

    for (final n in widget.nodes) _forces[n.id] = Offset.zero;

    // Repulsão entre todos os pares (Coulomb)
    final kRepel = _kRepel;
    for (int i = 0; i < widget.nodes.length; i++) {
      for (int j = i + 1; j < widget.nodes.length; j++) {
        final a = widget.nodes[i];
        final b = widget.nodes[j];
        var d = a.position - b.position;
        double dist = d.distance;
        if (dist < 1) {
          d = Offset(Random().nextDouble() - 0.5, Random().nextDouble() - 0.5);
          dist = 1;
        }
        final f = kRepel / (dist * dist);
        final dir = d / dist;
        _forces[a.id] = _forces[a.id]! + dir * f;
        _forces[b.id] = _forces[b.id]! - dir * f;
      }
    }

    // Molas nas arestas (atração em direção ao comprimento de repouso)
    final rest = _rest;
    final kSpring = _kSpring;
    for (final e in widget.edges) {
      final a = _byId(e.from);
      final b = _byId(e.to);
      if (a == null || b == null) continue;
      final d = b.position - a.position;
      final dist = d.distance < 1 ? 1.0 : d.distance;
      final f = (dist - rest) * kSpring;
      final dir = d / dist;
      _forces[a.id] = _forces[a.id]! + dir * f;
      _forces[b.id] = _forces[b.id]! - dir * f;
    }

    // Força centrípeta (mantém o grafo coeso próximo à origem).
    // 0 = o grafo se espalha livremente (estilo Obsidian "Center force" off).
    final kCenter = _kCenter;
    for (final n in widget.nodes) {
      _forces[n.id] = _forces[n.id]! + (-n.position) * kCenter;
    }

    // Integração (com amortecimento)
    const maxVel = 50.0; // limita o salto por passo (evita "explosão" da física)
    const maxRadius = 4000.0; // mantém o grafo visível mesmo no zoom mínimo
    double energy = 0;
    for (final n in widget.nodes) {
      if (n.id == _draggingId) continue;
      var v = _velocities[n.id]! + _forces[n.id]!;
      v *= 0.85; // damping
      if (v.distance > maxVel) v = v * (maxVel / v.distance);
      _velocities[n.id] = v;
      n.position += v;
      // Trava os nós dentro de um raio visível (não somem da tela)
      final r = n.position.distance;
      if (r > maxRadius) n.position = n.position * (maxRadius / r);
      energy += v.distanceSquared;
    }

    // Para a simulação quando estabiliza (economy battery)
    if (energy < 0.4 && _draggingId == null) {
      _controller.stop();
    }
  }

  GraphNode? _byId(String id) {
    for (final n in widget.nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  /// Converte um ponto local (pixels) para coordenadas do grafo.
  Offset _toGraph(Offset local) => (local - _offset) / _scale;

  /// Retorna o id do nó atingido pelo ponto (ou null).
  String? _hitTest(Offset graphPoint) {
    for (final n in widget.nodes) {
      if ((n.position - graphPoint).distance < 22) return n.id;
    }
    return null;
  }

  void _restartSim() {
    if (!_controller.isAnimating) _controller.repeat();
  }

  /// Zoom centrado na tela (botões +/-).
  void _zoom(double factor) {
    final box = _areaKey.currentContext?.findRenderObject() as RenderBox?;
    final c = (box != null && box.size != Size.zero)
        ? Offset(box.size.width / 2, box.size.height / 2)
        : Offset.zero;
    final newScale = (_scale * factor).clamp(0.12, 3.0);
    _offset = c - (c - _offset) * (newScale / _scale);
    _scale = newScale;
    _restartSim();
    setState(() {});
  }

  void _resetView() {
    final box = _areaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.size != Size.zero) {
      _offset = Offset(box.size.width / 2, box.size.height / 2);
    }
    _scale = _initialScale;
    for (final n in widget.nodes) _velocities[n.id] = Offset.zero;
    _restartSim();
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          key: _areaKey,
          behavior: HitTestBehavior.opaque,
          onScaleStart: (details) {
            final gp = _toGraph(details.localFocalPoint);
            _gestureNodeId = _hitTest(gp);
            _draggingId = _gestureNodeId;
            _dragMoved = false;
            _startScale = _scale;
            _startOffset = _offset;
            _startFocal = details.focalPoint;
            _restartSim();
          },
          onScaleUpdate: (details) {
            // Detecta se o gesto saiu do lugar (diferencia toque de arrasto)
            if ((details.focalPoint - _startFocal).distance > 6) {
              _dragMoved = true;
            }
            if (_draggingId != null) {
              // Arrasta o nó individualmente
              final gp = _toGraph(details.localFocalPoint);
              final node = _byId(_draggingId!);
              if (node != null) node.position = gp;
            } else {
              // Pan + zoom da câmera
              _scale = (_startScale * details.scale).clamp(0.12, 3.0);
              _offset = _startOffset + (details.focalPoint - _startFocal);
            }
            _restartSim();
            setState(() {});
          },
          onScaleEnd: (details) {
            // Toque (sem arrasto) em nó => seleciona
            if (_gestureNodeId != null && !_dragMoved) {
              widget.onSelect(
                widget.selectedId == _gestureNodeId ? null : _gestureNodeId,
              );
            }
            _draggingId = null;
            _gestureNodeId = null;
            _restartSim();
          },
          child: CustomPaint(
            painter: _GraphPainter(
              nodes: widget.nodes,
              edges: widget.edges,
              offset: _offset,
              scale: _scale,
              selectedId: widget.selectedId,
            ),
            size: Size.infinite,
          ),
        ),

        // Controles de zoom (flutuantes, canto inferior direito)
        Positioned(
          right: 16,
          bottom: 16,
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            borderRadius: 18,
            child: Column(
              children: [
                _ZoomButton(icon: Icons.add, onTap: () => _zoom(1.2)),
                const SizedBox(height: 6),
                _ZoomButton(icon: Icons.remove, onTap: () => _zoom(0.83)),
                const SizedBox(height: 6),
                _ZoomButton(icon: Icons.center_focus_strong, onTap: _resetView),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.backgroundAlt.withOpacity(0.6),
          border: Border.all(color: AppColors.glassBorder, width: 0.5),
        ),
        child: Icon(icon, size: 18, color: AppColors.accent),
      ),
    );
  }
}

/// Desenha o grafo (arestas, nós com glow e labels).
class _GraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final Offset offset;
  final double scale;
  final String? selectedId;

  _GraphPainter({
    required this.nodes,
    required this.edges,
    required this.offset,
    required this.scale,
    this.selectedId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);

    // ---- Arestas ----
    final edgePaint = Paint()
      ..color = AppColors.glassBorder.withOpacity(0.55)
      ..strokeWidth = 1.2;
    for (final e in edges) {
      final a = _node(e.from);
      final b = _node(e.to);
      if (a == null || b == null) continue;
      canvas.drawLine(a.position, b.position, edgePaint);
    }

    // ---- Nós ----
    for (final n in nodes) {
      final color = graphColor(n.group);
      final isSel = n.id == selectedId;

      // Glow
      final glowPaint = Paint()
        ..color = color.withOpacity(isSel ? 0.35 : 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isSel ? 18 : 12);
      canvas.drawCircle(n.position, isSel ? 24 : 18, glowPaint);

      // Corpo
      canvas.drawCircle(
        n.position,
        isSel ? 18 : 14,
        Paint()..color = color,
      );

      // Anel interno sutil
      canvas.drawCircle(
        n.position,
        isSel ? 18 : 14,
        Paint()
          ..color = Colors.white.withOpacity(0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Label — só para hubs (grau alto) ou nó selecionado (grafo grande)
      final showLabel = isSel || n.degree >= 6;
      if (!showLabel) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: n.label,
          style: TextStyle(
            color: isSel ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: isSel ? 14 : 11,
            fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(n.position.dx - tp.width / 2, n.position.dy + 22),
      );
    }

    canvas.restore();
  }

  GraphNode? _node(String id) {
    for (final n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  @override
  bool shouldRepaint(covariant _GraphPainter old) => true;
}
