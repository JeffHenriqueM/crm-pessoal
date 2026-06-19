import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/baixa_financeira_model.dart';
import 'package:crm_pessoal/services/firestore_service.dart';

/// Financeiro — importação de baixas (coleção canônica única `financeiro_baixas`).
///
/// Regras verificadas:
/// - importação grava na MESMA coleção que os lookups leem (sem coleção órfã);
/// - reimportação SUBSTITUI o conjunto via soft-delete (nunca delete físico);
/// - leituras e o "último pagamento" ignoram registros `deletado`;
/// - cada importação registra trilha em `/audit_log`.
void main() {
  FirestoreService serviceCom(
    FakeFirebaseFirestore db, {
    String uid = 'fin',
    String nome = 'Financeiro',
  }) =>
      FirestoreService(
        db: db,
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: uid, displayName: nome),
        ),
      );

  BaixaFinanceira baixa({
    required String cliente,
    required double valor,
    required DateTime credito,
    String doc = 'CAR-1',
  }) =>
      BaixaFinanceira(
        cliente: cliente,
        tipo: '018 - PIX',
        documentoCar: doc,
        vencimento: credito,
        valorPago: valor,
        dataBaixa: credito,
        dataCredito: credito,
        status: 'Baixado',
        mesCreditoKey: BaixaFinanceira.buildMesKey(credito),
        importadoEm: DateTime(2026, 6, 1),
        importadoPorId: 'fin',
        importadoPorNome: 'Financeiro',
      );

  late FakeFirebaseFirestore db;
  setUp(() => db = FakeFirebaseFirestore());

  test('importa e lê baixas na coleção canônica financeiro_baixas', () async {
    final s = serviceCom(db);
    await s.importarBaixasFinanceiras([
      baixa(cliente: 'JOÃO', valor: 100, credito: DateTime(2026, 3, 10)),
      baixa(cliente: 'MARIA', valor: 200, credito: DateTime(2026, 3, 12)),
    ]);

    final lidas = await s.getBaixasFinanceiras();
    expect(lidas.length, 2);
    // gravou de fato em financeiro_baixas (não em coleção paralela)
    final raw = await db.collection('financeiro_baixas').get();
    expect(raw.docs.length, 2);
  });

  test('reimportação substitui o conjunto via soft-delete (sem delete físico)',
      () async {
    final s = serviceCom(db);
    await s.importarBaixasFinanceiras(
        [baixa(cliente: 'ANTIGO', valor: 50, credito: DateTime(2026, 1, 5))]);
    await s.importarBaixasFinanceiras(
        [baixa(cliente: 'NOVO', valor: 70, credito: DateTime(2026, 2, 5))]);

    final lidas = await s.getBaixasFinanceiras();
    expect(lidas.length, 1);
    expect(lidas.first.cliente, 'NOVO');

    // nada apagado fisicamente: 1 antigo soft-deletado + 1 novo ativo
    final raw = await db.collection('financeiro_baixas').get();
    expect(raw.docs.length, 2);
    final deletados =
        raw.docs.where((d) => d.data()['deletado'] == true).length;
    expect(deletados, 1);
  });

  test('getUltimoPagamentoCliente ignora soft-deletados e pega o mais recente',
      () async {
    final s = serviceCom(db);
    await s.importarBaixasFinanceiras(
        [baixa(cliente: 'JOÃO', valor: 100, credito: DateTime(2026, 1, 10))]);
    // substitui — o JOÃO antigo (jan) vira deletado
    await s.importarBaixasFinanceiras([
      baixa(cliente: 'JOÃO', valor: 300, credito: DateTime(2026, 4, 20)),
      baixa(cliente: 'JOÃO', valor: 150, credito: DateTime(2026, 4, 1)),
    ]);

    final ultimo = await s.getUltimoPagamentoCliente('joão'); // case-insensitive
    expect(ultimo, isNotNull);
    expect(ultimo!.valorPago, 300); // 20/04, mais recente e ativo
  });

  test('getUltimoPagamentoCliente retorna null para cliente sem baixa',
      () async {
    final s = serviceCom(db);
    expect(await s.getUltimoPagamentoCliente('NINGUÉM'), isNull);
  });

  test('importação registra entrada em audit_log', () async {
    final s = serviceCom(db, uid: 'fin1', nome: 'Fin Um');
    await s.importarBaixasFinanceiras(
        [baixa(cliente: 'X', valor: 10, credito: DateTime(2026, 5, 5))]);

    final logs = await db
        .collection('audit_log')
        .where('tipo', isEqualTo: 'importacao_baixas')
        .get();
    expect(logs.docs.length, 1);
    expect(logs.docs.first.data()['autorId'], 'fin1');
    expect(logs.docs.first.data()['totalImportado'], 1);
  });

  test('getUltimosPagamentosClientes retorna o mais recente por cliente '
      'pela chave original, ignorando deletados', () async {
    final s = serviceCom(db);
    await s.importarBaixasFinanceiras([
      baixa(cliente: 'JOÃO', valor: 100, credito: DateTime(2026, 1, 10)),
      baixa(cliente: 'MARIA', valor: 200, credito: DateTime(2026, 2, 2)),
    ]);
    // substitui: JOÃO antigo vira deletado; entra JOÃO mais recente + MARIA.
    await s.importarBaixasFinanceiras([
      baixa(cliente: 'JOÃO', valor: 300, credito: DateTime(2026, 4, 20)),
      baixa(cliente: 'MARIA', valor: 250, credito: DateTime(2026, 4, 21)),
    ]);

    // chamado com os nomes "originais" (capitalização livre)
    final mapa = await s.getUltimosPagamentosClientes(['João', 'Maria', 'Zé']);
    expect(mapa.length, 2);
    expect(mapa['João']!.valorPago, 300);
    expect(mapa['Maria']!.valorPago, 250);
    expect(mapa.containsKey('Zé'), isFalse);
  });
}
