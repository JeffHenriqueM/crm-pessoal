import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/services/auth_service.dart';

/// Risco #5 — edge cases do campo `ativo` no login (AuthService.signIn).
///
/// Garantia central (green): usuário ativo entra; usuário desativado é
/// bloqueado e deslogado. Edge case de erro (red): se a verificação de `ativo`
/// falhar (Firestore indisponível), o signIn retorna mensagem de erro mas NÃO
/// desloga o usuário — estado inconsistente (fica autenticado). Ver ticket #5.
const _regrasUsuariosNegaLeitura = '''
service cloud.firestore {
  match /databases/{database}/documents {
    match /usuarios/{id} {
      allow read: if false;
      allow write: if true;
    }
  }
}
''';

void main() {
  group('AuthService.signIn — campo ativo (risco #5)', () {
    test('usuário ativo entra e permanece autenticado', () async {
      final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'u1'));
      final db = FakeFirebaseFirestore();
      await db.collection('usuarios').doc('u1').set({'ativo': true});
      final service = AuthService(auth: auth, db: db);

      final erro = await service.signIn('a@a.com', 'senha');

      expect(erro, isNull);
      expect(auth.currentUser, isNotNull);
    });

    test('usuário desativado é bloqueado e deslogado', () async {
      final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'u1'));
      final db = FakeFirebaseFirestore();
      await db.collection('usuarios').doc('u1').set({'ativo': false});
      final service = AuthService(auth: auth, db: db);

      final erro = await service.signIn('a@a.com', 'senha');

      expect(erro, contains('desativado'));
      expect(auth.currentUser, isNull,
          reason: 'Usuário desativado não pode permanecer autenticado.');
    });

    test(
      'falha ao verificar status NÃO pode deixar o usuário autenticado',
      () async {
        final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'u1'));
        final db = FakeFirebaseFirestore(
          securityRules: _regrasUsuariosNegaLeitura,
        );
        await db.collection('usuarios').doc('u1').set({'ativo': true});
        final service = AuthService(auth: auth, db: db);

        final erro = await service.signIn('a@a.com', 'senha');

        // Se o login reporta erro, o usuário não pode ter ficado logado.
        expect(erro, isNotNull);
        expect(auth.currentUser, isNull,
            reason:
                'Verificação de ativo falhou (Firestore indisponível) e o '
                'usuário ficou autenticado mesmo com signIn retornando erro — '
                'fail-open inconsistente (risco #5).');
      },
    );
  });
}
