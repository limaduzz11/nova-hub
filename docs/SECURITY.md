# Segurança

- Acesso de rede restrito ao IP Tailscale.
- Login obrigatório via Keycloak.
- Cookie de sessão `HttpOnly`, `SameSite=Strict` e com expiração.
- Tokens Keycloak e chave Nexus permanecem no processo Node.
- Token CSRF obrigatório em POST/PATCH/DELETE.
- Rate limit simples de login: 6 tentativas por 10 minutos/IP.
- CSP, `X-Frame-Options: DENY`, `nosniff`, referrer e permissions policies.
- Nenhum segredo em HTML, JavaScript, localStorage ou sessionStorage.
- Companion Moonlight apenas sonda portas Sunshine localmente após autenticação; não executa comandos nem expõe credenciais.
- Terminal SSH embutido autenticado por sessão + same-origin, com PTY (node-pty) e chave dedicada `nova_hub_key_web` exclusiva da web, nunca a mesma do app. Limite de sessões (8), timeout de detach (15s), buffer máx. 256KB, TTL de 60min, BatchMode e StrictHostKeyChecking=yes. Blindado por `DevicePolicy=closed` + `DeviceAllow` de PTY no systemd.

Pendência: habilitar HTTPS interno/Tailscale Serve antes de marcar cookie `Secure`.

---
## Relações no Context Engine

- [[02-PROJECTS/PROJECT-RELATIONSHIP-MAP|PROJECT RELATIONSHIP MAP]]
- [[02-PROJECTS/NOVA HUB/NOVA HUB V4 WEB/PROJECT|PROJECT]]
- [[03-KNOWLEDGE/ANDROID/CONTEXT-INDEX|CONTEXT INDEX]]
- [[03-KNOWLEDGE/FLUTTER/CONTEXT-INDEX|CONTEXT INDEX]]
- [[02-PROJECTS/NOVA HUB/ARCADIA/PROJECT|PROJECT]]
- [[01-INDEX/CONTEXT-GRAPH|CONTEXT GRAPH]]
