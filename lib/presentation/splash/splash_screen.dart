import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';

class SplashScreen extends StatefulWidget {
  final Widget child;

  const SplashScreen({
    super.key,
    required this.child,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _glowController;
  late AnimationController _backgroundController;
  late AnimationController _fadeController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _glowOpacity;
  late Animation<double> _backgroundOpacity;
  late Animation<double> _fadeOpacity;

  bool _showChild = false;

  @override
  void initState() {
    super.initState();

    // Set status bar to transparent
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Logo animation controller
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Glow pulse controller
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Background animation controller
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Fade out controller
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Logo animations
    _logoScale = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    ));

    _logoOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    ));

    // Glow animation
    _glowOpacity = Tween<double>(
      begin: 0.0,
      end: 0.6,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    // Background animation
    _backgroundOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeIn,
    ));

    // Fade out animation
    _fadeOpacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    // Start animations
    _startAnimations();
  }

  Future<void> _startAnimations() async {
    // Wait a bit before starting
    await Future.delayed(const Duration(milliseconds: 200));

    // Start background and logo animations simultaneously
    _backgroundController.forward();
    _logoController.forward();

    // Start glow animation after logo appears
    await Future.delayed(const Duration(milliseconds: 400));
    _glowController.repeat(reverse: true);

    // Wait for logo to be visible
    await Future.delayed(const Duration(milliseconds: 1200));

    // Fade out splash
    await _fadeController.forward();

    // Show child widget
    setState(() {
      _showChild = true;
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _glowController.dispose();
    _backgroundController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showChild) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: Listenable.merge([
        _logoController,
        _glowController,
        _backgroundController,
        _fadeController,
      ]),
      builder: (context, child) {
        return Opacity(
          opacity: _fadeOpacity.value,
          child: Container(
            color: AppColors.background,
            child: Stack(
              children: [
                // Animated background
                AnimatedBuilder(
                  animation: _backgroundController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _backgroundOpacity.value,
                      child: const GalaxyAnimation(
                        showNebulas: true,
                        starCount: 80,
                      ),
                    );
                  },
                ),

                // Center content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo with glow
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _logoScale.value,
                            child: Opacity(
                              opacity: _logoOpacity.value,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Glow effect
                                  AnimatedBuilder(
                                    animation: _glowController,
                                    builder: (context, child) {
                                      return Opacity(
                                        opacity: _glowOpacity.value,
                                        child: Container(
                                          width: 120,
                                          height: 120,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.primary
                                                    .withOpacity(0.5),
                                                blurRadius: 60,
                                                spreadRadius: 20,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  // Logo image
                                  Image.asset(
                                    'assets/icon/app_icon.png',
                                    width: 80,
                                    height: 80,
                                    errorBuilder: (context, error, stackTrace) {
                                      // Fallback to icon if image fails
                                      return Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: const Icon(
                                          Icons.auto_awesome,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // App name
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _logoOpacity.value,
                            child: const Text(
                              'NOVA HUB',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 4,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 8),

                      // Tagline
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _logoOpacity.value * 0.7,
                            child: const Text(
                              'Seu PC, sua rede, seu controle',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 1,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Version info at bottom
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _logoController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _logoOpacity.value * 0.5,
                          child: const Text(
                            'v2.0.0',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textMuted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
