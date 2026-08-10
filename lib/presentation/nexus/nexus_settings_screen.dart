import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/nexus_service.dart';

/// Configuração de conexão do NOVA Nexus (URL do backend + API key).
class NexusSettingsScreen extends StatefulWidget {
  const NexusSettingsScreen({super.key});

  @override
  State<NexusSettingsScreen> createState() => _NexusSettingsScreenState();
}

class _NexusSettingsScreenState extends State<NexusSettingsScreen> {
  final NexusService _service = NexusService();
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  bool _saving = false;
  bool? _pingResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final url = await _service.getUrl();
    final key = await _service.getApiKey();
    setState(() {
      _urlController.text = url;
      _keyController.text = key;
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    setState(() => _pingResult = null);
    final ok = await _service.ping(url: _urlController.text.trim());
    if (mounted) setState(() => _pingResult = ok);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await _service.saveConfig(
      url: _urlController.text.trim(),
      apiKey: _keyController.text.trim(),
    );
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context, true);
    }
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
        title: const Text(
          'Configurar Nexus',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(opacity: 0.2, child: const GalaxyAnimation()),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.neonCyan.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.neonCyan.withOpacity(0.2),
                          width: 0.5,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(CupertinoIcons.doc_text,
                              color: AppColors.neonCyan, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Backend Nova Nexus (Go + SQLite) via Tailscale.\nPorta padrão 8080.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _label('URL do Backend'),
                    _field(
                      controller: _urlController,
                      hint: 'http://localhost:8080',
                      validator: (v) => v!.isEmpty ? 'Informe a URL' : null,
                    ),
                    const SizedBox(height: 16),
                    _label('API Key'),
                    _field(
                      controller: _keyController,
                      hint: 'X-API-Key',
                      obscure: true,
                      validator: (v) => v!.isEmpty ? 'Informe a API key' : null,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _test,
                          icon: const Icon(Icons.wifi_tethering, size: 18),
                          label: const Text('Testar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.neonBlue,
                            side: BorderSide(
                                color: AppColors.neonBlue.withOpacity(0.4)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (_pingResult != null)
                          Row(
                            children: [
                              Icon(
                                _pingResult!
                                    ? Icons.check_circle
                                    : Icons.error,
                                size: 18,
                                color: _pingResult!
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _pingResult! ? 'Conectado' : 'Sem conexão',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _pingResult!
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _saving
                            ? const CupertinoActivityIndicator(
                                color: Colors.white)
                            : const Text(
                                'Salvar',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        filled: true,
        fillColor: AppColors.backgroundAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
