import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/services/financeiro_excel_parser.dart';

/// Parser de moeda da planilha de baixas: deve tratar pt-BR e tolerar o
/// formato US (ponto decimal) sem inflar o valor em 100×.
void main() {
  group('FinanceiroExcelParser.parseMoeda', () {
    test('pt-BR com milhar e decimal', () {
      expect(FinanceiroExcelParser.parseMoeda('1.234,56'), 1234.56);
      expect(FinanceiroExcelParser.parseMoeda('R\$ 1.234.567,89'), 1234567.89);
    });

    test('só vírgula decimal', () {
      expect(FinanceiroExcelParser.parseMoeda('1234,56'), 1234.56);
      expect(FinanceiroExcelParser.parseMoeda('0,50'), 0.50);
    });

    test('só ponto como milhar (3 casas)', () {
      expect(FinanceiroExcelParser.parseMoeda('1.234'), 1234.0);
      expect(FinanceiroExcelParser.parseMoeda('1.234.567'), 1234567.0);
    });

    test('formato US (ponto decimal, 2 casas) NÃO infla 100×', () {
      expect(FinanceiroExcelParser.parseMoeda('1234.56'), 1234.56);
      expect(FinanceiroExcelParser.parseMoeda('99.90'), 99.90);
    });

    test('inteiro simples', () {
      expect(FinanceiroExcelParser.parseMoeda('500'), 500.0);
    });

    test('vazio/sem dígitos retorna null', () {
      expect(FinanceiroExcelParser.parseMoeda(''), isNull);
      expect(FinanceiroExcelParser.parseMoeda('R\$'), isNull);
    });
  });
}
