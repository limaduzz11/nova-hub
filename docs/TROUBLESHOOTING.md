# Troubleshooting

## Página sem estilo

Use recarregamento forçado (`Ctrl+Shift+R`). O HTML atual usa `/src/css/*` e `/src/js/*` e responde com `Cache-Control: no-store`.

## Serviço

```bash
systemctl --user status nova-hub-web
journalctl --user -u nova-hub-web -n 100 --no-pager
curl http://100.117.90.59:3001/healthz
```

## Login

Confirme Keycloak em `100.121.250.3:18080` e client ID `nova-hub-v3`.

## Backend

Confirme `systemctl --user status nova-nexus` e que `~/.local/share/nova-nexus/api_key` existe com permissão restrita.

## IGDB/capas

A busca usa o Nexus. Capas vêm de `images.igdb.com`; em indisponibilidade de rota o web exibe placeholder e mantém os dados textuais.

---
## Relações no Context Engine

- [[02-PROJECTS/PROJECT-RELATIONSHIP-MAP|PROJECT RELATIONSHIP MAP]]
- [[02-PROJECTS/NOVA HUB/NOVA HUB V4 WEB/PROJECT|PROJECT]]
- [[03-KNOWLEDGE/ANDROID/CONTEXT-INDEX|CONTEXT INDEX]]
- [[03-KNOWLEDGE/FLUTTER/CONTEXT-INDEX|CONTEXT INDEX]]
- [[02-PROJECTS/NOVA HUB/ARCADIA/PROJECT|PROJECT]]
- [[01-INDEX/CONTEXT-GRAPH|CONTEXT GRAPH]]
