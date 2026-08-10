# Desktop Roadmap

**NOVA HUB** — Roadmap para desenvolvimento desktop (Windows, Linux, macOS).

---

## Visão Geral

O NOVA HUB Desktop será construído com Flutter Desktop, reutilizando o máximo de código possível do app mobile.

**Objetivo:** Feature parity com Android, com adaptações para desktop.

---

## Plataformas Alvo

| Plataforma | Status | Prioridade |
|------------|--------|------------|
| Windows | 🚧 Em desenvolvimento | **Alta** |
| Linux | 📋 Planejado | Média |
| macOS | 📋 Planejado | Média |

---

## Fases de Desenvolvimento

### Fase 1: Setup Inicial (Semana 1)

**Objetivo:** Projeto Flutter desktop funcional com tema premium.

**Tarefas:**
- [ ] Criar projeto Flutter desktop
- [ ] Configurar `pubspec.yaml` para desktop
- [ ] Integrar tema premium (`lib/core/theme.dart`)
- [ ] Integrar animações (`lib/core/animations.dart`)
- [ ] Configurar splash screen
- [ ] Testar build Windows

**Dependências:**
- Nenhuma

**Entregável:** Projeto desktop com tela de login funcional.

---

### Fase 2: Core Features (Semana 2-3)

**Objetivo:** Implementar funcionalidades principais.

**Tarefas:**
- [ ] Login Screen (adaptada para desktop)
- [ ] Main Screen com navegação por sidebar
- [ ] Nova Link (Dashboard)
  - [ ] DeviceCard
  - [ ] QuickActions
  - [ ] SystemMonitor
- [ ] Telemetria ao vivo (WebSocket)
- [ ] Controle de volume

**Dependências:**
- Fase 1 concluída
- NOVA Nexus backend rodando

**Entregável:** Dashboard funcional com monitoramento ao vivo.

---

### Fase 3: Módulos Especializados (Semana 4-5)

**Objetivo:** Implementar módulos Arcadia, Cortex e Nexus.

**Tarefas:**
- [ ] Arcadia (Video Games Tracker)
  - [ ] Busca de jogos
  - [ ] Lista de jogos pessoais
  - [ ] Detalhes do jogo
- [ ] Cortex (Knowledge Graph)
  - [ ] Visualização de grafo
  - [ ] Busca de entidades
  - [ ] Detalhes de observações
- [ ] Nexus (PKM Hub)
  - [ ] Workspaces
  - [ ] Items
  - [ ] Tags e categorias

**Dependências:**
- Fase 2 concluída
- API do NOVA Nexus implementada

**Entregável:** Todos os módulos funcionais.

---

### Fase 4: Features Avançadas (Semana 6-7)

**Objetivo:** Implementar features avançadas.

**Tarefas:**
- [ ] SSH Terminal
  - [ ] Conexão SSH
  - [ ] Terminal interativo
  - [ ] Gerenciamento de chaves
- [ ] OpenCode Editor
  - [ ] WebView wrapper
  - [ ] Autenticação básica
- [ ] Command Deck
  - [ ] Lista de comandos
  - [ ] Execução via backend
  - [ ] Confirmação para comandos perigosos
- [ ] Centro de Alertas
  - [ ] Configuração de alertas
  - [ ] Notificações desktop

**Dependências:**
- Fase 3 concluída
- WebSocket implementado

**Entregável:** Todas as features implementadas.

---

### Fase 5: Otimização e Polish (Semana 8)

**Objetivo:** Otimizar performance e refinar UI.

**Tarefas:**
- [ ] Otimizar uso de memória
- [ ] Implementar atalhos de teclado
- [ ] Suporte a múltiplas janelas
- [ ] Notificações desktop nativas
- [ ] Auto-updater
- [ ] Instalador (MSIX/NSIS)

**Dependências:**
- Fase 4 concluída

**Entregável:** Build final otimizado e pronto para distribuição.

---

