# Mapeamento Android → Web

| Módulo Android | Recurso | Endpoint | Implementação Web | Status |
|---|---|---|---|---|
| Auth | Login/logout/refresh | Keycloak token | sessão server-side | Implementado |
| Link | Telemetria | `/api/v1/telemetry` | cards responsivos/polling | Implementado |
| Link | WOL/desligar | `/api/power/wol`, `/api/power/off` | botões + confirmação | Implementado |
| Link | SSH interativo | SSH:22 | abertura `ssh://` | Parcial; terminal embutido pendente |
| Nexus | Workspaces/kanban | `/api/workspaces`, `/api/items` | leitura, criação, edição, status e exclusão | Implementado |
| Nexus | Busca/filtros/exportação | mesmos dados + export local | busca em título/corpo/tags; filtros status/tag/tipo; PNG e PDF/impressão | Implementado |
| Arcadia | Biblioteca/IGDB | `/api/library`, `/api/igdb/*` | busca resiliente, status, grade/lista e inclusão configurável | Implementado |
| Arcadia | Edição/detalhe completo | `/api/library/{id}` | detalhe, status, avaliação, notas e exclusão | Implementado |
| Arcadia | Notícias | `/api/news` | cards com links | Implementado |
| Arcadia | Moonlight | app/intent Android | companion: saúde Sunshine, host Tailscale e downloads oficiais | Implementado externo; sem streaming próprio |
| Cortex | Grafo completo | `/api/graph` | Canvas com mais de 1100 nós | Implementado |
| Cortex | Lista/filtros/controles | mesmo grafo | busca, lista, grupos, detalhes, zoom/pan e parâmetros físicos | Implementado |
| Settings | Estado/configuração | múltiplos | sessão, Nexus, Sunshine, navegador e controles de segurança | Implementado |

---
## Relações no Context Engine

- [[02-PROJECTS/PROJECT-RELATIONSHIP-MAP|PROJECT RELATIONSHIP MAP]]
- [[02-PROJECTS/NOVA HUB/NOVA HUB V4 WEB/PROJECT|PROJECT]]
- [[03-KNOWLEDGE/ANDROID/CONTEXT-INDEX|CONTEXT INDEX]]
- [[03-KNOWLEDGE/FLUTTER/CONTEXT-INDEX|CONTEXT INDEX]]
- [[02-PROJECTS/NOVA HUB/ARCADIA/PROJECT|PROJECT]]
- [[01-INDEX/CONTEXT-GRAPH|CONTEXT GRAPH]]
