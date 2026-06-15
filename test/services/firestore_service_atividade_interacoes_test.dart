import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/interacao_model.dart';
import 'package:crm_pessoal/services/firestore_service.dart';

/// getAtividadeInteracoesStream alimenta o relatório do dashboard.
/// Regras do que entra na contagem:
///  - só interações de LEADS (clientes/*/interacoes), nunca de contratos;
///  - eventos de sistema (canal 'sistema') não contam como mensagem;
///  - com autorId (perfil vendedor), só conta o que ele registrou;
///  - carrega o clienteId para permitir contar clientes distintos.
void main() {
  late FakeFirebaseFirestore db;
  late FirestoreService service;

  final recente = DateTime.now().subtract(const Duration(days: 2));

  Future<void> seedInteracao(
    String clienteId, {
    required Canal canal,
    required String autorId,
    DateTime? data,
  }) async {
    await db
        .collection('clientes')
        .doc(clienteId)
        .collection('interacoes')
        .add(Interacao(
          nota: 'msg',
          dataInteracao: data ?? recente,
          canal: canal,
        ).toFirestore()
          ..['autorId'] = autorId);
  }

  setUp(() {
    db = FakeFirebaseFirestore();
    service = FirestoreService(
      db: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1')),
    );
  });

  test('conta interações de leads, ignora contrato e eventos de sistema',
      () async {
    await seedInteracao('c1', canal: Canal.whatsapp, autorId: 'u1');
    await seedInteracao('c1', canal: Canal.ligacao, autorId: 'u2');
    await seedInteracao('c2', canal: Canal.whatsapp, autorId: 'u2');
    // Sistema: não conta.
    await seedInteracao('c2', canal: Canal.sistema, autorId: 'u2');
    // Interação de contrato: não entra no collection-group de leads.
    await db.collection('contratos').doc('LOC1').collection('interacoes').add(
        Interacao(nota: 'x', dataInteracao: recente, canal: Canal.whatsapp)
            .toFirestore());

    final lista = await service.getAtividadeInteracoesStream().first;

    expect(lista.length, 3); // 3 de lead (whatsapp/ligacao/whatsapp), sem sistema/contrato
    expect(lista.map((a) => a.clienteId).toSet(), {'c1', 'c2'});
    expect(lista.every((a) => a.canal != Canal.sistema), isTrue);
  });

  test('autorId filtra para a atividade do vendedor', () async {
    await seedInteracao('c1', canal: Canal.whatsapp, autorId: 'u1');
    await seedInteracao('c2', canal: Canal.whatsapp, autorId: 'u2');
    await seedInteracao('c3', canal: Canal.ligacao, autorId: 'u1');

    final lista =
        await service.getAtividadeInteracoesStream(autorId: 'u1').first;

    expect(lista.length, 2);
    expect(lista.map((a) => a.clienteId).toSet(), {'c1', 'c3'});
    expect(lista.every((a) => a.autorId == 'u1'), isTrue);
  });

  test('houveResposta é refletido no registro', () async {
    await db.collection('clientes').doc('c1').collection('interacoes').add(
        Interacao(
          nota: 'm',
          dataInteracao: recente,
          canal: Canal.whatsapp,
          houveResposta: true,
        ).toFirestore()
          ..['autorId'] = 'u1');

    final lista = await service.getAtividadeInteracoesStream().first;
    expect(lista.single.houveResposta, isTrue);
  });
}
