import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/cliente_model.dart';
import 'package:crm_pessoal/services/firestore_service.dart';

/// Recepção — visibilidade dos atendimentos por perfil (ticket #43).
///
/// Regra de negócio:
/// - admin / super admin: veem TODOS os atendimentos, INCLUSIVE os excluídos
///   (soft-deleted), para auditar e restaurar.
/// - recepcao: vê todos os atendimentos, mas SEM os excluídos.
/// - vendedor / captador: vê apenas os seus, sem os excluídos.
void main() {
  FirestoreService serviceCom(FakeFirebaseFirestore db, String uid) =>
      FirestoreService(
        db: db,
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: uid, displayName: 'User'),
        ),
      );

  late FakeFirebaseFirestore db;

  Future<void> usuario(String uid, String perfil) =>
      db.collection('usuarios').doc(uid).set({'nome': uid, 'perfil': perfil});

  Future<void> atendimento(
    String id, {
    required String criadoPorId,
    bool deletado = false,
  }) =>
      db.collection('clientes').doc(id).set({
        'nome': id,
        'tipo': 'pf',
        'fase': 'atendimento',
        'criadoPorId': criadoPorId,
        'vendedorId': criadoPorId,
        'dataCadastro': Timestamp.fromDate(DateTime(2026, 6, 1)),
        'dataAtualizacao': Timestamp.fromDate(DateTime(2026, 6, 1)),
        'dataEntradaSala': Timestamp.fromDate(DateTime(2026, 6, 1)),
        if (deletado) 'deletado': true,
      });

  setUp(() async {
    db = FakeFirebaseFirestore();
    await usuario('adminUid', 'admin');
    await usuario('superUid', 'super admin');
    await usuario('recepUid', 'recepcao');
    await usuario('vendAUid', 'vendedor');
    await usuario('vendBUid', 'vendedor');

    await atendimento('ativoRecep', criadoPorId: 'recepUid');
    await atendimento('excluidoRecep', criadoPorId: 'recepUid', deletado: true);
    await atendimento('ativoVendA', criadoPorId: 'vendAUid');
    await atendimento('excluidoVendA', criadoPorId: 'vendAUid', deletado: true);
  });

  Set<String> idsDe(List<Cliente> cs) => cs.map((c) => c.id!).toSet();

  test('admin vê TODOS os atendimentos, inclusive os excluídos', () async {
    final cs = await serviceCom(db, 'adminUid').getClientesRecepcaoStream().first;
    expect(
      idsDe(cs),
      {'ativoRecep', 'excluidoRecep', 'ativoVendA', 'excluidoVendA'},
    );
  });

  test('super admin vê TODOS, inclusive os excluídos', () async {
    final cs = await serviceCom(db, 'superUid').getClientesRecepcaoStream().first;
    expect(
      idsDe(cs),
      {'ativoRecep', 'excluidoRecep', 'ativoVendA', 'excluidoVendA'},
    );
  });

  test('recepcao vê todos os atendimentos, mas NÃO os excluídos', () async {
    final cs = await serviceCom(db, 'recepUid').getClientesRecepcaoStream().first;
    expect(idsDe(cs), {'ativoRecep', 'ativoVendA'});
  });

  test('vendedor vê apenas os seus e sem excluídos', () async {
    final cs = await serviceCom(db, 'vendAUid').getClientesRecepcaoStream().first;
    expect(idsDe(cs), {'ativoVendA'});
  });

  test('restaurarCliente reverte o soft-delete (deletado = false)', () async {
    final service = serviceCom(db, 'adminUid');
    await service.restaurarCliente('excluidoRecep');

    final doc = await db.collection('clientes').doc('excluidoRecep').get();
    expect(doc.data()?['deletado'], false);

    // Após restaurar, a recepcao volta a enxergar o lead.
    final cs = await serviceCom(db, 'recepUid').getClientesRecepcaoStream().first;
    expect(idsDe(cs).contains('excluidoRecep'), isTrue);
  });
}
