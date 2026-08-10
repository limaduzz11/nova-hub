import 'package:flutter/material.dart';

import '../../data/ssh_service.dart';
import 'ssh_terminal_page.dart';

class SSHScreen extends StatefulWidget {
  final String deviceIp;
  final String deviceName;
  final String username;

  const SSHScreen({
    super.key,
    required this.deviceIp,
    this.deviceName = 'PC Principal',
    this.username = '',
  });

  @override
  State<SSHScreen> createState() => _SSHScreenState();
}

class _SSHScreenState extends State<SSHScreen> {
  final SSHService _sshService = SSHService();

  @override
  Widget build(BuildContext context) {
    return SshTerminalPage(sshService: _sshService);
  }
}
