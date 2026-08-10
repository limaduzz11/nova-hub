// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:nova_hub/main.dart' as app;

/// Smoke test E2E: sobe o app, navega pelas 4 abas (via Semantics) e garante
/// que o processo segue vivo sem exceção não tratada.
///
/// Roda em modo release no device:
///   flutter test integration_test/smoke_test.dart --release
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('navega pelas abas sem crash', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    const tabs = ['Nova Link', 'Arcadia', 'Cortex', 'Nexus'];
    for (final label in tabs) {
      final finder = find.bySemanticsLabel(label);
      expect(finder, findsWidgets,
          reason: 'aba "$label" deve estar presente (Semantics)');
      await tester.tap(finder, warnIfMissed: false);
      await tester.pump(const Duration(seconds: 2));
    }

    // Retorna para a aba padrão.
    await tester.tap(find.bySemanticsLabel('Nova Link'), warnIfMissed: false);
    await tester.pump(const Duration(seconds: 2));
  });
}
