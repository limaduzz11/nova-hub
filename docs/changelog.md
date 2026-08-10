# Changelog

**NOVA HUB** — Histórico de versões.

---

## [2.0.0+7] - 2026-07-19

### Added
- **Splash Screen** premium com animação 2.1s
- **Sistema de animações** completo (`NovaAnimations`)
- **Skeleton screens** para loading states
- **Micro-interações** (`NovaAnimatedScale`, `NovaAnimatedHover`)
- **Shimmer effects** para feedback visual
- **Pulse animation** para status
- **Staggered animations** para listas
- **Design System** completo (`AppColors`, `AppTypography`, `AppSpacing`)
- **Glassmorphism** components (`GlassContainer`, `GlassCard`)
- **NovaButton** com variantes (primary, secondary, ghost, danger)
- **NovaIconButton** para ações circulares
- **NovaBadge** para status
- **NovaStatusIndicator** para indicadores visuais
- **EmptyState** para estados vazios
- **Logo glow effect** na splash screen

### Changed
- **Visual identity** premium (Deep Space Blue + Glassmorphism)
- **Tema** reescrito com paleta completa
- **Tipografia** hierarquizada (Display → Code)
- **Espaçamentos** baseados em grid 4px
- **Sombras** em 5 níveis de elevação
- **Border radius** com 7 tokens

### Removed
- **11 arquivos órfãos** (screens, services, models, testes não utilizados)
- **6 dependências** não utilizadas (`multicast_dns`, `xml`, `pointycastle`, `basic_utils`, `asn1lib`, `ffi`)
- **Diretório `native/`** (236MB) — remote streaming removido
- **Código nativo Android** para remote streaming
- **Screenshots de teste** (13 arquivos)

### Fixed
- **Nenhum bug crítico** conhecido nesta versão

---

## [2.0.0+6] - 2026-07-18

### Added
- **Remote streaming** (removido posteriormente)
- **Botão "Remoto"** na UI (substituído por "Moonlight")

### Changed
- **Navegação** para remote streaming

### Removed
- **Remote streaming** completo (decisão de produto)

---

## [2.0.0+5] - 2026-07-17

### Added
- **Command Deck** — Grade de ações rápidas
- **Centro de Alertas** — Configuração de alertas
- **OpenCode Editor** — WebView integrado
- **SSH Terminal** — Terminal SSH completo
- **UpSnap Client** — Wake-on-LAN

### Changed
- **Layout** para acomodar novos módulos
- **Navegação** para incluir novas telas

---

## [2.0.0+4] - 2026-07-16

### Added
- **Arcadia** — Video Games Tracker
- **Cortex** — Knowledge Graph
- **Nexus** — PKM Hub
- **Proxy IGDB** para dados de jogos

### Changed
- **Dashboard** para incluir novos módulos
- **Sidebar** para navegação entre módulos

---

## [2.0.0+3] - 2026-07-15

### Added
- **Telemetria ao vivo** via WebSocket
- **Monitoramento** de CPU, RAM, Disco, GPU
- **Controle de volume**
- **Status de rede**

### Changed
- **Device Card** para mostrar dados em tempo real

---

## [2.0.0+2] - 2026-07-14

### Added
- **Login Screen** com animações
- **Main Screen** com IndexedStack
- **Bottom Navigation** com 4 tabs
- **Provider** para state management

### Changed
- **Navegação** para suportar múltiplas tabs

---

## [2.0.0+1] - 2026-07-13

### Added
- **Projeto Flutter** inicial
- **Tema básico** (Dark theme)
- **Estrutura de pastas**
- **Dependências** iniciais

### Changed
- N/A

### Removed
- N/A

---

## [2.0.0] - 2026-07-12

### Added
- **Release inicial** do NOVA HUB
- **Controle de dispositivo** básico
- **Conexão** com NOVA Nexus

### Changed
- N/A

### Removed
- N/A

---

## Legenda

| Status | Descrição |
|--------|-----------|
| ✅ | Implementado |
| 🚧 | Em desenvolvimento |
| 📋 | Planejado |
| ❌ | Não suportado |

---

## Referências

- [Features Implementadas](features/implemented.md)
- [Desktop Roadmap](desktop/roadmap.md)
- [Arquitetura](architecture/overview.md)

---

*Última atualização: 19 de Julho de 2026*
