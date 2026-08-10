class TelemetrySnapshot {
  final int time;
  final String hostname;
  final double cpuPercent;
  final double memTotalGB;
  final double memUsedGB;
  final double memPercent;
  final List<DiskStat> disks;
  final String gpuName;
  final double gpuPercent;
  final double cpuTempC;
  final double gpuTempC;
  final double diskTempC;
  final List<ProcessStat> processes;

  TelemetrySnapshot({
    required this.time,
    required this.hostname,
    required this.cpuPercent,
    required this.memTotalGB,
    required this.memUsedGB,
    required this.memPercent,
    required this.disks,
    required this.gpuName,
    required this.gpuPercent,
    required this.cpuTempC,
    required this.gpuTempC,
    required this.diskTempC,
    required this.processes,
  });

  factory TelemetrySnapshot.fromJson(Map<String, dynamic> j) => TelemetrySnapshot(
        time: (j['time'] as int?) ?? 0,
        hostname: (j['hostname'] as String?) ?? '',
        cpuPercent: ((j['cpu_percent'] as num?) ?? 0).toDouble(),
        memTotalGB: ((j['mem_total_gb'] as num?) ?? 0).toDouble(),
        memUsedGB: ((j['mem_used_gb'] as num?) ?? 0).toDouble(),
        memPercent: ((j['mem_percent'] as num?) ?? 0).toDouble(),
        disks: (j['disks'] as List? ?? [])
            .map((e) => DiskStat.fromJson(e as Map<String, dynamic>))
            .toList(),
        gpuName: (j['gpu_name'] as String?) ?? 'N/A',
        gpuPercent: ((j['gpu_percent'] as num?) ?? 0).toDouble(),
        cpuTempC: ((j['cpu_temp_c'] as num?) ?? 0).toDouble(),
        gpuTempC: ((j['gpu_temp_c'] as num?) ?? 0).toDouble(),
        diskTempC: ((j['disk_temp_c'] as num?) ?? 0).toDouble(),
        processes: (j['processes'] as List? ?? [])
            .map((e) => ProcessStat.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class DiskStat {
  final String mount;
  final double totalGB;
  final double usedGB;
  final double percent;

  DiskStat({
    required this.mount,
    required this.totalGB,
    required this.usedGB,
    required this.percent,
  });

  factory DiskStat.fromJson(Map<String, dynamic> j) => DiskStat(
        mount: (j['mount'] as String?) ?? '',
        totalGB: ((j['total_gb'] as num?) ?? 0).toDouble(),
        usedGB: ((j['used_gb'] as num?) ?? 0).toDouble(),
        percent: ((j['percent'] as num?) ?? 0).toDouble(),
      );

  String get shortMount {
    if (mount == '/') return 'Sistema (/)';
    if (mount.startsWith('/media/')) {
      return mount.split('/').where((p) => p.isNotEmpty).last;
    }
    return mount;
  }
}

class ProcessStat {
  final int pid;
  final String name;
  final double cpu;
  final double memPct;
  final double memMB;

  ProcessStat({
    required this.pid,
    required this.name,
    required this.cpu,
    required this.memPct,
    required this.memMB,
  });

  factory ProcessStat.fromJson(Map<String, dynamic> j) => ProcessStat(
        pid: (j['pid'] as int?) ?? 0,
        name: (j['name'] as String?) ?? '?',
        cpu: ((j['cpu'] as num?) ?? 0).toDouble(),
        memPct: ((j['mem_pct'] as num?) ?? 0).toDouble(),
        memMB: ((j['mem_mb'] as num?) ?? 0).toDouble(),
      );
}
