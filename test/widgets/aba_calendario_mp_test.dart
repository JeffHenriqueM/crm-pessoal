import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:crm_pessoal/services/firestore_service.dart';
import 'package:crm_pessoal/widgets/aba_calendario_mp.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
  });

  testWidgets('AbaCalendarioMP exibe formato de tabela estruturada com colunas e separação por ano',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final service = FirestoreService(
      db: db,
      auth: MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user-jeff', displayName: 'Jefferson'),
      ),
    );

    // Preenche documento de teste do Firestore
    await db.collection('config').doc('calendario_ouro_domingo').set({
      'tier': 'ouro',
      'dia': 'domingo',
      'cotas': {
        '1': [
          {
            'a': 2027,
            'e': '2027-09-23',
            's': '2027-09-30',
            't': 'Alta',
            'f': '',
          },
          {
            'a': 2027,
            'e': '2027-12-02',
            's': '2027-12-09',
            't': 'Média',
            'f': 'N. Sra. Aparecida',
          },
          {
            'a': 2028,
            'e': '2028-01-27',
            's': '2028-02-03',
            't': 'Alta',
            'f': '',
          },
        ],
      },
    });

    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AbaCalendarioMP(firestoreService: service),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verifica cabeçalho geral
    expect(find.text('Calendário da Multipropriedade'), findsOneWidget);

    // Verifica cabeçalhos de anos (separação por ano)
    expect(find.text('2027'), findsWidgets);
    expect(find.text('2028'), findsWidgets);

    // Verifica colunas da tabela
    expect(find.text('Entrada'), findsWidgets);
    expect(find.text('Saída'), findsWidgets);
    expect(find.text('Mês'), findsWidgets);
    expect(find.text('Tipo de semana'), findsWidgets);
    expect(find.text('Feriado'), findsWidgets);

    // Verifica exibição dos meses calculados
    expect(find.text('Setembro'), findsOneWidget);
    expect(find.text('Dezembro'), findsOneWidget);
    expect(find.text('Janeiro'), findsOneWidget);

    // Verifica badge de feriado
    expect(find.text('N. Sra. Aparecida'), findsOneWidget);

    // Alterna para visualização "Tabela Completa"
    final botaoTabelaCompleta = find.text('Tabela Completa');
    expect(botaoTabelaCompleta, findsOneWidget);
    await tester.tap(botaoTabelaCompleta);
    await tester.pumpAndSettle();

    // Na tabela completa, a coluna "Ano" deve estar presente no cabeçalho (além do label do dropdown)
    expect(find.text('Ano'), findsNWidgets(2));
    expect(find.text('2027'), findsWidgets);
    expect(find.text('Setembro'), findsOneWidget);
  });

  testWidgets('AbaCalendarioMP permite alternar para modo Comparar Cotas',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final service = FirestoreService(
      db: db,
      auth: MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user-jeff', displayName: 'Jefferson'),
      ),
    );

    await db.collection('config').doc('calendario_ouro_domingo').set({
      'tier': 'ouro',
      'dia': 'domingo',
      'cotas': {
        '3': [
          {
            'a': 2028,
            'e': '2028-04-06',
            's': '2028-04-13',
            't': 'Média',
            'f': '',
          },
        ],
        '7': [
          {
            'a': 2028,
            'e': '2028-01-27',
            's': '2028-02-03',
            't': 'Alta',
            'f': '',
          },
        ],
      },
    });

    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AbaCalendarioMP(firestoreService: service),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Clica no modo "Comparar Cotas"
    final btnComparar = find.text('Comparar Cotas');
    expect(btnComparar, findsOneWidget);
    await tester.tap(btnComparar);
    await tester.pumpAndSettle();

    // Verifica que os controles de comparação foram renderizados
    expect(find.text('Cotas:'), findsOneWidget);
    expect(find.text('Cota A'), findsOneWidget);
    expect(find.text('Cota B'), findsOneWidget);
    expect(find.text('Lado a Lado'), findsOneWidget);
    expect(find.text('Cronológico'), findsOneWidget);

    // Alterna para o modo cronológico
    await tester.tap(find.text('Cronológico'));
    await tester.pumpAndSettle();

    // Na tabela cronológica, as badges das cotas aparecem
    expect(find.text('Cota 3'), findsWidgets);
    expect(find.text('Cota 7'), findsWidgets);
  });
}
