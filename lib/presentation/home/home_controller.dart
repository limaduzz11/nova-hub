import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/upsnap_client.dart';
import '../../data/models/device.dart';

class HomeController extends ChangeNotifier {
  final UpSnapClient _client;
  
  List<Device> _devices = [];
  bool _isLoading = false;
  String? _error;
  Timer? _refreshTimer;
  bool _isActionInProgress = false;
  String? _lastActionError;
  DateTime? _lastRefresh;

  HomeController({required UpSnapClient client}) : _client = client;

  List<Device> get devices => _devices;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isActionInProgress => _isActionInProgress;
  String? get lastActionError => _lastActionError;
  DateTime? get lastRefresh => _lastRefresh;

  Device? get pcPrincipal {
    try {
      return _devices.firstWhere(
        (d) => d.name.toLowerCase().contains('pc principal'),
      );
    } catch (_) {
      return _devices.isNotEmpty ? _devices.first : null;
    }
  }

  String _parseError(dynamic e) {
    if (e is SocketException) {
      if (e.message.contains('Connection refused')) {
        return 'Servidor indisponível. Verifique se o UpSnap está rodando.';
      }
      if (e.message.contains('Network is unreachable')) {
        return 'Rede inalcançável. Verifique sua conexão com a internet.';
      }
      if (e.message.contains('No route to host')) {
        return 'Sem rota para o servidor. Verifique a URL.';
      }
      return 'Erro de conexão: ${e.message}';
    }
    if (e is TimeoutException) {
      return 'Tempo esgotado. Servidor demorou para responder.';
    }
    if (e is HttpException) {
      return 'Erro HTTP: ${e.message}';
    }
    if (e.toString().contains('401') || e.toString().contains('403')) {
      return 'Credenciais inválidas. Faça login novamente.';
    }
    if (e.toString().contains('Token expired') || e.toString().contains('jwt')) {
      return 'Sessão expirada. Faça login novamente.';
    }
    return 'Erro: ${e.toString().replaceAll('Exception: ', '')}';
  }

  Future<void> loadDevices() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _devices = await _client.getDevices();
      _lastRefresh = DateTime.now();
    } catch (e) {
      _error = _parseError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> wakeDevice(String deviceId) async {
    if (_isActionInProgress) return false;
    
    _isActionInProgress = true;
    _lastActionError = null;
    notifyListeners();

    try {
      final success = await _client.wakeDevice(deviceId);
      if (success) {
        await Future.delayed(const Duration(seconds: 3));
        await loadDevices();
      } else {
        _lastActionError = 'Falha ao enviar sinal de ligar';
      }
      return success;
    } catch (e) {
      _lastActionError = _parseError(e);
      notifyListeners();
      return false;
    } finally {
      _isActionInProgress = false;
      notifyListeners();
    }
  }

  Future<bool> shutdownDevice(String deviceId) async {
    if (_isActionInProgress) return false;
    
    _isActionInProgress = true;
    _lastActionError = null;
    notifyListeners();

    try {
      final success = await _client.shutdownDevice(deviceId);
      if (success) {
        await Future.delayed(const Duration(seconds: 3));
        await loadDevices();
      } else {
        _lastActionError = 'Falha ao enviar comando de desligar';
      }
      return success;
    } catch (e) {
      _lastActionError = _parseError(e);
      notifyListeners();
      return false;
    } finally {
      _isActionInProgress = false;
      notifyListeners();
    }
  }

  void startAutoRefresh({Duration interval = const Duration(seconds: 10)}) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(interval, (_) => loadDevices());
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
