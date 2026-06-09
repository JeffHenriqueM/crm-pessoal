import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/contrato_model.dart';
import 'package:crm_pessoal/models/interacao_model.dart';
import 'package:crm_pessoal/services/firestore_service.dart';

/// Meta de pós-venda: cada interação em um contrato marca o contrato como
/// "contatado no mês" (contador interacoesPorMes no doc do contrato).
void main() {
  late FakeFirebaseFirestore db;
  late FirestoreService service;

  setUp(() async {
    db = FakeFirebaseFirestore();
    service = FirestoreService(
      db: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'pv1')),
    );
    await db.collection('contratos').doc('LOC1').set({'nomeComprador': 'Fulano'});
    await db.collection('contratos').doc('LOC2').set({'nomeComprador': 'Beltrano'});
  });

  Interacao interacao() => Interacao(
        titulo: 'Contato',
        nota: 'Liguei',
        canal: Canal.ligacao,
        dataInteracao: DateTime.now(),
      );

  test('interação em contrato marca contatadoEsteMes', () async {
    await service.adicionarInteracaoContrato('LOC1', interacao());

    final contratos = await service.getContratos();
    final loc1 = contratos.firstWhere((c) => c.localizador == 'LOC1');
    final loc2 = contratos.firstWhere((c) => c.localizador == 'LOC2');

    expect(loc1.contatadoEsteMes, isTrue);
    expect(loc2.contatadoEsteMes, isFalse);
  });

  test('chave do contador é o mês corrente', () async {
    await service.adicionarInteracaoContrato('LOC1', interacao());

    final doc = await db.collection('contratos').doc('LOC1').get();
    final mapa = doc.data()?['interacoesPorMes'] as Map<String, dynamic>?;
    final chave = FirestoreService.chaveMesDe(DateTime.now());
    expect(mapa?[chave], 1);
  });

  test('getContratos retorna todos os contratos', () async {
    final contratos = await service.getContratos();
    expect(contratos.map((c) => c.localizador).toSet(), {'LOC1', 'LOC2'});
  });

  group('meta de assinaturas', () {
    test('passar para assinado conta a assinatura do usuário', () async {
      await service.atualizarStatusAssinatura(
          'LOC1', StatusAssinatura.assinado);

      final u = await service.getUsuario('pv1');
      expect(u?.assinaturasMesAtual, 1);
      expect(u?.assinaturasTotal, 1);
    });

    test('re-salvar como assinado NÃO conta de novo', () async {
      await service.atualizarStatusAssinatura(
          'LOC1', StatusAssinatura.assinado);
      await service.atualizarStatusAssinatura(
          'LOC1', StatusAssinatura.assinado);

      final u = await service.getUsuario('pv1');
      expect(u?.assinaturasTotal, 1);
    });

    test('mudar para emAndamento não conta assinatura', () async {
      await service.atualizarStatusAssinatura(
          'LOC1', StatusAssinatura.emAndamento);
      final u = await service.getUsuario('pv1');
      expect(u?.assinaturasTotal ?? 0, 0);
    });

    test('resgatado (grupo Formalizados) conta a formalização', () async {
      await service.atualizarStatusAssinatura(
          'LOC1', StatusAssinatura.resgatado);
      final u = await service.getUsuario('pv1');
      expect(u?.assinaturasTotal, 1);
    });

    test('projeto atualizado (grupo Formalizados) conta a formalização',
        () async {
      await service.atualizarStatusAssinatura(
          'LOC1', StatusAssinatura.projetoAtualizado);
      final u = await service.getUsuario('pv1');
      expect(u?.assinaturasTotal, 1);
    });

    test('mudar entre dois formalizados NÃO conta de novo', () async {
      await service.atualizarStatusAssinatura(
          'LOC1', StatusAssinatura.assinado);
      await service.atualizarStatusAssinatura(
          'LOC1', StatusAssinatura.resgatado);
      final u = await service.getUsuario('pv1');
      expect(u?.assinaturasTotal, 1);
    });

    test('em andamento → formalizado conta a formalização', () async {
      await service.atualizarStatusAssinatura(
          'LOC1', StatusAssinatura.atualizandoProjeto);
      await service.atualizarStatusAssinatura(
          'LOC1', StatusAssinatura.projetoAtualizado);
      final u = await service.getUsuario('pv1');
      expect(u?.assinaturasTotal, 1);
    });
  });

  group('meta de upgrades', () {
    test('registrar upgrade realizado conta e marca o contrato', () async {
      await service.registrarUpgradeRealizado('LOC1');

      final u = await service.getUsuario('pv1');
      expect(u?.upgradesMesAtual, 1);
      expect(u?.upgradesTotal, 1);

      final c = (await service.getContratos())
          .firstWhere((c) => c.localizador == 'LOC1');
      expect(c.upgradeRealizado, isTrue);
      expect(c.upgradeOferecido, isTrue); // realizar implica oferecido
    });

    test('registrar upgrade realizado é idempotente', () async {
      await service.registrarUpgradeRealizado('LOC1');
      await service.registrarUpgradeRealizado('LOC1');

      final u = await service.getUsuario('pv1');
      expect(u?.upgradesTotal, 1);
    });

    test('oferecer upgrade marca o contrato sem contar realizado', () async {
      await service.registrarUpgradeOferecido('LOC1');

      final c = (await service.getContratos())
          .firstWhere((c) => c.localizador == 'LOC1');
      expect(c.upgradeOferecido, isTrue);
      expect(c.upgradeRealizado, isFalse);

      final u = await service.getUsuario('pv1');
      expect(u?.upgradesTotal ?? 0, 0);
    });
  });
}
