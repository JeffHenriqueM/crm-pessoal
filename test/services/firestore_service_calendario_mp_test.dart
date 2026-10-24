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
        mockUser: MockUser(uid: 'user-jeff', displayName: 'Jefferson Henrique'),
      ),
    );
  });

  group('FirestoreService — Calendário Multipropriedade', () {
    test('getCalendarioMP lê cotas e ordena as semanas por data de entrada',
        () async {
      await db.collection('config').doc('calendario_ouro_domingo').set({
        'tier': 'ouro',
        'dia': 'domingo',
        'cotas': {
          '1': [
            // Fora de ordem de propósito: deve sair ordenado por entrada.
            {'a': 2027, 'e': '2027-08-15', 's': '2027-08-21', 't': 'Média', 'f': ''},
            {'a': 2027, 'e': '2027-05-09', 's': '2027-05-15', 't': 'Média', 'f': ''},
            {'a': 2027, 'e': '2027-12-26', 's': '2028-01-01', 't': 'Alta', 'f': 'Ano Novo'},
          ],
          '2': [
            {'a': 2027, 'e': '2027-01-03', 's': '2027-01-09', 't': 'Alta', 'f': ''},
          ],
        },
      });

      final cal = await service.getCalendarioMP('ouro', 'domingo');

      expect(cal.keys.toSet(), {1, 2});
      final c1 = cal[1]!;
      expect(c1.length, 3);
      expect(c1.first.entrada, '2027-05-09'); // menor data primeiro
      expect(c1.last.entrada, '2027-12-26');
      expect(c1.last.feriado, 'Ano Novo');
      expect(c1.last.tipo, 'Alta');
      expect(c1.last.temFeriado, isTrue);
      expect(c1.first.temFeriado, isFalse);
    });

    test('getCalendarioMP retorna vazio quando o documento não existe',
        () async {
      final cal = await service.getCalendarioMP('bronze', 'quinta');
      expect(cal, isEmpty);
    });
  });
}
