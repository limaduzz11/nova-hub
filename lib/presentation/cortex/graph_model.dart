import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

/// Nó do grafo de conhecimento (um arquivo Markdown do vault).
class GraphNode {
  GraphNode({
    required this.id,
    required this.label,
    required this.group,
    Offset? position,
    this.degree = 0,
    this.path,
    this.content,
    this.tags = const [],
  }) : position = position ?? Offset.zero;

  final String id;
  final String label;
  final String group;
  final int degree;
  final String? path;
  final String? content;
  final List<String> tags;
  Offset position;

  /// Posição inicial determinística (seed fixa por id) p/ layout estável.
  void seedPosition([int seed = 7]) {
    final r = Random(id.hashCode ^ seed);
    position = Offset(r.nextDouble() * 1400 - 700, r.nextDouble() * 1000 - 500);
  }
}

/// Extrai tags de um conteúdo Markdown (inline `#tag` e frontmatter `tags:`).
List<String> parseTags(String? content) {
  if (content == null || content.isEmpty) return const [];
  final tags = <String>{};
  // Tags inline: #tag (sem espaço depois do #, e não precedido de #)
  final inline = RegExp(r'(?<!#)#([\w\/_-]+)');
  for (final m in inline.allMatches(content)) {
    tags.add(m.group(1)!.toLowerCase());
  }
  // Frontmatter YAML: tags:\n  - foo\n  - bar
  final fm = RegExp(r'tags:\s*\n((?:\s*-\s*[\w\/_-]+\s*\n)+)');
  final m = fm.firstMatch(content);
  if (m != null) {
    for (final line in m.group(1)!.split('\n')) {
      final t = line.replaceFirst(RegExp(r'\s*-\s*'), '').trim();
      if (t.isNotEmpty) tags.add(t.toLowerCase());
    }
  }
  return tags.toList();
}

/// Aresta do grafo (um link [[wikilink]] entre dois arquivos).
class GraphEdge {
  const GraphEdge({required this.from, required this.to});
  final String from;
  final String to;
}

/// Grafo completo do vault.
///
/// Fonte primária: backend Nexus (`/api/graph`), que faz parse ao vivo do Vault.
/// Fallback: asset embutido `assets/sample_graph.json` (offline).
class VaultGraph {
  VaultGraph({required this.nodes, required this.edges});

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  /// Constrói a partir do JSON retornado por `/api/graph` ou do asset.
  static VaultGraph fromJson(Map<String, dynamic> data) {
    final nodes = (data['nodes'] as List).map((n) {
      final node = GraphNode(
        id: n['id'] as String,
        label: n['label'] as String,
        group: n['group'] as String,
        degree: (n['degree'] as int?) ?? 0,
        path: n['path'] as String?,
        content: n['content'] as String?,
        tags: parseTags(n['content'] as String?),
      );
      node.seedPosition();
      return node;
    }).toList();

    final edges = (data['edges'] as List)
        .map((e) => GraphEdge(
              from: e['from'] as String,
              to: e['to'] as String,
            ))
        .toList();

    return VaultGraph(nodes: nodes, edges: edges);
  }

  /// Carrega do asset embutido (fallback offline).
  static Future<VaultGraph> loadAsset() async {
    final raw = await rootBundle.loadString('assets/sample_graph.json');
    return fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
