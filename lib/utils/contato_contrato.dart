import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../models/contrato_model.dart';
import '../models/festa_associacao.dart';
import '../models/modelo_mensagem_model.dart';
import '../services/auth_service.dart';
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

/// Número do quarto do contrato na Festa dos Sócios (variável `{apartamento}`),
/// resolvido pela associação manual da Hospedagem. Retorna `null` se não houver
/// vínculo — e nunca deixa uma falha de leitura travar o envio da mensagem.
Future<String?> _apartamentoDoContrato(Contrato c, FirestoreService? fs) async {
  try {
    final assocs = await (fs ?? FirestoreService()).getAssociacoesFesta();
    return quartoDoContrato(assocs, c.localizador);
  } catch (e) {
    debugPrint('[Contrato] Falha ao resolver apartamento: $e');
    return null;
  }
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
  final apartamento = await _apartamentoDoContrato(c, fs);
  if (!context.mounted) return;
  final escolha = await escolherMensagemWhatsApp(
    context,
    nome: c.nomeComprador,
    esposa: c.nomeComprador2,
    contrato: v.contrato,
    cota: v.cota,
    valorAtrasado: v.valorAtrasado,
    saldo: v.saldo,
    dataLimite: v.dataLimite,
    apartamento: apartamento,
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
  final apartamento = await _apartamentoDoContrato(c, fs);
  if (!context.mounted) return;
  final escolha = await escolherModeloEmail(
    context,
    nome: c.nomeComprador,
    esposa: c.nomeComprador2,
    contrato: v.contrato,
    cota: v.cota,
    valorAtrasado: v.valorAtrasado,
    saldo: v.saldo,
    dataLimite: v.dataLimite,
    apartamento: apartamento,
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

/// Abre diálogo unificado para disparar WhatsApp e E-mail juntos (ou ambos com
/// modelos selecionados/personalizados).
Future<void> enviarWhatsAppEEmailContrato(
  BuildContext context,
  Contrato c, {
  FirestoreService? fs,
}) async {
  final temTel = c.telefoneComprador.trim().isNotEmpty;
  final temEmail = c.emailComprador.trim().isNotEmpty;
  if (!temTel && !temEmail) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Contrato sem telefone e sem e-mail cadastrados.')),
    );
    return;
  }
  if (!temTel) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contrato sem telefone para WhatsApp.')),
    );
    return;
  }
  if (!temEmail) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contrato sem e-mail cadastrado.')),
    );
    return;
  }

  List<ModeloMensagem> todos = [];
  try {
    final servico = fs ?? FirestoreService();
    todos = await servico.getModelosMensagem();
  } catch (_) {}

  String? uid;
  try {
    uid = AuthService().getCurrentUser()?.uid;
  } catch (_) {}

  final modelosWhats = todos
      .where((m) =>
          !m.isEmail && (m.padrao || (uid != null && m.criadoPorId == uid)))
      .toList()
    ..sort((a, b) {
      if (a.padrao != b.padrao) return a.padrao ? -1 : 1;
      return a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
    });

  final modelosEmail = todos
      .where((m) =>
          m.isEmail && (m.padrao || (uid != null && m.criadoPorId == uid)))
      .toList()
    ..sort((a, b) {
      if (a.padrao != b.padrao) return a.padrao ? -1 : 1;
      return a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
    });

  final v = variaveisContrato(c);
  final apartamento = await _apartamentoDoContrato(c, fs);

  String formatar(String texto) => aplicarVariaveisMensagem(
        texto,
        nome: c.nomeComprador,
        esposa: c.nomeComprador2,
        contrato: v.contrato,
        cota: v.cota,
        valorAtrasado: v.valorAtrasado,
        saldo: v.saldo,
        dataLimite: v.dataLimite,
        apartamento: apartamento,
      );

  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      final cs = Theme.of(dialogCtx).colorScheme;

      ModeloMensagem? whatsSelecionado =
          modelosWhats.isNotEmpty ? modelosWhats.first : null;
      ModeloMensagem? emailSelecionado =
          modelosEmail.isNotEmpty ? modelosEmail.first : null;

      final whatsCtrl = TextEditingController(
        text: whatsSelecionado != null ? formatar(whatsSelecionado.texto) : '',
      );
      final assuntoCtrl = TextEditingController(
        text: emailSelecionado != null && emailSelecionado.assunto != null
            ? formatar(emailSelecionado.assunto!)
            : '',
      );
      final corpoCtrl = TextEditingController(
        text: emailSelecionado != null ? formatar(emailSelecionado.texto) : '',
      );

      bool enviarWhats = true;
      bool enviarEmail = true;

      return StatefulBuilder(
        builder: (ctx, setDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 720, maxHeight: 780),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cabeçalho
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: cs.primaryContainer,
                          child: Icon(Icons.send_rounded,
                              color: cs.onPrimaryContainer, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Enviar WhatsApp e E-mail juntos',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${c.nomeComprador} · Tel: ${c.telefoneComprador} · E-mail: ${c.emailComprador}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Conteúdo com rolagem
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Seção WhatsApp ──────────────────────────
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366)
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF25D366)
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const FaIcon(FontAwesomeIcons.whatsapp,
                                          size: 16,
                                          color: Color(0xFF25D366)),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'WhatsApp',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const Spacer(),
                                      Checkbox(
                                        value: enviarWhats,
                                        onChanged: (v) => setDialog(
                                            () => enviarWhats = v ?? true),
                                        activeColor: const Color(0xFF25D366),
                                      ),
                                      Text(
                                        enviarWhats ? 'Ativo' : 'Não enviar',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: enviarWhats
                                              ? const Color(0xFF1B8A44)
                                              : cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (enviarWhats) ...[
                                    const SizedBox(height: 8),
                                    if (modelosWhats.isNotEmpty) ...[
                                      DropdownButtonFormField<ModeloMensagem?>(
                                        initialValue: whatsSelecionado,
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                          labelText: 'Modelo de WhatsApp',
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 8),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        items: [
                                          const DropdownMenuItem(
                                            value: null,
                                            child: Text('(Mensagem livre)'),
                                          ),
                                          for (final m in modelosWhats)
                                            DropdownMenuItem(
                                              value: m,
                                              child: Text(
                                                '${m.padrao ? '🌐' : '👤'} ${m.titulo}',
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                        onChanged: (novo) {
                                          setDialog(() {
                                            whatsSelecionado = novo;
                                            if (novo != null) {
                                              whatsCtrl.text =
                                                  formatar(novo.texto);
                                            }
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    TextField(
                                      controller: whatsCtrl,
                                      maxLines: 4,
                                      decoration: InputDecoration(
                                        labelText: 'Mensagem do WhatsApp',
                                        hintText:
                                            'Texto a ser enviado via WhatsApp...',
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        filled: true,
                                        fillColor: cs.surface,
                                        isDense: true,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // ── Seção E-mail ────────────────────────────
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: cs.primary.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.email_outlined,
                                          size: 18, color: cs.primary),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'E-mail (Gmail)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const Spacer(),
                                      Checkbox(
                                        value: enviarEmail,
                                        onChanged: (v) => setDialog(
                                            () => enviarEmail = v ?? true),
                                        activeColor: cs.primary,
                                      ),
                                      Text(
                                        enviarEmail ? 'Ativo' : 'Não enviar',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: enviarEmail
                                              ? cs.primary
                                              : cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (enviarEmail) ...[
                                    const SizedBox(height: 8),
                                    if (modelosEmail.isNotEmpty) ...[
                                      DropdownButtonFormField<ModeloMensagem?>(
                                        initialValue: emailSelecionado,
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                          labelText: 'Modelo de E-mail',
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 8),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        items: [
                                          const DropdownMenuItem(
                                            value: null,
                                            child:
                                                Text('(E-mail em branco)'),
                                          ),
                                          for (final m in modelosEmail)
                                            DropdownMenuItem(
                                              value: m,
                                              child: Text(
                                                '${m.padrao ? '🌐' : '👤'} ${m.titulo}',
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                        onChanged: (novo) {
                                          setDialog(() {
                                            emailSelecionado = novo;
                                            if (novo != null) {
                                              assuntoCtrl.text = formatar(
                                                  novo.assunto ?? '');
                                              corpoCtrl.text =
                                                  formatar(novo.texto);
                                            }
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    TextField(
                                      controller: assuntoCtrl,
                                      decoration: InputDecoration(
                                        labelText: 'Assunto do E-mail',
                                        isDense: true,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        filled: true,
                                        fillColor: cs.surface,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: corpoCtrl,
                                      maxLines: 4,
                                      decoration: InputDecoration(
                                        labelText: 'Corpo do E-mail',
                                        hintText: 'Conteúdo do e-mail...',
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        filled: true,
                                        fillColor: cs.surface,
                                        isDense: true,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Rodapé
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: (!enviarWhats && !enviarEmail)
                              ? null
                              : () async {
                                  Navigator.pop(dialogCtx);
                                  final launcher = UrlLauncherService();
                                  bool abriuWhats = false;
                                  bool abriuEmail = false;

                                  if (enviarWhats) {
                                    try {
                                      await launcher.abrirWhatsApp(
                                        c.telefoneComprador,
                                        mensagem: whatsCtrl.text.trim(),
                                      );
                                      abriuWhats = true;
                                    } catch (e) {
                                      debugPrint('[Ambos] Erro WhatsApp: $e');
                                    }
                                  }

                                  if (enviarEmail) {
                                    try {
                                      await launcher.abrirEmail(
                                        c.emailComprador,
                                        assunto: assuntoCtrl.text.trim(),
                                        corpo: corpoCtrl.text.trim(),
                                      );
                                      abriuEmail = true;
                                    } catch (e) {
                                      debugPrint('[Ambos] Erro Gmail: $e');
                                    }
                                  }

                                  if (abriuWhats && abriuEmail) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                            'WhatsApp e Gmail abertos com sucesso!'),
                                        action: SnackBarAction(
                                          label: 'Reabrir Gmail',
                                          onPressed: () =>
                                              launcher.abrirEmail(
                                            c.emailComprador,
                                            assunto: assuntoCtrl.text.trim(),
                                            corpo: corpoCtrl.text.trim(),
                                          ),
                                        ),
                                      ),
                                    );
                                  } else if (abriuWhats) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'WhatsApp aberto com sucesso!')),
                                    );
                                  } else if (abriuEmail) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Gmail aberto com sucesso!')),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: const Text('Enviar WhatsApp + E-mail'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
