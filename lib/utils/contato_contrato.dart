import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/contrato_model.dart';
import '../services/firestore_service.dart';
import 'email_modelos.dart';
import 'url_launcher_service.dart';
import 'whatsapp_modelos.dart';

final _moeda =
    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ', decimalDigits: 2);
final _dataFmt = DateFormat('dd/MM/yyyy');

/// Variáveis de contrato já formatadas (moeda/data) para os modelos de mensagem.
/// `{dataLimite}` = hoje + 15 dias (prazo de purgação da mora, cláusula 4.7).
({
  String contrato,
  String cota,
  String valorAtrasado,
  String saldo,
  String dataLimite,
}) variaveisContrato(Contrato c) {
  final limite = DateTime.now().add(const Duration(days: 15));
  return (
    contrato:
        (c.codigoContrato ?? '').isNotEmpty ? c.codigoContrato! : c.localizador,
    cota: c.cota,
    valorAtrasado: _moeda.format(c.valorAtrasado),
    saldo: _moeda.format(c.saldoRestante),
    dataLimite: _dataFmt.format(limite),
  );
}

/// Abre o WhatsApp do comprador do contrato, passando pelo seletor de modelos
/// (com as variáveis de contrato preenchidas). Usado na lista de contratos, na
/// ficha do contrato e na aba Distratar.
Future<void> abrirWhatsAppContrato(
  BuildContext context,
  Contrato c, {
  FirestoreService? fs,
}) async {
  if (c.telefoneComprador.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contrato sem telefone cadastrado.')),
    );
    return;
  }
  final v = variaveisContrato(c);
  final escolha = await escolherMensagemWhatsApp(
    context,
    nome: c.nomeComprador,
    esposa: c.nomeComprador2,
    contrato: v.contrato,
    cota: v.cota,
    valorAtrasado: v.valorAtrasado,
    saldo: v.saldo,
    dataLimite: v.dataLimite,
    fs: fs,
  );
  if (escolha == null) return; // cancelou
  try {
    await UrlLauncherService()
        .abrirWhatsApp(c.telefoneComprador, mensagem: escolha.texto);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Erro ao abrir WhatsApp: $e'),
          backgroundColor: Colors.red),
    );
  }
}

/// Abre o cliente de e-mail (mailto:) do comprador do contrato, passando pelo
/// seletor de modelos de e-mail (assunto + corpo com variáveis preenchidas).
Future<void> enviarEmailContrato(
  BuildContext context,
  Contrato c, {
  FirestoreService? fs,
}) async {
  if (c.emailComprador.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contrato sem e-mail cadastrado.')),
    );
    return;
  }
  final v = variaveisContrato(c);
  final escolha = await escolherModeloEmail(
    context,
    nome: c.nomeComprador,
    esposa: c.nomeComprador2,
    contrato: v.contrato,
    cota: v.cota,
    valorAtrasado: v.valorAtrasado,
    saldo: v.saldo,
    dataLimite: v.dataLimite,
    fs: fs,
  );
  if (escolha == null) return; // cancelou
  try {
    await UrlLauncherService().abrirEmail(
      c.emailComprador,
      assunto: escolha.assunto,
      corpo: escolha.corpo,
    );
  } catch (e) {
    // Fallback: se não houver cliente de e-mail, copia o endereço.
    await Clipboard.setData(ClipboardData(text: c.emailComprador));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Não abriu o e-mail; endereço copiado: ${c.emailComprador}'),
      ),
    );
  }
}
