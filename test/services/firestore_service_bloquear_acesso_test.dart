import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/services/firestore_service.dart';

/// Bloqueio de acesso (login) sem desativar o usuário: ele para de logar mas
/// continua atribuível a leads. `bloquearAcessoUsuario` só mexe no campo
/// `acessoBloqueado`, sem tocar em `ativo` nem em nada mais.
void main() {
  late FakeFirebaseFirestore db;
  late FirestoreService service;

  setUp(() async {
    db = FakeFirebaseFirestore();
    service = FirestoreService(
      db: db,
      auth: MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'admin', displayName: 'Admin'),
      ),
    );
    await db.collection('usuarios').doc('maria').set({
      'nome': 'Maria',
      'email': 'maria@x.com',
      'perfil': 'vendedor',
      'ativo': true,
    });
  });

  test('bloquear acesso grava acessoBloqueado=true e preserva ativo', () async {
    await service.bloquearAcessoUsuario(id: 'maria', bloqueado: true);

    final doc = await db.collection('usuarios').doc('maria').get();
    expect(doc.data()?['acessoBloqueado'], isTrue);
    // Segue ativo (continua atribuível a leads / nos dropdowns).
    expect(doc.data()?['ativo'], isTrue);
  });

  test('liberar acesso volta acessoBloqueado=false', () async {
    await service.bloquearAcessoUsuario(id: 'maria', bloqueado: true);
    await service.bloquearAcessoUsuario(id: 'maria', bloqueado: false);

    final doc = await db.collection('usuarios').doc('maria').get();
    expect(doc.data()?['acessoBloqueado'], isFalse);
  });

  group('isUsuarioAtivo (gate de acesso)', () {
    test('bloqueado retorna false', () async {
      await service.bloquearAcessoUsuario(id: 'maria', bloqueado: true);
      expect(await service.isUsuarioAtivo('maria'), isFalse);
    });

    test('ativo e sem bloqueio retorna true', () async {
      expect(await service.isUsuarioAtivo('maria'), isTrue);
    });

    test('usuário sem documento é considerado com acesso (fail-open)',
        () async {
      expect(await service.isUsuarioAtivo('inexistente'), isTrue);
    });
  });

  group('acessoDoUsuarioStream (derruba sessão ao vivo)', () {
    test('emite true enquanto liberado e false ao bloquear', () async {
      final emissoes = <bool>[];
      final sub =
          service.acessoDoUsuarioStream('maria').listen(emissoes.add);

      // primeira emissão: liberado
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(emissoes.last, isTrue);

      // gestor bloqueia com a pessoa logada
      await service.bloquearAcessoUsuario(id: 'maria', bloqueado: true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(emissoes.last, isFalse);

      await sub.cancel();
    });

    test('desativar o usuário (ativo=false) também emite false', () async {
      final emissoes = <bool>[];
      final sub =
          service.acessoDoUsuarioStream('maria').listen(emissoes.add);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await service.alterarStatusUsuario(id: 'maria', ativo: false);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(emissoes.last, isFalse);

      await sub.cancel();
    });
  });
}
