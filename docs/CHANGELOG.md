# Changelog

## 2026-08-12 — 0.5.0 / NOVA HUB V5 WEB

- Marca visual alterada para NOVA HUB V5 exclusivamente na WEB.
- Logo oficial da ELP exibida no site corporativo foi adaptada em SVG local com detalhe ciano/V5.
- Cortex deixou de encerrar a simulação após assentamento: física contínua eficiente,
  movimento ambiente determinístico, limite de velocidade e pintura a ~30 Hz.
- Teste Cortex agora exige avanço contínuo de frames em 5s, 30s, 90s e 180s.
- Interface ampliada para equivalentes de zoom 50% e 33%, com conteúdo explicitamente
  verificado como visível, sem overflow e com expansão dos grids em telas muito amplas.
- Adicionadas animações de login, marca, fundo, navegação e troca de módulos, respeitando reduced motion.

## 2026-08-12 — Midnight Navy UI

- Identidade Dark Ember/Gold substituída por Midnight Navy com destaque azul-gelo.
- Nova logo geométrica NOVA em SVG; antigo PNG externo deixou de ser usado na interface.
- Navegação dos módulos movida da lateral esquerda para barra superior horizontal.
- DM Sans passou a ser hospedada localmente para respeitar a CSP privada do HUB.
- Detector visual do Cortex tornou-se independente da cor dos nós.
- `check`, matriz visual (6 viewports/4 zooms), terminal e estabilidade Cortex de 180 s aprovados.

## 2026-08-12 — 0.3.1

- Terminal SSH web corrigido: passou a usar chave privada exclusiva da web via `NOVA_SSH_IDENTITY_FILE` (antes usava chaves padrão do usuário, o que resultava em `Permission denied (publickey,password)`).
- Adicionado suporte a `-i` e `IdentitiesOnly=yes` no `terminal-server.js` quando `NOVA_SSH_IDENTITY_FILE` está definido.
- Chaves SSH dedicadas e separadas: `nova_hub_key_app` (app) e `nova_hub_key_web` (web), ambas autorizadas no `~/.ssh/authorized_keys`.

## 2026-08-03 — 0.3.0

- Arcadia ganhou detalhe completo, edição de status/avaliação/notas e exclusão confirmada.
- Inclusão via IGDB agora permite escolher status, nota e observações antes da escrita.
- Busca IGDB preserva a biblioteca e apresenta retry quando a integração externa falha.
- Notícias e Moonlight receberam abas completas; o companion verifica Sunshine e fornece host/downloads sem streaming próprio.
- Settings deixou de usar valores hardcoded e passou a diagnosticar sessão, Nexus, Sunshine, navegador e segurança.
- Smoke passou a usar fixtures apenas para dependências externas, testa também o estado degradado e continua usando dados reais de biblioteca/Nexus.
- Adicionado `probe:integrations` para separar disponibilidade externa da regressão de interface.

## 2026-08-03 — 0.2.0

- Nexus ganhou busca normalizada, filtros por status/tag/tipo e contagem de resultados.
- Detalhe Nexus deixou de usar `alert` e passou a permitir edição sincronizada via API existente.
- Exportação Nexus implementada em PNG real e PDF por relatório de impressão do navegador.
- Cortex ganhou busca, lista agrupada, filtros, detalhes/conexões, pan/zoom/enquadramento e parâmetros físicos.
- Layouts Nexus/Cortex validados também em 390 × 844 sem overflow horizontal.
- Smoke Playwright ampliado para exercitar os novos fluxos sem alterar o banco.
- Navegação agora reposiciona o conteúdo no topo ao trocar de módulo.

## 2026-08-03 — 0.1.1

- Corrigidos caminhos 404 de todos os CSS/JS.
- Adicionada logo oficial e renderização Dark Ember validada em Chromium.
- Removida chave Nexus e tokens do frontend/localStorage.
- Implementadas sessão HttpOnly, refresh Keycloak, CSRF e proxy same-origin.
- Corrigido client ID para `nova-hub-v3`.
- Adicionados CSP, rate limit, health check e cache-control do HTML.
- Corrigido mapeamento snake_case do Arcadia e fallback de capas.
- Adicionados smoke tests desktop/móvel com dados reais.

---
## Relações no Context Engine

- [[02-PROJECTS/PROJECT-RELATIONSHIP-MAP|PROJECT RELATIONSHIP MAP]]
- [[02-PROJECTS/NOVA HUB/NOVA HUB V4 WEB/PROJECT|PROJECT]]
- [[03-KNOWLEDGE/ANDROID/CONTEXT-INDEX|CONTEXT INDEX]]
- [[03-KNOWLEDGE/FLUTTER/CONTEXT-INDEX|CONTEXT INDEX]]
- [[02-PROJECTS/NOVA HUB/ARCADIA/PROJECT|PROJECT]]
- [[01-INDEX/CONTEXT-GRAPH|CONTEXT GRAPH]]
