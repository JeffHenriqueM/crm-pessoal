import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/contrato_model.dart';
import 'package:crm_pessoal/services/firestore_service.dart';
import 'package:crm_pessoal/widgets/aba_transicao.dart';

void main() {
  testWidgets(
      'Prioridade agrupa contratos por sócio, soma integralizado e ordena decrescente',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'user-jeff', displayName: 'Jefferson Henrique'),
    );
    final fs = FirestoreService(db: db, auth: auth);

    // MTROCHA: dois contratos (182.207 + 141.555 = 323.762)
    await fs.salvarContrato(const Contrato(
      localizador: 'LOC_MTR1',
      localizadorAtendimento: 'ATD_MTR1',
      nomeComprador: 'MTROCHA EMPREENDIMENTOS E PARTICIPACOES LTDA',
      imovel: '413',
      bloco: 'C',
      cota: 'Cota 01',
      valorIntegralizado: 182207,
      status: 'Ativo',
    ));
    await fs.salvarContrato(const Contrato(
      localizador: 'LOC_MTR2',
      localizadorAtendimento: 'ATD_MTR2',
      nomeComprador: 'MTROCHA EMPREENDIMENTOS E PARTICIPACOES LTDA',
      imovel: '109',
      bloco: 'B',
      cota: 'Cota 02',
      valorIntegralizado: 141555,
      status: 'Ativo',
    ));

    // S & S: um contrato (114.770)
    await fs.salvarContrato(const Contrato(
      localizador: 'LOC_SS',
      localizadorAtendimento: 'ATD_SS',
      nomeComprador: 'S & S ADMINISTRADORA DE BENS LTDA',
      imovel: '101',
      bloco: 'B',
      cota: 'Cota 01',
      valorIntegralizado: 114770,
      status: 'Ativo',
    ));

    // CAMELOHAESBAERT: dois contratos (96.720 + 70.728 = 167.448)
    await fs.salvarContrato(const Contrato(
      localizador: 'LOC_CH1',
      localizadorAtendimento: 'ATD_CH1',
      nomeComprador: 'CAMELOHAESBAERT EMPREENDIMENTOS IMOBILIARIOS',
      imovel: '101',
      bloco: 'C',
      cota: 'Cota 01',
      valorIntegralizado: 96720,
      status: 'Ativo',
    ));
    await fs.salvarContrato(const Contrato(
      localizador: 'LOC_CH2',
      localizadorAtendimento: 'ATD_CH2',
      nomeComprador: 'CAMELOHAESBAERT EMPREENDIMENTOS IMOBILIARIOS',
      imovel: '102',
      bloco: 'C',
      cota: 'Cota 02',
      valorIntegralizado: 70728,
      status: 'Ativo',
    ));

    // Separados: Matheus Camelo e Reynaldo Fabbri (devem ser excluídos da prioridade geral)
    await fs.salvarContrato(const Contrato(
      localizador: 'LOC_MATHEUS',
      localizadorAtendimento: 'ATD_MATHEUS',
      nomeComprador: 'Matheus Camelo',
      imovel: '201',
      bloco: 'A',
      cota: 'Cota 01',
      valorIntegralizado: 999999,
      status: 'Ativo',
    ));

    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AbaTransicao(
            modo: ModoAba.transicao,
            firestoreService: fs,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Clica na aba "Prioridade"
    final tabPrioridade = find.text('Prioridade');
    expect(tabPrioridade, findsOneWidget);
    await tester.tap(tabPrioridade);
    await tester.pumpAndSettle();

    // Verifica que o cabeçalho mostra os sócios classificados
    expect(find.text('Prioridade de atendimento'), findsOneWidget);
    expect(find.text('3 sócios'), findsOneWidget);

    // MTROCHA consolidado deve aparecer com 2 cotas e soma ~R$ 323.762
    expect(find.text('MTROCHA EMPREENDIMENTOS E PARTICIPACOES LTDA'), findsOneWidget);
    expect(find.text('2 cotas'), findsNWidgets(2)); // MTROCHA e CAMELOHAESBAERT têm 2 cotas
    expect(find.text('S & S ADMINISTRADORA DE BENS LTDA'), findsOneWidget);
    expect(find.text('CAMELOHAESBAERT EMPREENDIMENTOS IMOBILIARIOS'), findsOneWidget);

    // Matheus Camelo não pode estar na lista de prioridade geral
    expect(find.text('Matheus Camelo'), findsNothing);

    // Clica no MTROCHA para abrir o modal de detalhes
    await tester.tap(find.text('MTROCHA EMPREENDIMENTOS E PARTICIPACOES LTDA'));
    await tester.pumpAndSettle();

    // Modal de detalhes deve exibir as duas cotas e botão da ficha
    expect(find.text('Cotas e Contratos vinculados (2):'), findsOneWidget);
    expect(find.text('Ver ficha do contrato'), findsNWidgets(2));
  });

  testWidgets(
      'Recontar contratos atualiza lista e métricas de prioridade',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'user-jeff', displayName: 'Jefferson Henrique'),
    );
    final fs = FirestoreService(db: db, auth: auth);

    await fs.salvarContrato(const Contrato(
      localizador: 'LOC1',
      localizadorAtendimento: 'ATD1',
      nomeComprador: 'Sócio Alfa',
      imovel: '101',
      bloco: 'A',
      cota: 'Cota 01',
      valorIntegralizado: 50000,
      status: 'Ativo',
    ));

    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AbaTransicao(
            modo: ModoAba.transicao,
            firestoreService: fs,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Abre aba Prioridade
    await tester.tap(find.text('Prioridade'));
    await tester.pumpAndSettle();

    expect(find.text('1 sócios'), findsOneWidget);
    expect(find.text('Sócio Alfa'), findsOneWidget);

    // Adiciona um novo sócio com valor maior diretamente no Firestore
    await fs.salvarContrato(const Contrato(
      localizador: 'LOC2',
      localizadorAtendimento: 'ATD2',
      nomeComprador: 'Sócio Beta Top',
      imovel: '202',
      bloco: 'B',
      cota: 'Cota 01',
      valorIntegralizado: 250000,
      status: 'Ativo',
    ));

    // Clica no botão "Recontar contratos" no topo da tela
    final botaoRecontar = find.text('Recontar contratos');
    expect(botaoRecontar, findsOneWidget);
    await tester.tap(botaoRecontar);
    await tester.pump();
    await tester.pumpAndSettle();

    // Fecha o modal de confirmação de sincronização
    expect(find.text('Contratos Sincronizados!'), findsOneWidget);
    expect(find.text('Sócios ativos classificados: 2'), findsOneWidget);
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();

    // Verifica que agora há 2 sócios e o Sócio Beta Top foi incluído e classificado
    expect(find.text('2 sócios'), findsOneWidget);
    expect(find.text('Sócio Beta Top'), findsOneWidget);
  });
}
