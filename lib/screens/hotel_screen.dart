import 'package:flutter/material.dart';

import '../widgets/aba_transicao.dart';

/// Tela "Hotel" (menu lateral): apartamentos, áreas e a projeção financeira
/// do hotel em operação (Pool, Condomínio, Ganhos).
class HotelScreen extends StatelessWidget {
  const HotelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hotel'),
        toolbarHeight: 50,
      ),
      body: const AbaTransicao(modo: ModoAba.hotel),
    );
  }
}
