/// Metadados de um comando da allowlist do Command Deck (backend).
class NovaCommand {
  final String id;
  final String label;
  final String desc;
  final String icon;
  final String group;
  final bool danger;

  const NovaCommand({
    required this.id,
    required this.label,
    required this.desc,
    required this.icon,
    required this.group,
    required this.danger,
  });

  factory NovaCommand.fromJson(Map<String, dynamic> j) => NovaCommand(
        id: (j['id'] ?? '') as String,
        label: (j['label'] ?? '') as String,
        desc: (j['desc'] ?? '') as String,
        icon: (j['icon'] ?? '') as String,
        group: (j['group'] ?? 'Geral') as String,
        danger: (j['danger'] ?? false) as bool,
      );
}

/// Resultado da execução de um comando.
class CommandResult {
  final String id;
  final bool ok;
  final int exitCode;
  final String output;
  final String error;
  final int ms;

  const CommandResult({
    required this.id,
    required this.ok,
    required this.exitCode,
    required this.output,
    required this.error,
    required this.ms,
  });

  factory CommandResult.fromJson(Map<String, dynamic> j) => CommandResult(
        id: (j['id'] ?? '') as String,
        ok: (j['ok'] ?? false) as bool,
        exitCode: (j['exit_code'] ?? 0) as int,
        output: (j['output'] ?? '') as String,
        error: (j['error'] ?? '') as String,
        ms: (j['ms'] ?? 0) as int,
      );
}
