import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/command_service.dart';
import '../../data/models/command.dart';

/// Command Deck: grade de ações rápidas executadas no PC via backend Nexus.
class CommandDeckScreen extends StatefulWidget {
  const CommandDeckScreen({super.key});

  @override
  State<CommandDeckScreen> createState() => _CommandDeckScreenState();
}

class _CommandDeckScreenState extends State<CommandDeckScreen> {
  final _service = CommandService();
  List<NovaCommand> _commands = [];
  bool _loading = true;
  String? _error;
  final Set<String> _running = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cmds = await _service.list();
      if (!mounted) return;
      setState(() {
        _commands = cmds;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _run(NovaCommand cmd) async {
    if (_running.contains(cmd.id)) return;
    if (cmd.danger) {
      final ok = await _confirm(cmd);
      if (ok != true) return;
    }
    setState(() => _running.add(cmd.id));
    try {
      final res = await _service.run(cmd.id);
      if (mounted) _showResult(cmd, res);
    } catch (e) {
      if (mounted) {
        _showResult(
          cmd,
          CommandResult(
            id: cmd.id,
            ok: false,
            exitCode: -1,
            output: '',
            error: e.toString(),
            ms: 0,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _running.remove(cmd.id));
    }
  }

  Future<bool?> _confirm(NovaCommand cmd) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Executar "${cmd.label}"?'),
        content: Text(cmd.desc),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Executar'),
          ),
        ],
      ),
    );
  }

  void _showResult(NovaCommand cmd, CommandResult res) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  res.ok ? CupertinoIcons.check_mark_circled : CupertinoIcons.xmark_circle,
                  color: res.ok ? AppColors.success : AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cmd.label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${res.ms} ms',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 320),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  res.error.isNotEmpty && res.output.isEmpty
                      ? res.error
                      : (res.output.isEmpty ? '(sem saída)' : res.output),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    fontFamily: 'monospace',
                    height: 1.4,
                  ),
                ),
              ),
            ),
            if (res.error.isNotEmpty && res.output.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'erro: ${res.error}',
                style: const TextStyle(color: AppColors.error, fontSize: 11.5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Command Deck', style: TextStyle(fontSize: 17)),
        actions: [
          IconButton(
            tooltip: 'Recarregar comandos',
            icon: const Icon(CupertinoIcons.refresh, size: 18),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CupertinoActivityIndicator(radius: 14, color: AppColors.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.wifi_exclamationmark,
                  size: 32, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(CupertinoIcons.refresh, size: 16),
                label: const Text('Tentar novamente'),
              ),
            ],
        ),
      ),
    );
  }

    if (_commands.isEmpty) {
      return const Center(
        child: Text('Nenhum comando cadastrado',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }

    final groups = <String, List<NovaCommand>>{};
    for (final c in _commands) {
      groups.putIfAbsent(c.group, () => []).add(c);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildNovaMode(),
        const SizedBox(height: 8),
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10, top: 6),
            child: Text(
              entry.key.toUpperCase(),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: entry.value.map(_buildTile).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildTile(NovaCommand cmd) {
    final running = _running.contains(cmd.id);
    final color = cmd.danger ? AppColors.warning : AppColors.neonBlue;
    return Semantics(
      label: cmd.label,
      button: true,
      enabled: !running,
      onTap: running ? null : () => _run(cmd),
      child: GestureDetector(
        onTap: running ? null : () => _run(cmd),
        child: GlassContainer(
        padding: const EdgeInsets.all(14),
        border: Border.all(color: color.withOpacity(0.25), width: 0.6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_iconFor(cmd.icon), color: color, size: 18),
                ),
                const Spacer(),
                if (running)
                  const CupertinoActivityIndicator(radius: 8)
                else
                  Icon(CupertinoIcons.play_arrow_solid,
                      color: color.withOpacity(0.5), size: 14),
              ],
            ),
            const Spacer(),
            Text(
              cmd.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              cmd.desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    ),
    );
  }

  /// Card fixo de NOVA Mode: alterna o host entre os modos WORK e GAME com
  /// um toque, sem precisar caçar o comando na lista.
  Widget _buildNovaMode() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      border: Border.all(color: AppColors.neonPurple.withOpacity(0.3), width: 0.8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.bolt_fill, color: AppColors.neonPurple, size: 18),
              const SizedBox(width: 8),
              const Text(
                'NOVA MODE',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Alterna o host entre os modos Work e Game.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _novaButton(
                  'WORK',
                  Icons.work_outline,
                  AppColors.neonBlue,
                  () => _runNova('work'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _novaButton(
                  'GAME',
                  Icons.videogame_asset_outlined,
                  AppColors.neonPurple,
                  () => _runNova('game'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _novaButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Semantics(
      label: 'NOVA MODE $label',
      button: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.35), width: 0.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  /// Descobre o comando de NOVA Mode do backend por nome (nova + modo).
  NovaCommand? _novaCmd(String mode) {
    for (final c in _commands) {
      final hay = '${c.id} ${c.label} ${c.desc} ${c.group}'.toLowerCase();
      if (!hay.contains('nova')) continue;
      if (mode == 'game') {
        if (hay.contains('game') || hay.contains('jogo') || hay.contains('sunshine')) {
          return c;
        }
      } else if (hay.contains('work') || hay.contains('trabalho')) {
        return c;
      }
    }
    return null;
  }

  Future<void> _runNova(String mode) async {
    final cmd = _novaCmd(mode);
    if (cmd == null) {
      _snackNova('Comando "NOVA Mode: $mode" não encontrado no backend.');
      return;
    }
    final ok = await _confirm(cmd);
    if (ok != true) return;
    setState(() => _running.add(cmd.id));
    try {
      final res = await _service.run(cmd.id);
      if (mounted) _showResult(cmd, res);
    } catch (e) {
      if (mounted) {
        _showResult(
          cmd,
          CommandResult(
            id: cmd.id,
            ok: false,
            exitCode: -1,
            output: '',
            error: e.toString(),
            ms: 0,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _running.remove(cmd.id));
    }
  }

  void _snackNova(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'timer':
        return CupertinoIcons.timer;
      case 'storage':
        return Icons.storage;
      case 'memory':
        return Icons.memory;
      case 'thermostat':
        return Icons.thermostat;
      case 'speed':
        return Icons.speed;
      case 'leaderboard':
        return Icons.leaderboard;
      case 'dns':
        return Icons.dns;
      case 'sync':
        return Icons.sync;
      default:
        return CupertinoIcons.bolt_fill;
    }
  }
}
