// lib/services/reynaldo_pdf.dart
//
// Gera um PDF PRETO E BRANCO da proposta de investimento para o Reynaldo,
// pensado para impressão e apresentação. Foco: mostrar mês a mês o retorno.
// Abre o diálogo nativo de impressão/download (Printing.layoutPdf).

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Dados já calculados da simulação (montados na aba Reynaldo).
class DadosReynaldo {
  final double aporte;
  final double base; // valor pago (ativos, excl. Matheus/Reynaldo)
  final double desistPct; // fração (0..1)
  final double distPrazo; // parcelas do distrato
  final double totalDistrato;
  final double distParcela;
  final double resort; // aporte do resort/mês (hoje)
  final double resortLiq; // resort após a desistência
  final double vendaMes;
  final double entradaPct; // fração (0..1)
  final double vendaPrazo; // parcelas da venda
  final double entradaMes;
  final double parcelaSafra;
  final double poolMes;
  final double poolInicio;
  final double sharePct; // fração das vendas que volta ao Reynaldo
  final int anoInicio;
  final int mesInicio; // 1..12
  final int horizonte; // meses mostrados no fluxo
  final int? paybackMes; // mês em que o acumulado atinge o aporte (referência)
  final double acumHorizonte; // total devolvido dentro do horizonte
  // (mês, recebimento operacional, retorno ao Reynaldo no mês, acumulado)
  final List<(int, double, double, double)> fluxo;

  const DadosReynaldo({
    required this.aporte,
    required this.base,
    required this.desistPct,
    required this.distPrazo,
    required this.totalDistrato,
    required this.distParcela,
    required this.resort,
    required this.resortLiq,
    required this.vendaMes,
    required this.entradaPct,
    required this.vendaPrazo,
    required this.entradaMes,
    required this.parcelaSafra,
    required this.poolMes,
    required this.poolInicio,
    required this.sharePct,
    required this.anoInicio,
    required this.mesInicio,
    required this.horizonte,
    required this.paybackMes,
    required this.acumHorizonte,
    required this.fluxo,
  });

  static const _abrevMes = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez'
  ];

  /// Rótulo "mmm/aaaa" do mês [m] da projeção (m = 1 → início).
  String dataDoMes(int m) {
    final dt = DateTime(anoInicio, mesInicio + (m - 1));
    return '${_abrevMes[dt.month - 1]}/${dt.year}';
  }
}

class ReynaldoPdf {
  static final _moeda =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ', decimalDigits: 0);
  static final _dataFmt = DateFormat('dd/MM/yyyy');

  // Paleta preto e branco.
  static const _preto = PdfColors.black;
  static const _cinza = PdfColors.grey700;
  static const _borda = PdfColors.grey400;
  static const _fundoCab = PdfColors.grey200;

