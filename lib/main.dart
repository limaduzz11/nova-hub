import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/ui_log.dart';
import 'config/app_config.dart';
import 'data/upsnap_client.dart';
import 'presentation/main/main_screen.dart';
import 'presentation/home/home_controller.dart';
import 'presentation/login/login_screen.dart';
import 'presentation/login/login_controller.dart';
import 'presentation/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Expõe a árvore de semântica p/ leitura externa (uiautomator/ADB) durante
  // validação — permite inspecionar textos e botões dos menus sem screenshot.
  SemanticsBinding.instance.ensureSemantics();
  uiLog('APP', 'boot');

  const config = AppConfig();
  final client = UpSnapClient(baseUrl: config.upsnapUrl);

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: client),
        ChangeNotifierProvider(create: (_) => LoginController(client: client)),
        ChangeNotifierProvider(create: (_) => HomeController(client: client)),
      ],
      child: const NovaHubApp(),
    ),
  );
}

class NovaHubApp extends StatefulWidget {
  const NovaHubApp({super.key});

  @override
  State<NovaHubApp> createState() => _NovaHubAppState();
}

class _NovaHubAppState extends State<NovaHubApp> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final loginController = context.read<LoginController>();
    await loginController.tryAutoLogin();
    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return MaterialApp(
        theme: AppTheme.darkTheme,
        home: SplashScreen(
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        debugShowCheckedModeBanner: false,
      );
    }

    return MaterialApp(
      title: 'NOVA HUB',
      theme: AppTheme.darkTheme,
      navigatorObservers: [UiLogObserver()],
      home: SplashScreen(
        child: Consumer<LoginController>(
          builder: (context, loginController, _) {
            if (loginController.isLoggedIn) {
              return const MainScreen();
            }
            return const LoginScreen();
          },
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
