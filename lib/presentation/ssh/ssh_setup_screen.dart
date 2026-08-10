import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../data/ssh_service.dart';

class SSHSetupScreen extends StatefulWidget {
  final String deviceIp;
  final String deviceName;

  const SSHSetupScreen({
    super.key,
    required this.deviceIp,
    this.deviceName = 'PC Principal',
  });

  @override
  State<SSHSetupScreen> createState() => _SSHSetupScreenState();
}

class _SSHSetupScreenState extends State<SSHSetupScreen> {
  final SSHService _sshService = SSHService();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  final _usernameController = TextEditingController();
  bool _hasKeyPair = false;
  bool _saving = false;
  String _keyFingerprint = '';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final hasKey = await _sshService.hasStoredKeyPair();
    final config = await _sshService.getConnectionConfig();
    if (!mounted) return;
    setState(() {
      _hasKeyPair = hasKey;
      _hostController.text = config['host'] ?? '';
      _portController.text = config['port'] ?? '22';
      _usernameController.text = config['username'] ?? '';
      if (hasKey) {
        _keyFingerprint = 'Chave SSH configurada';
      }
    });
  }

  Future<void> _importKeyFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null || data.text!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Área de transferência vazia')),
        );
      }
      return;
    }

    try {
      await _sshService.storeKeyPair(privateKey: data!.text!);
      if (mounted) {
        setState(() {
          _hasKeyPair = true;
          _keyFingerprint = 'Chave importada';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chave SSH importada com sucesso')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao importar chave: $e')),
        );
      }
    }
  }

  Future<void> _removeKey() async {
    await _sshService.clearStoredKeys();
    if (mounted) {
      setState(() {
        _hasKeyPair = false;
        _keyFingerprint = '';
      });
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _saving = true);
    try {
      final host = _hostController.text.trim();
      final port = int.tryParse(_portController.text.trim()) ?? 22;
      final username = _usernameController.text.trim();

      await _sshService.saveConnectionConfig(
        host: host,
        port: port,
        username: username,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuração salva')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
        title: const Text('Configuração SSH',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chave Privada',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (_hasKeyPair) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppColors.success, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Chave configurada',
                              style: TextStyle(color: AppColors.textPrimary)),
                          if (_keyFingerprint.isNotEmpty)
                            Text(_keyFingerprint,
                                style: const TextStyle(
                                    color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _removeKey,
                      child: const Text('Remover',
                          style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.glassBorder, style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.vpn_key, color: AppColors.textMuted, size: 40),
                    const SizedBox(height: 12),
                    const Text(
                      'Nenhuma chave SSH configurada',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _importKeyFromClipboard,
                      icon: const Icon(Icons.content_paste, size: 18),
                      label: const Text('Colar chave da área de transferência'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            const Text('Conexão',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: _hostController,
              decoration: InputDecoration(
                labelText: 'Host',
                hintText: 'Endereço do servidor',
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.glassBorder),
                ),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portController,
              decoration: InputDecoration(
                labelText: 'Porta',
                hintText: '22',
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.glassBorder),
                ),
              ),
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Usuário',
                hintText: 'Nome de usuário SSH',
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.glassBorder),
                ),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveConfig,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Salvar configuração',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    super.dispose();
  }
}
