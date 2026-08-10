import 'dart:convert';

import 'package:http/http.dart' as http;

import 'nexus_service.dart';
import 'models/command.dart';

/// Cliente do Command Deck: lista e executa comandos da allowlist do backend.
///
/// Reutiliza [NexusService] para resolver URL + API key (mesma config).
class CommandService {
  final NexusService _cfg;
  CommandService([NexusService? cfg]) : _cfg = cfg ?? NexusService();

  Future<Map<String, String>> _headers() async => {
        'Content-Type': 'application/json',
        'X-API-Key': await _cfg.getApiKey(),
      };

  Future<List<NovaCommand>> list() async {
    final base = await _cfg.getUrl();
    final r = await http
        .get(Uri.parse('$base/api/commands'), headers: await _headers())
        .timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) {
      throw Exception('Erro ${r.statusCode} ao listar comandos');
    }
    return (jsonDecode(r.body) as List)
        .map((e) => NovaCommand.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CommandResult> run(String id) async {
    final base = await _cfg.getUrl();
    final r = await http
        .post(Uri.parse('$base/api/commands/$id/run'), headers: await _headers())
        .timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) {
      throw Exception('Erro ${r.statusCode} ao executar comando');
    }
    return CommandResult.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }
}
