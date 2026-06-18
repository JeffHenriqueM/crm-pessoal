import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/widgets/grupo_notificacao_colapsavel.dart';

/// Comportamento do grupo recolhível do painel de notificações (ticket #50):
/// começa aberto, recolhe ao tocar o cabeçalho e reabre ao tocar de novo.
void main() {
  Widget envolver(Widget child) =>
      MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

  GrupoNotificacaoColapsavel grupo({bool inicialAberto = true}) =>
      GrupoNotificacaoColapsavel(
        titulo: 'Tickets',
        icone: Icons.confirmation_number_outlined,
        cor: Colors.indigo,
        contador: 2,
        inicialAberto: inicialAberto,
        children: const [
          Text('Item A'),
          Text('Item B'),
        ],
      );

  testWidgets('começa aberto: conteúdo visível', (tester) async {
    await tester.pumpWidget(envolver(grupo()));
    expect(find.text('Item A'), findsOneWidget);
    expect(find.text('Item B'), findsOneWidget);
    // O título e o contador sempre aparecem.
    expect(find.text('Tickets'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('toca no cabeçalho recolhe o conteúdo', (tester) async {
    await tester.pumpWidget(envolver(grupo()));
    await tester.tap(find.text('Tickets'));
    await tester.pumpAndSettle();

    // Cabeçalho continua; itens somem (AnimatedCrossFade oculta o ramo).
    expect(find.text('Tickets'), findsOneWidget);
    expect(find.text('Item A'), findsNothing);
    expect(find.text('Item B'), findsNothing);
  });

  testWidgets('toca de novo reabre o conteúdo', (tester) async {
    await tester.pumpWidget(envolver(grupo()));
    await tester.tap(find.text('Tickets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tickets'));
    await tester.pumpAndSettle();

    expect(find.text('Item A'), findsOneWidget);
    expect(find.text('Item B'), findsOneWidget);
  });

  testWidgets('inicialAberto=false começa recolhido', (tester) async {
    await tester.pumpWidget(envolver(grupo(inicialAberto: false)));
    expect(find.text('Tickets'), findsOneWidget);
    expect(find.text('Item A'), findsNothing);
  });
}
