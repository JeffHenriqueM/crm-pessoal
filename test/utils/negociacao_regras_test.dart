import 'package:flutter_test/flutter_test.dart';
import 'package:crm_pessoal/utils/negociacao_regras.dart';

/// Testes da regra de limite de parcelas (#52 — Joelma).
/// Diamante libera até 100x sem virar Especial; demais mantêm 80x.
void main() {
  group('limiteParcelasNormais', () {
    test('produto Diamante libera 100 parcelas', () {
      expect(limiteParcelasNormais('Cota Diamante'), 100);
      expect(limiteParcelasNormais('DIAMANTE Premium'), 100);
      expect(limiteParcelasNormais('plano diamante anual'), 100);
    });

    test('demais tiers mantêm o limite de 80', () {
      expect(limiteParcelasNormais('Cota Bronze'), 80);
      expect(limiteParcelasNormais('Cota Prata'), 80);
      expect(limiteParcelasNormais('Cota Ouro'), 80);
      expect(limiteParcelasNormais('Produto Avulso'), 80);
    });

    test('nome nulo ou vazio cai no limite padrão de 80', () {
      expect(limiteParcelasNormais(null), 80);
      expect(limiteParcelasNormais(''), 80);
    });

    test('90x: especial p/ não-Diamante, normal p/ Diamante', () {
      const parcelas = 90;
      expect(parcelas > limiteParcelasNormais('Cota Ouro'), isTrue,
          reason: '90 > 80 → deve exigir negociação especial');
      expect(parcelas > limiteParcelasNormais('Cota Diamante'), isFalse,
          reason: '90 <= 100 → Diamante não precisa ser especial');
    });
  });
}
