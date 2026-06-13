import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/services/firestore_service.dart';

/// Comportamento esperado da confirmação de presença na Festa dos Sócios:
/// gravar Sim/Não por quarto, ler de volta pelo stream, e limpar a resposta
/// (volta a "não perguntado") quando o valor é nulo.
void main() {
  FirestoreService serviceCom(FakeFirebaseFirestore db, String uid,
          {String nome = 'Recep'}) =>
      FirestoreService(
        db: db,
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: uid, displayName: nome),
        ),
      );

  late FakeFirebaseFirestore db;
  late FirestoreService service;

  setUp(() {
    db = FakeFirebaseFirestore();
    service = serviceCom(db, 'recep_a', nome: 'Recep A');
  });

  test('setPresencaFesta(true) grava confirmou=true e quem registrou', () async {
    await service.setPresencaFesta('101', true);
    final doc =
        await db.collection('festa_socios_presencas').doc('101').get();
    expect(doc.exists, isTrue);
    expect(doc.data()?['confirmou'], isTrue);
    expect(doc.data()?['registradoPorId'], 'recep_a');
  });

  test('setPresencaFesta(false) grava confirmou=false', () async {
    await service.setPresencaFesta('101', false);
    final doc =
        await db.collection('festa_socios_presencas').doc('101').get();
    expect(doc.data()?['confirmou'], isFalse);
  });

  test('setPresencaFesta(null) limpa a resposta (remove o doc)', () async {
    await service.setPresencaFesta('101', true);
    await service.setPresencaFesta('101', null);
    final doc =
        await db.collection('festa_socios_presencas').doc('101').get();
    expect(doc.exists, isFalse);
  });

  test('getPresencasFestaStream indexa por quarto e ignora ausentes', () async {
    await service.setPresencaFesta('101', true);
    await service.setPresencaFesta('202', false);
    final mapa = await service.getPresencasFestaStream().first;
    expect(mapa['101'], isTrue);
    expect(mapa['202'], isFalse);
    expect(mapa.containsKey('303'), isFalse);
  });
}
