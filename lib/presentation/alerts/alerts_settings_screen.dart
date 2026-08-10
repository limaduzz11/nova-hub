import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/alert_service.dart';
import '../../data/models/alert_settings.dart';

/// Configuração do Centro de Alertas: liga/desliga tipos e ajusta limiares.
class AlertsSettingsScreen extends StatefulWidget {
  const AlertsSettingsScreen({super.key});

  @override
  State<AlertsSettingsScreen> createState() => _AlertsSettingsScreenState();
}

class _AlertsSettingsScreenState extends State<AlertsSettingsScreen> {
  late AlertSettings _s;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await AlertSettings.load();
    if (!mounted) return;
    setState(() {
      _s = s;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await _s.save();
    await AlertService.instance.reloadSettings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Alertas atualizados'),
          backgroundColor: AppColors.success.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Centro de Alertas', style: TextStyle(fontSize: 17)),
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _save,
              child: const Text('Salvar',
                  style: TextStyle(color: AppColors.accent, fontSize: 15)),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child:
                  CupertinoActivityIndicator(radius: 14, color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _switchTile(
                  'Alertas ativos',
                  'Habilita todo o Centro de Alertas',
                  _s.enabled,
                  (v) => setState(() => _s.enabled = v),
                ),
                const SizedBox(height: 8),
                _section('Notificações'),
                _switchTile('PC online/offline',
                    'Avisa quando o PC fica inacessível', _s.notifyPcState,
                    (v) => setState(() => _s.notifyPcState = v)),
                _switchTile('Limiares de hardware',
                    'CPU, RAM, temperatura e disco', _s.notifyThresholds,
                    (v) => setState(() => _s.notifyThresholds = v)),
                _switchTile('Prazos do Nexus',
                    'Tarefas atrasadas ou que vencem hoje', _s.notifyDueTasks,
                    (v) => setState(() => _s.notifyDueTasks = v)),
                const SizedBox(height: 8),
                _section('Limiares'),
                _sliderTile('Temp. CPU', '°C', _s.cpuTempMax, 60, 100,
                    (v) => setState(() => _s.cpuTempMax = v)),
                _sliderTile('Uso de CPU', '%', _s.cpuPctMax, 50, 100,
                    (v) => setState(() => _s.cpuPctMax = v)),
                _sliderTile('Uso de RAM', '%', _s.ramPctMax, 50, 100,
                    (v) => setState(() => _s.ramPctMax = v)),
                _sliderTile('Uso de disco', '%', _s.diskPctMax, 50, 100,
                    (v) => setState(() => _s.diskPctMax = v)),
                const SizedBox(height: 8),
                _section('Frequência'),
                _sliderTile('Intervalo entre avisos', 'min',
                    _s.cooldownMin.toDouble(), 5, 60,
                    (v) => setState(() => _s.cooldownMin = v.round()),
                    divisions: 11),
                const SizedBox(height: 20),
                Text(
                  'Os alertas funcionam com o app aberto ou em segundo plano '
                  'enquanto ativo. Monitoramento com o app totalmente fechado '
                  'virá em versão futura (foreground service).',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _switchTile(
      String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeColor: AppColors.accent,
        title: Text(title,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _sliderTile(String title, String unit, double value, double min,
      double max, ValueChanged<double> onChanged,
      {int? divisions}) {
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${value.round()} $unit',
                  style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions ?? (max - min).round(),
            activeColor: AppColors.accent,
            inactiveColor: AppColors.glassBorder,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
