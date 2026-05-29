import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/services/firestore_service.dart';

/// Regras que liberam `clientes` mas NEGAM escrita em `audit_log`, simulando
/// uma falha (regra de segurança/indisponibilidade) na trilha de auditoria.
const _regrasAuditLogIndisponivel = '''
service cloud.firestore {
  match /databases/{database}/documents {
    match /clientes/{id} {
      allow read, write: if true;
    }
    match /audit_log/{id} {
      allow read, write: if false;
    }
  }
}
''';

/// Risco #2 — soft-delete de cliente deve ser ATÔMICO.
///
/// Comportamento correto sob teste: se a gravação do audit_log falhar, o
/// cliente NÃO pode ficar marcado como deletado. Hoje o código faz dois awaits
/// separados (update no cliente, depois audit_log.add), então este teste fica
/// VERMELHO de propósito — é a guarda de regressão. Ele deve passar quando as
/// duas escritas virarem atômicas (WriteBatch/transação). Ver ticket #17.
void main() {
  group('FirestoreService.deletarCliente (atomicidade — risco #2)', () {
    test(
      'falha ao gravar audit_log NÃO pode deixar o cliente soft-deleted',
      () async {
        final db = FakeFirebaseFirestore(
          securityRules: _regrasAuditLogIndisponivel,
        );
        final service =
            FirestoreService(db: db, auth: MockFirebaseAuth(signedIn: true));

        await db.collection('clientes').doc('lead1').set({
          'nome': 'Cliente Teste',
          'deletado': false,
        });

        // A operação deve falhar, pois a auditoria (obrigatória) não pode ser gravada.
        await expectLater(
          service.deletarCliente('lead1'),
          throwsA(isA<Exception>()),
        );

        // Atomicidade: como a auditoria falhou, o cliente NÃO pode estar deletado.
        final doc = await db.collection('clientes').doc('lead1').get();
        expect(
          doc.data()?['deletado'],
          isNot(true),
          reason:
              'Cliente ficou soft-deleted sem registro de auditoria — escrita '
              'não atômica (risco #2). Corrigir com WriteBatch/transação.',
        );
      },
      tags: 'bug-aberto',
    );

    test('caminho feliz: cliente é marcado como deletado e audit_log é gravado',
        () async {
      final db = FakeFirebaseFirestore();
      final service =
          FirestoreService(db: db, auth: MockFirebaseAuth(signedIn: true));

      await db.collection('clientes').doc('lead2').set({
        'nome': 'Outro Cliente',
        'deletado': false,
      });

      await service.deletarCliente('lead2');

      final doc = await db.collection('clientes').doc('lead2').get();
      expect(doc.data()?['deletado'], isTrue);

      final logs = await db
          .collection('audit_log')
          .where('clienteId', isEqualTo: 'lead2')
          .get();
      expect(logs.docs, isNotEmpty);
    });
  });
}
