import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/usuario_model.dart';

/// "Sem acesso" (acessoBloqueado): o usuário não loga, mas continua atribuível
/// a leads. Distinto de `ativo=false` (desativação completa).
void main() {
  group('Usuario.acessoBloqueado', () {
    test('default é false (retrocompat: docs antigos sem o campo)', () {
      final u = Usuario.fromMap({
        'nome': 'Maria',
        'email': 'maria@x.com',
        'perfil': 'vendedor',
        'ativo': true,
      }, 'u1');
      expect(u.acessoBloqueado, isFalse);
      expect(u.contabilizaEquipe, isTrue);
    });

    test('lê acessoBloqueado quando presente', () {
      final u = Usuario.fromMap({
        'nome': 'Jenny',
        'email': 'jenny@x.com',
        'perfil': 'vendedor',
        'ativo': true,
        'acessoBloqueado': true,
      }, 'u2');
      expect(u.acessoBloqueado, isTrue);
    });

    test('round-trip por toMap/fromMap', () {
      final u = Usuario(
        id: 'u3',
        nome: 'Fulana',
        email: 'f@x.com',
        perfil: 'captador',
        ativo: true,
        acessoBloqueado: true,
      );
      final lida = Usuario.fromMap(u.toMap(), 'u3');
      expect(lida.acessoBloqueado, isTrue);
      expect(lida.ativo, isTrue);
    });

    group('contabilizaEquipe (rankings/metas)', () {
      Usuario comFlags({required bool ativo, required bool bloqueado}) =>
          Usuario(
            id: 'x',
            nome: 'X',
            email: 'x@x.com',
            perfil: 'vendedor',
            ativo: ativo,
            acessoBloqueado: bloqueado,
          );

      test('ativo e com acesso: conta', () {
        expect(comFlags(ativo: true, bloqueado: false).contabilizaEquipe,
            isTrue);
      });
      test('ativo mas sem acesso: NÃO conta (sai das rankings/metas)', () {
        expect(comFlags(ativo: true, bloqueado: true).contabilizaEquipe,
            isFalse);
      });
      test('inativo: NÃO conta', () {
        expect(comFlags(ativo: false, bloqueado: false).contabilizaEquipe,
            isFalse);
      });
    });
  });
}
