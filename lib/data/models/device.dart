class Device {
  final String id;
  final String name;
  final String ip;
  final String? mac;
  final bool isOnline;

  const Device({
    required this.id,
    required this.name,
    required this.ip,
    this.mac,
    this.isOnline = false,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      ip: json['ip'] ?? '',
      mac: json['mac'],
      isOnline: json['status'] == 'online',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ip': ip,
      'mac': mac,
      'status': isOnline ? 'online' : 'offline',
    };
  }
}
