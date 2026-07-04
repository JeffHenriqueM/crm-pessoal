import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/contrato_model.dart';
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

  const BotoesContatoContrato({
    super.key,
    required this.contrato,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final temTel = contrato.telefoneComprador.trim().isNotEmpty;
    final temEmail = contrato.emailComprador.trim().isNotEmpty;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: temTel ? () => abrirWhatsAppContrato(context, contrato) : null,
          icon: FaIcon(FontAwesomeIcons.whatsapp, size: iconSize),
          color: const Color(0xFF25D366),
          tooltip: temTel
              ? 'WhatsApp (${contrato.telefoneComprador})'
              : 'Sem telefone',
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          onPressed:
              temEmail ? () => enviarEmailContrato(context, contrato) : null,
          icon: Icon(Icons.email_outlined, size: iconSize + 2),
          color: cs.primary,
          tooltip:
              temEmail ? 'E-mail (${contrato.emailComprador})' : 'Sem e-mail',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
