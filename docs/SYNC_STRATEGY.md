# Estratégia de Sincronização

Não existe replicação web. Todas as operações Nexus, Arcadia e Cortex usam o mesmo backend Go e o mesmo `nexus.db` do Android.

- IDs e timestamps são gerados pelo backend oficial.
- Alterações web ficam imediatamente disponíveis ao Android na próxima leitura/polling.
- Alterações Android ficam imediatamente disponíveis ao web na próxima leitura.
- Não há fila ou banco paralelo no navegador.

---
## Relações no Context Engine

- [[02-PROJECTS/PROJECT-RELATIONSHIP-MAP|PROJECT RELATIONSHIP MAP]]
- [[02-PROJECTS/NOVA HUB/NOVA HUB V4 WEB/PROJECT|PROJECT]]
- [[03-KNOWLEDGE/ANDROID/CONTEXT-INDEX|CONTEXT INDEX]]
- [[03-KNOWLEDGE/FLUTTER/CONTEXT-INDEX|CONTEXT INDEX]]
- [[02-PROJECTS/NOVA HUB/ARCADIA/PROJECT|PROJECT]]
- [[01-INDEX/CONTEXT-GRAPH|CONTEXT GRAPH]]
