# Arquitetura

O frontend HTML/CSS/JavaScript é servido por Node.js/Express exclusivamente no IP Tailscale. O navegador nunca recebe a chave do Nexus nem tokens Keycloak.

```text
Navegador ──cookie HttpOnly──> NOVA HUB V4 WEB :3001
                                  ├── Keycloak :18080 (login/refresh)
                                  └── NOVA Nexus :8080 (proxy com API key no servidor)
                                              └── SQLite oficial compartilhado
```

- Sessões são mantidas em memória, expiram conforme o refresh token e são revogadas no logout.
- Escritas exigem token CSRF.
- Web e Android usam o mesmo Nexus e o mesmo SQLite; não existe banco web.
- O projeto Android permanece em seu local original e não é importado pelo web.
- `/web-api/integrations/moonlight` é autenticado e faz somente sondagem TCP local das portas Sunshine; não inicia processos, não expõe credenciais e não transporta streaming.

---
## Relações no Context Engine

- [[02-PROJECTS/PROJECT-RELATIONSHIP-MAP|PROJECT RELATIONSHIP MAP]]
- [[02-PROJECTS/NOVA HUB/NOVA HUB V4 WEB/PROJECT|PROJECT]]
- [[03-KNOWLEDGE/ANDROID/CONTEXT-INDEX|CONTEXT INDEX]]
- [[03-KNOWLEDGE/FLUTTER/CONTEXT-INDEX|CONTEXT INDEX]]
- [[02-PROJECTS/NOVA HUB/ARCADIA/PROJECT|PROJECT]]
- [[01-INDEX/CONTEXT-GRAPH|CONTEXT GRAPH]]
