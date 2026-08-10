import 'package:shared_preferences/shared_preferences.dart';

/// Configuração do Centro de Alertas (limiares e chaves de notificação).
/// Persistida em [SharedPreferences].
class AlertSettings {
  bool enabled;
  bool notifyPcState; // PC ficou online/offline
  bool notifyThresholds; // CPU/RAM/temp/disco acima do limiar
  bool notifyDueTasks; // prazos do Nexus vencendo

  double cpuTempMax; // °C
  double cpuPctMax; // %
  double ramPctMax; // %
  double diskPctMax; // %
  int cooldownMin; // minutos entre alertas do mesmo tipo

  AlertSettings({
    this.enabled = true,
    this.notifyPcState = true,
    this.notifyThresholds = true,
    this.notifyDueTasks = true,
    this.cpuTempMax = 85,
    this.cpuPctMax = 90,
    this.ramPctMax = 90,
    this.diskPctMax = 90,
    this.cooldownMin = 15,
  });

  static const _kEnabled = 'alerts_enabled';
  static const _kPcState = 'alerts_pc_state';
  static const _kThresholds = 'alerts_thresholds';
  static const _kDueTasks = 'alerts_due_tasks';
  static const _kCpuTemp = 'alerts_cpu_temp';
  static const _kCpuPct = 'alerts_cpu_pct';
  static const _kRamPct = 'alerts_ram_pct';
  static const _kDiskPct = 'alerts_disk_pct';
  static const _kCooldown = 'alerts_cooldown';

  static Future<AlertSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return AlertSettings(
      enabled: p.getBool(_kEnabled) ?? true,
      notifyPcState: p.getBool(_kPcState) ?? true,
      notifyThresholds: p.getBool(_kThresholds) ?? true,
      notifyDueTasks: p.getBool(_kDueTasks) ?? true,
      cpuTempMax: p.getDouble(_kCpuTemp) ?? 85,
      cpuPctMax: p.getDouble(_kCpuPct) ?? 90,
      ramPctMax: p.getDouble(_kRamPct) ?? 90,
      diskPctMax: p.getDouble(_kDiskPct) ?? 90,
      cooldownMin: p.getInt(_kCooldown) ?? 15,
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, enabled);
    await p.setBool(_kPcState, notifyPcState);
    await p.setBool(_kThresholds, notifyThresholds);
    await p.setBool(_kDueTasks, notifyDueTasks);
    await p.setDouble(_kCpuTemp, cpuTempMax);
    await p.setDouble(_kCpuPct, cpuPctMax);
    await p.setDouble(_kRamPct, ramPctMax);
    await p.setDouble(_kDiskPct, diskPctMax);
    await p.setInt(_kCooldown, cooldownMin);
  }
}
