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

  group('FinanceiroExcelParser.resolverColunas', () {
    test('cabeçalho na ordem documentada', () {
      final cols = FinanceiroExcelParser.resolverColunas([
        'Cliente',
        'Tipo',
        'Documento do CAR',
        'Vencimento',
        'Valor pago parcela',
        'Data da baixa',
        'Data de crédito',
        'Status',
      ]);
      expect(cols['cliente'], 0);
      expect(cols['tipo'], 1);
      expect(cols['documentoCar'], 2);
      expect(cols['vencimento'], 3);
      expect(cols['valorPago'], 4);
      expect(cols['dataBaixa'], 5);
      expect(cols['dataCredito'], 6);
      expect(cols['status'], 7);
    });

    test('colunas fora de ordem são resolvidas pelo nome', () {
      final cols = FinanceiroExcelParser.resolverColunas([
        'Status',
        'Data de crédito',
        'Cliente',
        'Valor pago parcela',
        'Documento do CAR',
        'Tipo',
        'Vencimento',
        'Data da baixa',
      ]);
      expect(cols['status'], 0);
      expect(cols['dataCredito'], 1);
      expect(cols['cliente'], 2);
      expect(cols['valorPago'], 3);
      expect(cols['documentoCar'], 4);
      expect(cols['tipo'], 5);
      expect(cols['vencimento'], 6);
      expect(cols['dataBaixa'], 7);
    });

    test('cabeçalho irreconhecível cai na posição fixa documentada', () {
      final cols = FinanceiroExcelParser.resolverColunas(
        List<String?>.filled(8, null),
      );
      expect(cols['cliente'], 0);
      expect(cols['valorPago'], 4);
      expect(cols['status'], 7);
    });

    test('coluna extra no início desloca todas corretamente', () {
      final cols = FinanceiroExcelParser.resolverColunas([
        'ID',
        'Cliente',
        'Tipo',
        'Documento do CAR',
        'Vencimento',
        'Valor pago parcela',
        'Data da baixa',
        'Data de crédito',
        'Status',
      ]);
      expect(cols['cliente'], 1);
      expect(cols['valorPago'], 5);
      expect(cols['dataCredito'], 7);
      expect(cols['status'], 8);
    });
  });
}
