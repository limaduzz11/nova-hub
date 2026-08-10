import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OpenCodeService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _urlKey = 'opencode_url';
  static const String _usernameKey = 'opencode_username';
  static const String _passwordKey = 'opencode_password';

  Future<void> saveCredentials({
    required String url,
    required String username,
    required String password,
  }) async {
    await _storage.write(key: _urlKey, value: url);
    await _storage.write(key: _usernameKey, value: username);
    await _storage.write(key: _passwordKey, value: password);
  }

  Future<Map<String, String>> getCredentials() async {
    return {
      'url': await _storage.read(key: _urlKey) ?? '',
      'username': await _storage.read(key: _usernameKey) ?? '',
      'password': await _storage.read(key: _passwordKey) ?? '',
    };
  }

  Future<bool> hasCredentials() async {
    final creds = await getCredentials();
    return creds['url']!.isNotEmpty &&
        creds['username']!.isNotEmpty &&
        creds['password']!.isNotEmpty;
  }

  Future<void> clearCredentials() async {
    await _storage.delete(key: _urlKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _passwordKey);
  }
}
