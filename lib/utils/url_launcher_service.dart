import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlLauncherService {
  Future<void> abrirWhatsApp(String telefone, {String? mensagem}) async {
    var numero = telefone.replaceAll(RegExp(r'[^0-9]'), '');
    // Normaliza para o padrão internacional do Brasil: números locais
    // (DDD + 8/9 dígitos = 10 ou 11) recebem o prefixo 55.
    if (!numero.startsWith('55') && (numero.length == 10 || numero.length == 11)) {
      numero = '55$numero';
    }
    final mensagemCodificada = Uri.encodeComponent(mensagem ?? '');
    final uri = Uri.parse('https://wa.me/$numero?text=$mensagemCodificada');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Não foi possível abrir o WhatsApp.';
      }
    } catch (e) {
      debugPrint('[WhatsApp] Erro ao abrir: $e');
      rethrow;
    }
  }
}
