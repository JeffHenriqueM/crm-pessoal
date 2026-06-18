import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/agendamento_model.dart';
import 'package:crm_pessoal/services/firestore_service.dart';

/// Remarcação de agendamento (ticket #63): muda data/hora com motivo, conta as
/// remarcações, bloqueia após o limite (2) e só volta a permitir após o admin
/// liberar (aumenta o teto).
void main() {
  FirestoreService serviceCom(FakeFirebaseFirestore db, String uid) =>
      FirestoreService(
        db: db,
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: uid, displayName: 'Recep'),
        ),
      );

  late FakeFirebaseFirestore db;
  late FirestoreService service;

  setUp(() async {
    db = FakeFirebaseFirestore();
    service = serviceCom(db, 'recep');
    await db.collection('usuarios').doc('recep').set({
      'nome': 'Recep',
      'perfil': 'recepcao',
    });
  });

  Future<String> criar() => service.adicionarAgendamento(Agendamento(
        nome: 'Cliente',
        dataHoraAgendamento: DateTime(2026, 6, 20, 14, 30),
      ));

  Future<Agendamento> ler(String id) async =>
      Agendamento.fromFirestore(await db.collection('agendamentos').doc(id).get());

  test('remarca: muda data, conta e registra histórico com motivo', () async {
    final id = await criar();
    await service.remarcarAgendamento(
        id, DateTime(2026, 6, 25, 10, 0), 'Cliente pediu outro dia');

    final a = await ler(id);
    expect(a.dataHoraAgendamento, DateTime(2026, 6, 25, 10, 0));
    expect(a.remarcacoes, 1);
    expect(a.historicoRemarcacoes.length, 1);
    expect(a.historicoRemarcacoes.first['motivo'], 'Cliente pediu outro dia');
    expect(a.podeRemarcar, isTrue); // 1 de 2
  });

  test('bloqueia na 3ª remarcação (limite 2)', () async {
    final id = await criar();
    await service.remarcarAgendamento(id, DateTime(2026, 6, 25, 10), 'm1');
    await service.remarcarAgendamento(id, DateTime(2026, 6, 26, 10), 'm2');

    final a = await ler(id);
    expect(a.remarcacoes, 2);
    expect(a.podeRemarcar, isFalse);

    expect(
      () => service.remarcarAgendamento(id, DateTime(2026, 6, 27, 10), 'm3'),
      throwsStateError,
    );
  });

  test('admin liberar aumenta o teto e permite remarcar de novo', () async {
    final id = await criar();
    await service.remarcarAgendamento(id, DateTime(2026, 6, 25, 10), 'm1');
    await service.remarcarAgendamento(id, DateTime(2026, 6, 26, 10), 'm2');

    await service.liberarRemarcacaoAgendamento(id);
    final liberado = await ler(id);
    expect(liberado.podeRemarcar, isTrue); // teto 3, feitas 2

    await service.remarcarAgendamento(id, DateTime(2026, 6, 27, 10), 'm3');
    final a = await ler(id);
    expect(a.remarcacoes, 3);
    expect(a.dataHoraAgendamento, DateTime(2026, 6, 27, 10));
  });
}
