import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/services/firestore_service.dart';

/// Metas múltiplas por usuário (mapa {tipoMeta: valorAlvo}).
void main() {
  late FakeFirebaseFirestore db;
  late FirestoreService service;

  setUp(() {
    db = FakeFirebaseFirestore();
    service =
        FirestoreService(db: db, auth: MockFirebaseAuth(signedIn: true));
  });

  group('FirestoreService — metas múltiplas', () {
    test('definirMetas grava várias metas e getMetas as retorna', () async {
      await db.collection('usuarios').doc('v1').set({'nome': 'V1'});

      await service.definirMetas('v1', {
        'valorVendido': 50000,
        'mensagensEnviadas': 300,
      });

      final metas = await service.getMetas('v1');
      expect(metas, {'valorVendido': 50000.0, 'mensagensEnviadas': 300.0});
    });

    test('definirMetas substitui o conjunto anterior (remove ausentes)',
        () async {
      await db.collection('usuarios').doc('v1').set({'nome': 'V1'});

      await service.definirMetas('v1', {'valorVendido': 50000, 'fechamentos': 5});
      await service.definirMetas('v1', {'fechamentos': 8});

      final metas = await service.getMetas('v1');
      expect(metas, {'fechamentos': 8.0});
    });

    test('mapa vazio remove todas as metas', () async {
      await db.collection('usuarios').doc('v1').set({'nome': 'V1'});
      await service.definirMetas('v1', {'fechamentos': 5});

      await service.definirMetas('v1', {});

      final metas = await service.getMetas('v1');
      expect(metas, isEmpty);
    });

    test('retrocompat: meta única antiga vira mapa de uma entrada', () async {
      await db.collection('usuarios').doc('v1').set({
        'nome': 'V1',
        'tipoMeta': 'valorVendido',
        'valorMeta': 12000,
      });

      final metas = await service.getMetas('v1');
      expect(metas, {'valorVendido': 12000.0});
    });

    test('retrocompat: metaMensal legado vira meta de fechamentos', () async {
      await db.collection('usuarios').doc('v1').set({
        'nome': 'V1',
        'metaMensal': 7,
      });

      final metas = await service.getMetas('v1');
      expect(metas, {'fechamentos': 7.0});
    });

    test('definirMetas limpa os campos legados de meta única', () async {
      await db.collection('usuarios').doc('v1').set({
        'nome': 'V1',
        'tipoMeta': 'fechamentos',
        'valorMeta': 3,
        'metaMensal': 3,
      });

      await service.definirMetas('v1', {'mensagensEnviadas': 100});

      final doc = await db.collection('usuarios').doc('v1').get();
      expect(doc.data()?['tipoMeta'], isNull);
      expect(doc.data()?['valorMeta'], isNull);
      expect(doc.data()?['metaMensal'], isNull);
      expect(doc.data()?['metas'], {'mensagensEnviadas': 100.0});
    });

    test('usuário sem meta retorna mapa vazio', () async {
      await db.collection('usuarios').doc('v1').set({'nome': 'V1'});
      expect(await service.getMetas('v1'), isEmpty);
    });
  });
}
