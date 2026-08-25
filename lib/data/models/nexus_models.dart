import 'package:flutter/material.dart';
import '../../core/theme.dart';

// Modelos do NOVA Nexus (espelham o backend Go/SQLite).

/// Definição canônica das colunas Kanban do NOVA Nexus.
/// Mantida aqui para reuso entre model, service e UI.
class NexusKanban {
  const NexusKanban._();

  static const List<({String id, String label, String shortLabel, IconData icon})> columns = [
    (id: 'todo', label: 'Na Fila', shortLabel: 'FILA', icon: Icons.inbox_outlined),
    (id: 'doing', label: 'Atuando', shortLabel: 'ATU', icon: Icons.play_circle_outline),
    (id: 'standby', label: 'StandBy', shortLabel: 'STB', icon: Icons.pause_circle_outline),
    (id: 'done', label: 'Concluído', shortLabel: 'CON', icon: Icons.check_circle_outline),
    (id: 'project', label: 'Projetos', shortLabel: 'PRJ', icon: Icons.folder_outlined),
  ];

  static const Map<String, String> labelById = {
    'todo': 'Na Fila',
    'doing': 'Atuando',
    'standby': 'StandBy',
    'done': 'Concluído',
    'project': 'Projetos',
  };

  static const Map<String, Color> colorById = {
    'todo': AppColors.neonBlue,
    'doing': AppColors.warning,
    'standby': AppColors.textMuted,
    'done': AppColors.success,
    'project': AppColors.neonPurple,
  };

  static const Map<String, IconData> iconById = {
    'todo': Icons.inbox_outlined,
    'doing': Icons.play_circle_outline,
    'standby': Icons.pause_circle_outline,
    'done': Icons.check_circle_outline,
    'project': Icons.folder_outlined,
  };

  static String labelOf(String id) => labelById[id] ?? id;
  static Color colorOf(String id) => colorById[id] ?? AppColors.primary;
  static IconData iconOf(String id) => iconById[id] ?? Icons.circle_outlined;

  /// Ordem canônica para exibição das colunas.
  static const List<String> order = ['todo', 'doing', 'standby', 'done', 'project'];
}

class NexusWorkspace {
  final String id;
  final String name;
  final String kind; // rotina | work | custom
  final String icon;
  final String color;
  final int position;

  const NexusWorkspace({
    required this.id,
    required this.name,
    required this.kind,
    this.icon = '',
    this.color = '',
    this.position = 0,
  });

