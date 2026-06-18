import 'package:flutter_test/flutter_test.dart';
import 'package:crm_pessoal/utils/perfis.dart';

/// Regra do ticket #60: rankings de venda contam SOMENTE vendedores e
/// captadores. ehPerfilVendas é a guarda dessa regra.
void main() {
  group('ehPerfilVendas', () {
    test('vendedor e captador contam', () {
      expect(ehPerfilVendas('vendedor'), isTrue);
      expect(ehPerfilVendas('captador'), isTrue);
    });

    test('demais perfis NÃO contam', () {
      for (final p in [
        'admin',
        'super admin',
        'financeiro',
        'pós-venda',
        'recepcao',
        'reserva',
      ]) {
        expect(ehPerfilVendas(p), isFalse, reason: '$p não é força de venda');
      }
    });

    test('null não conta', () {
      expect(ehPerfilVendas(null), isFalse);
    });
  });
}
