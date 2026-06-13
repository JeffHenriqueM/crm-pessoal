import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/interacao_model.dart';
import 'package:crm_pessoal/services/firestore_service.dart';

/// Registrar a resposta do cliente depois: atualizarInteracao (cliente) e
/// atualizarInteracaoContrato (contrato) gravam o texto e marcam houveResposta.
void main() {
  late FakeFirebaseFirestore db;
  late FirestoreService service;

  setUp(() {
    db = FakeFirebaseFirestore();
    service = FirestoreService(
      db: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1')),
    );
  });

  test('atualizarInteracaoContrato grava resposta e houveResposta', () async {
    final ref =
        db.collection('contratos').doc('LOC1').collection('interacoes');
    final doc = await ref.add(Interacao(
      nota: 'Mandei proposta',
      dataInteracao: DateTime(2026, 6, 10),
      houveResposta: false,
    ).toFirestore());

    final atual = Interacao.fromFirestore(await doc.get());
    final nova = atual.copyWith(
      respostaCliente: 'Topo, pode emitir',
      respostaEm: DateTime(2026, 6, 13),
      houveResposta: true,
    );
    await service.atualizarInteracaoContrato('LOC1', nova);

    final lido = await doc.get();
    expect(lido.data()?['respostaCliente'], 'Topo, pode emitir');
    expect(lido.data()?['houveResposta'], isTrue);
  });

  test('atualizarInteracao (cliente) grava resposta e houveResposta', () async {
    final ref =
        db.collection('clientes').doc('C1').collection('interacoes');
    final doc = await ref.add(Interacao(
      nota: 'Liguei, sem retorno',
      dataInteracao: DateTime(2026, 6, 10),
      houveResposta: false,
    ).toFirestore());

    final atual = Interacao.fromFirestore(await doc.get());
    await service.atualizarInteracao(
      'C1',
      atual.copyWith(
        respostaCliente: 'Retornou: quer agendar',
        respostaEm: DateTime(2026, 6, 13),
        houveResposta: true,
      ),
    );

    final lido = await doc.get();
    expect(lido.data()?['respostaCliente'], 'Retornou: quer agendar');
    expect(lido.data()?['houveResposta'], isTrue);
  });
}
