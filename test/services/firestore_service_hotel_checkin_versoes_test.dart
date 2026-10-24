import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/versao_preco_hotel.dart';
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
        mockUser: MockUser(uid: 'user-jeff', displayName: 'Jefferson Henrique'),
      ),
    );
  });

  group('FirestoreService — Hotel: Check-in por apartamento', () {
    test('getCheckinHotel retorna apto 141 como sexta por padrão', () async {
      final checkins = await service.getCheckinHotel();
      expect(checkins['141'], 'sexta');
    });

    test('setCheckinHotel define dia de check-in para apartamento', () async {
      await service.setCheckinHotel('101', 'quinta');
      await service.setCheckinHotel('102', 'domingo');

      final checkins = await service.getCheckinHotel();
      expect(checkins['101'], 'quinta');
      expect(checkins['102'], 'domingo');
      expect(checkins['141'], 'sexta'); // 141 permanece sexta
    });

    test('setCheckinHotel com null limpa o check-in do apartamento', () async {
      await service.setCheckinHotel('105', 'segunda');
      var checkins = await service.getCheckinHotel();
      expect(checkins['105'], 'segunda');

      await service.setCheckinHotel('105', null);
      checkins = await service.getCheckinHotel();
      expect(checkins.containsKey('105'), isFalse);
    });

    test('setCheckinHotelEmLote define check-in para múltiplos apartamentos', () async {
      await service.setCheckinHotelEmLote(['201', '202', '203'], 'sabado');

      final checkins = await service.getCheckinHotel();
      expect(checkins['201'], 'sabado');
      expect(checkins['202'], 'sabado');
      expect(checkins['203'], 'sabado');
    });
  });

  group('FirestoreService — Hotel: Versões da tabela de preços', () {
    test('getVersoesPrecosHotel gera versão inicial Versão Jeff se coleção estiver vazia', () async {
      final versoes = await service.getVersoesPrecosHotel();
      expect(versoes, isNotEmpty);
      expect(versoes.first.id, 'versao_jeff');
      expect(versoes.first.nome, 'Versão Jeff');
      expect(versoes.first.isPadrao, isTrue);
    });

    test('salvarVersaoPrecoHotel e deletarVersaoPrecoHotel', () async {
      // Cria versão inicial
      await service.getVersoesPrecosHotel();

      final nova = VersaoPrecoHotel(
        id: 'versao_carlos',
        nome: 'Versão Carlos',
        criadoPorId: 'user-carlos',
        criadoPorNome: 'Carlos',
        criadoEm: DateTime.now(),
        atualizadoEm: DateTime.now(),
        precos: {'Bangalô|ouro': 120000.0},
        isPadrao: false,
      );

      await service.salvarVersaoPrecoHotel(nova);

      var versoes = await service.getVersoesPrecosHotel();
      expect(versoes.length, 2);
      expect(versoes.any((v) => v.id == 'versao_carlos'), isTrue);

      await service.deletarVersaoPrecoHotel('versao_carlos');
      versoes = await service.getVersoesPrecosHotel();
      expect(versoes.length, 1);
      expect(versoes.any((v) => v.id == 'versao_carlos'), isFalse);
    });
  });
}
