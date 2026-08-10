import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'models/alert_settings.dart';
import 'models/telemetry.dart';
import 'nexus_service.dart';

/// Centro de Alertas: monitora a telemetria (WS próprio) e os prazos do Nexus,
/// disparando notificações locais quando limiares são ultrapassados.
///
/// Limitação v1: as notificações disparam enquanto o app está em execução
/// (primeiro ou segundo plano com o processo vivo). Rodar 100% fechado exige um
/// foreground service — fica para uma próxima iteração.
class AlertService {
  AlertService._();
  static final AlertService instance = AlertService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _nexus = NexusService();

  AlertSettings _settings = AlertSettings();
  AlertSettings get settings => _settings;

  bool _started = false;
  bool _initialized = false;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  Timer? _dueTimer;

  bool _pcOnline = false;
  final Map<String, DateTime> _lastFired = {};

  static const _channelId = 'nova_alerts';
  static const _channelName = 'NOVA Alertas';

  Future<void> _initPlugin() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const init = InitializationSettings(android: android);
    await _plugin.initialize(init);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  /// Inicia o monitoramento. Idempotente.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _settings = await AlertSettings.load();
    await _initPlugin();
    _connect();
    _dueTimer = Timer.periodic(const Duration(minutes: 30), (_) => _checkDue());
    _checkDue();
  }

  /// Recarrega a config (após o usuário salvar na tela de settings).
  Future<void> reloadSettings() async {
    _settings = await AlertSettings.load();
    if (_settings.enabled && !_started) {
      await start();
    }
  }

  void _connect() {
    if (!_settings.enabled) return;
    _sub?.cancel();
    _channel?.sink.close();
    () async {
      try {
        final url = await _nexus.getUrl();
        final key = await _nexus.getApiKey();
        final wsUrl = url
                .replaceFirst('http://', 'ws://')
                .replaceFirst('https://', 'wss://') +
            '/ws/stats?key=' +
            Uri.encodeComponent(key);
        final ch = WebSocketChannel.connect(Uri.parse(wsUrl));
        _channel = ch;
        _sub = ch.stream.listen(
          _onFrame,
          onError: (_) => _scheduleReconnect(offline: true),
          onDone: () => _scheduleReconnect(offline: true),
          cancelOnError: false,
        );
      } catch (_) {
        _scheduleReconnect(offline: true);
      }
    }();
  }

  void _scheduleReconnect({bool offline = false}) {
    if (offline && _pcOnline && _settings.notifyPcState) {
      _pcOnline = false;
      _notify('pc_off', 'PC offline', 'O PC principal ficou inacessível.');
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 15), () {
      if (_started) _connect();
    });
  }

  void _onFrame(dynamic data) {
    if (!_pcOnline) {
      _pcOnline = true;
      if (_settings.notifyPcState && _lastFired.containsKey('pc_off')) {
        _notify('pc_on', 'PC online', 'O PC principal está acessível novamente.');
      }
    }
    if (!_settings.notifyThresholds) return;
    try {
      final snap =
          TelemetrySnapshot.fromJson(jsonDecode(data) as Map<String, dynamic>);
      _evaluate(snap);
    } catch (_) {}
  }

  void _evaluate(TelemetrySnapshot s) {
    if (s.cpuTempC >= _settings.cpuTempMax) {
      _notify('cpu_temp', 'Temperatura da CPU alta',
          '${s.cpuTempC.toStringAsFixed(0)}°C (limite ${_settings.cpuTempMax.toStringAsFixed(0)}°C)');
    }
    if (s.cpuPercent >= _settings.cpuPctMax) {
      _notify('cpu_pct', 'Uso de CPU alto',
          '${s.cpuPercent.toStringAsFixed(0)}% (limite ${_settings.cpuPctMax.toStringAsFixed(0)}%)');
    }
    if (s.memPercent >= _settings.ramPctMax) {
      _notify('ram_pct', 'Uso de RAM alto',
          '${s.memPercent.toStringAsFixed(0)}% (limite ${_settings.ramPctMax.toStringAsFixed(0)}%)');
    }
    for (final d in s.disks) {
      if (d.percent >= _settings.diskPctMax) {
        _notify('disk_${d.mount}', 'Disco quase cheio',
            '${d.shortMount}: ${d.percent.toStringAsFixed(0)}% usado');
      }
    }
  }

  Future<void> _checkDue() async {
    if (!_settings.enabled || !_settings.notifyDueTasks) return;
    try {
      final items = await _nexus.listAllItems();
      final today = DateTime.now();
      final todayKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      var overdue = 0;
      var dueToday = 0;
      for (final it in items) {
        final due = it.dueDate;
        if (due == null || due.isEmpty || it.isDone) continue;
        final d = DateTime.tryParse(due);
        if (d == null) continue;
        final dOnly = DateTime(d.year, d.month, d.day);
        final tOnly = DateTime(today.year, today.month, today.day);
        if (dOnly.isBefore(tOnly)) {
          overdue++;
        } else if (due.startsWith(todayKey)) {
          dueToday++;
        }
      }
      if (overdue > 0 || dueToday > 0) {
        final parts = <String>[];
        if (overdue > 0) parts.add('$overdue atrasada(s)');
        if (dueToday > 0) parts.add('$dueToday vence(m) hoje');
        _notify('due', 'Prazos do Nexus', parts.join(' · '), cooldownFree: true);
      }
    } catch (_) {}
  }

  void _notify(String key, String title, String body,
      {bool cooldownFree = false}) {
    if (!_settings.enabled) return;
    final now = DateTime.now();
    if (!cooldownFree) {
      final last = _lastFired[key];
      if (last != null &&
          now.difference(last).inMinutes < _settings.cooldownMin) {
        return;
      }
    }
    _lastFired[key] = now;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Alertas de telemetria e prazos da NOVA',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    _plugin.show(key.hashCode & 0x7fffffff, title, body, details);
  }

  void stop() {
    _started = false;
    _sub?.cancel();
    _channel?.sink.close();
    _reconnectTimer?.cancel();
    _dueTimer?.cancel();
  }
}
