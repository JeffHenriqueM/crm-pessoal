import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm_pessoal/utils/moeda_input.dart';

/// Testes da máscara de moeda e parsing robusto (#51 — Joelma).
void main() {
  group('parseMoeda', () {
    test('aceita formato BR mascarado com milhar e decimais', () {
      expect(parseMoeda('1.234,56'), closeTo(1234.56, 1e-9));
      expect(parseMoeda('50.000,00'), closeTo(50000.0, 1e-9));
      expect(parseMoeda('1.000.000,99'), closeTo(1000000.99, 1e-9));
    });

    test('mantém compatibilidade com entradas simples (sem máscara)', () {
      expect(parseMoeda('1234.56'), closeTo(1234.56, 1e-9));
      expect(parseMoeda('1234,56'), closeTo(1234.56, 1e-9));
      expect(parseMoeda('1234'), closeTo(1234.0, 1e-9));
    });

    test('ignora símbolos e espaços', () {
      expect(parseMoeda('R\$ 2.500,00'), closeTo(2500.0, 1e-9));
    });

    test('string vazia ou inválida vira zero', () {
      expect(parseMoeda(''), 0);
      expect(parseMoeda('   '), 0);
      expect(parseMoeda('abc'), 0);
    });
  });

  group('formatMoeda', () {
    test('formata com separador de milhar e duas casas decimais', () {
      expect(formatMoeda(1234.5), '1.234,50');
      expect(formatMoeda(50000), '50.000,00');
      expect(formatMoeda(0), '0,00');
    });

    test('round-trip format → parse preserva o valor', () {
      for (final v in [0.0, 12.34, 1234.56, 50000.0, 1000000.99]) {
        expect(parseMoeda(formatMoeda(v)), closeTo(v, 1e-9));
      }
    });
  });

  group('MoedaInputFormatter (centavos)', () {
    final fmt = MoedaInputFormatter();

    TextEditingValue aplicar(String novo) => fmt.formatEditUpdate(
          const TextEditingValue(text: ''),
          TextEditingValue(
            text: novo,
            selection: TextSelection.collapsed(offset: novo.length),
          ),
        );

    test('digitação progressiva monta valor da direita para a esquerda', () {
      expect(aplicar('1').text, '0,01');
      expect(aplicar('12').text, '0,12');
      expect(aplicar('1234').text, '12,34');
      expect(aplicar('123456').text, '1.234,56');
    });

    test('campo vazio permanece vazio', () {
      expect(aplicar('').text, '');
    });

    test('descarta caracteres não numéricos já existentes', () {
      expect(aplicar('R\$ 1.234,56').text, '1.234,56');
    });

    test('cursor fica ao final do texto formatado', () {
      final r = aplicar('123456');
      expect(r.selection.baseOffset, r.text.length);
    });
  });
}
