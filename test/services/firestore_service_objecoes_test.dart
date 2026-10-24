import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/services/firestore_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreService service;

  setUp(() {
    db = FakeFirebaseFirestore();
    service = FirestoreService(
      db: db,
      auth: MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user-admin', displayName: 'Admin Teste'),
      ),
    );
  });

  group('FirestoreService — Transição: objeções e respostas personalizadas', () {
    test('retorna lista vazia quando documento ainda não existe', () async {
      final lista = await service.getObjecoesTransicao();
      expect(lista, isEmpty);
    });

    test('salva nova objeção com pergunta, resposta e autor', () async {
      await service.salvarObjecaoTransicao(
        pergunta: 'E se a entrega do resort atrasar mais 3 anos?',
        resposta:
            'A troca para o hotel elimina 100% desse risco, pois o hotel já funciona.',
      );

      final lista = await service.getObjecoesTransicao();
      expect(lista.length, 1);
      final item = lista.first;
      expect(item['pergunta'],
          'E se a entrega do resort atrasar mais 3 anos?');
      expect(item['resposta'],
          'A troca para o hotel elimina 100% desse risco, pois o hotel já funciona.');
      expect(item['id'], isNotEmpty);
      expect(item['criadoPorNome'], 'Admin Teste');
    });

    test('atualiza objeção existente quando id é informado', () async {
      await service.salvarObjecaoTransicao(
        id: 'obj-123',
        pergunta: 'Pergunta original',
        resposta: 'Resposta original',
      );

      var lista = await service.getObjecoesTransicao();
      expect(lista.length, 1);
      expect(lista.first['pergunta'], 'Pergunta original');

      // Atualiza
      await service.salvarObjecaoTransicao(
        id: 'obj-123',
        pergunta: 'Pergunta editada',
        resposta: 'Resposta revisada pela equipe',
      );

      lista = await service.getObjecoesTransicao();
      expect(lista.length, 1);
      expect(lista.first['id'], 'obj-123');
      expect(lista.first['pergunta'], 'Pergunta editada');
      expect(lista.first['resposta'], 'Resposta revisada pela equipe');
    });

    test('remove objeção pelo id', () async {
      await service.salvarObjecaoTransicao(
        id: 'obj-1',
        pergunta: 'Pergunta 1',
        resposta: 'Resposta 1',
      );
      await service.salvarObjecaoTransicao(
        id: 'obj-2',
        pergunta: 'Pergunta 2',
        resposta: 'Resposta 2',
      );

      var lista = await service.getObjecoesTransicao();
      expect(lista.length, 2);

      await service.removerObjecaoTransicao('obj-1');

      lista = await service.getObjecoesTransicao();
      expect(lista.length, 1);
      expect(lista.first['id'], 'obj-2');
    });
  });
}
