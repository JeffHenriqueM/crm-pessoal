import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/contrato_model.dart';
import 'package:crm_pessoal/services/firestore_service.dart';
import 'package:crm_pessoal/widgets/aba_transicao.dart';

void main() {
  testWidgets('Renderiza AbaTransicao na aba Atualização com múltiplos sócios e estados',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'user-jeff', displayName: 'Jefferson Henrique'),
    );
    final fs = FirestoreService(db: db, auth: auth);

    // Vários contratos com perfis distintos
    await fs.salvarContrato(const Contrato(
      localizador: 'LOC1',
      localizadorAtendimento: 'ATD1',
      nomeComprador: 'João da Silva',
      cpfComprador: '11122233344',
      imovel: 'Apto 101',
      bloco: 'A',
      cota: 'Cota 01',
      valorIntegralizado: 100000,
      status: 'Ativo',
    ));

    await fs.salvarContrato(const Contrato(
      localizador: 'LOC2',
      localizadorAtendimento: 'ATD2',
      nomeComprador: 'Maria Oliveira',
      cpfComprador: '22233344455',
      imovel: 'Apto 102',
      bloco: 'B',
      cota: 'Cota 02',
      valorIntegralizado: 50000,
      status: 'Ativo',
    ));

    await fs.salvarContrato(const Contrato(
      localizador: 'LOC3',
      localizadorAtendimento: 'ATD3',
      nomeComprador: 'Carlos Santos',
      cpfComprador: '33344455566',
      imovel: 'Apto 103',
      bloco: 'C',
      cota: 'Cota 03',
      valorIntegralizado: 75000,
      status: 'Ativo',
    ));

    // Contratos de Matheus Camelo e Reynaldo Fabbri (devem ser excluídos da transição geral)
    await fs.salvarContrato(const Contrato(
      localizador: 'LOC_MATHEUS',
      localizadorAtendimento: 'ATD_M',
      nomeComprador: 'MATHEUS ANTONIUS VELOSO CAMELO',
      cpfComprador: '99988877766',
      imovel: 'Apto 501',
      bloco: 'Luxo',
      cota: 'Cota 01',
      valorIntegralizado: 4500000,
      status: 'Ativo',
    ));

    await fs.salvarContrato(const Contrato(
      localizador: 'LOC_REYNALDO',
      localizadorAtendimento: 'ATD_R',
      nomeComprador: 'REYNALDO FABBRI',
      cpfComprador: '88877766655',
      imovel: 'Apto 502',
      bloco: 'Villamor',
      cota: 'Cota 01',
      valorIntegralizado: 3564000,
      status: 'Ativo',
    ));

    // Simula dados salvos de atualização no Firestore com distrato e diferentes datas
    await fs.salvarAtualizacaoSocioTransicao(
      nomeSocio: 'João da Silva',
      status: 'Aceitar',
      fases: ['Informado', 'Contrato Hotel Villamor assinado'],
      apartamentoDestino: '302',
      dataAceiteTransicao: DateTime(2026, 10, 15),
    );

    await fs.salvarAtualizacaoSocioTransicao(
      nomeSocio: 'Maria Oliveira',
      status: 'Recusar',
      fases: ['Solicitou distrato'],
      negociacaoDistrato: 'Negociação de distrato em andamento com devolução parcelada.',
      observacoes: 'Cliente pediu atenção aos prazos.',
      dataSolicitacaoDistrato: DateTime(2026, 10, 18),
    );

    // Também injeta diretamente formato com String em atualizadoEm para testar resiliência
    await db.collection('config').doc('transicao_atualizacoes_socios').set({
      'socios': {
        'Carlos Santos': {
          'nome': 'Carlos Santos',
          'status': 'Aguardando Resposta',
          'fases': ['Aguardando aceite do cliente'],
          'atualizadoEm': '2026-10-22T14:30:00.000Z',
          'atualizadoPorNome': 'Jeff',
        }
      }
    }, SetOptions(merge: true));

    await tester.binding.setSurfaceSize(const Size(1280, 900));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AbaTransicao(
            firestoreService: fs,
            modo: ModoAba.transicao,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Clica na aba Atualização
    final abaAtualizacao = find.text('Atualização');
    expect(abaAtualizacao, findsOneWidget);
    await tester.tap(abaAtualizacao);
    await tester.pumpAndSettle();

    // Valida que todos os sócios e seus estados estão visíveis
    expect(find.text('João da Silva'), findsOneWidget);
    expect(find.text('Maria Oliveira'), findsOneWidget);
    expect(find.text('Carlos Santos'), findsOneWidget);
    expect(find.text('Aceitou (15/10/2026)'), findsOneWidget);
    expect(find.text('Recusou a transição'), findsOneWidget);
    expect(find.text('Solicitou distrato (18/10/2026)'), findsWidgets);
    expect(find.text('Negociação de Distrato Realizada (Solicitado em 18/10/2026):'), findsOneWidget);
    expect(find.text('Apto 302'), findsOneWidget);
    expect(find.text('Ficará no Apto: 302'), findsOneWidget);

    // Valida que Matheus e Reynaldo foram removidos da listagem de transição
    expect(find.text('MATHEUS ANTONIUS VELOSO CAMELO'), findsNothing);
    expect(find.text('REYNALDO FABBRI'), findsNothing);

    // Sem nenhum erro na árvore de renderização
    expect(find.byType(ErrorWidget), findsNothing);
  });

  testWidgets('Abre dialog de atualização de sócio e salva com data de aceite e distrato',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'user-jeff', displayName: 'Jefferson Henrique'),
    );
    final fs = FirestoreService(db: db, auth: auth);

    await fs.salvarContrato(const Contrato(
      localizador: 'LOC_TEST',
      localizadorAtendimento: 'ATD_TEST',
      nomeComprador: 'Ana Pereira',
      cpfComprador: '12345678900',
      imovel: 'Apto 201',
      bloco: 'A',
      cota: 'Cota 01',
      valorIntegralizado: 80000,
      status: 'Ativo',
    ));

    await tester.binding.setSurfaceSize(const Size(1280, 900));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AbaTransicao(
            firestoreService: fs,
            modo: ModoAba.transicao,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Clica na aba Atualização
    await tester.tap(find.text('Atualização'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Pereira'), findsOneWidget);

    // Clica no card ou botão de atualizar
    await tester.tap(find.text('Atualizar'));
    await tester.pumpAndSettle();

    // Modal aberto
    expect(find.text('Decisão do Sócio (Aceite da Transição):'), findsOneWidget);

    // Seleciona Aceitar
    await tester.tap(find.text('Aceitar'));
    await tester.pumpAndSettle();

    // Valida que o container com a data do aceite apareceu
    expect(find.textContaining('Data do Aceite:'), findsOneWidget);

    // Salva atualização
    await tester.tap(find.text('Salvar atualização'));
    await tester.pumpAndSettle();

    // Valida que o modal fechou e no card aparece Aceitou com data
    expect(find.textContaining('Aceitou ('), findsOneWidget);

    // Valida que no Firestore os dados foram persistidos
    final doc = await db.collection('config').doc('transicao_atualizacoes_socios').get();
    final data = doc.data();
    expect(data, isNotNull);
    final socioMap = (data!['socios'] as Map<String, dynamic>)['Ana Pereira'] as Map<String, dynamic>;
    expect(socioMap['status'], 'Aceitar');
    expect(socioMap['dataAceiteTransicao'], isNotNull);
  });
}
