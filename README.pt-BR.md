# NOVA HUB

<div align="center">

**Dashboard Operacional Web & Orquestrador de Infraestrutura Pessoal**

[![Node.js](https://img.shields.io/badge/Node.js-22.x_LTS-339933?style=flat&logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![Express](https://img.shields.io/badge/Express-5.x-000000?style=flat&logo=express&logoColor=white)](https://expressjs.com)
[![Vanilla JS](https://img.shields.io/badge/Frontend-ES6%2B%20%2F%20CSS3-F7DF1E?style=flat&logo=javascript&logoColor=black)](https://developer.mozilla.org)
[![Tailscale](https://img.shields.io/badge/Rede-Tailscale_Mesh_VPN-4F46E5?style=flat&logo=tailscale&logoColor=white)](https://tailscale.com)
[![Xterm.js](https://img.shields.io/badge/Terminal-Xterm.js%20%2B%20PTY-E95420?style=flat)](https://xtermjs.org)
[![Status](https://img.shields.io/badge/Status-Infraestrutura_Pessoal-informational?style=flat)](#escopo-do-repositório)
[![Licença: MIT](https://img.shields.io/badge/Licen%C3%A7a-MIT-blue.svg?style=flat)](LICENSE)

<br />

[English](README.md) &nbsp;|&nbsp; **Português (Brasil)**

<br />


</div>

> Centro de operações web projetado para telemetria unificada de sistemas, orquestração de hardware remoto e acesso interativo a terminal SSH através de uma rede privada Tailscale.

---

## Sumário

- [Conceito & Filosofia](#conceito--filosofia)
- [Arquitetura do Sistema](#arquitetura-do-sistema)
- [Módulos Principais](#módulos-principais)
- [Terminal SSH Web Interativo (PTY)](#terminal-ssh-web-interativo-pty)
- [Modelo de Segurança & Sandboxing](#modelo-de-segurança--sandboxing)
- [Especificações Técnicas](#especificações-técnicas)
- [Escopo do Repositório](#escopo-do-repositório)
- [Licença](#licença)

---

## Conceito & Filosofia

O NOVA HUB é um painel de controle operacional projetado para monitorar, gerenciar e orquestrar estações de trabalho, nós de homelab e serviços locais através de uma interface web unificada.

### Decisões Arquiteturais

- **Stack Web Sem Frameworks Pesados:** Construído sem dependência de SPAs volumosos (React, Vue, Angular). Todo o frontend baseia-se em módulos ES6+ padrão, roteamento leve no cliente e variáveis nativas de CSS (Design System "Midnight Navy"). Isso assegura renderização abaixo de 50ms e consumo residual de memória.
- **Transporte Exclusivo em Rede Mesh:** O dashboard não é exposto para a internet pública nem para nuvens comerciais. Opera estritamente dentro de uma VPN privada baseada em WireGuard (**Tailscale**), viabilizando acesso seguro entre dispositivos com zero portas de entrada expostas.
- **Evolução Web-First:** Originalmente concebido como um aplicativo desktop/mobile em Flutter, a arquitetura migrou na versão V5 para tecnologias web nativas, proporcionando disponibilidade instantânea em navegadores de desktop, tablets e smartphones sem necessidade de compilação ou instalação local.

---

## Arquitetura do Sistema

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                           NAVEGADOR CLIENTE                                 │
│   (Desktop, Tablet, Celular via VPN Privada Tailscale)                      │
│                                                                             │
│   ├── Shell SPA em Vanilla JS (Módulos ES6+, Zero Overhead de Bundler)      │
│   ├── Cliente de Terminal Xterm.js 6.x (@xterm/addon-fit)                   │
│   └── Interface Responsiva Midnight Navy (Propriedades CSS Customizadas)    │
└──────────────────────▲───────────────────────────────▲──────────────────────┘
                       │ HTTP/REST API                 │ WebSockets (WS)
                       │ (Estado & Telemetria)         │ (Terminal Interativo)
┌──────────────────────▼───────────────────────────────▼──────────────────────┐
│                           BACKEND NO HOST                                   │
│                                                                             │
│   ┌───────────────────────────────────┐ ┌─────────────────────────────────┐ │
│   │        API Central Express 5      │ │      Daemon de Terminal (WS)    │ │
│   │  • Autenticação & Guard CSRF      │ │  • Multiplexador via node-pty   │ │
│   │  • Coletor de Telemetria de HW    │ │  • Streaming ANSI / Truecolor   │ │
│   │  • Introspecção de Units systemd  │ │  • Redimensionamento Dinâmico   │ │
│   └─────────────────┬─────────────────┘ └────────────────┬────────────────┘ │
│                     │                                    │                  │
│                     ▼                                    ▼                  │
│   ┌───────────────────────────────────────────────────────────────────────┐ │
│   │                     SISTEMA OPERACIONAL DO HOST                       │ │
│   │  • Sensores do Kernel Linux (CPU / Memória / Discos / GPU)            │ │
│   │  • Gerenciador de Serviços systemd (Status & Controle de Energia)     │ │
│   │  • Servidor OpenSSH Local (Autenticação Estrita por Chave)            │ │
│   └───────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Módulos Principais

| Módulo | Classificação | Escopo & Capacidades |
| :--- | :---: | :--- |
| **Link** | Operações & Telemetria | Layout em bento grid exibindo carga de CPU, consumo de memória, partições de disco, métricas de GPU, tempo de atividade (uptime), interfaces de rede, controle de energia (WOL, reinicialização, suspensão) e terminal SSH embutido. |
| **Nexus** | Orquestração de Tarefas | Quadro Kanban horizontal com drag-and-drop HTML5 nativo, separação por workspaces (Trabalho, Pessoal, Rotina, Estudos), filtros rápidos por prioridade/tags e exportação de relatórios no cliente. |
| **Arcadia** | Mídia & Streaming | Catálogo e biblioteca local de mídia com layout adaptativo, enriquecimento de metadados via IGDB e acionamento integrado para sessões remotas via Moonlight / Sunshine. |
| **Cortex** | Grafo de Conhecimento | Motor próprio de grafo com física de forças em Canvas 2D, mapeando conexões entre notas, documentos e nós conceituais sem necessidade de banco de dados de grafos dedicado. |
| **Settings** | Diagnóstico & Integridade | Diagnóstico em tempo real de serviços gerenciados via `systemd`, integridade de nós na rede Tailscale, validação de cabeçalhos de segurança e controle de sessões ativas. |

---

## Terminal SSH Web Interativo (PTY)

Diferente de consoles web que executam comandos isolados através de processos descartáveis sem persistência, o NOVA HUB integra um emulador de terminal com estado contínuo:

- **Multiplexação no Backend (`node-pty`):** Cria pseudo-terminais no host através da chamada POSIX `forkpty`, preservando estado do shell, variáveis de ambiente, controle de jobs e utilitários interativos (`vim`, `htop`, `tmux`).
- **Streaming por WebSocket (`ws`):** Canal bidirecional de baixa latência transmitindo sequências de escape ANSI, paleta Truecolor de 24 bits e entradas de teclado diretamente entre o navegador e o PTY.
- **Emulação no Frontend (`@xterm/xterm`):** Renderização acelerada em canvas com ajuste automático do viewport (`@xterm/addon-fit`) diante de mudanças na janela do navegador, propagando sinais `SIGWINCH` ao shell remoto.
- **Isolamento e Acesso:** Restrito a sessões autenticadas originadas de IPs validados da Tailscale, com autenticação configurada via par de chaves SSH dedicado.

---

## Modelo de Segurança & Sandboxing

- **Isolamento de Rede:** O serviço responde unicamente no endereço `127.0.0.1` e no IP correspondente à interface privada Tailscale. Nenhuma porta é mapeada para redes públicas ou roteadores de borda.
- **Defesa em Camadas:**
  - Content Security Policy (`CSP`) rigoroso, restringindo execução de scripts não autorizados e iframes.
  - Cabeçalhos de proteção HTTP (`X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`).
  - Validação criptográfica de tokens CSRF em todas as operações com efeito colateral.
- **Isolamento de Processo via systemd:** Quando executado em background, o serviço roda sob sandbox restritivo:
  ```ini
  NoNewPrivileges=yes
  ProtectSystem=strict
  ProtectHome=read-only
  PrivateTmp=yes
  DevicePolicy=closed
  ```

---

## Especificações Técnicas

| Componente | Tecnologia | Papel no Sistema |
| :--- | :--- | :--- |
| **Runtime do Backend** | Node.js 22 LTS | Loop de eventos assíncrono e hospedeiro de serviços |
| **Framework HTTP** | Express 5.x | Rotas de API REST, pipeline de middlewares, entrega estática |
| **Núcleo de Terminal** | `node-pty` + `ws` | Alocação de PTY no kernel e streaming via WebSockets |
| **Shell do Frontend** | JavaScript Puro (Módulos ES6) | Cliente SPA sem dependências e gerenciamento reativo leve |
| **Estilização** | CSS3 Nativo ("Midnight Navy") | Layouts em Grid e Flexbox, alto contraste focado em monitoramento |
| **Emulador no Navegador** | `@xterm/xterm` 6.x | Renderizador de terminal ANSI / Truecolor no cliente |
| **Garantia de Qualidade** | Playwright | Validação de matriz visual responsiva e testes de fumaça |

---

## Escopo do Repositório

Este repositório documenta a especificação arquitetural, os padrões de design e a visão conceitual do **NOVA HUB**. Por se tratar de uma plataforma de infraestrutura pessoal, scripts operacionais internos e credenciais locais são mantidos fora do versionamento público.

---

## Licença

Distribuído sob a licença [MIT](LICENSE).

---

<div align="center">
  <sub>Projetado e mantido por <b>Eduardo de Lima Paranhos</b></sub>
</div>
