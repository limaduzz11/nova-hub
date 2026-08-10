# ADR-004: Remoção do Remote Streaming

**Status:** Aceito
**Data:** 2026-07-18
**Decisor:** Eduardo

---

## Contexto

O NOVA HUB tinha funcionalidade de remote streaming que permitia acessar o PC remotamente via protocolo proprietário.

## Decisão

Remover completamente o remote streaming do app, mantendo apenas integração com Moonlight.

## Consequências

### Positivas
- ✅ Redução de 236MB no tamanho do app
- ✅ Remoção de código nativo complexo
- ✅ Eliminação de dependências desnecessárias
- ✅ Simplificação da arquitetura
- ✅ Foco em integração com Moonlight (solução madura)

### Negativas
- ❌ Perda de funcionalidade proprietária
- ❌ Dependência de app externo (Moonlight)
- ❌ Menos controle sobre a experiência

## Alternativas Consideradas

1. **Manter remote streaming** — Rejeitado por complexidade e tamanho
2. **Usar Moonlight apenas** — Aceito como solução mais simples
3. **Implementar RDP** — Rejeitado por complexidade

## Código Removido

- `native/` directory (236MB)
- `CMakeLists.txt` configuração
- Dependências: `multicast_dns`, `xml`, `pointycastle`, `basic_utils`, `asn1lib`, `ffi`
- Arquivos nativos Android para remote streaming

## Impacto

- **Tamanho do APK:** Reduzido significativamente
- **Complexidade:** Reduzida
- **Funcionalidade:** Mantida via Moonlight

---

*Última atualização: 19 de Julho de 2026*
