# ADR-002: Provider para State Management

**Status:** Aceito
**Data:** 2026-07-12
**Decisor:** Eduardo

---

## Contexto

O NOVA HUB precisa de um sistema de gerenciamento de estado que seja:
- Simples de usar
- Performático
- Escalável
- Bem documentado

## Decisão

Utilizar **Provider** com **ChangeNotifier** para gerenciamento de estado.

## Consequências

### Positivas
- ✅ Simples de implementar
- ✅ Boa performance
- ✅ Integração nativa com Flutter
- ✅ Boa documentação e exemplos
- ✅ Suporte a injeção de dependência

### Negativas
- ❌ Verboso para casos complexos
- ❌ Não suporta states complexos nativamente
- ❌ Pode causar rebuilds desnecessários se mal utilizado

## Alternativas Consideradas

1. **BLoC** — Rejeitado por verbosidade excessiva
2. **Riverpod** — Considerado para futuro
3. **GetX** — Rejeitado por "magic" demais
4. **MobX** — Rejeitado por complexidade

## Notas

Para futuras versões, considerar migração para **Riverpod** que é a evolução do Provider.

---

*Última atualização: 19 de Julho de 2026*
