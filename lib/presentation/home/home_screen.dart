import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_controller.dart';
import '../login/login_controller.dart';
import '../widgets/device_card.dart';
import '../ssh/ssh_screen.dart';
import '../ssh/ssh_setup_screen.dart';
import '../opencode/opencode_screen.dart';
import '../opencode/opencode_setup_screen.dart';
import '../commands/command_deck_screen.dart';
import '../alerts/alerts_settings_screen.dart';
import '../../core/theme.dart';
import '../../data/models/device.dart';
import 'telemetry_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Timer _clockTimer;
  String _currentTime = '';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
    
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
    
    final controller = context.read<HomeController>();
    controller.loadDevices();
    controller.startAutoRefresh();
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _clockTimer.cancel();
    context.read<HomeController>().stopAutoRefresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Galaxy Background (darker)
          Positioned.fill(
            child: Opacity(
              opacity: 0.3,
              child: const GalaxyAnimation(),
            ),
          ),
          
          // Content
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Telemetria ao vivo (PC principal)
                const TelemetryPanel(),

                // Device List
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildDeviceList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
      child: Row(
        children: [
          // Status
          Consumer<HomeController>(
            builder: (context, controller, _) {
              final isOnline = controller.error == null;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isOnline
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isOnline
                        ? AppColors.success.withOpacity(0.2)
                        : AppColors.error.withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isOnline ? AppColors.success : AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isOnline ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          const Spacer(),
          
          // Clock
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.glass,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.glassBorder,
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.clock,
                  size: 12,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  _currentTime,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          
          // Logout
          PopupMenuButton<String>(
            icon: const Icon(
              CupertinoIcons.ellipsis,
              color: AppColors.textMuted,
              size: 18,
            ),
            onSelected: (value) {
              if (value == 'logout') {
                context.read<LoginController>().logout();
              } else if (value == 'ssh_setup') {
                _openSSHSetup();
              } else if (value == 'opencode_setup') {
                _openOpenCodeSetup();
              } else if (value == 'command_deck') {
                _openCommandDeck();
              } else if (value == 'alerts') {
                _openAlerts();
              }
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: AppColors.card,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'command_deck',
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.bolt_fill,
                      size: 16,
                      color: AppColors.neonBlue,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Command Deck',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'alerts',
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.bell_fill,
                      size: 16,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Centro de Alertas',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'ssh_setup',
                child: Row(
                  children: [
                    const Icon(
                      Icons.terminal,
                      size: 16,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Configurar SSH',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'opencode_setup',
                child: Row(
                  children: [
                    const Icon(
                      Icons.code,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Configurar OpenCode',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.square_arrow_right,
                      size: 16,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Desconectar',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    return Consumer<HomeController>(
      builder: (context, controller, child) {
        if (controller.isLoading && controller.devices.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CupertinoActivityIndicator(
                  radius: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Carregando...',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        if (controller.error != null && controller.devices.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: GlassContainer(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.wifi_exclamationmark,
                        size: 32,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Sem conexão',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      controller.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => controller.loadDevices(),
                      icon: const Icon(CupertinoIcons.refresh, size: 16),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (controller.devices.isEmpty) {
          return Center(
            child: GlassContainer(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.desktopcomputer,
                    size: 40,
                    color: AppColors.textMuted.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhum dispositivo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Adicione no UpSnap',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => controller.loadDevices(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: controller.devices.length,
            itemBuilder: (context, index) {
              final device = controller.devices[index];
              return DeviceCard(
                device: device,
                isLoading: controller.isActionInProgress,
                onWake: () async {
                  final success = await controller.wakeDevice(device.id);
                  if (mounted) {
                    _showSnackBar(
                      context,
                      success
                          ? 'Sinal enviado'
                          : (controller.lastActionError ?? 'Falha'),
                      success,
                    );
                  }
                },
                onShutdown: () => _confirmShutdown(context, controller, device),
                onSSH: () => _openSSH(device),
                onOpenCode: () => _openOpenCode(device),
              );
            },
          ),
        );
      },
    );
  }

  void _showSnackBar(BuildContext context, String message, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? CupertinoIcons.check_mark : CupertinoIcons.xmark,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: success
            ? AppColors.success.withOpacity(0.9)
            : AppColors.error.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: success ? 2 : 4),
      ),
    );
  }

  void _confirmShutdown(
    BuildContext context,
    HomeController controller,
    Device device,
  ) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Desligar PC?'),
        content: Text('Desligar "${device.name}"?'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              final success = await controller.shutdownDevice(device.id);
              if (context.mounted) {
                _showSnackBar(
                  context,
                  success ? 'Desligando...' : (controller.lastActionError ?? 'Falha'),
                  success,
                );
              }
            },
            child: const Text('Desligar'),
          ),
        ],
      ),
    );
  }

  void _openSSH(Device device) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SSHScreen(
          deviceIp: 'configured',
          deviceName: 'PC Principal',
          username: '',
        ),
      ),
    );
  }

  void _openSSHSetup() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SSHSetupScreen(
          deviceIp: 'configured',
          deviceName: 'PC Principal',
        ),
      ),
    );
  }

  void _openOpenCode(Device device) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OpenCodeScreen(
          deviceIp: device.ip,
          deviceName: 'Nova-PopOS',
        ),
      ),
    );
  }

  void _openOpenCodeSetup() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OpenCodeSetupScreen(
          deviceIp: 'localhost',
          deviceName: 'Nova-PopOS',
        ),
      ),
    );
  }

  void _openCommandDeck() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CommandDeckScreen()),
    );
  }

  void _openAlerts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AlertsSettingsScreen()),
    );
  }
}
