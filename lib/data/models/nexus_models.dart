// Modelos do NOVA Nexus (espelham o backend Go/SQLite).

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
