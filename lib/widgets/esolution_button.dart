import 'package:flutter/material.dart';

import '../utils/url_launcher_service.dart';

/// Botão de atalho para a Central de Contratos (eSolution), aberta em nova aba.
/// Usado na barra superior da Pós-venda e da Hospedagem.
class EsolutionButton extends StatelessWidget {
  static const _url = 'http://168.75.88.126:1584/Fractional/CentralContratos';

  const EsolutionButton({super.key});

  Future<void> _abrir(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await UrlLauncherService().abrirUrl(_url);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o eSolution.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _abrir(context),
      icon: const Icon(Icons.open_in_new, size: 18),
      label: const Text('Esolution'),
    );
  }
}
