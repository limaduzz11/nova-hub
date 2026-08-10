# Arquitetura - Visão Geral

**NOVA HUB** — Arquitetura do sistema e decisões técnicas.

---

## Visão Geral

O NOVA HUB segue uma arquitetura **Presentation → Data → Core** com separação clara de responsabilidades.

```
┌─────────────────────────────────────────────┐
│                Presentation                  │
│  (Screens, Widgets, Controllers, Providers)  │
├─────────────────────────────────────────────┤
│                   Data                       │
│     (Services, Models, API Clients)          │
├─────────────────────────────────────────────┤
│                    Core                      │
│  (Theme, Animations, Utils, Config)          │
└─────────────────────────────────────────────┘
```

---

## Camadas

### 1. Presentation Layer

Responsável por toda a UI e interação do usuário.

**Componentes:**
- **Screens** — Telas principais do app
- **Widgets** — Componentes reutilizáveis
- **Controllers** — Lógica de negócio (via ChangeNotifier)
- **Providers** — Injeção de dependência

**Diretório:** `lib/presentation/`

### 2. Data Layer

Responsável por comunicação com backend, modelos de dados e persistência local.

**Componentes:**
- **Services** — Clientes de API e lógica de negócio
- **Models** — Data classes (data models)
- **Config** — Configurações e constantes

**Diretório:** `lib/data/`

### 3. Core Layer

Componentes fundamentais compartilhados entre todas as camadas.

**Componentes:**
- **Theme** — Design System completo
- **Animations** — Sistema de animações
- **Utils** — Funções utilitárias
- **Config** — Constantes do app

**Diretório:** `lib/core/`

---

## Navegação

### Estrutura Principal

O app utiliza **IndexedStack** para manter o estado de cada tab, com **Navigator** aninhado para navegação interna.

```
MainScreen (Scaffold)
├── IndexedStack (4 tabs)
│   ├── HomeTab (Nova Link)
│   │   └── Navigator → DeviceScreen → Features...
│   ├── ArcadiaTab
│   │   └── Navigator → GameList → GameDetail
│   ├── CortexTab
│   │   └── Navigator → Search → Vault
│   └── NexusTab
│       └── Navigator → Workspaces → Items
├── BottomNavigationBar
└── FloatingActionButton (Quick Actions)
```

### Rotas Principais

| Rota | Descrição |
|------|-----------|
| `/` | Login Screen |
| `/splash` | Splash Screen animada |
| `/main` | Main Screen (após login) |
| `/device/:id` | Device Screen |
| `/ssh` | SSH Terminal |
| `/opencode` | OpenCode Editor |
| `/commands` | Command Deck |

---

## State Management

### Provider Pattern

O app utiliza **Provider** com **ChangeNotifier** para gerenciamento de estado.

**Exemplo de uso:**

```dart
// Definindo um provider
class DeviceController extends ChangeNotifier {
  Device? _device;
  bool _loading = false;
  
  Device? get device => _device;
  bool get loading => _loading;
  
  Future<void> loadDevice(String id) async {
    _loading = true;
    notifyListeners();
    
    _device = await _service.getDevice(id);
    _loading = false;
    notifyListeners();
  }
}

// Usando em uma tela
ChangeNotifierProvider(
  create: (_) => DeviceController(),
  child: DeviceScreen(),
)

// Acessando em widgets
Consumer<DeviceController>(
  builder: (context, controller, _) {
    if (controller.loading) {
      return SkeletonLoader();
    }
    return DeviceCard(device: controller.device);
  },
)
```

### Estado Local vs Global

| Tipo | Uso | Exemplo |
|------|-----|---------|
| **Global** | Dados compartilhados entre telas | Device info, User session |
| **Local** | Estado de uma tela específica | Form fields, UI state |
| **Efêmero** | Estado temporário | Loading, Error messages |

---

## Comunicação com Backend

