import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/interacao_model.dart';
import 'package:crm_pessoal/services/firestore_service.dart';

/// Contador de interações por usuário (meta "mensagens enviadas").
///
/// Comportamento desejado: cada nova interação registrada por um usuário
/// incrementa o contador mensal no doc do próprio usuário (interacoesPorMes)
/// e o contador acumulado no cliente (interaction_count).
void main() {
  group('FirestoreService — contador de interações', () {
    late FakeFirebaseFirestore db;
    late FirestoreService service;

    setUp(() async {
      db = FakeFirebaseFirestore();
      service = FirestoreService(
        db: db,
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'vendedor_a', displayName: 'Vendedor A'),
        ),
      );
      await db.collection('usuarios').doc('vendedor_a').set({
        'nome': 'Vendedor A',
        'perfil': 'vendedor',
      });
      await db.collection('clientes').doc('lead1').set({
        'nome': 'Lead Teste',
        'fase': 'prospeccao',
      });
    });

    Interacao novaInteracao() => Interacao(
          titulo: 'Contato',
          nota: 'Liguei para o cliente',
          canal: Canal.ligacao,
          houveResposta: true,
          dataInteracao: DateTime.now(),
        );

    test('cada interação incrementa o contador mensal do usuário', () async {
      await service.adicionarInteracao('lead1', novaInteracao());
      await service.adicionarInteracao('lead1', novaInteracao());

      final total = await service.getInteracoesMesAtual('vendedor_a');
      expect(total, 2);
    });

    test('contador é gravado sob a chave do mês corrente', () async {
      await service.adicionarInteracao('lead1', novaInteracao());

      final doc = await db.collection('usuarios').doc('vendedor_a').get();
      final mapa = doc.data()?['interacoesPorMes'] as Map<String, dynamic>?;
      final chave = FirestoreService.chaveMesDe(DateTime.now());
      expect(mapa?[chave], 1);
    });

    test('interação também incrementa interaction_count no cliente', () async {
      await service.adicionarInteracao('lead1', novaInteracao());

      final doc = await db.collection('clientes').doc('lead1').get();
      expect(doc.data()?['interaction_count'], 1);
    });

    test('usuário sem interações no mês retorna 0', () async {
      final total = await service.getInteracoesMesAtual('vendedor_a');
      expect(total, 0);
    });
  });

  group('FirestoreService.getClientesCaptados', () {
    late FakeFirebaseFirestore db;
    late FirestoreService service;

    setUp(() async {
      db = FakeFirebaseFirestore();
      service = FirestoreService(
        db: db,
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'capt_a'),
        ),
      );
    });

    test('retorna apenas leads do captador e exclui deletados', () async {
      await db.collection('clientes').doc('c1').set(
          {'nome': 'Casal 1', 'fase': 'prospeccao', 'captadorId': 'capt_a'});
      await db.collection('clientes').doc('c2').set({
        'nome': 'Casal 2',
        'fase': 'fechado',
        'captadorId': 'capt_a',
        'deletado': true,
      });
      await db.collection('clientes').doc('c3').set(
          {'nome': 'Outro', 'fase': 'prospeccao', 'captadorId': 'capt_b'});

      final captados = await service.getClientesCaptados('capt_a');

      expect(captados.map((c) => c.id), ['c1']);
    });
  });
}
