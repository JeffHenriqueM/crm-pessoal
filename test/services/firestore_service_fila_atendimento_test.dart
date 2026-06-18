import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/services/firestore_service.dart';

/// Comportamento da Linha de atendimento (fila da sala de vendas):
/// disponibilidade entra no fim; ordenação por posicaoEm asc; "mandar pro fim"
/// re-timestampa; reordenação manual troca posições.
void main() {
  FirestoreService serviceCom(FakeFirebaseFirestore db, String uid) =>
      FirestoreService(
        db: db,
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: uid, displayName: 'U'),
        ),
      );

  late FakeFirebaseFirestore db;
  late FirestoreService service;

  setUp(() {
    db = FakeFirebaseFirestore();
    service = serviceCom(db, 'recep');
  });

  // Semeia um doc da fila com posicaoEm explícito (passado), para ordenação
  // determinística.
  Future<void> semear(String id, String nome, DateTime posicao,
      {bool disponivel = true}) async {
    await db.collection('fila_atendimento').doc(id).set({
      'vendedorNome': nome,
      'disponivel': disponivel,
      'posicaoEm': Timestamp.fromDate(posicao),
    });
  }

  group('definirDisponibilidadeFila', () {
    test('disponível=true grava flag e posicaoEm', () async {
      await service.definirDisponibilidadeFila('v1', 'Vend 1',
          disponivel: true);
      final doc = await db.collection('fila_atendimento').doc('v1').get();
      expect(doc.data()?['disponivel'], true);
      expect(doc.data()?['posicaoEm'], isNotNull);
    });

    test('disponível=false desmarca a flag', () async {
      await service.definirDisponibilidadeFila('v1', 'Vend 1',
          disponivel: true);
      await service.definirDisponibilidadeFila('v1', 'Vend 1',
          disponivel: false);
      final doc = await db.collection('fila_atendimento').doc('v1').get();
      expect(doc.data()?['disponivel'], false);
    });
  });

  group('getFilaAtendimentoStream — ordenação', () {
    test('ordena por posicaoEm ascendente (mais antigo na frente)', () async {
      await semear('v2', 'Vend 2', DateTime(2026, 6, 18, 10, 5));
      await semear('v1', 'Vend 1', DateTime(2026, 6, 18, 10, 0));
      await semear('v3', 'Vend 3', DateTime(2026, 6, 18, 10, 10));

      final fila = await service.getFilaAtendimentoStream().first;
      expect(fila.map((f) => f.vendedorId), ['v1', 'v2', 'v3']);
    });
  });

  group('mandarParaFimDaFila', () {
    test('joga o vendedor para o fim (re-timestampa)', () async {
      await semear('v1', 'Vend 1', DateTime(2026, 6, 18, 10, 0));
      await semear('v2', 'Vend 2', DateTime(2026, 6, 18, 10, 5));

      // v1 estava na frente; após atender, vai pro fim.
      await service.mandarParaFimDaFila('v1');

      final fila = await service.getFilaAtendimentoStream().first;
      expect(fila.last.vendedorId, 'v1');
    });

    test('não cria doc para quem não está na fila', () async {
      await service.mandarParaFimDaFila('fantasma');
      final doc =
          await db.collection('fila_atendimento').doc('fantasma').get();
      expect(doc.exists, isFalse);
    });
  });

  group('trocarPosicaoFila', () {
    test('inverte a ordem entre dois vendedores', () async {
      await semear('v1', 'Vend 1', DateTime(2026, 6, 18, 10, 0));
      await semear('v2', 'Vend 2', DateTime(2026, 6, 18, 10, 5));

      await service.trocarPosicaoFila('v1', 'v2');

      final fila = await service.getFilaAtendimentoStream().first;
      expect(fila.map((f) => f.vendedorId), ['v2', 'v1']);
    });
  });
}
