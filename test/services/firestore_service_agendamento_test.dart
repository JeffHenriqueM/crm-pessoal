import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/agendamento_model.dart';
import 'package:crm_pessoal/services/firestore_service.dart';

/// Comportamento esperado da feature "Agendamento" (atendimento futuro que
/// ainda NÃO é lead): criar grava na coleção `agendamentos` com status
/// `agendado`, o stream entrega todos os agendamentos a todos os perfis
/// (ticket #62), e comparecer vincula o cliente criado.
void main() {
  FirestoreService serviceCom(FakeFirebaseFirestore db, String uid,
          {String nome = 'Usuário'}) =>
      FirestoreService(
        db: db,
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: uid, displayName: nome),
        ),
      );

  Agendamento novo({String nome = 'Cliente Futuro', String? captadorId}) =>
      Agendamento(
        nome: nome,
        telefone: '(21) 90000-0000',
        captadorId: captadorId,
        dataHoraAgendamento: DateTime(2026, 6, 20, 14, 30),
      );

  group('adicionarAgendamento', () {
    late FakeFirebaseFirestore db;
    late FirestoreService service;

    setUp(() async {
      db = FakeFirebaseFirestore();
      service = serviceCom(db, 'recep_a', nome: 'Recep A');
      await db.collection('usuarios').doc('recep_a').set({
        'nome': 'Recep A',
        'perfil': 'recepcao',
      });
    });

    test('grava com status agendado e criadoPorId do usuário logado', () async {
      final id = await service.adicionarAgendamento(novo());
      final doc = await db.collection('agendamentos').doc(id).get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['status'], 'agendado');
      expect(doc.data()?['criadoPorId'], 'recep_a');
      expect(doc.data()?['nome'], 'Cliente Futuro');
    });

    test('NÃO toca o contador de atendimentos (config/contadores)', () async {
      await service.adicionarAgendamento(novo());
      final contador = await db.collection('config').doc('contadores').get();
      // O documento de contador nem deve ter sido criado pelo agendamento.
      expect(contador.exists, isFalse);
    });
  });

  group('getAgendamentosStream — escopo', () {
    late FakeFirebaseFirestore db;

    setUp(() async {
      db = FakeFirebaseFirestore();
      await db.collection('usuarios').doc('recep_a').set({
        'nome': 'Recep A',
        'perfil': 'recepcao',
      });
      await db.collection('usuarios').doc('vend_a').set({
        'nome': 'Vend A',
        'perfil': 'vendedor',
      });
      // Agendamentos de donos distintos.
      await db.collection('agendamentos').doc('ag_a').set({
        'nome': 'Do A',
        'captadorId': 'vend_a',
        'status': 'agendado',
        'dataHoraAgendamento': Timestamp.fromDate(DateTime(2026, 6, 20, 10)),
      });
      await db.collection('agendamentos').doc('ag_b').set({
        'nome': 'Do B',
        'captadorId': 'vend_b',
        'status': 'agendado',
        'dataHoraAgendamento': Timestamp.fromDate(DateTime(2026, 6, 21, 10)),
      });
    });

    test('perfil recepcao vê todos, ordenados por data/hora', () async {
      final service = serviceCom(db, 'recep_a', nome: 'Recep A');
      final lista = await service.getAgendamentosStream().first;
      expect(lista.map((a) => a.id), ['ag_a', 'ag_b']);
    });

    // Ticket #62: todos os perfis enxergam todos os agendamentos (a captadora
    // lança e o vendedor precisa ver na agenda mesmo sem ser o dono).
    test('vendedor também vê todos os agendamentos', () async {
      final service = serviceCom(db, 'vend_a', nome: 'Vend A');
      final lista = await service.getAgendamentosStream().first;
      expect(lista.map((a) => a.id), ['ag_a', 'ag_b']);
    });
  });

  group('conversão de status', () {
    late FakeFirebaseFirestore db;
    late FirestoreService service;

    setUp(() async {
      db = FakeFirebaseFirestore();
      service = serviceCom(db, 'recep_a', nome: 'Recep A');
      await db.collection('usuarios').doc('recep_a').set({
        'nome': 'Recep A',
        'perfil': 'recepcao',
      });
    });

    test('marcarCompareceu grava status e vincula clienteId', () async {
      final id = await service.adicionarAgendamento(novo());
      await service.marcarCompareceu(id, 'cliente_123');

      final doc = await db.collection('agendamentos').doc(id).get();
      expect(doc.data()?['status'], 'compareceu');
      expect(doc.data()?['clienteVinculadoId'], 'cliente_123');
    });

    test('atualizarStatusAgendamento(faltou) grava o status', () async {
      final id = await service.adicionarAgendamento(novo());
      await service.atualizarStatusAgendamento(id, 'faltou');

      final doc = await db.collection('agendamentos').doc(id).get();
      expect(doc.data()?['status'], 'faltou');
    });
  });
}
