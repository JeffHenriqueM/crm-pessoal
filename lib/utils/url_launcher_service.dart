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

  /// Abre o compositor do **Gmail no navegador** (nova aba do Chrome) com
  /// destinatário, assunto e corpo já preenchidos — em vez do app de e-mail do
  /// sistema (mailto:). A operação usa Google Workspace, então o Gmail web é o
  /// destino esperado. Variáveis devem vir já aplicadas pelo chamador.
  Future<void> abrirEmail(
    String destinatario, {
    String? assunto,
    String? corpo,
  }) async {
    final uri = Uri.https('mail.google.com', '/mail/', {
      'view': 'cm',
      'fs': '1',
      'to': destinatario,
      if ((assunto ?? '').isNotEmpty) 'su': assunto!,
      if ((corpo ?? '').isNotEmpty) 'body': corpo!,
    });
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Não foi possível abrir o Gmail.';
      }
    } catch (e) {
      debugPrint('[Email] Erro ao abrir Gmail: $e');
      rethrow;
    }
  }

  /// Abre uma URL qualquer em nova aba/app externo.
  Future<void> abrirUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Não foi possível abrir o link.';
      }
    } catch (e) {
      debugPrint('[UrlLauncher] Erro ao abrir $url: $e');
      rethrow;
    }
  }
}