### Padrões de Requisição

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Flutter   │────▶│   NOVA      │────▶│   APIs      │
│   App       │     │   Nexus     │     │   Externas  │
└─────────────┘     └─────────────┘     └─────────────┘
       │                    │                    │
       │    HTTP/REST       │    HTTP/REST       │
       │    WebSocket       │    WebSocket       │
       │◀───────────────────│◀───────────────────│
```

### Serviços Principais

| Serviço | Protocolo | Uso |
|---------|-----------|-----|
| NexusService | HTTP/REST | Dados e workspace |
| TelemetryService | WebSocket | Telemetria ao vivo |
| AlertService | HTTP | Configuração de alertas |
| ArcadiaService | HTTP | Dados de jogos |
| CommandService | HTTP | Execução de comandos |
| SSHService | WebSocket | Terminal SSH |
| OpenCodeService | HTTP | Credenciais OpenCode |
| UpSnapClient | HTTP | Wake-on-LAN |

Para mais detalhes, veja [../backend/api.md](../backend/api.md).

---

## Padrões de Design

### Design Patterns Utilizados

| Pattern | Uso no Projeto |
|---------|----------------|
| **Provider** | Injeção de dependência e state management |
| **Repository** | Abstração de fontes de dados |
| **Factory** | Criação de objetos complexos |
| **Observer** | ChangeNotifier para reatividade |
| **Strategy** | Diferentes comportamentos de UI |
| **Composite** | Widgets composição |

### Convenções de Código

- **Arquivos:** `snake_case.dart`
- **Classes:** `PascalCase`
- **Variáveis:** `camelCase`
- **Constantes:** `kCamelCase`
- **Privados:** `_prefix` (variáveis), `_ClassName` (classes privadas)

Para mais detalhes, veja [../development/coding-standards.md](../development/coding-standards.md).

---

## Fluxo de Dados

### Fluxo de Inicialização

```
main.dart
  └── runApp()
      └── MultiProvider (providers globais)
          └── MaterialApp
              └── SplashScreen
                  └── LoginScreen
                      └── LoginController
                          └── LoginService
                              └── NexusService (backend)
                                  └── MainScreen
                                      └── Tabs (Home, Arcadia, Cortex, Nexus)
```

### Fluxo de Dados (Exemplo: Device Telemetry)

```
1. TelemetryService.connect(deviceIp)
   └── WebSocket.connect(ws://deviceIp:8081/ws)
       └── Stream<Map<String, dynamic>>

2. DeviceController.subscribe(telemetryStream)
   └── stream.listen((data) {
       _device = Device.fromJson(data);
       notifyListeners();
   })

3. Consumer<DeviceController>(
   builder: (context, controller, _) {
       return DeviceCard(device: controller.device);
   })
```

---

## Segurança

### Autenticação

- **API Key:** Armazenada localmente via `NexusService`
- **Credenciais SSH:** Gerenciadas via `SSHService`
- **OpenCode:** Basic Auth via `OpenCodeService`

### Armazenamento Seguro

| Dado | Local | Método |
|------|-------|--------|
| API Key | SharedPreferences | Encrypted |
| SSH Keys | File system | Permissões restritas |
| Sessão | Memory | Não persistido |

---

## Performance

### Otimizações Implementadas

- **Lazy Loading:** Carregamento sob demanda
- **Skeleton Screens:** Feedback visual durante carregamento
- **Cached Network Image:** Cache de imagens
- **IndexedStack:** Manter estado das tabs
- **AnimationController:** Animações otimizadas

### Limites Conhecidos

- **WebSocket:** Reconexão automática limitada a 5 tentativas
- **WebView:** Consumo de memória significativo
- **Imagens:** Cache ilimitado (pode causar problemas de memória)

---

## Referências

- [Features Implementadas](../features/implemented.md)
- [Design System](../ui/design-system.md)
- [API Backend](../backend/api.md)
- [Desktop Roadmap](../desktop/roadmap.md)
- [Changelog](../changelog.md)

---

*Última atualização: 19 de Julho de 2026*
