# Coding Standards

**NOVA HUB** — Padrões de codificação e convenções.

---

## Visão Geral

Este documento define os padrões de codificação para o projeto NOVA HUB.

---

## Convenções de Arquivos

### Nomes de Arquivos

- **Formato:** `snake_case.dart`
- **Exemplos:**
  - `device_card.dart`
  - `telemetry_service.dart`
  - `nova_theme.dart`

### Estrutura de Diretórios

```
lib/
├── config/           # Configurações
├── core/             # Componentes fundamentais
├── data/             # Serviços e modelos
│   ├── models/       # Data models
│   └── services/     # Clientes de API
├── presentation/     # UI e telas
│   ├── screens/      # Telas principais
│   ├── widgets/      # Componentes reutilizáveis
│   └── controllers/  # Lógica de negócio
└── main.dart         # Entry point
```

---

## Convenções de Código

### Nomes de Classes

- **Formato:** `PascalCase`
- **Exemplos:**
  - `DeviceCard`
  - `TelemetryService`
  - `NovaTheme`

### Nomes de Variáveis

- **Formato:** `camelCase`
- **Exemplos:**
  - `deviceName`
  - `isLoading`
  - `telemetryData`

### Nomes de Constantes

- **Formato:** `kCamelCase`
- **Exemplos:**
  - `kDefaultPadding`
  - `kAnimationDuration`
  - `kMaxRetries`

### Nomes de Privados

- **Variáveis:** `_prefix` (ex: `_isLoading`)
- **Classes:** `_ClassName` (ex: `_DeviceCardState`)
- **Métodos:** `_methodName` (ex: `_loadData`)

---

## Organização de Arquivos

### Ordem de Imports

```dart
// 1. Dart SDK
import 'dart:async';
import 'dart:convert';

// 2. Flutter SDK
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

// 3. Pacotes de terceiros
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

// 4. Arquivos do projeto (core)
import '../core/theme.dart';
import '../core/animations.dart';

// 5. Arquivos do projeto (data)
import '../data/models/device.dart';
import '../data/telemetry_service.dart';

// 6. Arquivos do projeto (presentation)
import '../presentation/widgets/device_card.dart';
```

### Estrutura de um Arquivo

```dart
// 1. Imports
import 'package:flutter/material.dart';
import '../core/theme.dart';

// 2. Constants
const _kDefaultHeight = 200.0;

// 3. Enum (se houver)
enum DeviceStatus { online, offline, unknown }

// 4. Class
class DeviceCard extends StatefulWidget {
  // Constants
  static const double defaultHeight = 200.0;
  
  // Props
  final String deviceName;
  final DeviceStatus status;
  final VoidCallback? onTap;
  
  // Constructor
  const DeviceCard({
    super.key,
    required this.deviceName,
    this.status = DeviceStatus.unknown,
    this.onTap,
  });
  
  // State
  @override
  State<DeviceCard> createState() => _DeviceCardState();
}

// 5. State class
class _DeviceCardState extends State<DeviceCard> {
  // State variables
  bool _isHovered = false;
  
  // Lifecycle methods
  @override
  void initState() {
    super.initState();
    // initialization
  }
  
  @override
  void dispose() {
    // cleanup
    super.dispose();
  }
  
  // Build method
  @override
  Widget build(BuildContext context) {
    return Container();
  }
  
  // Private methods
  void _handleTap() {
    widget.onTap?.call();
  }
}
```

---

## Padrões de UI

### Widgets StatelessWidget

```dart
class DeviceInfo extends StatelessWidget {
  final String name;
  final String status;
  
  const DeviceInfo({
    super.key,
    required this.name,
    required this.status,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(name, style: AppTypography.titleLarge),
        Text(status, style: AppTypography.bodyMedium),
      ],
    );
  }
}
```

### Widgets StatefulWidget

```dart
class AnimatedCard extends StatefulWidget {
  final Widget child;
  
  const AnimatedCard({super.key, required this.child});
  
  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: ScaleTransition(
        scale: _animation,
        child: widget.child,
      ),
    );
  }
}
```

---

## Padrões de Serviços

### Serviço Base

```dart
class BaseService {
  final String baseUrl;
  final String? apiKey;
  
  BaseService({
    required this.baseUrl,
    this.apiKey,
  });
  
  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (apiKey != null) 'X-API-Key': apiKey!,
  };
  
  Future<Map<String, dynamic>> get(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load data');
    }
  }
}
```

### Serviço com State

```dart
class TelemetryService extends ChangeNotifier {
  final WebSocketChannel _channel;
  TelemetryData? _data;
  bool _isConnected = false;
  
  TelemetryData? get data => _data;
  bool get isConnected => _isConnected;
  
  TelemetryService({required String deviceIp})
      : _channel = WebSocketChannel.connect(
          Uri.parse('ws://$deviceIp:8081/ws'),
        ) {
    _channel.stream.listen(_onData);
  }
  
  void _onData(dynamic data) {
    _data = TelemetryData.fromJson(jsonDecode(data));
    _isConnected = true;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }
}
```

---

## Padrões de Testing

### Teste de Widget

```dart
void main() {
  group('DeviceCard', () {
    testWidgets('renders device name', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DeviceCard(
            deviceName: 'Test Device',
            status: DeviceStatus.online,
          ),
        ),
      );
      
      expect(find.text('Test Device'), findsOneWidget);
    });
    
    testWidgets('calls onTap when tapped', (tester) async {
      bool tapped = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: DeviceCard(
            deviceName: 'Test Device',
            onTap: () => tapped = true,
          ),
        ),
      );
      
      await tester.tap(find.byType(DeviceCard));
      expect(tapped, isTrue);
    });
  });
}
```

### Teste de Serviço

```dart
void main() {
  group('TelemetryService', () {
    test('parses telemetry data correctly', () {
      final json = {
        'cpu': {'usage': 45.2},
        'ram': {'percentage': 50.0},
      };
      
      final data = TelemetryData.fromJson(json);
      
      expect(data.cpu.usage, 45.2);
      expect(data.ram.percentage, 50.0);
    });
  });
}
```

---

## Análise de Código

### Regras Flutter Analyze

```yaml
# analysis_options.yaml
analyzer:
  errors:
    missing_return: error
    dead_code: warning
    unused_import: warning
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"

linter:
  rules:
    - prefer_const_constructors
    - prefer_const_declarations
    - avoid_print
    - prefer_single_quotes
```

### Comando de Análise

```bash
flutter analyze
```

---

## Referências

- [Flutter Style Guide](https://dart.dev/guides/language/effective-dart/style)
- [Effective Dart](https://dart.dev/guides/language/effective-dart)
- [Flutter Recipes](https://docs.flutter.dev/cookbook)

---

*Última atualização: 19 de Julho de 2026*
