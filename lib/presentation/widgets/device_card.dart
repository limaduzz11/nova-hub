import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../data/models/device.dart';
import '../../core/theme.dart';
import '../../core/animations.dart' as animations;

class DeviceCard extends StatefulWidget {
  final Device device;
  final VoidCallback? onWake;
  final VoidCallback? onShutdown;
  final VoidCallback? onSSH;
  final VoidCallback? onOpenCode;
  final bool isLoading;
  final int animationIndex;

  const DeviceCard({
    super.key,
    required this.device,
    this.onWake,
    this.onShutdown,
    this.onSSH,
    this.onOpenCode,
    this.isLoading = false,
    this.animationIndex = 0,
  });

  @override
  State<DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<DeviceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    if (widget.device.isOnline) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(DeviceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.device.isOnline && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.device.isOnline && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: device.isOnline ? _pulseAnimation.value : 1.0,
          child: GlassContainer(
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            padding: AppSpacing.paddingLg,
            borderRadius: AppRadius.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Device Info
                Row(
                  children: [
                    // Status Icon
                    AnimatedContainer(
                      duration: animations.NovaAnimations.fast,
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: device.isOnline
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.backgroundAlt,
                        borderRadius: AppRadius.radiusMd,
                        border: Border.all(
                          color: device.isOnline
                              ? AppColors.success.withValues(alpha: 0.2)
                              : AppColors.glassBorder,
                          width: 0.5,
                        ),
                      ),
                      child: Icon(
                        CupertinoIcons.desktopcomputer,
                        color: device.isOnline
                            ? AppColors.success
                            : AppColors.textMuted,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    
                    // Name & IP
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nova-PopOS',
                            style: AppTypography.titleMedium.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            device.isOnline ? 'Conectado' : 'Indisponível',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Status
                    NovaBadge(
                      label: device.isOnline ? 'ON' : 'OFF',
                      color: device.isOnline ? AppColors.success : AppColors.error,
                      isSmall: true,
                    ),
                  ],
                ),
                
                const SizedBox(height: AppSpacing.lg),
                
                // Actions
                Row(
                  children: [
                    if (!device.isOnline) ...[
                      Expanded(
                        child: _ActionChip(
                          label: 'Ligar',
                          color: AppColors.success,
                          enabled: !widget.isLoading && !device.isOnline,
                          onTap: widget.onWake,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                    ],
                    Expanded(
                      child: _ActionChip(
                        label: 'Desligar',
                        color: AppColors.error,
                        enabled: !widget.isLoading && device.isOnline,
                        onTap: widget.onShutdown,
                      ),
                    ),
                    if (device.isOnline) ...[
                      const SizedBox(width: AppSpacing.md),
                      _ActionChip(
                        label: 'SSH',
                        color: AppColors.accent,
                        enabled: !widget.isLoading && device.isOnline,
                        onTap: widget.onSSH,
                        icon: Icons.terminal,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _ActionChip(
                        label: 'Code',
                        color: AppColors.primary,
                        enabled: !widget.isLoading && device.isOnline,
                        onTap: widget.onOpenCode,
                        icon: Icons.code,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;
  final IconData? icon;

  const _ActionChip({
    required this.label,
    required this.color,
    required this.enabled,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return animations.NovaAnimatedScale(
      scale: enabled ? 0.95 : 1.0,
      duration: animations.NovaAnimations.fast,
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: animations.NovaAnimations.fast,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: enabled
              ? color.withValues(alpha: 0.1)
              : AppColors.backgroundAlt.withValues(alpha: 0.5),
          borderRadius: AppRadius.radiusSm,
          border: Border.all(
            color: enabled
                ? color.withValues(alpha: 0.2)
                : AppColors.glassBorder,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? CupertinoIcons.power,
              size: 14,
              color: enabled ? color : AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: enabled ? color : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
