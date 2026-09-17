# NOVA HUB

<div align="center">

**Private Web Operations & Personal Infrastructure Dashboard**

[![Node.js](https://img.shields.io/badge/Node.js-22.x_LTS-339933?style=flat&logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![Express](https://img.shields.io/badge/Express-5.x-000000?style=flat&logo=express&logoColor=white)](https://expressjs.com)
[![Vanilla JS](https://img.shields.io/badge/Frontend-ES6%2B%20%2F%20CSS3-F7DF1E?style=flat&logo=javascript&logoColor=black)](https://developer.mozilla.org)
[![Tailscale](https://img.shields.io/badge/Network-Tailscale_Mesh_VPN-4F46E5?style=flat&logo=tailscale&logoColor=white)](https://tailscale.com)
[![Xterm.js](https://img.shields.io/badge/Terminal-Xterm.js%20%2B%20PTY-E95420?style=flat)](https://xtermjs.org)
[![Status](https://img.shields.io/badge/Status-Personal_Infrastructure-informational?style=flat)](#repository-scope)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat)](LICENSE)

<br />

**English** &nbsp;|&nbsp; [Português (Brasil)](README.pt-BR.md)

<br />


</div>

> A private, web-first operations center designed for unified system telemetry, remote hardware orchestration, and persistent terminal access across a personal Tailscale mesh network.

---

## Table of Contents

- [Concept & Philosophy](#concept--philosophy)
- [System Architecture](#system-architecture)
- [Core Modules](#core-modules)
- [Interactive Web Terminal (PTY)](#interactive-web-terminal-pty)
- [Security & Sandbox Model](#security--sandbox-model)
- [Technical Specifications](#technical-specifications)
- [Repository Scope](#repository-scope)
- [License](#license)

---

## Concept & Philosophy

NOVA HUB is a centralized operational cockpit built to monitor, manage, and orchestrate personal workstations, homelab nodes, and local services through a unified web interface.

### Architectural Decisions

- **Zero-Framework Web Stack:** Built without heavyweight SPA frameworks (React, Vue, Angular). The entire frontend relies on standard ES6+ modules, a lightweight custom client-side router, and native CSS custom properties ("Midnight Navy" design system). This guarantees sub-50ms page loads and minimal memory consumption.
- **Mesh-Only Transport:** The dashboard is not published to public domains or cloud hosting. It operates exclusively across a private, WireGuard-backed **Tailscale VPN** mesh, enabling secure cross-device access from anywhere with zero exposed ingress ports.
- **Web-First Evolution:** Initially prototyped as a cross-platform Flutter application, the architecture transitioned in V5 to a web-native stack. This provides instant accessibility across desktop, tablet, and mobile browsers without requiring platform-specific binary installations.

---

## System Architecture

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CLIENT BROWSER                                    │
│   (Desktop, Tablet, Mobile over Tailscale Encrypted Mesh)                   │
│                                                                             │
│   ├── Vanilla JS SPA Shell (ES6 Modules, Zero Bundler Overhead)             │
│   ├── Xterm.js 6.x Terminal Client (@xterm/addon-fit)                       │
│   └── Midnight Navy Responsive UI (CSS Custom Properties)                   │
└──────────────────────▲───────────────────────────────▲──────────────────────┘
                       │ HTTP/REST API                 │ WebSockets (WS)
                       │ (State & Telemetry)           │ (Interactive Terminal)
┌──────────────────────▼───────────────────────────────▼──────────────────────┐
│                           HOST BACKEND                                      │
│                                                                             │
│   ┌───────────────────────────────────┐ ┌─────────────────────────────────┐ │
│   │        Express 5 Core API         │ │       Terminal Daemon (WS)      │ │
│   │  • Session Auth & CSRF Guard      │ │  • node-pty Spawn Multiplexer   │ │
│   │  • Hardware Telemetry Collector   │ │  • ANSI / Truecolor Streaming   │ │
│   │  • Systemd Unit Introspection     │ │  • Dynamic Viewport Resize      │ │
│   └─────────────────┬─────────────────┘ └────────────────┬────────────────┘ │
│                     │                                    │                  │
│                     ▼                                    ▼                  │
│   ┌───────────────────────────────────────────────────────────────────────┐ │
│   │                       HOST OPERATING SYSTEM                           │ │
│   │  • Linux Kernel Hardware Sensors (CPU / RAM / Disks / GPU)            │ │
│   │  • systemd Service Manager (Unit Health & Power Control)              │ │
│   │  • Local OpenSSH Server (Key-Based Authentication)                    │ │
│   └───────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Core Modules

| Module | Classification | Scope & Capabilities |
| :--- | :---: | :--- |
| **Link** | Operations & Telemetry | Bento grid layout displaying live CPU load, memory utilization, disk mounts, GPU metrics, system uptime, network interfaces, power controls (WOL, reboot, suspend), and the embedded interactive SSH terminal. |
| **Nexus** | Task Orchestration | Horizontal Kanban workspace with HTML5 drag-and-drop, multi-workspace segregation (Work, Personal, Routine, Studies), instant filtering by priority and tags, and client-side snapshot exports. |
| **Arcadia** | Media & Streaming | Local media library catalog with adaptive layout, external metadata aggregation via IGDB, and companion orchestration for remote streaming sessions via Moonlight / Sunshine. |
| **Cortex** | Knowledge Graph | Canvas-based force-directed graph engine visualizing document relationships, cross-references, and structural hierarchies without external graph database dependencies. |
| **Settings** | Diagnostics & System Health | Introspection of active `systemd` units, Tailscale node connection diagnostics, security configuration validation, and session lifecycle controls. |

---

## Interactive Web Terminal (PTY)

Unlike typical web consoles that execute stateless shell commands through one-off child processes, NOVA HUB integrates a persistent, stateful terminal emulator:

- **Backend Multiplexing (`node-pty`):** Spawns native pseudo-terminals on the host machine using POSIX `forkpty`, maintaining shell state, environment variables, job control, and interactive sessions (`vim`, `htop`, `tmux`).
- **WebSocket Streaming (`ws`):** Bi-directional, low-latency binary streams transport ANSI escape sequences, Truecolor rendering, and keyboard inputs directly between the browser and the PTY.
- **Frontend Emulation (`@xterm/xterm`):** Hardware-accelerated terminal canvas rendering with automatic viewport recalculation (`@xterm/addon-fit`) upon browser window resizing (`SIGWINCH` propagation).
- **Access Control:** Restricted strictly to authenticated sessions originating from verified Tailscale IP addresses with dedicated SSH keypair authentication.

---

## Security & Sandbox Model

- **Network Boundary:** The service binds solely to `127.0.0.1` and the private Tailscale interface IP. All external interfaces are unmapped, preventing access from unauthorized LAN devices or public networks.
- **Defense in Depth:**
  - Strict Content Security Policy (`CSP`) preventing unvetted scripts, frames, and inline injections.
  - Hardened HTTP response headers (`X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`).
  - Cryptographic CSRF tokens validated on all state-mutating requests.
- **Systemd Sandboxing:** When running as a daemon, the service executes with hardened systemd isolation flags:
  ```ini
  NoNewPrivileges=yes
  ProtectSystem=strict
  ProtectHome=read-only
  PrivateTmp=yes
  DevicePolicy=closed
  ```

---

## Technical Specifications

| Component | Technology | Role |
| :--- | :--- | :--- |
| **Backend Runtime** | Node.js 22 LTS | Asynchronous event loop and service host |
| **HTTP Framework** | Express 5.x | REST API routes, middleware pipeline, static asset delivery |
| **Terminal Core** | `node-pty` + `ws` | Pseudo-terminal multiplexing and WebSocket socket pipe |
| **Frontend Shell** | Vanilla JavaScript (ES6 Modules) | Zero-dependency SPA client and reactive state |
| **Styling** | Custom CSS3 ("Midnight Navy") | Responsive layouts, CSS Grid / Flexbox, high-contrast dark theme |
| **Terminal Frontend** | `@xterm/xterm` 6.x | ANSI/Truecolor terminal emulator in the browser |
| **Quality & QA** | Playwright | End-to-end visual matrix regression and component smoke testing |

---

## Repository Scope

This repository documents the architectural blueprint, design patterns, and core concept of **NOVA HUB**. Because it is tailored to a personal infrastructure topology, private operational scripts and local network credentials are maintained outside public tracking.

---

## License

Published under the [MIT License](LICENSE).

---

<div align="center">
  <sub>Designed & engineered by <b>Eduardo de Lima Paranhos</b></sub>
</div>
