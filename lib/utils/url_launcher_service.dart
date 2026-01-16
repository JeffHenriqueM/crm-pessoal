// lib/utils/url_launcher_service.dart

import 'package:url_launcher/url_launcher.dart';

class UrlLauncherService {

  /// Abre o WhatsApp com um número de telefone e uma mensagem pré-definida.
  ///
  /// [telefone] O número de telefone completo, incluindo o código do país (ex: '5511999998888').
  /// [mensagem] A mensagem opcional que será pré-preenchida na conversa.
  Future<void> abrirWhatsApp(String telefone, {String? mensagem}) async {
    // 1. Remove caracteres não numéricos do telefone para garantir um formato limpo.
    final numeroLimpo = telefone.replaceAll(RegExp(r'[^0-9]'), '');

    // 2. Codifica a mensagem para que caracteres especiais (espaços, etc.) funcionem na URL.
    final mensagemCodificada = Uri.encodeComponent(mensagem ?? '');

    // 3. Monta a URL final do WhatsApp.
    final Uri whatsappUrl = Uri.parse(
      'https://wa.me/$numeroLimpo?text=$mensagemCodificada',
    );

    try {
      // 4. Tenta abrir a URL. O sistema operacional escolherá o WhatsApp.
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(
          whatsappUrl,
          // O modo 'externalApplication' é crucial para sair do seu app e abrir o WhatsApp.
          mode: LaunchMode.externalApplication,
        );
      } else {
        // 5. Se não puder abrir (ex: WhatsApp não instalado), lança um erro.
        // Em um app real, você poderia mostrar uma mensagem bonita para o usuário aqui.
        throw 'Não foi possível abrir o WhatsApp. Verifique se o aplicativo está instalado.';
      }
    } catch (e) {
      // Captura qualquer outro erro e o imprime no console para depuração.
      print('Erro ao tentar abrir o WhatsApp: $e');
      // Você pode relançar o erro ou tratar de outra forma.
      rethrow;
    }
  }
}
