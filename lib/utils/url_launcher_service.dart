import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlLauncherService {
  Future<void> abrirWhatsApp(String telefone, {String? mensagem}) async {
    final numero = telefone.replaceAll(RegExp(r'[^0-9]'), '');
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
