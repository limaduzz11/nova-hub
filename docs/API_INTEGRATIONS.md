# Integrações de API

| Integração | Android | Web | Credencial | Compartilhamento/observação |
|---|---|---|---|---|
| NOVA Nexus | Retrofit | Proxy server-side | `Bearer OIDC` (Keycloak) | Token nunca enviado ao browser; proxy injeta `Authorization` |
| Keycloak | password/refresh grant | password/refresh server-side | client público `nova-hub-v3` | Mesma configuração; tokens ficam no servidor web |
| Twitch/IGDB | Proxy Nexus | Proxy Nexus | Client ID/Secret no Nexus | Mesmas credenciais; nenhum segredo no web |
| News RSS | Proxy Nexus | Proxy Nexus | nenhuma | Reutilização integral |
| Telemetria | REST Nexus | REST via proxy | Bearer OIDC | Polling de 7 s |
| Cortex | `/api/graph` | `/api/graph` via proxy | Bearer OIDC | Vault oficial CONTEXT ENGINE V2 |
| Power/WOL | Nexus/Relay | Nexus via proxy | Bearer OIDC | Confirmação para desligamento |
| SSH | JSch Android | terminal web embutido (WebSocket/PTY) + protocolo externo `ssh://` no companion | chave dedicada `nova_hub_key_web` (server-side) | Implementado via `terminal-server.js` (xterm.js + node-pty); chave nunca sai do servidor |
| Moonlight | app Android | companion web autenticado | nenhuma no frontend | Verifica portas Sunshine, copia host Tailscale e aponta downloads oficiais; streaming continua externo |

Nenhuma credencial exclusiva adicional é necessária para os fluxos já implementados.

---
## Relações no Context Engine

- [[02-PROJECTS/PROJECT-RELATIONSHIP-MAP|PROJECT RELATIONSHIP MAP]]
- [[02-PROJECTS/NOVA HUB/NOVA HUB V4 WEB/PROJECT|PROJECT]]
- [[03-KNOWLEDGE/ANDROID/CONTEXT-INDEX|CONTEXT INDEX]]
- [[03-KNOWLEDGE/FLUTTER/CONTEXT-INDEX|CONTEXT INDEX]]
- [[02-PROJECTS/NOVA HUB/ARCADIA/PROJECT|PROJECT]]
- [[01-INDEX/CONTEXT-GRAPH|CONTEXT GRAPH]]
