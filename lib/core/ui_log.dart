import 'package:flutter/material.dart';

/// Log de UI para validação externa via logcat.
///
/// Toda mensagem sai no logcat (tag `flutter`) com o prefixo `[NOVAUI]`,
/// permitindo acompanhar, por texto, qual tela está ativa e quais ações o
/// usuário/ferramenta dispararam — funciona como um "screenshot em texto"
/// para inspeção via ADB (`adb logcat | grep NOVAUI`).
void uiLog(String screen, String message) {
  debugPrint('[NOVAUI] $screen | $message');
}

/// Observa a pilha de navegação e loga cada push/pop de rota, para saber
/// em qual tela o app está sem precisar ler pixels.
class UiLogObserver extends NavigatorObserver {
  String _name(Route<dynamic>? route) {
    final n = route?.settings.name;
    if (n != null && n.isNotEmpty) return n;
    return route?.settings.arguments?.toString() ??
        route.runtimeType.toString();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    uiLog('NAV', 'push -> ${_name(route)}');
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    uiLog('NAV', 'pop <- ${_name(route)} (volta p/ ${_name(previousRoute)})');
    super.didPop(route, previousRoute);
  }
}
