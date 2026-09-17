# Instalação

Requisitos: Node.js 24+, npm, Tailscale conectado e serviços `nova-nexus`/Keycloak acessíveis.

```bash
cd "/media/limaduzz/HD 1TB LDUZZ 2/NOVA CONTEXT ENGINE V2/02-PROJECTS/NOVA HUB/NOVA HUB V4 WEB"
npm ci
npm run check
npm test
```

Não copie segredos para `.env`. A chave do Nexus é lida pelo backend web de `~/.local/share/nova-nexus/api_key`.

---
## Relações no Context Engine

- [[02-PROJECTS/PROJECT-RELATIONSHIP-MAP|PROJECT RELATIONSHIP MAP]]
- [[02-PROJECTS/NOVA HUB/NOVA HUB V4 WEB/PROJECT|PROJECT]]
- [[03-KNOWLEDGE/ANDROID/CONTEXT-INDEX|CONTEXT INDEX]]
- [[03-KNOWLEDGE/FLUTTER/CONTEXT-INDEX|CONTEXT INDEX]]
- [[02-PROJECTS/NOVA HUB/ARCADIA/PROJECT|PROJECT]]
- [[01-INDEX/CONTEXT-GRAPH|CONTEXT GRAPH]]
