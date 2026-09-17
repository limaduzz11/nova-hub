# Testes

```bash
npm run check
npm test
npm run test:visual
npm run probe:integrations
```

O smoke test Playwright valida:

- CSS/logo/login real;
- Link com telemetria real e desligamento aceito somente contra interceptação local do teste, nunca contra o host;
- Nexus com workspaces `Rotina`/`Work`, editor, busca, filtros, exportações PNG/PDF e ciclo criar/mover/excluir sobre item temporário único;
- Arcadia com biblioteca real, detalhe/editor, filtros, fixture IGDB determinística, fallback 502, busca local de notícias e companion Moonlight;
- Cortex completo (mais de 1100 nós; contagem cresce com o Vault), busca, lista, detalhe, filtro de grupo, parâmetro físico, tooltip e seleção no canvas;
- Settings com usuário de sessão e diagnóstico Nexus/Sunshine;
- viewports desktop e móvel de Link, Nexus, Arcadia e Cortex sem overflow horizontal;
- ausência de erros JavaScript e falhas first-party.

Login bem-sucedido depende de credencial humana e não é automatizado. Login inválido e bloqueio sem sessão são testados via HTTP.

O smoke escreve somente um item Nexus temporário com prefixo `UI-SMOKE`, valida a mudança de status e o exclui; existe cleanup direto de contingência e a validação final confirmou zero itens temporários ativos. O comando de desligamento é interceptado no roteamento Playwright. O smoke não depende da disponibilidade externa da IGDB. `probe:integrations` consulta separadamente Nexus, biblioteca, notícias e IGDB reais; na execução final, todos retornaram 200, com 60 notícias e 29 resultados IGDB.

`test:visual` valida os cinco módulos em 1366×768, 1920×1080, 2560×1440, 3840×2160, tablet horizontal e janela compacta. Também testa reflow equivalente a zoom de 80%, 100%, 125% e 150%, overflow, dimensões mínimas dos controles, IDs duplicados, nomes acessíveis, `alt`, contraste dos tokens, redução de movimento e interação real de hover/seleção no canvas Cortex.

Evidências principais em `test-results/`: `link.png`, `nexus.png`, `arcadia-news.png`, `arcadia-moonlight.png`, `cortex-detail.png`, `settings.png`, capturas móveis, `visual-*` por viewport/zoom e `visual-cortex-hover.png`/`visual-cortex-selected.png`.

---
## Relações no Context Engine

- [[02-PROJECTS/PROJECT-RELATIONSHIP-MAP|PROJECT RELATIONSHIP MAP]]
- [[02-PROJECTS/NOVA HUB/NOVA HUB V4 WEB/PROJECT|PROJECT]]
- [[03-KNOWLEDGE/ANDROID/CONTEXT-INDEX|CONTEXT INDEX]]
- [[03-KNOWLEDGE/FLUTTER/CONTEXT-INDEX|CONTEXT INDEX]]
- [[02-PROJECTS/NOVA HUB/ARCADIA/PROJECT|PROJECT]]
- [[01-INDEX/CONTEXT-GRAPH|CONTEXT GRAPH]]