  static Future<void> gerar(DadosReynaldo d) async {
    final doc = pw.Document(title: 'Proposta de Investimento — Villamor');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 44, vertical: 40),
        build: (ctx) => _build(d),
      ),
    );
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: 'proposta-investimento-villamor.pdf',
    );
  }

  static List<pw.Widget> _build(DadosReynaldo d) {
    final pctAcum =
        d.aporte > 0 ? (d.acumHorizonte / d.aporte * 100) : 0.0;
    final retMes1 = d.fluxo.isNotEmpty ? d.fluxo.first.$3 : 0.0;
    final retUlt = d.fluxo.isNotEmpty ? d.fluxo.last.$3 : 0.0;

    return [
      // ── Cabeçalho ──
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('PROPOSTA DE INVESTIMENTO',
                style: pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold, color: _preto)),
            pw.SizedBox(height: 2),
            pw.Text('Projeto Villamor — Transição para o Hotel',
                style: pw.TextStyle(fontSize: 11, color: _cinza)),
          ]),
          pw.Text(_dataFmt.format(DateTime.now()),
              style: pw.TextStyle(fontSize: 10, color: _cinza)),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Divider(color: _preto, thickness: 1.2),
      pw.SizedBox(height: 14),

      // ── Destaque ──
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _preto, width: 1.5)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('APORTE SOLICITADO',
              style: pw.TextStyle(fontSize: 10, color: _cinza, letterSpacing: 1)),
          pw.Text(_moeda.format(d.aporte),
              style: pw.TextStyle(
                  fontSize: 28, fontWeight: pw.FontWeight.bold, color: _preto)),
          pw.SizedBox(height: 8),
          pw.Text(
            'Retorno ao investidor mês a mês, começando em ${d.dataDoMes(1)} '
            '(inauguração da multipropriedade), por meio das vendas + 15% do pool.',
            style: pw.TextStyle(
                fontSize: 12, fontWeight: pw.FontWeight.bold, color: _preto),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Retorno no mês cresce de ${_moeda.format(retMes1)} (${d.dataDoMes(1)}) '
            'para ${_moeda.format(retUlt)} (${d.dataDoMes(d.horizonte)}). '
            'Acumulado no período: ${_moeda.format(d.acumHorizonte)} '
            '(${pctAcum.toStringAsFixed(0)}% do aporte).',
            style: pw.TextStyle(fontSize: 10, color: _cinza),
          ),
        ]),
      ),
      pw.SizedBox(height: 14),

      pw.Text('Finalidade do aporte',
          style: pw.TextStyle(
              fontSize: 12, fontWeight: pw.FontWeight.bold, color: _preto)),
      pw.SizedBox(height: 3),
      pw.Text(
        'O aporte será investido unicamente na Villamor, para finalizar as '
        'obras e os novos apartamentos necessários à transição do resort para o '
        'hotel em operação. As desistências reduzem o recebimento atual, que '
        'volta a crescer mês a mês com as novas vendas.',
        style: pw.TextStyle(fontSize: 10.5, color: _preto, lineSpacing: 2),
      ),
      pw.SizedBox(height: 16),

      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: _bloco('Desistências e recebimento', [
            ('Valor pago em contratos ativos*', _moeda.format(d.base)),
            ('Desistência (${(d.desistPct * 100).toStringAsFixed(0)}%)',
                _moeda.format(d.totalDistrato)),
            ('Parcela do distrato (${d.distPrazo.toStringAsFixed(0)}x)',
                '${_moeda.format(d.distParcela)}/mês'),
            ('Recebimento hoje', '${_moeda.format(d.resort)}/mês'),
            ('Recebimento após desistência',
                '${_moeda.format(d.resortLiq)}/mês'),
          ]),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _bloco('Vendas projetadas', [
            ('Vendas por mês', _moeda.format(d.vendaMes)),
            ('Entrada à vista (${(d.entradaPct * 100).toStringAsFixed(0)}%)',
                '${_moeda.format(d.entradaMes)}/mês'),
            ('Parcela por safra (${d.vendaPrazo.toStringAsFixed(0)}x)',
                '${_moeda.format(d.parcelaSafra)}/mês'),
            ('% das vendas ao investidor',
                '${(d.sharePct * 100).toStringAsFixed(0)}%'),
            ('Início do pool (15%)', 'mês ${d.poolInicio.toStringAsFixed(0)}'),
          ]),
        ),
      ]),
      pw.SizedBox(height: 16),

      pw.Text('Retorno mês a mês ao investidor',
          style: pw.TextStyle(
              fontSize: 12, fontWeight: pw.FontWeight.bold, color: _preto)),
      pw.SizedBox(height: 6),
      _tabelaFluxo(d),
      pw.SizedBox(height: 10),
      pw.Divider(color: _borda),
      pw.Text(
        '*Base: soma do valor já pago nos contratos ativos, excluídos os '
        'contratos de Matheus Camelo e do próprio Reynaldo. "Recebimento" = '
        'recebimento após a desistência + caixa das novas vendas no mês. '
        '"Retorno ao investidor" = % das vendas destinado a ele + 15% do pool. '
        'Valores projetados, sujeitos às condições reais de vendas, ocupação e '
        'cronograma de obras.',
        style: pw.TextStyle(fontSize: 8.5, color: _cinza, lineSpacing: 1.5),
      ),
    ];
  }

  static pw.Widget _bloco(String titulo, List<(String, String)> linhas) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _borda)),
      child: pw.Column(children: [
        pw.Container(
          width: double.infinity,
          color: _fundoCab,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: pw.Text(titulo,
              style: pw.TextStyle(
                  fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _preto)),
        ),
        for (var i = 0; i < linhas.length; i++)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: i == linhas.length - 1
                ? null
                : const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: _borda))),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                    child: pw.Text(linhas[i].$1,
                        style: pw.TextStyle(fontSize: 9.5, color: _cinza))),
                pw.SizedBox(width: 6),
                pw.Text(linhas[i].$2,
                    style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _preto)),
              ],
            ),
          ),
      ]),
    );
  }

  static pw.Widget _tabelaFluxo(DadosReynaldo d) {
    pw.Widget cel(String t, {bool cab = false, bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Text(t,
              style: pw.TextStyle(
                  fontSize: cab ? 9 : 9.5,
                  fontWeight:
                      cab || bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: cab ? _cinza : _preto)),
        );
    return pw.Table(
      border: pw.TableBorder.all(color: _borda),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.1),
        1: pw.FlexColumnWidth(1.6),
        2: pw.FlexColumnWidth(1.6),
        3: pw.FlexColumnWidth(1.6),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _fundoCab),
          children: [
            cel('Mês', cab: true),
            cel('Recebimento', cab: true),
            cel('Retorno ao investidor', cab: true),
            cel('Acumulado', cab: true),
          ],
        ),
        for (final f in d.fluxo)
          pw.TableRow(children: [
            cel(d.dataDoMes(f.$1)),
            cel(_moeda.format(f.$2)),
            cel(_moeda.format(f.$3)),
            cel(_moeda.format(f.$4)),
          ]),
      ],
    );
  }
}
