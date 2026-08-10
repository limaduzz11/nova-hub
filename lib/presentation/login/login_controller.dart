import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/upsnap_client.dart';

class LoginController extends ChangeNotifier {
  final UpSnapClient _client;
  
  bool _isLoading = false;
  String? _error;
  bool _isLoggedIn = false;

  LoginController({required UpSnapClient client}) : _client = client;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _isLoggedIn;
  String get url => _client.baseUrl;

  Future<void> tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('upsnap_url');
      final token = prefs.getString('upsnap_token');
      
      if (token != null && token.isNotEmpty && savedUrl != null) {
        _client.updateBaseUrl(savedUrl);
        _client.setToken(token);
        _isLoggedIn = true;
        notifyListeners();
      }
    } catch (e) {
      _error = 'Erro ao verificar credenciais salvas';
      notifyListeners();
    }
  }

  Future<void> login({
    required String url,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _client.updateBaseUrl(url);
      await _client.login(email, password);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('upsnap_token', _client.token ?? '');
      await prefs.setString('upsnap_url', url);
      await prefs.setString('upsnap_email', email);
      
      _isLoggedIn = true;
    } catch (e) {
      if (e.toString().contains('401') || e.toString().contains('403')) {
        _error = 'Email ou senha incorretos';
      } else if (e.toString().contains('SocketException')) {
        _error = 'Não foi possível conectar ao servidor. Verifique a URL.';
      } else if (e.toString().contains('Falha no login')) {
        _error = 'Falha no login. Verifique email e senha.';
      } else {
        _error = 'Erro: ${e.toString()}';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('upsnap_token');
    await prefs.remove('upsnap_url');
    await prefs.remove('upsnap_email');
    
    _client.setToken(null);
    _isLoggedIn = false;
    notifyListeners();
  }
}
