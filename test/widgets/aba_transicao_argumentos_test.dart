import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/services/firestore_service.dart';
import 'package:crm_pessoal/widgets/aba_transicao.dart';

void main() {
  testWidgets(
      'AbaTransicao — Aba Argumentos exibe botões de imprimir e adicionar objeção',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'user-jeff', displayName: 'Jefferson Henrique'),
    );
    final fs = FirestoreService(db: db, auth: auth);

    // Salva uma objeção personalizada no banco
    await fs.salvarObjecaoTransicao(
      pergunta: 'Como funciona a taxa de condomínio na troca?',
      resposta: 'A taxa é compatível e inclui toda a operação do hotel.',
    );

    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: AbaTransicao(
            modo: ModoAba.transicao,
            firestoreService: fs,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Encontra e clica na aba "Argumentos"
    final tabArg = find.widgetWithText(Tab, 'Argumentos');
    expect(tabArg, findsOneWidget);
    await tester.tap(tabArg);
    await tester.pumpAndSettle();

    // Verifica que o cabeçalho, botão de imprimir e adicionar objeção estão visíveis
    expect(find.text('Imprimir / Salvar PDF'), findsOneWidget);
    expect(find.text('Adicionar Objeção'), findsOneWidget);

    // Clica em "Adicionar Objeção" para abrir o diálogo
    await tester.tap(find.text('Adicionar Objeção'));
    await tester.pumpAndSettle();

    // Diálogo de nova objeção deve ser renderizado
    expect(find.text('Nova Objeção / Pergunta'), findsOneWidget);
    expect(find.text('Salvar Objeção'), findsOneWidget);

    // Fecha o diálogo
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    // Rola para baixo para visualizar a seção de objeções
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();

    final itemFinder =
        find.text('"Como funciona a taxa de condomínio na troca?"');
    expect(itemFinder, findsOneWidget);
    expect(find.text('Personalizada'), findsOneWidget);
  });
}
