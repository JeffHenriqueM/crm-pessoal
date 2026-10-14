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

  group('FirestoreService — Hotel: argumentos de transição por sócio', () {
    test('retorna mapa vazio quando documento ainda não existe', () async {
      final mapa = await service.getArgumentosSociosHotel();
      expect(mapa, isEmpty);
    });

    test('salva e recupera argumentos de um sócio', () async {
      await service.salvarArgumentoSocioHotel(
        'JOÃO DA SILVA',
        'Cliente focado em rentabilidade. Apresentar números do Pool.',
      );

      final mapa = await service.getArgumentosSociosHotel();
      expect(mapa.containsKey('JOÃO DA SILVA'), isTrue);
      expect(
        mapa['JOÃO DA SILVA']?['argumentos'],
        'Cliente focado em rentabilidade. Apresentar números do Pool.',
      );
      expect(mapa['JOÃO DA SILVA']?['nome'], 'JOÃO DA SILVA');
    });

    test('removerArgumentoSocioHotel apaga o sócio do mapa', () async {
      await service.salvarArgumentoSocioHotel(
        'MARIA SOUZA',
        'Priorizar antecipação de uso do hotel.',
      );

      var mapa = await service.getArgumentosSociosHotel();
      expect(mapa.containsKey('MARIA SOUZA'), isTrue);

      await service.removerArgumentoSocioHotel('MARIA SOUZA');

      mapa = await service.getArgumentosSociosHotel();
      expect(mapa.containsKey('MARIA SOUZA'), isFalse);
    });

    test('salvarArgumentoSocioHotel com texto em branco remove o sócio', () async {
      await service.salvarArgumentoSocioHotel(
        'CARLOS EDUARDO',
        'Argumento inicial',
      );

      var mapa = await service.getArgumentosSociosHotel();
      expect(mapa.containsKey('CARLOS EDUARDO'), isTrue);

      await service.salvarArgumentoSocioHotel('CARLOS EDUARDO', '   ');

      mapa = await service.getArgumentosSociosHotel();
      expect(mapa.containsKey('CARLOS EDUARDO'), isFalse);
    });

    test('permite múltiplos sócios sem sobrescrever os demais', () async {
      await service.salvarArgumentoSocioHotel('SÓCIO 1', 'Argumento 1');
      await service.salvarArgumentoSocioHotel('SÓCIO 2', 'Argumento 2');

      final mapa = await service.getArgumentosSociosHotel();
      expect(mapa.length, 2);
      expect(mapa['SÓCIO 1']?['argumentos'], 'Argumento 1');
      expect(mapa['SÓCIO 2']?['argumentos'], 'Argumento 2');

      // Atualiza sócio 1
      await service.salvarArgumentoSocioHotel('SÓCIO 1', 'Argumento 1 Atualizado');

      final mapaAtualizado = await service.getArgumentosSociosHotel();
      expect(mapaAtualizado['SÓCIO 1']?['argumentos'], 'Argumento 1 Atualizado');
      expect(mapaAtualizado['SÓCIO 2']?['argumentos'], 'Argumento 2');
    });
  });
}
