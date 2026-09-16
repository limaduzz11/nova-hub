import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme.dart';
import '../../data/opencode_service.dart';

class OpenCodeScreen extends StatefulWidget {
  final String deviceIp;
  final String deviceName;

  const OpenCodeScreen({
    super.key,
    required this.deviceIp,
    this.deviceName = 'Nova-PopOS',
  });

  @override
  State<OpenCodeScreen> createState() => _OpenCodeScreenState();
}

class _OpenCodeScreenState extends State<OpenCodeScreen> {
  final OpenCodeService _service = OpenCodeService();
  WebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String _username = 'opencode';
  String _password = const String.fromEnvironment('OPENCODE_PASSWORD', defaultValue: '');

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    final creds = await _service.getCredentials();
    final baseUrl = creds['url']!.isNotEmpty
        ? creds['url']!
        : 'http://${widget.deviceIp}:3000';
    _username = creds['username']!.isNotEmpty
        ? creds['username']!
        : 'opencode';
    _password = creds['password']!.isNotEmpty
        ? creds['password']!
        : const String.fromEnvironment('OPENCODE_PASSWORD', defaultValue: '');

    // Envia o Basic Auth pré-emptivamente no header. Assim o documento carrega
    // com 200 e o WebView "cacheia" a credencial para TODOS os requests
    // same-origin (subrecursos, fetch de /api e o WebSocket da sessão),
    // evitando o loop de 401 (ERR_TOO_MANY_RETRIES).
    final token = base64.encode(utf8.encode('$_username:$_password'));
    final authHeaders = <String, String>{
      'Authorization': 'Basic $token',
    };

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
                _errorMessage =
                    'Erro ${error.errorCode}: ${error.description}';
              });
            }
          },
          onHttpError: (response) {
            // 401 = auth issue (caso o header não seja suficiente)
            if (response.response?.statusCode == 401 && mounted) {
              setState(() {
                _hasError = true;
                _errorMessage =
                    'Falha de autenticação. Verifique usuário/senha no menu "Configurar OpenCode".';
              });
            }
          },
          onHttpAuthRequest: (request) {
            // Backup: responde o desafio Basic Auth com as credenciais salvas.
            request.onProceed(
              WebViewCredential(
                user: _username,
                password: _password,
              ),
            );
          },
        ),
      )
      ..loadRequest(Uri.parse(baseUrl), headers: authHeaders);
  }

  Future<void> _reload() async {
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
    await _controller?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundAlt,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text(
              'OpenCode',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              widget.deviceName,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.accent),
            onPressed: _reload,
            tooltip: 'Recarregar',
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!_hasError && _controller != null)
            WebViewWidget(controller: _controller!),
          if (_isLoading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.accent),
                  SizedBox(height: 16),
                  Text(
                    'Carregando OpenCode...',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          if (_hasError)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Erro ao carregar OpenCode',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar Novamente'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
