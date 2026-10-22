import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/versao_preco_hotel.dart';

void main() {
  group('VersaoPrecoHotel Model', () {
    test('criação e serialização toFirestore', () {
      final now = DateTime(2026, 10, 22, 10, 30);
      final versao = VersaoPrecoHotel(
        id: 'v1',
        nome: 'Tabela Jeff',
        criadoPorId: 'user123',
        criadoPorNome: 'Jeff',
        criadoEm: now,
        atualizadoEm: now,
        precos: {'Standard|ouro': 50000.0, 'Luxo|prata': 75000.0},
        isPadrao: true,
      );

      final map = versao.toFirestore();
      expect(map['nome'], 'Tabela Jeff');
      expect(map['criadoPorId'], 'user123');
      expect(map['criadoPorNome'], 'Jeff');
      expect(map['isPadrao'], isTrue);
      expect(map['precos'], {'Standard|ouro': 50000.0, 'Luxo|prata': 75000.0});
    });

    test('desserialização fromFirestore via FakeCloudFirestore DocumentSnapshot', () async {
      final db = FakeFirebaseFirestore();
      final docRef = db.collection('hotel_precos_versoes').doc('v2');
      final now = DateTime(2026, 10, 22, 12, 0);

      await docRef.set({
        'nome': 'Versão Verão',
        'criadoPorId': 'user456',
        'criadoPorNome': 'Ana',
        'criadoEm': now,
        'atualizadoEm': now,
        'precos': {'Master|ouro': 90000.0},
        'isPadrao': false,
      });

      final snap = await docRef.get();
      final versao = VersaoPrecoHotel.fromFirestore(snap);

      expect(versao.id, 'v2');
      expect(versao.nome, 'Versão Verão');
      expect(versao.criadoPorId, 'user456');
      expect(versao.criadoPorNome, 'Ana');
      expect(versao.isPadrao, isFalse);
      expect(versao.precos['Master|ouro'], 90000.0);
    });

    test('copyWith preserva campos e altera especificados', () {
      final now = DateTime(2026, 10, 22);
      final v1 = VersaoPrecoHotel(
        id: 'v1',
        nome: 'Original',
        criadoPorId: 'u1',
        criadoPorNome: 'Jeff',
        criadoEm: now,
        atualizadoEm: now,
        precos: {'A|b': 100.0},
        isPadrao: false,
      );

      final v2 = v1.copyWith(
        nome: 'Duplicata',
        isPadrao: true,
        precos: {'A|b': 200.0},
      );

      expect(v2.id, 'v1');
      expect(v2.nome, 'Duplicata');
      expect(v2.isPadrao, isTrue);
      expect(v2.precos['A|b'], 200.0);
      expect(v2.criadoPorId, 'u1');
    });
  });
}
