import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../widgets/interacao_form_dialog.dart';
import 'url_launcher_service.dart';
import 'whatsapp_modelos.dart';

/// Abre o WhatsApp do contato e, em seguida, oferece registrar a interação no
/// contrato. Cada contrato/cliente deve receber um contato a cada 30 dias —
/// registrar a interação reinicia esse ciclo (incrementa `interacoesPorMes`).
///
/// Antes de abrir, pergunta se quer ir **com uma mensagem pronta** (modelo) ou
/// **sem mensagem**.
///
/// [contratoId] é o localizador do contrato. [telefone] o número do contato.
Future<void> abrirWhatsAppERegistrarInteracao(
  BuildContext context, {
  required String contratoId,
  required String telefone,
  String? nomeContato,
  String? esposaContato,
  String? responsavelContato,
  FirestoreService? fs,
  UrlLauncherService? launcher,
}) async {
  final servico = fs ?? FirestoreService();
  final url = launcher ?? UrlLauncherService();

  // Pergunta com/sem mensagem e qual modelo usar.
  final escolha = await escolherMensagemWhatsApp(
    context,
    nome: nomeContato ?? '',
    esposa: esposaContato,
    responsavel: responsavelContato,
    fs: servico,
  );
  if (escolha == null) return; // usuário cancelou

  try {
    await url.abrirWhatsApp(telefone,
        mensagem: escolha.texto.isEmpty ? null : escolha.texto);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
      );
    }
    return;
  }

  if (!context.mounted) return;

  // Oferece registrar a interação que acabou de acontecer.
  InteracaoFormDialog.show(
    context,
    titulo: nomeContato == null ? 'Registrar conversa' : 'Conversa com $nomeContato',
    onSalvar: (i) async {
      await servico.adicionarInteracaoContrato(contratoId, i);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Interação registrada. ✓')),
        );
      }
    },
  );
}
