import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../screens/ficha_cliente_screen.dart';
import 'url_launcher_service.dart';

/// Menu de ações ao tocar num lead (usado nas abas de analytics):
/// "Ver lead" (abre a ficha) ou "Enviar mensagem" (abre o WhatsApp).
///
/// Centralizado aqui para que as abas Risco e Potencial usem exatamente o
/// mesmo comportamento.
void mostrarAcoesLead(
  BuildContext context,
  Cliente c, {
  String userProfile = 'vendedor',
}) {
  final cs = Theme.of(context).colorScheme;
  final temTelefone = (c.telefoneContato ?? '').trim().isNotEmpty;

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(c.nome,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.person_outline, color: cs.primary),
            title: const Text('Ver lead'),
            subtitle: const Text('Abrir a ficha completa'),
            onTap: () {
              Navigator.pop(sheetCtx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FichaClienteScreen(
                      cliente: c, userProfile: userProfile),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.chat_outlined,
                color: temTelefone
                    ? const Color(0xFF25D366)
                    : cs.onSurfaceVariant),
            title: const Text('Enviar mensagem'),
            subtitle: Text(temTelefone
                ? 'Abrir o WhatsApp deste lead'
                : 'Lead sem telefone cadastrado'),
            enabled: temTelefone,
            onTap: temTelefone
                ? () {
                    Navigator.pop(sheetCtx);
                    _enviarWhatsApp(context, c);
                  }
                : null,
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<void> _enviarWhatsApp(BuildContext context, Cliente c) async {
  final tel = (c.telefoneContato ?? '').trim();
  if (tel.isEmpty) return;
  try {
    await UrlLauncherService().abrirWhatsApp(tel);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
    );
  }
}
