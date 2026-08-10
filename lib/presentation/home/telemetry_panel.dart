import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/telemetry.dart';
import '../../data/telemetry_service.dart';

/// Painel de telemetria ao vivo do PC principal (Nova Link).
/// Conecta no WebSocket `/ws/stats` do backend Nexus e mostra CPU/RAM/GPU,
/// temperaturas, discos, top processos e gráficos históricos (últimos ~2 min).
class TelemetryPanel extends StatefulWidget {
  const TelemetryPanel({super.key});

  @override
  State<TelemetryPanel> createState() => _TelemetryPanelState();
}

class _TelemetryPanelState extends State<TelemetryPanel> {
  static const int _maxHistory = 60; // ~2 min a 2s por amostra

  TelemetrySnapshot? _snap;
  final List<TelemetrySnapshot> _history = [];
  bool _connected = false;
  bool _error = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    final svc = TelemetryService.instance;
    try {
      await svc.connect();
      _sub = svc.stream.listen(
        (s) => setState(() {
          _snap = s;
          _history.add(s);
          if (_history.length > _maxHistory) {
            _history.removeAt(0);
          }
          _connected = true;
          _error = false;
        }),
        onError: (_) => setState(() {
          _connected = false;
          _error = true;
        }),
      );
      if (mounted) setState(() => _connected = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _connected = false;
          _error = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    TelemetryService.instance.disconnect();
    super.dispose();
  }

  /// Cor por faixa de temperatura (°C).
  static Color _tempColor(double t) {
    if (t >= 80) return AppColors.error;
    if (t >= 65) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final s = _snap;
    final children = <Widget>[
      Row(
        children: [
          Icon(
            _connected ? Icons.cloud_done : Icons.cloud_off,
            size: 14,
            color: _connected ? AppColors.neonCyan : AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _connected
                  ? (s?.hostname.isNotEmpty == true
                      ? s!.hostname
                      : 'PC Principal')
                  : 'Telemetria',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          if (_connected)
            const Text('ao vivo',
                style: TextStyle(color: AppColors.neonCyan, fontSize: 11)),
          if (_error)
            IconButton(
              icon: const Icon(Icons.refresh, size: 16),
              color: AppColors.accent,
              onPressed: () {
                setState(() => _error = false);
                _connect();
              },
              tooltip: 'Reconectar',
            ),
        ],
      ),
      const SizedBox(height: 10),
    ];

    if (s == null) {
      children.add(
        const Center(
          child: Text('Conectando...',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ),
      );
    } else {
      children
        ..add(_MetricBar(
            label: 'CPU',
            value: s.cpuPercent,
            color: AppColors.accent,
            tempC: s.cpuTempC))
        ..add(const SizedBox(height: 8))
        ..add(_MetricBar(
            label: 'RAM',
            value: s.memPercent,
            color: AppColors.neonPurple,
            sub:
                '${s.memUsedGB.toStringAsFixed(1)} / ${s.memTotalGB.toStringAsFixed(1)} GB'))
        ..add(const SizedBox(height: 8));
      if (s.gpuName != 'N/A') {
        children
          ..add(_MetricBar(
              label: s.gpuName,
              value: s.gpuPercent,
              color: AppColors.neonCyan,
              tempC: s.gpuTempC))
          ..add(const SizedBox(height: 8));
      }
      // Chip de temperatura do disco (NVMe), se disponível.
      if (s.diskTempC > 0) {
        children
          ..add(_TempChip(
              icon: Icons.storage,
              label: 'NVMe',
              tempC: s.diskTempC,
              color: _tempColor(s.diskTempC)))
          ..add(const SizedBox(height: 8));
      }

      for (final d in s.disks) {
        children
          ..add(_DiskRow(d))
          ..add(const SizedBox(height: 4));
      }

      // ---- Gráficos históricos ----
      if (_history.length >= 2) {
        children
          ..add(const SizedBox(height: 10))
          ..add(const Text('Histórico (últimos 2 min)',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)))
          ..add(const SizedBox(height: 8))
          ..add(_Sparkline(
            label: 'CPU',
            data: _history.map((e) => e.cpuPercent).toList(),
            color: AppColors.accent,
            current: '${s.cpuPercent.toStringAsFixed(0)}%',
            maxY: 100,
          ))
          ..add(const SizedBox(height: 8))
          ..add(_Sparkline(
            label: 'RAM',
            data: _history.map((e) => e.memPercent).toList(),
            color: AppColors.neonPurple,
            current: '${s.memPercent.toStringAsFixed(0)}%',
            maxY: 100,
          ))
          ..add(const SizedBox(height: 8))
          ..add(_Sparkline(
            label: 'Temp CPU',
            data: _history.map((e) => e.cpuTempC).toList(),
            color: _tempColor(s.cpuTempC),
            current: '${s.cpuTempC.toStringAsFixed(0)}°C',
            maxY: 100,
          ));
      }

      children.add(const SizedBox(height: 10));
      children.add(const Text('Top processos (RAM)',
          style: TextStyle(color: AppColors.textMuted, fontSize: 11)));
      children.add(const SizedBox(height: 4));
      for (final p in s.processes.take(5)) {
        children.add(_ProcessRow(p));
      }
    }

    return GlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.label,
    required this.value,
    required this.color,
    this.sub,
    this.tempC,
  });

  final String label;
  final double value;
  final Color color;
  final String? sub;
  final double? tempC;

  @override
  Widget build(BuildContext context) {
    final t = tempC ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const Spacer(),
            if (sub != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(sub!,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
              ),
            if (t > 0)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text('${t.toStringAsFixed(0)}°C',
                    style: TextStyle(
                        color: _TelemetryPanelState._tempColor(t),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            Text('${value.toStringAsFixed(0)}%',
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 6,
            backgroundColor: AppColors.backgroundAlt,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _TempChip extends StatelessWidget {
  const _TempChip({
    required this.icon,
    required this.label,
    required this.tempC,
    required this.color,
  });

  final IconData icon;
  final String label;
  final double tempC;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ),
        Text('${tempC.toStringAsFixed(0)}°C',
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({
    required this.label,
    required this.data,
    required this.color,
    required this.current,
    required this.maxY,
  });

  final String label;
  final List<double> data;
  final Color color;
  final String current;
  final double maxY;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (var i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i]),
    ];
    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
        ),
        Expanded(
          child: SizedBox(
            height: 34,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (data.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.25,
                    barWidth: 1.8,
                    color: color,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withValues(alpha: 0.14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(current,
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _DiskRow extends StatelessWidget {
  const _DiskRow(this.disk);
  final DiskStat disk;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.storage, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(disk.shortMount,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ),
        Text(
          '${disk.percent.toStringAsFixed(0)}%',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}

class _ProcessRow extends StatelessWidget {
  const _ProcessRow(this.p);
  final ProcessStat p;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              p.name,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${p.memMB.toStringAsFixed(0)}MB',
            style: const TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 10),
          Text(
            '${p.cpu.toStringAsFixed(0)}%',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
