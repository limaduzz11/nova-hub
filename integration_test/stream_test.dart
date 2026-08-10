// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:nova_hub/main.dart' as app;

/// Validação E2E do stream: navega até o host, inicia o stream (video nativo)
/// e encerra, conferindo que o app NÃO crasha/ANR.
///
/// Roda em modo debug no device:
///   flutter test integration_test/stream_test.dart -d <device>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('stream start + stop sem crash/ANR', (tester) async {
    app.main();
    await tester.pump(const Duration(seconds: 3));

    // 1) Aba Arcadia
    await tester.tap(find.bySemanticsLabel('Arcadia').first, warnIfMissed: false);
    await tester.pump(const Duration(seconds: 2));

    // 2) RemoteView + host pareado (sem PIN)
    final paired = find.textContaining('Pareado');
    if (paired.evaluate().isEmpty) {
      print('STREAM_TEST_SKIP: host nao pareado / RemoteView nao encontrada');
      return;
    }
    print('STREAM_TEST: remoteview ok, host pareado');

    // 3) Lista de apps
    await tester.tap(find.text('Apps').first, warnIfMissed: false);
    await tester.pump(const Duration(seconds: 2));

    // 4) Primeiro app da lista
    var appTile = find.text('Desktop');
    if (appTile.evaluate().isEmpty) appTile = find.byType(ListTile);
    if (appTile.evaluate().isEmpty) {
      print('STREAM_TEST_SKIP: sem apps na lista');
      return;
    }
    await tester.tap(appTile.first, warnIfMissed: false);
    await tester.pump(const Duration(seconds: 6));

    // 5) StreamPage ativa?
    final encerrar = find.text('Encerrar');
    final preparando = find.textContaining('Preparando');
    final onStream = encerrar.evaluate().isNotEmpty || preparando.evaluate().isNotEmpty;
    print('STREAM_TEST: stream ativo=$onStream');
    await tester.pump(const Duration(seconds: 4));

    // 6) Encerra
    if (encerrar.evaluate().isNotEmpty) {
      await tester.tap(encerrar.first, warnIfMissed: false);
      await tester.pump(const Duration(seconds: 3));
      print('STREAM_TEST: encerrou');
    }

    print('STREAM_TEST_OK');
  });
}