  factory NexusWorkspace.fromJson(Map<String, dynamic> j) => NexusWorkspace(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        kind: j['kind'] as String? ?? 'custom',
        icon: j['icon'] as String? ?? '',
        color: j['color'] as String? ?? '',
        position: (j['position'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind,
        'icon': icon,
        'color': color,
        'position': position,
      };
}

class NexusItem {
  final String id;
  final String workspaceId;
  final String? parentId;
  final String type; // task | note | page
  final String title;
  final String body; // markdown
  final String status; // todo | doing | done | none
  final List<String> tags;
  final String? dueDate;
  final int position;
  final int timeSpent;
  final String createdAt;
  final String updatedAt;

  const NexusItem({
    required this.id,
    required this.workspaceId,
    this.parentId,
    this.type = 'task',
    this.title = '',
    this.body = '',
    this.status = 'todo',
    this.tags = const [],
    this.dueDate,
    this.position = 0,
    this.timeSpent = 0,
    this.createdAt = '',
    this.updatedAt = '',
  });

  bool get isTask => type == 'task';
  bool get isDone => status == 'done';
  bool get isStandby => status == 'standby';
  bool get isDoing => status == 'doing';

  // ── Qualitor helpers (tags: qualitor, qualitor:123, cliente:X, tipo:Y, severidade:Z) ──
  bool get isQualitor => tags.any((t) => t == 'qualitor' || t.startsWith('qualitor:'));

  String? get qualitorId {
    for (final t in tags) {
      if (t.startsWith('qualitor:')) return t.split(':').last;
    }
    // fallback: tenta extrair [QUALITOR 123] do título
    final m = RegExp(r'\[QUALITOR\s+(\d+)\]').firstMatch(title);
    return m?.group(1);
  }

  String? get clientTag {
    for (final t in tags) {
      if (t.toLowerCase().startsWith('cliente:')) return t.substring(8).trim();
    }
    return null;
  }

  String? get severityTag {
    for (final t in tags) {
      final low = t.toLowerCase();
      if (low.startsWith('severidade:')) return t.substring(11).trim();
      if (low.startsWith('severity:')) return t.substring(9).trim();
    }
    return null;
  }

  String? get typeTag {
    for (final t in tags) {
      if (t.toLowerCase().startsWith('tipo:')) return t.substring(5).trim();
    }
    return null;
  }

  String get severityNormalized => (severityTag ?? '').toLowerCase();
  String get clientNormalized => (clientTag ?? '').toLowerCase();

  bool get isHighPriority =>
      severityNormalized.contains('alta') || severityNormalized.contains('high') || severityNormalized.contains('crítica') || severityNormalized.contains('critica');
  bool get isMediumPriority => severityNormalized.contains('media') || severityNormalized.contains('média');
  bool get isLowPriority => severityNormalized.contains('baixa') || severityNormalized.contains('low');

  Color get severityColor {
    if (isHighPriority) return AppColors.error;
    if (isMediumPriority) return AppColors.warning;
    if (isLowPriority) return AppColors.success;
    // REQUISIÇÃO vs INCIDENTE
    final tt = (typeTag ?? '').toLowerCase();
    if (tt.contains('incidente')) return AppColors.errorLight;
    if (tt.contains('requisi')) return AppColors.neonBlue;
    return AppColors.textMuted;
  }

  String get severityLabel {
    final s = severityTag;
    if (s == null || s.isEmpty) return typeTag ?? '';
    return s.toUpperCase();
  }

  String get clientLabel => clientTag ?? '';

  /// Data de prazo parseada (AAAA-MM-DD) se existir.
  DateTime? get dueDateParsed {
    if (dueDate == null || dueDate!.trim().isEmpty) return null;
    try {
      return DateTime.parse(dueDate!.trim());
    } catch (_) {
      return null;
    }
  }

  bool get isOverdue {
    final d = dueDateParsed;
    if (d == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(d.year, d.month, d.day);
    return due.isBefore(today) && !isDone;
  }

  bool get isDueSoon {
    final d = dueDateParsed;
    if (d == null) return false;
    final now = DateTime.now();
    final diff = d.difference(DateTime(now.year, now.month, now.day)).inDays;
    return diff >= 0 && diff <= 2 && !isDone;
  }

  /// Título limpo sem prefixo [QUALITOR 123]
  String get displayTitle {
    return title.replaceAll(RegExp(r'^\[QUALITOR\s+\d+\]\s*'), '').trim();
  }

  /// Identificador curto para card (ex: #3167227 ou •)
  String get shortId {
    final q = qualitorId;
    if (q != null) return '#$q';
    if (id.length >= 8) return '#${id.substring(0, 8)}';
    return '#$id';
  }

  /// Status label traduzido
  String get statusLabel => NexusKanban.labelOf(status);
  Color get statusColor => NexusKanban.colorOf(status);
  IconData get statusIcon => NexusKanban.iconOf(status);

  /// Última atualização curta
  String get updatedShort {
    if (updatedAt.isEmpty) return '';
    try {
      final dt = DateTime.parse(updatedAt);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return 'há ${diff.inMinutes}m';
      if (diff.inHours < 24) return 'há ${diff.inHours}h';
      if (diff.inDays < 7) return 'há ${diff.inDays}d';
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return updatedAt.substring(0, 10);
    }
  }

  factory NexusItem.fromJson(Map<String, dynamic> j) => NexusItem(
        id: j['id'] as String,
        workspaceId: j['workspace_id'] as String? ?? '',
        parentId: j['parent_id'] as String?,
        type: j['type'] as String? ?? 'task',
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        status: j['status'] as String? ?? 'todo',
        tags: (j['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        dueDate: j['due_date'] as String?,
        position: (j['position'] as num?)?.toInt() ?? 0,
        timeSpent: (j['time_spent'] as num?)?.toInt() ?? 0,
        createdAt: j['created_at'] as String? ?? '',
        updatedAt: j['updated_at'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'workspace_id': workspaceId,
        'parent_id': parentId,
        'type': type,
        'title': title,
        'body': body,
        'status': status,
        'tags': tags,
        'due_date': dueDate,
        'position': position,
        'time_spent': timeSpent,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}
