import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/baixa_financeira_model.dart';
import 'package:crm_pessoal/models/contrato_model.dart';
import 'package:crm_pessoal/services/relatorio_recebimentos_export.dart';

/// Núcleo do relatório de recebimentos: o cruzamento
/// LOCALIZADOR → codigoContrato → baixas do mês.
void main() {
  Contrato contrato(String localizador, String codigo) => Contrato(
        localizador: localizador,
        localizadorAtendimento: '',
        codigoContrato: codigo,
        nomeComprador: 'Fulano $localizador',
      );

  BaixaFinanceira baixa(String documentoCar, double valor, String mesKey) =>
      BaixaFinanceira(
        cliente: 'X',
        tipo: '018 - PIX',
        documentoCar: documentoCar,
        vencimento: DateTime(2026, 1, 1),
        valorPago: valor,
        dataBaixa: DateTime(2026, 1, 1),
        dataCredito: DateTime(2026, 1, 1),
        status: 'Baixado',
        mesCreditoKey: mesKey,
        importadoEm: DateTime(2026, 1, 1),
        importadoPorId: 'x',
        importadoPorNome: 'X',
      );

  test('agrupa recebido por localizador e por mês (uma entrada por mês)', () {
    final contratos = [
      contrato('100', 'VLP-135-445/Cota-01'),
      contrato('101', 'VLP-136-448/Cota-06'),
      contrato('102', 'LP-137-717/Cota-01'),
    ];
    final baixas = [
      baixa('VLP-135-445/Cota-01', 1000, '2026-05'),
      baixa('VLP-135-445/Cota-01', 500, '2026-05'), // mesmo mês → soma
      baixa('VLP-135-445/Cota-01', 300, '2026-04'), // outro mês selecionado
      baixa('VLP-136-448/Cota-06', 700, '2026-05'),
      baixa('LP-137-717/Cota-01', 999, '2026-03'), // mês NÃO selecionado → fora
    ];

    final mapa = RelatorioRecebimentosExport.mapaRecebidoPorLocalizadorPorMes(
        contratos, baixas, ['2026-04', '2026-05']);

    expect(mapa['100'], {'2026-05': 1500, '2026-04': 300});
    expect(mapa['101'], {'2026-05': 700});
    // 102 só pagou em 2026-03 (não selecionado) → fora
    expect(mapa.containsKey('102'), isFalse);
  });

  test('rotuloMes formata yyyy-MM para Mmm/aaaa', () {
    expect(RelatorioRecebimentosExport.rotuloMes('2026-05'), 'Mai/2026');
    expect(RelatorioRecebimentosExport.rotuloMes('2026-01'), 'Jan/2026');
  });

  test('localizador sem código ou sem baixa não entra no mapa', () {
    final contratos = [
      contrato('200', ''), // sem código
      contrato('201', 'AAA-1-1/Cota-01'), // código sem baixa
    ];
    final baixas = [baixa('ZZZ-9-9/Cota-99', 100, '2026-05')];

    final mapa = RelatorioRecebimentosExport.mapaRecebidoPorLocalizadorPorMes(
        contratos, baixas, ['2026-05']);

    expect(mapa.isEmpty, isTrue);
  });
}
