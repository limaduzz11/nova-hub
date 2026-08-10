# Design System

**NOVA HUB** — Sistema de design, paleta de cores, tipografia e componentes.

---

## Visão Geral

O Design System do NOVA HUB é inspirado em OpenAI, Arc Browser, Linear e Material 3 Expressive, com foco em:
- **Deep Space Blue** como cor principal
- **Glassmorphism** para efeitos de vidro
- **Animações suaves** para micro-interações
- **Escuro por padrão** com suporte a claro

---

## Paleta de Cores

### Cores Principais

| Nome | Hex | Uso |
|------|-----|-----|
| `background` | `#020617` | Fundo principal (Slate 950) |
| `surface` | `#0F172A` | Cards, surfaces (Slate 900) |
| `surfaceLight` | `#1E293B` | Elevações (Slate 800) |
| `textPrimary` | `#F8FAFC` | Texto principal (Slate 50) |
| `textSecondary` | `#94A3B8` | Texto secundário (Slate 400) |
| `textTertiary` | `#64748B` | Texto terciário (Slate 500) |

### Cores de Marca

| Nome | Hex | Uso |
|------|-----|-----|
| `primary` | `#2563EB` | Botões, links, ações (Blue 600) |
| `primaryLight` | `#3B82F6` | Hover states (Blue 500) |
| `primaryDark` | `#1D4ED8` | Press states (Blue 700) |

### Cores Neon (Accents)

| Nome | Hex | Uso |
|------|-----|-----|
| `neonBlue` | `#38BDF8` | Highlights (Sky 400) |
| `neonCyan` | `#22D3EE` | Accents (Cyan 400) |
| `neonPurple` | `#A855F7` | Secondary (Purple 500) |
| `neonPink` | `#EC4899` | Alerts especiais (Pink 500) |

### Cores de Status

| Nome | Hex | Uso |
|------|-----|-----|
| `success` | `#10B981` | Online, sucesso (Emerald 500) |
| `warning` | `#F59E0B` | Aviso (Amber 500) |
| `error` | `#EF4444` | Offline, erro (Red 500) |
| `info` | `#3B82F6` | Informação (Blue 500) |

### Cores de Superfície

| Nome | Hex | Uso |
|------|-----|-----|
| `glass` | `rgba(15, 23, 42, 0.6)` | Fundo glassmorphism |
| `glassBorder` | `rgba(148, 163, 184, 0.1)` | Bordas glass |
| `glassHighlight` | `rgba(255, 255, 255, 0.05)` | Highlights glass |

---

## Tipografia

### Hierarquia

| Estilo | Tamanho | Peso | Tracking | Uso |
|--------|---------|------|----------|-----|
| `Display Large` | 57px | w700 | -1.5 | Títulos principais |
| `Display Medium` | 45px | w700 | -0.5 | Subtítulos |
| `Headline Large` | 32px | w600 | -0.5 | Headers de seção |
| `Headline Medium` | 28px | w600 | 0 | Subheaders |
| `Title Large` | 22px | w600 | 0 | Títulos de card |
| `Title Medium` | 16px | w500 | 0.15 | Títulos de item |
| `Body Large` | 16px | w400 | 0.5 | Texto principal |
| `Body Medium` | 14px | w400 | 0.25 | Texto secundário |
| `Body Small` | 12px | w400 | 0.4 | Texto terciário |
| `Label Large` | 14px | w500 | 0.1 | Botões |
| `Label Medium` | 12px | w500 | 0.5 | Labels |
| `Label Small` | 11px | w500 | 0.5 | Badges |
| `Code` | 14px | w400 | 0 | Código |

### Fontes

| Fonte | Uso |
|-------|-----|
| **Inter** | Texto geral |
| **JetBrains Mono** | Código |
| **SF Pro** | iOS (sistema) |
| **Roboto** | Android (sistema) |

---

## Espaçamento

### Grid System

Baseado em 4px.

| Token | Valor | Uso |
|-------|-------|-----|
| `xxs` | 2px | Micro espaçamento |
| `xs` | 4px | Entre elementos pequenos |
| `sm` | 8px | Padding interno |
| `md` | 12px | Padding de cards |
| `lg` | 16px | Padding de seções |
| `xl` | 24px | Margem externa |
| `xxl` | 32px | Margem de seções |
| `xxxl` | 48px | Margem de páginas |

### Exemplos

```dart
// Uso do sistema de espaçamento
Padding(
  padding: const EdgeInsets.all(AppSpacing.md),
  child: Column(
    children: [
      Text('Título'),
      const SizedBox(height: AppSpacing.sm),
      Text('Subtítulo'),
    ],
  ),
)
```

---

## Bordas

### Border Radius

| Token | Valor | Uso |
|-------|-------|-----|
| `xs` | 4px | Elementos pequenos |
| `sm` | 8px | Inputs, badges |
| `md` | 12px | Cards |
| `lg` | 16px | Cards grandes |
| `xl` | 20px | Modals |
| `xxl` | 24px | Bottom sheets |
| `full` | 9999px | Pills, avatares |

---

## Sombras

### Níveis de Elevação

