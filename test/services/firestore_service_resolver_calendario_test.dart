import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/contrato_model.dart';
import 'package:crm_pessoal/services/firestore_service.dart';

Contrato _contrato({
  String bloco = 'B (HERA)',
  String imovel = '101',
  String produto = 'LUXO PRATA 1° / 2° / 3º',
  String cota = 'Cota-01',
  String? codigo,
}) {
  return Contrato(
    localizador: 'loc-1',
    localizadorAtendimento: '',
    nomeComprador: 'Teste',
    bloco: bloco,
    imovel: imovel,
    produto: produto,
    cota: cota,
    codigoContrato: codigo,
    status: 'Ativo',
  );
}

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreService service;

  setUp(() async {
    db = FakeFirebaseFirestore();
    service = FirestoreService(
      db: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u')),
    );
    await db.collection('config').doc('mp_checkin').set({
      'blocos': {
        'B': {'101': 'segunda', '14': 'domingo'},
      },
    });
    await db.collection('config').doc('calendario_prata_segunda').set({
      'cotas': {
        '1': [
          {'a': 2027, 'e': '2027-01-04', 's': '2027-01-10', 't': 'Alta', 'f': ''},
          {'a': 2028, 'e': '2028-06-04', 's': '2028-06-10', 't': 'Média', 'f': ''},
        ],
      },
    });
    await db.collection('config').doc('calendario_prata_domingo').set({
      'cotas': {
        '1': [
          {'a': 2027, 'e': '2027-03-07', 's': '2027-03-13', 't': 'Média', 'f': ''},
        ],
      },
    });
  });

  group('resolverCalendarioContrato', () {
    test('resolve tier (produto), cota (campo) e dia (bloco+imóvel)', () async {
      final r = await service.resolverCalendarioContrato(_contrato());
      expect(r.ok, isTrue);
      expect(r.tier, 'prata');
      expect(r.dia, 'segunda');
      expect(r.cota, 1);
      expect(r.semanas.length, 2);
      expect(r.semanas.first.entrada, '2027-01-04');
    });

    test('normaliza imóvel com zero à esquerda ("014" = "14")', () async {
      final r = await service.resolverCalendarioContrato(_contrato(imovel: '014'));
      expect(r.ok, isTrue);
      expect(r.dia, 'domingo');
      expect(r.semanas.single.entrada, '2027-03-07');
    });

    test('tier do produto cobre OURO/PRATA/BRONZE', () {
      expect(FirestoreService.tierRodizioDeProduto('LUXO OURO T'), 'ouro');
      expect(FirestoreService.tierRodizioDeProduto('LUXO BRONZE T'), 'bronze');
      expect(FirestoreService.tierRodizioDeProduto('INTEGRAL'), isNull);
    });

    test('bloco não mapeado retorna erro com motivo', () async {
      final r = await service
          .resolverCalendarioContrato(_contrato(bloco: '2° PAVIMENTO'));
      expect(r.ok, isFalse);
      expect(r.motivo, contains('check-in'));
    });

    test('blocoKeyMP não confunde Bangalô com Bloco B', () {
      expect(FirestoreService.blocoKeyMP('B (HERA)'), 'B');
      expect(FirestoreService.blocoKeyMP('C (AFRODITE)'), 'C');
      expect(FirestoreService.blocoKeyMP('Bangalo'), isNull);
      expect(FirestoreService.blocoKeyMP('TÉRREO'), isNull);
    });

    test('número da cota cai para o código quando o campo não tem dígito',
        () async {
      final r = await service.resolverCalendarioContrato(
          _contrato(cota: 'Cota', codigo: 'LP-800-101/Cota-01'));
      expect(r.ok, isTrue);
      expect(r.cota, 1);
    });
  });
}
