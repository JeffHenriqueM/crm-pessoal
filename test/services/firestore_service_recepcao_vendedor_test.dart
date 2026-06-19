import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/services/firestore_service.dart';

/// Guarda (lead "Osmar Quadros"): um vendedor deve enxergar, na Recepção, um
/// atendimento em que ele é o `vendedorId`, mesmo quando criador/captador/liner
/// são outras pessoas. `getClientesRecepcaoStream` combina
/// criadoPorId + captadorId + linerId + vendedorId.
void main() {
  FirestoreService serviceCom(FakeFirebaseFirestore db, String uid) =>
      FirestoreService(
        db: db,
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: uid, displayName: 'User'),
        ),
      );

  test(
    'vendedor vê atendimento em que é o vendedorId (sem ser criador/captador/liner)',
    () async {
      final db = FakeFirebaseFirestore();
      await db
          .collection('usuarios')
          .doc('marco')
          .set({'nome': 'Marco Ferreira', 'perfil': 'vendedor'});
      await db.collection('clientes').doc('osmar').set({
        'nome': 'Osmar Quadros',
        'tipo': 'pf',
        'fase': 'atendimento',
        'vendedorId': 'marco',
        'vendedorNome': 'Marco Ferreira',
        'criadoPorId': 'joelma',
        'captadorId': 'jennifer',
        'linerId': 'jennifer',
        'dataCadastro': Timestamp.fromDate(DateTime(2026, 6, 1)),
        'dataAtualizacao': Timestamp.fromDate(DateTime(2026, 6, 1)),
        'dataEntradaSala': Timestamp.fromDate(DateTime(2026, 6, 1)),
      });

      final marco = serviceCom(db, 'marco');
      final lista = await marco.getClientesRecepcaoStream().first;

      expect(lista.map((c) => c.nome), contains('Osmar Quadros'));
    },
  );
}
