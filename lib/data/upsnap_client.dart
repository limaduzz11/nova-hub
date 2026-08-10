import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/device.dart';

class UpSnapClient {
  String _baseUrl;
  String? _token;

  UpSnapClient({required String baseUrl}) : _baseUrl = baseUrl;

  String get baseUrl => _baseUrl;
  String? get token => _token;

  String get _apiUrl => '$_baseUrl/api';

  void setToken(String? token) {
    _token = token;
  }

  void updateBaseUrl(String url) {
    _baseUrl = url;
  }

  Future<void> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_apiUrl/collections/_superusers/auth-with-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identity': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['token'];
    } else {
      throw Exception('Falha no login: ${response.statusCode}');
    }
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<List<Device>> getDevices() async {
    final response = await http.get(
      Uri.parse('$_apiUrl/collections/devices/records'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final items = data['items'] as List;
      return items.map((item) => Device.fromJson(item)).toList();
    } else {
      throw Exception('Falha ao buscar dispositivos: ${response.statusCode}');
    }
  }

  Future<bool> wakeDevice(String deviceId) async {
    final response = await http.get(
      Uri.parse('$_apiUrl/upsnap/wake/$deviceId?async=true'),
      headers: _headers,
    );
    return response.statusCode == 200;
  }

  Future<bool> shutdownDevice(String deviceId) async {
    final response = await http.get(
      Uri.parse('$_apiUrl/upsnap/shutdown/$deviceId?async=true'),
      headers: _headers,
    );
    return response.statusCode == 200;
  }

  Future<bool> checkStatus(String deviceId) async {
    try {
      final devices = await getDevices();
      for (final device in devices) {
        if (device.id == deviceId || device.name == deviceId) {
          return device.isOnline;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
