class AppConfig {
  static const String defaultUpSnapUrl = 'http://localhost:8090';
  static const String defaultDeviceId = 'PC Principal';
  
  final String upsnapUrl;
  final String? authToken;
  final String deviceId;

  const AppConfig({
    this.upsnapUrl = defaultUpSnapUrl,
    this.authToken,
    this.deviceId = defaultDeviceId,
  });

  AppConfig copyWith({
    String? upsnapUrl,
    String? authToken,
    String? deviceId,
  }) {
    return AppConfig(
      upsnapUrl: upsnapUrl ?? this.upsnapUrl,
      authToken: authToken ?? this.authToken,
      deviceId: deviceId ?? this.deviceId,
    );
  }
}
