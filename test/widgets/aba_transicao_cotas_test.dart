import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/services/firestore_service.dart';
import 'package:crm_pessoal/widgets/aba_transicao.dart';

void main() {
  testWidgets('AbaTransicao na aba Cotas renderiza categorias customizadas da Multipropriedade (como VILLAMOR)',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final service = FirestoreService(
      db: db,
      auth: MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user-jeff', displayName: 'Jefferson'),
      ),
    );

    // Salva categorias customizadas na coleção config/multipropriedade
    await db.collection('config').doc('multipropriedade').set({
      'categorias': [
        {
          'nome': 'LUXO',
          'cor': 4280921058,
          'aptos': [51, 52],
        },
        {
          'nome': 'VILLAMOR (BANHEIRA)',
          'cor': 4278225275,
          'aptos': [300, 301, 302],
        },
      ],
    });

    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AbaTransicao(
            firestoreService: service,
            modo: ModoAba.hotel,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Navega para a aba Cotas
    final tabCotas = find.text('Cotas');
    expect(tabCotas, findsOneWidget);
    await tester.tap(tabCotas);
    await tester.pumpAndSettle();

    // Verifica que a categoria VILLAMOR (BANHEIRA) está presente na aba Cotas
    expect(find.text('VILLAMOR (BANHEIRA)'), findsOneWidget);

    // Verifica que os apartamentos da categoria aparecem
    expect(find.text('300'), findsOneWidget);
    expect(find.text('301'), findsOneWidget);
    expect(find.text('302'), findsOneWidget);
  });
}
