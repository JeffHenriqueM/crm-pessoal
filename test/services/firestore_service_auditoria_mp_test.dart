import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/services/firestore_service.dart';

FirestoreService _svc(FakeFirebaseFirestore db) => FirestoreService(
      db: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u')),
    );

void main() {
  group('auditarCalendarioMP', () {
    test('detecta duração ≠ 7, sobreposição e semanas/ano erradas', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('config').doc('calendario_ouro_domingo').set({
        'cotas': {
          // Cota 1: 4 semanas de 7 dias, datas distintas → OK.
          '1': [
            {'a': 2028, 'e': '2028-01-02', 's': '2028-01-09', 't': 'Alta', 'f': ''},
            {'a': 2028, 'e': '2028-02-06', 's': '2028-02-13', 't': 'Média', 'f': ''},
            {'a': 2028, 'e': '2028-03-05', 's': '2028-03-12', 't': 'Média', 'f': ''},
            {'a': 2028, 'e': '2028-04-02', 's': '2028-04-09', 't': 'Média', 'f': ''},
          ],
          // Cota 2: 1 semana de 6 dias, sobrepondo a cota 1 em 02/01.
          '2': [
            {'a': 2028, 'e': '2028-01-02', 's': '2028-01-08', 't': 'Alta', 'f': ''},
          ],
        },
      });
      final r = await _svc(db).auditarCalendarioMP();

      expect(r.tudoOk, isFalse);
      final cats = r.achados.map((a) => a.categoria).toSet();
      expect(cats, containsAll({'Duração', 'Encaixe', 'Semanas/ano'}));
      // Semanas/ano deve apontar a cota 2 (1 semana, esperado 4), não a cota 1.
      expect(
        r.achados.any((a) =>
            a.categoria == 'Semanas/ano' && a.descricao.contains('Cota 2')),
        isTrue,
      );
    });

    test('calendário correto não gera achados', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('config').doc('calendario_prata_domingo').set({
        'cotas': {
          '1': [
            {'a': 2028, 'e': '2028-01-02', 's': '2028-01-09', 't': 'Alta', 'f': ''},
            {'a': 2028, 'e': '2028-06-04', 's': '2028-06-11', 't': 'Média', 'f': ''},
          ],
        },
      });
      final r = await _svc(db).auditarCalendarioMP();
      expect(r.tudoOk, isTrue);
      expect(r.totalSemanas, 2);
    });

    test('cota reservada não é cobrada no nº de semanas/ano', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('config').doc('calendario_bronze_domingo').set({
        'cotas': {
          // Bronze reservada = 52; 1 semana/ano é o esperado p/ Bronze mesmo,
          // mas aqui testamos que mesmo com nº "errado" ela não é cobrada.
          '52': [
            {'a': 2028, 'e': '2028-01-02', 's': '2028-01-09', 't': 'Alta', 'f': ''},
            {'a': 2028, 'e': '2028-02-06', 's': '2028-02-13', 't': 'Alta', 'f': ''},
          ],
        },
      });
      final r = await _svc(db).auditarCalendarioMP();
      expect(
        r.achados.any((a) => a.categoria == 'Semanas/ano'),
        isFalse,
      );
    });
  });
}
