import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/contrato_model.dart';
import 'package:crm_pessoal/services/firestore_service.dart';

/// Pós-venda — camada de dados de Contrato (model + FirestoreService).
///
/// Cobre o round-trip do model, o upsert em lote e a atualização de status.
/// A guarda vermelha documenta o bug do `criadoEm` (ver ticket a abrir):
/// como `salvarContrato`/`salvarContratosLote` gravam `criadoEm:
/// serverTimestamp()` com merge em TODO upsert, reimportar o mesmo localizador
/// apaga a data de criação original.
FirestoreService _servico(FakeFirebaseFirestore db) =>
    FirestoreService(db: db, auth: MockFirebaseAuth(signedIn: true));

Contrato _contratoBase({
  String localizador = 'LOC1',
  String nome = 'Fulano de Tal',
  double valorAtrasado = 0,
  String statusFinanceiro = 'Em andamento',
}) {
  return Contrato(
    localizador: localizador,
    localizadorAtendimento: 'AT-$localizador',
    nomeComprador: nome,
    valorAtrasado: valorAtrasado,
    statusFinanceiro: statusFinanceiro,
    valorFinanciado: 1000,
  );
}

void main() {
  group('Contrato — round-trip e getters', () {
    test('toFirestore → fromFirestore preserva os campos principais', () async {
      final db = FakeFirebaseFirestore();
      final c = _contratoBase(nome: 'Maria', valorAtrasado: 250.5);

      await db.collection('contratos').doc(c.localizador).set(c.toFirestore());
      final doc = await db.collection('contratos').doc(c.localizador).get();
      final lido = Contrato.fromFirestore(doc);

      expect(lido.localizador, 'LOC1');
      expect(lido.nomeComprador, 'Maria');
      expect(lido.valorAtrasado, 250.5);
      expect(lido.valorFinanciado, 1000);
      expect(lido.statusAssinatura, StatusAssinatura.naoAssinado);
    });

    test('codigoContrato faz round-trip', () async {
      final db = FakeFirebaseFirestore();
      final c = Contrato(
        localizador: 'LOC9',
        localizadorAtendimento: '',
        nomeComprador: 'Zé',
        codigoContrato: 'LMP-1590-320/Cota-15',
      );
      await db.collection('contratos').doc(c.localizador).set(c.toFirestore());
      final lido = Contrato.fromFirestore(
          await db.collection('contratos').doc(c.localizador).get());
      expect(lido.codigoContrato, 'LMP-1590-320/Cota-15');
    });

    test('revertido e origemReversao fazem round-trip', () async {
      final db = FakeFirebaseFirestore();
      final c = Contrato(
        localizador: 'LOC7',
        localizadorAtendimento: '',
        nomeComprador: 'Rev',
        revertido: true,
        origemReversao: '199',
      );
      await db.collection('contratos').doc(c.localizador).set(c.toFirestore());
      final lido = Contrato.fromFirestore(
          await db.collection('contratos').doc(c.localizador).get());
      expect(lido.revertido, isTrue);
      expect(lido.origemReversao, '199');
    });

    test('precisaReajuste/motivoReajuste: round-trip e NÃO no toFirestore',
        () async {
      final db = FakeFirebaseFirestore();
      // Grava direto o doc com o alerta (anotação interna).
      await db.collection('contratos').doc('LOC8').set({
        'nomeComprador': 'Alerta',
        'precisaReajuste': true,
        'motivoReajuste': 'Ajustar status',
      });
      final lido = Contrato.fromFirestore(
          await db.collection('contratos').doc('LOC8').get());
      expect(lido.precisaReajuste, isTrue);
      expect(lido.motivoReajuste, 'Ajustar status');
      // Não é serializado (sobrevive ao re-import por merge).
      expect(lido.toFirestore().containsKey('precisaReajuste'), isFalse);
      expect(lido.toFirestore().containsKey('motivoReajuste'), isFalse);
    });

    test('toFirestore NÃO serializa statusAssinatura (preserva no re-import)',
        () {
      final c = Contrato(
        localizador: 'LOC1',
        localizadorAtendimento: '',
        nomeComprador: 'X',
        statusAssinatura: StatusAssinatura.assinado,
      );
      expect(c.toFirestore().containsKey('statusAssinatura'), isFalse);
    });

    test('temAtrasos e estaQuitado refletem os valores', () {
      expect(_contratoBase(valorAtrasado: 0).temAtrasos, isFalse);
      expect(_contratoBase(valorAtrasado: 10).temAtrasos, isTrue);
      expect(_contratoBase(statusFinanceiro: 'Em andamento').estaQuitado,
          isFalse);
      expect(_contratoBase(statusFinanceiro: 'Quitado').estaQuitado, isTrue);
      expect(_contratoBase(statusFinanceiro: 'quitado').estaQuitado, isTrue);
    });
  });

  group('FirestoreService — contratos', () {
    test('salvarContrato cria o doc usando o localizador como id', () async {
      final db = FakeFirebaseFirestore();
      await _servico(db).salvarContrato(_contratoBase(nome: 'João'));

      final doc = await db.collection('contratos').doc('LOC1').get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['nomeComprador'], 'João');
    });

    test('salvarContratosLote grava todos os contratos da lista', () async {
      final db = FakeFirebaseFirestore();
      final lista = [
        _contratoBase(localizador: 'A1', nome: 'Ana'),
        _contratoBase(localizador: 'B2', nome: 'Bruno'),
        _contratoBase(localizador: 'C3', nome: 'Carla'),
      ];

      await _servico(db).salvarContratosLote(lista);

      final snap = await db.collection('contratos').get();
      expect(snap.docs.map((d) => d.id), containsAll(['A1', 'B2', 'C3']));
    });

    test('atualizarStatusAssinatura altera apenas o status', () async {
      final db = FakeFirebaseFirestore();
      await _servico(db).salvarContrato(_contratoBase());

      await _servico(db)
          .atualizarStatusAssinatura('LOC1', StatusAssinatura.assinado);

      final doc = await db.collection('contratos').doc('LOC1').get();
      expect(doc.data()?['statusAssinatura'], 'assinado');
      expect(doc.data()?['nomeComprador'], 'Fulano de Tal');
    });

    test(
      'reimportar um contrato NÃO pode sobrescrever a data de criação',
      () async {
        final db = FakeFirebaseFirestore();
        // Contrato já existente, criado em uma data conhecida no passado.
        final criadoOriginal = Timestamp.fromDate(DateTime.utc(2020, 1, 1));
        await db.collection('contratos').doc('LOC1').set({
          'nomeComprador': 'Fulano de Tal',
          'criadoEm': criadoOriginal,
        });

        // Reimportação do mesmo localizador (merge).
        await _servico(db).salvarContrato(_contratoBase());

        final doc = await db.collection('contratos').doc('LOC1').get();
        expect(
          doc.data()?['criadoEm'],
          criadoOriginal,
          reason:
              'criadoEm foi reescrito no upsert — reimportar apaga a data de '
              'criação original. salvarContrato/salvarContratosLote gravam '
              'criadoEm: serverTimestamp() com merge em todo save.',
        );
      },
    );

    test(
      'reimportar um contrato preserva o statusAssinatura existente',
      () async {
        final db = FakeFirebaseFirestore();
        // Contrato já existe e foi marcado como assinado no banco.
        await _servico(db).salvarContrato(_contratoBase());
        await _servico(db)
            .atualizarStatusAssinatura('LOC1', StatusAssinatura.assinado);

        // Reimportação (a planilha não traz coluna de assinatura).
        await _servico(db).salvarContrato(_contratoBase());

        final doc = await db.collection('contratos').doc('LOC1').get();
        expect(doc.data()?['statusAssinatura'], 'assinado',
            reason:
                'toFirestore não deve gravar statusAssinatura no re-import.');
      },
    );
  });
}
