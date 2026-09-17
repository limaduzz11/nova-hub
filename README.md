# NOVA HUB V5 WEB

<div align="center">

### Private Web Operations & Infrastructure Dashboard
**Built for System Telemetry, SSH Management, and Operational Orchestration**

[![Node.js](https://img.shields.io/badge/Node.js-22.x-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![Express](https://img.shields.io/badge/Express-5.x-000000?style=for-the-badge&logo=express&logoColor=white)](https://expressjs.com)
[![Vanilla JS](https://img.shields.io/badge/Vanilla-JS%20%2F%20CSS3-F7DF1E?style=for-the-badge&logo=javascript&logoColor=black)](https://developer.mozilla.org)
[![Tailscale](https://img.shields.io/badge/Network-Tailscale%20VPN-4F46E5?style=for-the-badge&logo=tailscale&logoColor=white)](https://tailscale.com)
[![Xterm.js](https://img.shields.io/badge/Terminal-Xterm.js%20%2B%20PTY-E95420?style=for-the-badge)](https://xtermjs.org)
[![Playwright](https://img.shields.io/badge/QA-Playwright-2EAD33?style=for-the-badge&logo=playwright&logoColor=white)](https://playwright.dev)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)

</div>

---

## 📌 Visão Geral

O **NOVA HUB V5 WEB** é um dashboard operacional e de infraestrutura web-first projetado para telemetria em tempo real, orquestração de tarefas e administração remota de sistemas locais.

Evoluído a partir do protótipo multiplataforma inicial em Flutter, a arquitetura V5 é **100% Web**, focando em desempenho ultrarrápido, baixo consumo de recursos e zero overhead de frameworks SPA pesados (utilizando JavaScript puro, Express 5 e WebSockets nativos). A aplicação opera sob uma rede privada malhada (**Tailscale VPN**), garantindo isolamento total da LAN pública e da internet exposta.

> [!NOTE]
> O código histórico do aplicativo móvel/desktop em Flutter foi preservado na branch [`legacy-flutter`](https://github.com/limaduzz11/nova-hub/tree/legacy-flutter).

---

## 🧩 Módulos Principais

| Módulo | Status | Descrição Técnica |
|---|:---:|---|
| **Link** | ✅ | **Telemetria & Controle:** Bento grid dinâmico com métricas de CPU, RAM, discos, uptime, Wake-on-LAN (WOL), controle de energia e **Terminal SSH interativo embutido**. |
| **Nexus** | ✅ | **Kanban Operacional:** Board horizontal fluido com drag & drop HTML5, filtros avançados por severidade/prazo/tags, busca instantânea e exportação em PNG/PDF. |
| **Arcadia** | ✅ | **Catálogo & Streaming:** Biblioteca de mídia com fallback visual, agregação IGDB e integração companion com Moonlight / Sunshine. |
| **Cortex** | ✅ | **Grafo de Conhecimento:** Visualizador contínuo de nós e arestas com motor físico próprio, agrupamento semântico e drawer de metadados. |
| **Settings** | ✅ | **Diagnóstico do Sistema:** Verificação de integridade de serviços `systemd`, status de conexões, segurança e gerenciamento de sessões. |

---

## 🖥️ Terminal SSH Web Interativo (PTY)

Diferente de interfaces web convencionais que executam comandos isolados via shell exec sem estado, o NOVA HUB integra um **emulador de terminal completo no navegador**:
- **Backend PTY:** Multiplexador de pseudo-terminais via `node-pty` e WebSockets (`ws`).
- **Frontend Xterm.js:** Renderização de alta fidelidade com `@xterm/xterm` e `@xterm/addon-fit`, suporte a 256 cores, Truecolor, redimensionamento dinâmico de viewport e atalhos de teclado nativos.
- **Segurança:** Isolamento por chave SSH dedicada, autenticação de sessão e validação estrita de origem de WebSockets.

---

## 🏛️ Arquitetura do Sistema

```text
nova-hub/
├── public/                  # Documento HTML principal e assets estáticos
│   ├── assets/              # Identidade visual SVG, ícones e fontes locais
│   └── index.html           # Shell da aplicação web
├── src/
│   ├── css/                 # Design System Midnight Navy + layout modular
│   │   ├── base.css
│   │   ├── components.css
│   │   └── modules/         # Estilos específicos de cada módulo
│   └── js/
│       ├── app.js           # Inicialização e orquestração de módulos
│       ├── modules/         # Link, Nexus Kanban, Arcadia, Cortex Graph, Settings
│       └── utils/           # API Client com CSRF, Router SPA leve, terminal client
├── docs/                    # Especificações de arquitetura, segurança e deploy
├── tests/                   # Testes de fumaça, matriz visual e integração
├── server.js                # Servidor Express 5 (HTTP API, proxy reverso, auth)
├── terminal-server.js       # Servidor WebSocket + node-pty para sessões SSH
└── package.json             # Dependências de runtime e ferramentas de QA
```

---

## 🚀 Como Executar Localmente

### Pré-requisitos
- **Node.js**: >= 20.x (recomendado Node.js 22 LTS)
- **npm**: >= 10.x
- Cliente OpenSSH instalado no host

### Instalação

1. **Clone o repositório:**
   ```bash
   git clone https://github.com/limaduzz11/nova-hub.git
   cd nova-hub
   ```

2. **Instale as dependências:**
   ```bash
   npm install
   ```

3. **Configure as variáveis de ambiente:**
   ```bash
   cp .env.example .env
   # Edite o .env conforme a sua infraestrutura local
   ```

4. **Inicie o servidor de desenvolvimento:**
   ```bash
   npm start
   ```

   Acesse no navegador: `http://localhost:3001`

---

## 🧪 Validação & Testes

O projeto conta com rotinas de verificação sintática, testes de fumaça e testes de matriz visual com Playwright:

```bash
# Verificação de sintaxe de todos os arquivos JS
npm run check

# Executar testes de fumaça
npm test

# Executar testes da matriz visual responsiva (6 viewports)
npm run test:visual

# Teste de integração do terminal PTY
npm run test:terminal
```

---

## 🔒 Segurança & Hardening

- **Isolamento de Rede:** Por padrão configurado para escutar apenas em loopback ou IP seguro de VPN privada (Tailscale).
- **Proteção CSRF & Headers:** Uso de tokens CSRF criptográficos em todas as mutações e cabeçalhos defensivos (`X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`).
- **Defesa em Profundidade:** Suporte nativo a execução via unit systemd com diretivas restritivas (`NoNewPrivileges`, `ProtectSystem=strict`, `PrivateTmp`).

---

## 📄 Licença

Distribuído sob a licença **MIT**. Consulte [`LICENSE`](LICENSE) para mais detalhes.

---

<div align="center">
  <sub>Criado e mantido por <b>Eduardo de Lima Paranhos</b></sub>
</div>
