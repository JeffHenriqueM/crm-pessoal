import 'package:flutter/material.dart';

import '../widgets/aba_transicao.dart';

/// Tela "Transição" (item do menu lateral, exclusiva do super admin):
/// projeta a futura migração dos contratos do resort para o Hotel Villamor.
class TransicaoScreen extends StatelessWidget {
  const TransicaoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transição'),
        toolbarHeight: 50,
      ),
      body: const AbaTransicao(),
    );
  }
}
