import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/interacao_model.dart';
import 'package:crm_pessoal/services/firestore_service.dart';

/// Sugestão de próximo contato (texto) registrada junto com a interação.
///
/// Comportamento esperado:
/// - a sugestão fica gravada NA interação (vira histórico na timeline);
/// - a mais recente vira o "próximo passo atual" do lead (campo no cliente);
/// - uma interação SEM sugestão não apaga a sugestão anterior do lead.
void main() {
  group('FirestoreService.adicionarInteracao — sugestão de próximo contato', () {
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

    Interacao interacao({String? sugestao}) => Interacao(
          nota: 'Conversa registrada',
          canal: Canal.whatsapp,
          houveResposta: false,
          dataInteracao: DateTime.now(),
          sugestaoProximoContato: sugestao,
        );

    test('grava a sugestão na própria interação', () async {
      await service.adicionarInteracao(
        'lead1',
        interacao(sugestao: 'Oferecer condição especial de entrada'),
      );

      final snap = await db
          .collection('clientes')
          .doc('lead1')
          .collection('interacoes')
          .get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['sugestaoProximoContato'],
          'Oferecer condição especial de entrada');
    });

    test('a sugestão vira o próximo passo atual do lead', () async {
      await service.adicionarInteracao(
        'lead1',
        interacao(sugestao: 'Ligar falando do financiamento'),
      );

      final doc = await db.collection('clientes').doc('lead1').get();
      expect(doc.data()?['sugestaoProximoContato'],
          'Ligar falando do financiamento');
    });

    test('a sugestão mais recente substitui a anterior no lead', () async {
      await service.adicionarInteracao('lead1', interacao(sugestao: 'Primeira'));
      await service.adicionarInteracao('lead1', interacao(sugestao: 'Segunda'));

      final doc = await db.collection('clientes').doc('lead1').get();
      expect(doc.data()?['sugestaoProximoContato'], 'Segunda');
    });

    test('interação SEM sugestão não apaga a sugestão anterior do lead',
        () async {
      await service.adicionarInteracao(
          'lead1', interacao(sugestao: 'Enviar proposta revisada'));
      await service.adicionarInteracao('lead1', interacao()); // sem sugestão

      final doc = await db.collection('clientes').doc('lead1').get();
      expect(doc.data()?['sugestaoProximoContato'], 'Enviar proposta revisada');
      // A interação foi registrada normalmente.
      expect(doc.data()?['interaction_count'], 2);
    });

    test('sugestão em branco não vira campo no lead nem na interação', () async {
      await service.adicionarInteracao('lead1', interacao(sugestao: ''));

      final doc = await db.collection('clientes').doc('lead1').get();
      expect(doc.data()?.containsKey('sugestaoProximoContato'), isFalse);

      final snap = await db
          .collection('clientes')
          .doc('lead1')
          .collection('interacoes')
          .get();
      expect(snap.docs.first.data().containsKey('sugestaoProximoContato'),
          isFalse);
    });
  });
}