| Nível | Sombra | Uso |
|-------|--------|-----|
| `none` | `none` | Fundo |
| `low` | `0 1px 3px rgba(0,0,0,0.3)` | Cards estáticos |
| `medium` | `0 4px 6px rgba(0,0,0,0.4)` | Cards interativos |
| `high` | `0 10px 15px rgba(0,0,0,0.5)` | Modals, popups |
| `highest` | `0 20px 25px rgba(0,0,0,0.6)` | Dropdowns |

### Exemplos

```dart
// Uso do sistema de sombras
Container(
  decoration: BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadius.md),
    boxShadow: AppShadows.medium,
  ),
)
```

---

## Componentes Base

### GlassContainer

Efeito glassmorphism com backdrop blur.

```dart
GlassContainer(
  child: Text('Conteúdo'),
)
```

**Propriedades:**
- `child` — Widget filho
- `borderRadius` — Raio da borda (padrão: `AppRadius.md`)
- `padding` — Padding interno (padrão: `AppSpacing.md`)
- `blur` — Intensidade do blur (padrão: 10)

### GlassCard

Card com efeito glassmorphism.

```dart
GlassCard(
  title: Text('Título'),
  child: Text('Conteúdo'),
)
```

**Propriedades:**
- `title` — Widget título
- `child` — Widget filho
- `onTap` — Callback de toque
- `padding` — Padding interno

### NovaButton

Botão customizado com variantes.

```dart
NovaButton(
  label: 'Salvar',
  onTap: () => _save(),
  variant: NovaButtonVariant.primary,
)
```

**Variantes:**
- `primary` — Azul preenchido
- `secondary` — Borda azul
- `ghost` — Transparente
- `danger` — Vermelho

### NovaIconButton

Botão de ícone circular.

```dart
NovaIconButton(
  icon: Icons.add,
  onTap: () => _add(),
  size: 40,
)
```

### NovaCard

Card com glassmorphism.

```dart
NovaCard(
  child: Column(
    children: [
      Text('Título'),
      Text('Conteúdo'),
    ],
  ),
)
```

### NovaBadge

Badge de status colorido.

```dart
NovaBadge(
  label: 'Online',
  color: AppColors.success,
)
```

### NovaStatusIndicator

Indicador visual de status.

```dart
NovaStatusIndicator(
  status: 'online',
  size: 8,
)
```

### NovaDivider

Dividers customizados.

```dart
NovaDivider() // Horizontal
NovaDivider.vertical() // Vertical
```

### EmptyState

Estado vazio com ícone e mensagem.

```dart
EmptyState(
  icon: Icons.inbox,
  title: 'Nada por aqui',
  subtitle: 'Adicione algo para começar',
  action: NovaButton(
    label: 'Adicionar',
    onTap: () => _add(),
  ),
)
```

---

## Animações

### Transições

```dart
// Fade
NovaAnimations.fadeIn(child: widget)

// Slide
NovaAnimations.slideIn(child: widget, direction: SlideDirection.fromBottom)

// Scale
NovaAnimations.scaleIn(child: widget)

// Combined
NovaAnimations.fadeSlideIn(child: widget)
```

### Micro-interações

```dart
// Scale on tap
NovaAnimatedScale(
  child: widget,
  onTap: () => _handleTap(),
)

// Hover effect
NovaAnimatedHover(
  child: widget,
  onHover: (isHovered) => _handleHover(isHovered),
)
```

### Skeleton Screens

```dart
// Skeleton loader
SkeletonLoader(
  width: 200,
  height: 20,
)

// Skeleton card
SkeletonCard()
```

### Pulse Animation

```dart
PulseAnimation(
  child: widget,
  color: AppColors.primary,
)
```

---

## Ícones

### Ícones Customizados

| Nome | Ícone | Uso |
|------|-------|-----|
| `AppIcons.logo` | Logo NOVA | Brand |
| `AppIcons.cpu` | CPU | Monitoramento |
| `AppIcons.ram` | RAM | Monitoramento |
| `AppIcons.disk` | Disco | Monitoramento |
| `AppIcons.gpu` | GPU | Monitoramento |
| `AppIcons.network` | Rede | Status |
| `AppIcons.volume` | Volume | Controle |
| `AppIcons.power` | Power | Ações |

### Tamanhos

| Token | Valor | Uso |
|-------|-------|-----|
| `xs` | 12px | Badges |
| `sm` | 16px | Inline |
| `md` | 20px | Botões |
| `lg` | 24px | Cards |
| `xl` | 32px | Headers |
| `xxl` | 48px | Destaque |

---

## Tema Claro

O tema claro é suportado mas não é o padrão.

**Mudanças principais:**
- Background: `#F8FAFC` (Slate 50)
- Surface: `#FFFFFF` (White)
- Text Primary: `#0F172A` (Slate 900)
- Text Secondary: `#64748B` (Slate 500)

---

## Referências

- [Paleta de Cores Completa](../ui/colors.md)
- [Tipografia Detalhada](../ui/typography.md)
- [Componentes](../ui/components.md)
- [Animações](../ui/animations.md)

---

*Última atualização: 19 de Julho de 2026*
