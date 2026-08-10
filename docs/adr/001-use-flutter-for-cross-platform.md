# ADR-001: Uso de Flutter para Multiplataforma

**Status:** Aceito
**Data:** 2026-07-12
**Decisor:** Eduardo

---

## Contexto

O NOVA HUB precisa suportar múltiplas plataformas (Android, Windows, Linux, macOS, Web) com uma única base de código.

## Decisão

Utilizar **Flutter** como framework principal para desenvolvimento multiplataforma.

## Consequências

### Positivas
- ✅ Uma única base de código para todas as plataformas
- ✅ Performance nativa em todas as plataformas
- ✅ Hot reload para desenvolvimento rápido
- ✅ Ecossistema rico de pacotes
- ✅ Comunidade ativa e suporte da Google

### Negativas
- ❌ Tamanho do binário maior que apps nativos
- ❌ Dependência do Flutter SDK
- ❌ Algumas limitações em APIs nativas
- ❌ Curva de aprendizado para desenvolvedores nativos

## Alternativas Consideradas

1. **React Native** — Rejeitado por performance inferior em desktop
2. **.NET MAUI** — Rejeitado por limitações em mobile
3. **Electron** — Rejeitado por consumo de recursos
4. **Apps nativos separados** — Rejeitado por custo de manutenção

---

*Última atualização: 19 de Julho de 2026*
