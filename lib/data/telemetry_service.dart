import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'models/telemetry.dart';
import 'nexus_service.dart';

/// Cliente de telemetria do PC principal via WebSocket do backend Nexus.
///
/// Conecta em `ws://<host>:8080/ws/stats?key=<apiKey>` e expõe um stream
/// de [TelemetrySnapshot] atualizado a cada ~2s. Reusa a config (URL/key)
/// do [NexusService].
class TelemetryService {
  TelemetryService._();
  static final TelemetryService instance = TelemetryService._();

  WebSocketChannel? _channel;
  bool _connected = false;
  final _controller = StreamController<TelemetrySnapshot>.broadcast();
  Stream<TelemetrySnapshot> get stream => _controller.stream;

  bool get isConnected => _connected;

  Future<void> connect() async {
    if (_connected) return;
    final url = await NexusService().getUrl();
    final key = await NexusService().getApiKey();
    final wsUrl = url
            .replaceFirst('http://', 'ws://')
            .replaceFirst('https://', 'wss://') +
        '/ws/stats?key=' +
        Uri.encodeComponent(key);

    try {
      final ch = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel = ch;
      _connected = true;
      ch.stream.listen(
        (data) {
          try {
            final map = jsonDecode(data) as Map<String, dynamic>;
            _controller.add(TelemetrySnapshot.fromJson(map));
          } catch (_) {
            // ignora frame inválido
          }
        },
        onError: (e) {
          _connected = false;
          _controller.addError(e);
        },
        onDone: () {
          _connected = false;
        },
        cancelOnError: false,
      );
    } catch (e) {
      _connected = false;
      rethrow;
    }
  }

  void disconnect() {
    _connected = false;
    _channel?.sink.close();
    _channel = null;
  }
}
