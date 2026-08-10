import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SSHKeyInfo {
  final String publicKey;
  final String privateKey;

  SSHKeyInfo({required this.publicKey, required this.privateKey});
}

class SSHService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _privateKeyKey = 'ssh_private_key';
  static const String _publicKeyKey = 'ssh_public_key';
  static const String _hostKey = 'ssh_host';
  static const String _portKey = 'ssh_port';
  static const String _usernameKey = 'ssh_username';

  SSHClient? _client;
  SSHSession? _session;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  SSHClient? get client => _client;

  Future<bool> hasStoredKeyPair() async {
    final privateKey = await _storage.read(key: _privateKeyKey);
    return privateKey != null && privateKey.isNotEmpty;
  }

  Future<void> storeKeyPair({
    required String privateKey,
    String? publicKey,
  }) async {
    await _storage.write(key: _privateKeyKey, value: privateKey);
    if (publicKey != null) {
      await _storage.write(key: _publicKeyKey, value: publicKey);
    }
  }

  Future<SSHKeyInfo?> getStoredKeyPair() async {
    final privateKey = await _storage.read(key: _privateKeyKey);
    final publicKey = await _storage.read(key: _publicKeyKey);

    if (privateKey != null && privateKey.isNotEmpty) {
      return SSHKeyInfo(
        publicKey: publicKey ?? '',
        privateKey: privateKey,
      );
    }
    return null;
  }

  Future<void> saveConnectionConfig({
    required String host,
    required int port,
    required String username,
  }) async {
    await _storage.write(key: _hostKey, value: host);
    await _storage.write(key: _portKey, value: port.toString());
    await _storage.write(key: _usernameKey, value: username);
  }

  Future<Map<String, String>> getConnectionConfig() async {
    return {
      'host': await _storage.read(key: _hostKey) ?? '',
      'port': await _storage.read(key: _portKey) ?? '22',
      'username': await _storage.read(key: _usernameKey) ?? '',
    };
  }

  Future<bool> connect({
    required String host,
    required int port,
    required String username,
    String? privateKey,
  }) async {
    try {
      final rawKey = privateKey ?? await _storage.read(key: _privateKeyKey);
      if (rawKey == null || rawKey.isEmpty) {
        print('No SSH private key found');
        return false;
      }
      final key = rawKey
          .trim()
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .replaceAll(RegExp(r'[ \t]+\n'), '\n')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n');

      final socket = await SSHSocket.connect(host, port);

      _client = SSHClient(
        socket,
        username: username,
        identities: SSHKeyPair.fromPem(key),
      );

      _session = await _client!.shell(
        pty: SSHPtyConfig(width: 120, height: 30),
      );

      _isConnected = true;
      return true;
    } catch (e) {
      print('SSH connection error: $e');
      _isConnected = false;
      return false;
    }
  }

  Stream<Uint8List>? get stdout {
    return _session?.stdout;
  }

  Stream<Uint8List>? get stderr {
    return _session?.stderr;
  }

  void sendCommand(String command) {
    if (_session != null && _isConnected) {
      _session!.write(Uint8List.fromList(utf8.encode(command)));
    }
  }

  void sendInput(String input) {
    if (_session != null && _isConnected) {
      _session!.write(Uint8List.fromList(utf8.encode(input)));
    }
  }

  void resize(int cols, int rows) {
    if (_session != null && _isConnected) {
      _session!.resizeTerminal(cols, rows, 0, 0);
    }
  }

  Future<void> disconnect() async {
    try {
      _session?.close();
      _client?.close();
    } catch (e) {
      print('Error disconnecting SSH: $e');
    } finally {
      _session = null;
      _client = null;
      _isConnected = false;
    }
  }

  Future<void> clearStoredKeys() async {
    await _storage.delete(key: _privateKeyKey);
    await _storage.delete(key: _publicKeyKey);
  }
}
