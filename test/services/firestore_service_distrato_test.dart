import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/contrato_model.dart';
import 'package:crm_pessoal/services/firestore_service.dart';

/// Marcação de "em distrato" (aba Distratar, super admin).
/// Regras verificadas:
/// - marcar grava distratoEm + distratoPorNome + motivo via merge;
/// - desmarcar limpa os três campos;
/// - cada operação registra trilha em /audit_log;
/// - não toca outros campos do contrato (merge).
void main() {
  FirestoreService serviceCom(
    FakeFirebaseFirestore db, {
    String uid = 'sa',
    String nome = 'Super Admin',
  }) =>
      FirestoreService(
        db: db,
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: uid, displayName: nome),
        ),
      );

  late FakeFirebaseFirestore db;
  setUp(() async {
    db = FakeFirebaseFirestore();
    await db.collection('contratos').doc('LOC1').set({
      'nomeComprador': 'FULANO',
      'valorAtrasado': 1000.0,
    });
  });

  test('marcar grava distratoEm, distratoPorNome e motivo sem apagar o resto',
      () async {
    final s = serviceCom(db);
    await s.marcarEmDistrato('LOC1', marcar: true, motivo: 'sem pagar há meses');

    final doc = await db.collection('contratos').doc('LOC1').get();
    final d = doc.data()!;
    expect(d['distratoEm'], isNotNull);
    expect(d['distratoPorNome'], 'Super Admin');
    expect(d['motivoDistrato'], 'sem pagar há meses');
    // merge preservou os campos originais
    expect(d['nomeComprador'], 'FULANO');
    expect(d['valorAtrasado'], 1000.0);
  });

  test('desmarcar limpa os três campos de distrato', () async {
    final s = serviceCom(db);
    await s.marcarEmDistrato('LOC1', marcar: true, motivo: 'x');
    await s.marcarEmDistrato('LOC1', marcar: false);

    final d = (await db.collection('contratos').doc('LOC1').get()).data()!;
    expect(d['distratoEm'], isNull);
    expect(d['distratoPorNome'], isNull);
    expect(d['motivoDistrato'], isNull);
  });

  test('cada operação registra trilha em audit_log', () async {
    final s = serviceCom(db, uid: 'sa1', nome: 'SA Um');
    await s.marcarEmDistrato('LOC1', marcar: true, motivo: 'motivo y');
    await s.marcarEmDistrato('LOC1', marcar: false);

    final marcados = await db
        .collection('audit_log')
        .where('tipo', isEqualTo: 'distrato_marcado')
        .get();
    expect(marcados.docs.length, 1);
    expect(marcados.docs.first.data()['autorId'], 'sa1');
    expect(marcados.docs.first.data()['contratoLocalizador'], 'LOC1');
    expect(marcados.docs.first.data()['motivo'], 'motivo y');

    final desmarcados = await db
        .collection('audit_log')
        .where('tipo', isEqualTo: 'distrato_desmarcado')
        .get();
    expect(desmarcados.docs.length, 1);
  });

  test('marcar inicia o funil em "marcado"', () async {
    final s = serviceCom(db);
    await s.marcarEmDistrato('LOC1', marcar: true);
    final c = (await s.getContratos()).firstWhere((x) => x.localizador == 'LOC1');
    expect(c.situacaoDistrato, SituacaoDistrato.marcado);
  });

  test('atualizarSituacaoDistrato grava situação + datas e audita', () async {
    final s = serviceCom(db);
    await s.marcarEmDistrato('LOC1', marcar: true);
    final notif = DateTime(2026, 6, 20);
    final prev = DateTime(2026, 7, 5);
    await s.atualizarSituacaoDistrato(
      'LOC1',
      situacao: SituacaoDistrato.emNegociacao,
      notificadoEm: notif,
      distratoPrevistoEm: prev,
    );

    final c = (await s.getContratos()).firstWhere((x) => x.localizador == 'LOC1');
    expect(c.situacaoDistrato, SituacaoDistrato.emNegociacao);
    expect(c.notificadoEm, notif);
    expect(c.distratoPrevistoEm, prev);

    final logs = await db
        .collection('audit_log')
        .where('tipo', isEqualTo: 'distrato_situacao')
        .get();
    expect(logs.docs.length, 1);
    expect(logs.docs.first.data()['situacao'], 'em_negociacao');
  });

  test('desmarcar limpa também situação e datas do funil', () async {
    final s = serviceCom(db);
    await s.marcarEmDistrato('LOC1', marcar: true);
    await s.atualizarSituacaoDistrato(
      'LOC1',
      situacao: SituacaoDistrato.notificado,
      notificadoEm: DateTime(2026, 6, 20),
      distratoPrevistoEm: DateTime(2026, 7, 5),
    );
    await s.marcarEmDistrato('LOC1', marcar: false);

    final c = (await s.getContratos()).firstWhere((x) => x.localizador == 'LOC1');
    expect(c.emDistrato, isFalse);
    expect(c.situacaoDistrato, isNull);
    expect(c.notificadoEm, isNull);
    expect(c.distratoPrevistoEm, isNull);
  });

  Future<int> _qtdInteracoes(FakeFirebaseFirestore db) async =>
      (await db.collection('contratos').doc('LOC1').collection('interacoes').get())
          .docs
          .length;

  test('definir data de notificação cria interação de e-mail no contrato',
      () async {
    final s = serviceCom(db);
    await s.marcarEmDistrato('LOC1', marcar: true);
    await s.atualizarSituacaoDistrato(
      'LOC1',
      situacao: SituacaoDistrato.notificado,
      notificadoEm: DateTime(2026, 6, 20),
      distratoPrevistoEm: DateTime(2026, 7, 5),
    );

    final inter = await db
        .collection('contratos')
        .doc('LOC1')
        .collection('interacoes')
        .get();
    expect(inter.docs.length, 1);
    expect(inter.docs.first.data()['canal'], 'email');
    expect(inter.docs.first.data()['nota'], contains('20/06/2026'));
  });

  test('re-salvar com a MESMA data não duplica a interação', () async {
    final s = serviceCom(db);
    await s.marcarEmDistrato('LOC1', marcar: true);
    final d = DateTime(2026, 6, 20);
    await s.atualizarSituacaoDistrato('LOC1',
        situacao: SituacaoDistrato.notificado, notificadoEm: d);
    await s.atualizarSituacaoDistrato('LOC1',
        situacao: SituacaoDistrato.emTratativa, notificadoEm: d);
    expect(await _qtdInteracoes(db), 1);
  });

  test('mudar a data de notificação cria nova interação', () async {
    final s = serviceCom(db);
    await s.marcarEmDistrato('LOC1', marcar: true);
    await s.atualizarSituacaoDistrato('LOC1',
        situacao: SituacaoDistrato.notificado,
        notificadoEm: DateTime(2026, 6, 20));
    await s.atualizarSituacaoDistrato('LOC1',
        situacao: SituacaoDistrato.notificado,
        notificadoEm: DateTime(2026, 7, 1));
    expect(await _qtdInteracoes(db), 2);
  });

  test('atualizar sem data de notificação não cria interação', () async {
    final s = serviceCom(db);
    await s.marcarEmDistrato('LOC1', marcar: true);
    await s.atualizarSituacaoDistrato('LOC1',
        situacao: SituacaoDistrato.emTratativa);
    expect(await _qtdInteracoes(db), 0);
  });

  test('atualizar situação entra no funil sem precisar marcar p/ distrato',
      () async {
    final s = serviceCom(db);
    // Sem chamar marcarEmDistrato antes — entra direto em "Em análise".
    await s.atualizarSituacaoDistrato('LOC1',
        situacao: SituacaoDistrato.emAnalise, motivo: 'cliente pediu prazo');

    final c = (await s.getContratos()).firstWhere((x) => x.localizador == 'LOC1');
    expect(c.emDistrato, isTrue); // distratoEm foi setado na entrada
    expect(c.distratoPorNome, 'Super Admin');
    expect(c.situacaoDistrato, SituacaoDistrato.emAnalise);
    expect(c.motivoDistrato, 'cliente pediu prazo');
  });

  test('entrar em análise não cria interação (sem data de notificação)',
      () async {
    final s = serviceCom(db);
    await s.atualizarSituacaoDistrato('LOC1',
        situacao: SituacaoDistrato.emTratativa);
    expect(await _qtdInteracoes(db), 0);
  });

  test('SituacaoDistrato faz round-trip valor/fromString', () {
    for (final s in SituacaoDistrato.values) {
      expect(SituacaoDistrato.fromString(s.valor), s);
    }
    expect(SituacaoDistrato.fromString(null), isNull);
    expect(SituacaoDistrato.fromString('inexistente'), isNull);
  });
}