## Adaptações Desktop

### Layout

| Mobile | Desktop |
|--------|---------|
| Bottom Navigation | Sidebar |
| Full-screen tabs | Split view |
| Pull-to-refresh | Botão de refresh |
| Swipe gestures | Mouse hover/click |

### Interações

| Mobile | Desktop |
|--------|---------|
| Tap | Click |
| Long press | Right click |
| Swipe | Scroll |
| Pinch | Ctrl+Scroll |
| Pull-to-refresh | F5 / Botão refresh |

### Atalhos de Teclado

| Atalho | Ação |
|--------|------|
| `Ctrl+N` | Nova aba/janela |
| `Ctrl+W` | Fechar aba/janela |
| `Ctrl+R` | Refresh |
| `Ctrl+F` | Busca |
| `Ctrl+S` | Salvar |
| `Ctrl+Z` | Desfazer |
| `Ctrl+Y` | Refazer |
| `F1` | Ajuda |
| `F11` | Tela cheia |
| `Esc` | Cancelar/Fechar |

---

## Componentes Desktop

### Sidebar

```dart
class DesktopSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onIndexChanged;
  
  const DesktopSidebar({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AppColors.surface,
      child: Column(
        children: [
          // Logo
          _buildLogo(),
          
          // Navigation items
          _buildNavItem(0, 'Nova Link', Icons.dashboard),
          _buildNavItem(1, 'Arcadia', Icons.games),
          _buildNavItem(2, 'Cortex', Icons.psychology),
          _buildNavItem(3, 'Nexus', Icons.workspaces),
          
          const Spacer(),
          
          // Settings
          _buildNavItem(4, 'Settings', Icons.settings),
        ],
      ),
    );
  }
}
```

### Title Bar Customizada

```dart
class CustomTitleBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      color: AppColors.background,
      child: Row(
        children: [
          // App title
          Text('NOVA HUB'),
          
          const Spacer(),
          
          // Window controls
          WindowControlButton(
            icon: Icons.minimize,
            onTap: () => windowManager.minimize(),
          ),
          WindowControlButton(
            icon: Icons.maximize,
            onTap: () => windowManager.maximize(),
          ),
          WindowControlButton(
            icon: Icons.close,
            onTap: () => windowManager.close(),
          ),
        ],
      ),
    );
  }
}
```

---

## Dependências Desktop

### Novas Dependências

| Dependência | Uso |
|-------------|-----|
| `window_manager` | Controle de janela |
| `bitsdojo_window` | Title bar customizada |
| `tray_manager` | System tray |
| `local_notifier` | Notificações desktop |
| `auto_updater` | Auto-update |
| `desktop_webview` | WebView desktop |

### Dependências Compartilhadas

Todas as dependências atuais são compartilhadas entre mobile e desktop.

---

## Build e Distribuição

### Windows

```bash
# Build
flutter build windows --release

# Output
build/windows/x64/runner/Release/
```

### Formatos de Distribuição

| Formato | Uso |
|---------|-----|
| **MSIX** | Microsoft Store |
| **NSIS** | Instalador tradicional |
| **Portable** | Sem instalação |

### Código de Assinatura

Para distribuição via Microsoft Store, é necessário um certificado de assinatura.

---

## Testes

### Testes de Desktop

- [ ] Testes de unitários
- [ ] Testes de widget
- [ ] Testes de integração
- [ ] Testes de UI
- [ ] Testes de performance

### Cenários de Teste

- [ ] Múltiplas janelas
- [ ] Resoluções diferentes (1080p, 1440p, 4K)
- [ ] Monitores múltiplos
- [ ] Modo tela cheia
- [ ] Modo janela

---

## Referências

- [Arquitetura](../architecture/overview.md)
- [Features](../features/implemented.md)
- [Design System](../ui/design-system.md)
- [API](../backend/api.md)
- [Changelog](../changelog.md)

---

*Última atualização: 19 de Julho de 2026*
