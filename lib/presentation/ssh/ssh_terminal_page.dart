import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../../core/theme.dart';
import '../../data/ssh_service.dart';

class SshTerminalPage extends StatefulWidget {
  final SSHService sshService;

  const SshTerminalPage({
    super.key,
    required this.sshService,
  });

  @override
  State<SshTerminalPage> createState() => _SshTerminalPageState();
}

class _SshTerminalPageState extends State<SshTerminalPage> {
  final Terminal _terminal = Terminal(maxLines: 10000);
  StreamSubscription<Uint8List>? _stdoutSub;
  StreamSubscription<Uint8List>? _stderrSub;
  double _fontSize = 13.0;
  bool _connecting = false;
  bool _connected = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _terminal.onOutput = (String data) {
      widget.sshService.sendInput(data);
    };

    _terminal.onResize = (int cols, int rows, int pw, int ph) {
      widget.sshService.resize(cols, rows);
    };

    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
  }

  Future<void> _connect() async {
    if (_connecting || !mounted) return;
    setState(() {
      _connecting = true;
      _errorMessage = null;
    });

    try {
      final config = await widget.sshService.getConnectionConfig();
      final host = config['host'] ?? '';
      final port = int.tryParse(config['port'] ?? '22') ?? 22;
      final username = config['username'] ?? '';

      if (host.isEmpty || username.isEmpty) {
        setState(() {
          _errorMessage = 'Configure o SSH nas configurações';
          _connecting = false;
        });
        return;
      }

      final ok = await widget.sshService.connect(
        host: host,
        port: port,
        username: username,
      );

      if (!mounted) return;

      if (ok) {
        _connected = true;
        _setupStreams();
      } else {
        _errorMessage = 'Falha na conexão. Verifique a chave SSH.';
      }
    } catch (e) {
      if (mounted) {
        _errorMessage = 'Erro: ${e.toString()}';
      }
    } finally {
      if (mounted) {
        setState(() => _connecting = false);
      }
    }
  }

  void _setupStreams() {
    _teardownStreams();

    final stdout = widget.sshService.stdout;
    final stderr = widget.sshService.stderr;

    if (stdout != null) {
      _stdoutSub = stdout.listen(
        (data) => _terminal.write(String.fromCharCodes(data)),
        onDone: () => _handleDisconnected(),
      );
    }

    if (stderr != null) {
      _stderrSub = stderr.listen(
        (data) {
          _terminal.write('\x1b[31m');
          _terminal.write(String.fromCharCodes(data));
          _terminal.write('\x1b[0m');
        },
      );
    }
  }

  void _teardownStreams() {
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;
  }

  void _handleDisconnected() {
    if (!mounted) return;
    _teardownStreams();
    setState(() {
      _connected = false;
    });
  }

  Future<void> _disconnect() async {
    _teardownStreams();
    await widget.sshService.disconnect();
    if (mounted) {
      setState(() => _connected = false);
      Navigator.pop(context);
    }
  }

  Future<void> _onBack() async {
    if (_connected) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Desconectar',
              style: TextStyle(color: AppColors.textPrimary)),
          content: const Text('A sessão ativa será encerrada.',
              style: TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Desconectar',
                  style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        await _disconnect();
      }
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundAlt,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: _onBack,
        ),
        title: const Column(
          children: [
            Text('Terminal SSH',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            Text('Conexão segura',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.remove, color: AppColors.accent),
            onPressed: () => setState(() => _fontSize = (_fontSize - 1).clamp(8.0, 22.0)),
            tooltip: 'Diminuir fonte',
          ),
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.accent),
            onPressed: () => setState(() => _fontSize = (_fontSize + 1).clamp(8.0, 22.0)),
            tooltip: 'Aumentar fonte',
          ),
          IconButton(
            icon: Icon(
              _connected ? Icons.link_off : Icons.refresh,
              color: AppColors.accent,
            ),
            onPressed: _connected ? _disconnect : _connect,
            tooltip: _connected ? 'Desconectar' : 'Reconectar',
          ),
        ],
      ),
      body: Stack(
        children: [
          Offstage(
            offstage: !_connected,
            child: Container(
              color: const Color(0xFF0D1117),
              child: TerminalView(
                _terminal,
                textStyle: TerminalStyle(fontFamily: 'monospace', fontSize: _fontSize),
                theme: const TerminalTheme(
                  background: Color(0xFF0D1117),
                  foreground: Color(0xFFE6EDF3),
                  cursor: Color(0xFF79C0FF),
                  selection: Color(0x40264F78),
                  black: Color(0xFF000000),
                  red: Color(0xFFFF7B72),
                  green: Color(0xFF3FB950),
                  yellow: Color(0xFFD29922),
                  blue: Color(0xFF58A6FF),
                  magenta: Color(0xFFBC8CFF),
                  cyan: Color(0xFF39D2C0),
                  white: Color(0xFFC9D1D9),
                  brightBlack: Color(0xFF484F58),
                  brightRed: Color(0xFFFFA198),
                  brightGreen: Color(0xFF56D364),
                  brightYellow: Color(0xFFE3B341),
                  brightBlue: Color(0xFF79C0FF),
                  brightMagenta: Color(0xFFD2A8FF),
                  brightCyan: Color(0xFF56D4DD),
                  brightWhite: Color(0xFFF0F6FC),
                  searchHitBackground: Color(0xFFFFFF2B),
                  searchHitBackgroundCurrent: Color(0xFF31FF26),
                  searchHitForeground: Color(0xFF000000),
                ),
                padding: const EdgeInsets.all(8),
              ),
            ),
          ),
          if (_connecting || _errorMessage != null || !_connected)
            Positioned.fill(
              child: Container(
                color: AppColors.background.withOpacity(0.92),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_connecting) ...[
                          const CircularProgressIndicator(color: AppColors.accent),
                          const SizedBox(height: 20),
                          const Text('Conectando ao PC Principal...',
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 15)),
                        ] else ...[
                          const Icon(Icons.error_outline,
                              color: AppColors.error, size: 56),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage ?? 'Conexão encerrada.',
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 15),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),
                          ElevatedButton.icon(
                            onPressed: _connecting ? null : _connect,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Tentar novamente'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 14),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _connected ? _buildQuickCommands() : null,
    );
  }

  Widget _buildQuickCommands() {
    return Container(
      height: 52,
      color: AppColors.backgroundAlt,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _quickChip('whoami', Icons.person),
          const SizedBox(width: 8),
          _quickChip('uname -a', Icons.info_outline),
          const SizedBox(width: 8),
          _quickChip('uptime', Icons.timer),
          const SizedBox(width: 8),
          _quickChip('free -h', Icons.memory),
          const SizedBox(width: 8),
          _quickChip('df -h /', Icons.storage),
          const SizedBox(width: 8),
          _quickChip('docker ps', Icons.dashboard),
          const SizedBox(width: 8),
          _quickChip('clear', Icons.cleaning_services),
        ],
      ),
    );
  }

  Widget _quickChip(String command, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: AppColors.accent),
      label: Text(command,
          style:
              const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      backgroundColor: AppColors.backgroundAlt,
      side: const BorderSide(color: AppColors.glassBorder),
      onPressed: () => widget.sshService.sendInput('$command\n'),
    );
  }

  @override
  void dispose() {
    _teardownStreams();
    widget.sshService.disconnect();
    super.dispose();
  }
}
