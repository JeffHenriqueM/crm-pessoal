import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/screens/tutorial_screen.dart';

/// Tela de Tutoriais (ticket #33): lista as seções e expande o passo a passo
/// ao tocar no cabeçalho.
void main() {
  testWidgets('lista seções de tutorial recolhidas por padrão', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TutorialScreen()));

    expect(find.text('Tutoriais'), findsWidgets);
    // Seção conhecida aparece como cabeçalho.
    expect(
      find.text('Recepção — registrar atendimento e agendamento'),
      findsOneWidget,
    );
    // Conteúdo do passo a passo só aparece após expandir.
    expect(
      find.textContaining('Abra "Recepção" no menu lateral'),
      findsNothing,
    );
  });

  testWidgets('toca na seção expande e mostra os passos', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TutorialScreen()));

    await tester.tap(
        find.text('Recepção — registrar atendimento e agendamento'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Abra "Recepção" no menu lateral'),
      findsOneWidget,
    );
  });
}
