import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/services/firestore_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreService service;

  setUp(() async {
    db = FakeFirebaseFirestore();
    service = FirestoreService(
      db: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u')),
    );
    service.invalidarCacheContratos(); // cache de contratos é estático

    await db.collection('config').doc('mp_checkin').set({
      'blocos': {
        'B': {'101': 'segunda'},
      },
    });
    await db.collection('config').doc('calendario_prata_segunda').set({
      'cotas': {
        '1': [
          {'a': 2027, 'e': '2027-01-04', 's': '2027-01-10', 't': 'Alta', 'f': ''},
          {'a': 2028, 'e': '2028-06-05', 's': '2028-06-11', 't': 'Média', 'f': ''},
        ],
      },
    });

    // Ativo resolvível (bloco B, imóvel 101, prata cota 1).
    await db.collection('contratos').doc('L1').set({
      'localizador': 'L1',
      'nomeComprador': 'Alice',
      'bloco': 'B (HERA)',
      'imovel': '101',
      'produto': 'LUXO PRATA T',
      'cota': 'Cota-01',
      'status': 'Ativo',
    });
    // Ativo não resolvível (bloco legado sem check-in).
    await db.collection('contratos').doc('L2').set({
      'localizador': 'L2',
      'nomeComprador': 'Bruno',
      'bloco': '2° PAVIMENTO',
      'imovel': '210',
      'produto': 'LUXO PRATA T',
      'cota': 'Cota-02',
      'status': 'Ativo',
    });
    // Cancelado: ignorado (não é ativo).
    await db.collection('contratos').doc('L3').set({
      'localizador': 'L3',
      'nomeComprador': 'Carla',
      'bloco': 'B (HERA)',
      'imovel': '101',
      'produto': 'LUXO PRATA T',
      'cota': 'Cota-01',
      'status': 'Cancelado',
    });
  });

  group('montarOcupacaoMP', () {
    test('agrega entradas/saídas dos ativos resolvíveis e conta o resto',
        () async {
      final o = await service.montarOcupacaoMP();

      expect(o.ativos, 2); // L1 e L2 (L3 é cancelado)
      expect(o.naoResolvidos, 1); // L2 (bloco não mapeado)

      final entra = o.entradasEm(DateTime(2027, 1, 4));
      expect(entra.length, 1);
      expect(entra.single.nome, 'Alice');
      expect(entra.single.tier, 'prata');
      expect(entra.single.cota, 1);

      final sai = o.saidasEm(DateTime(2027, 1, 10));
      expect(sai.length, 1);
      expect(sai.single.nome, 'Alice');

      // 2ª semana (2028) também indexada.
      expect(o.entradasEm(DateTime(2028, 6, 5)).length, 1);

      // Carla (cancelada) não entra em nenhum dia.
      expect(o.entradasPorDia.values.expand((e) => e).any((e) => e.nome == 'Carla'),
          isFalse);
    });
  });
}
