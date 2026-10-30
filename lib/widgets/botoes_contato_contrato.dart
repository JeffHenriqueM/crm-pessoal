import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../models/contrato_model.dart';
import '../services/firestore_service.dart';
import '../utils/contato_contrato.dart';

/// Botões de WhatsApp + e-mail para um contrato. Reutilizado na lista de
/// contratos (Pós-Venda), na ficha do contrato e na aba Distratar.
///
/// Cada botão abre o seletor de modelos de mensagem (com as variáveis de
/// contrato preenchidas) e então o WhatsApp/cliente de e-mail.
class BotoesContatoContrato extends StatelessWidget {
  final Contrato contrato;

  /// Tamanho do ícone (lista usa menor; AppBar/ficha usa maior).
  final double iconSize;

  final FirestoreService? firestoreService;

  /// Callback opcional disparado quando um envio de mensagem é concluído e
  /// registrado com sucesso no Firestore.
  final VoidCallback? onEnvioConcluido;

  const BotoesContatoContrato({
    super.key,
    required this.contrato,
    this.iconSize = 20,
    this.firestoreService,
    this.onEnvioConcluido,
  });

  static final _dataFmt = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final temTel = contrato.telefoneComprador.trim().isNotEmpty;
    final temEmail = contrato.emailComprador.trim().isNotEmpty;
    final temAmbos = temTel && temEmail;
    final jaNotificado = contrato.notificadoEm != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (jaNotificado) ...[
          Tooltip(
            message:
                'Notificação registrada em ${_dataFmt.format(contrato.notificadoEm!)}',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1B8A44).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF1B8A44).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle,
                      size: 11, color: Color(0xFF1B8A44)),
                  const SizedBox(width: 4),
                  Text(
                    'Enviado ${_dataFmt.format(contrato.notificadoEm!)}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1B8A44),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        IconButton(
          onPressed: temTel
              ? () => abrirWhatsAppContrato(context, contrato,
                  fs: firestoreService)
              : null,
          icon: FaIcon(FontAwesomeIcons.whatsapp, size: iconSize),
          color: const Color(0xFF25D366),
          tooltip: temTel
              ? 'WhatsApp (${contrato.telefoneComprador})'
              : 'Sem telefone',
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          onPressed: temEmail
              ? () => enviarEmailContrato(context, contrato,
                  fs: firestoreService)
              : null,
          icon: Icon(Icons.email_outlined, size: iconSize + 2),
          color: cs.primary,
          tooltip:
              temEmail ? 'E-mail (${contrato.emailComprador})' : 'Sem e-mail',
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          onPressed: temAmbos
              ? () => enviarWhatsAppEEmailContrato(
                    context,
                    contrato,
                    fs: firestoreService,
                    onEnvioConcluido: onEnvioConcluido,
                  )
              : null,
          icon: SizedBox(
            width: iconSize + 10,
            height: iconSize + 4,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 0,
                  top: 2,
                  child: FaIcon(
                    FontAwesomeIcons.whatsapp,
                    size: iconSize - 3,
                    color: temAmbos
                        ? const Color(0xFF25D366)
                        : cs.onSurface.withValues(alpha: 0.35),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Icon(
                    Icons.email_outlined,
                    size: iconSize,
                    color: temAmbos
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.35),
                  ),
                ),
                if (jaNotificado)
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1B8A44),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 9,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          tooltip: temAmbos
              ? (jaNotificado
                  ? 'Enviar WhatsApp e E-mail juntos (Último envio: ${_dataFmt.format(contrato.notificadoEm!)})'
                  : 'Enviar WhatsApp e E-mail juntos')
              : 'Requer telefone e e-mail cadastrados',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
