// lib/services/reynaldo_pdf.dart
//
// Gera um PDF PRETO E BRANCO da proposta de investimento para o Reynaldo,
// pensado para impressão e apresentação. Abre o diálogo nativo de
// impressão/download (Printing.layoutPdf).

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
  final double resort; // aporte do resort/mês
  final double resortSobra;
  final double vendaMes;
  final double entradaPct; // fração (0..1)
  final double vendaPrazo; // parcelas da venda
  final double entradaMes;
  final double parcelaSafra;
  final double poolMes;
  final double poolInicio;
  final double sharePct; // fração (0..1)
  final int? paybackMes;
  final double cumVendas; // total vindo das vendas até o payback
  final int anoInicio; // ano de início da projeção (inauguração)
  final int mesInicio; // mês de início (1..12)
  final List<(int, double, double)> marcos; // (mês, acumulado, % do aporte)

  const DadosReynaldo({
    required this.aporte,
    required this.base,
    required this.desistPct,
    required this.distPrazo,
    required this.totalDistrato,
    required this.distParcela,
    required this.resort,
    required this.resortSobra,
    required this.vendaMes,
    required this.entradaPct,
    required this.vendaPrazo,
    required this.entradaMes,
    required this.parcelaSafra,
    required this.poolMes,
    required this.poolInicio,
    required this.sharePct,
    required this.paybackMes,
    required this.cumVendas,
    required this.anoInicio,
    required this.mesInicio,
    required this.marcos,
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

  String get paybackData => paybackMes == null ? '' : dataDoMes(paybackMes!);
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

  static String _mesesTexto(int m) {
    final anos = m ~/ 12;
    final meses = m % 12;
    if (anos == 0) return '$meses ${meses == 1 ? 'mês' : 'meses'}';
    if (meses == 0) return '$anos ${anos == 1 ? 'ano' : 'anos'}';
    return '$anos ${anos == 1 ? 'ano' : 'anos'} e $meses '
        '${meses == 1 ? 'mês' : 'meses'}';
  }

  static Future<void> gerar(DadosReynaldo d) async {
    final doc = pw.Document(title: 'Proposta de Investimento — Villamor');
    doc.addPage(
      pw.Page(
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

  static pw.Widget _build(DadosReynaldo d) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
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

        // ── Destaque: payback ──
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _preto, width: 1.5),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('APORTE SOLICITADO',
                style: pw.TextStyle(fontSize: 10, color: _cinza, letterSpacing: 1)),
            pw.Text(_moeda.format(d.aporte),
                style: pw.TextStyle(
                    fontSize: 28, fontWeight: pw.FontWeight.bold, color: _preto)),
            pw.SizedBox(height: 8),
            pw.Text(
              d.paybackMes == null
                  ? 'Retorno projetado além do horizonte simulado.'
                  : 'Retorno total do aporte até ${d.paybackData} — '
                      '${_mesesTexto(d.paybackMes!)} (${d.paybackMes} meses).',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold, color: _preto),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
                'Início em ${d.dataDoMes(1)} (inauguração da multipropriedade). '
                'Devolução pelas vendas + 15% do pool de hospedagem.',
                style: pw.TextStyle(fontSize: 10, color: _cinza)),
          ]),
        ),
        pw.SizedBox(height: 14),

        pw.Text('Finalidade do aporte',
            style: pw.TextStyle(
                fontSize: 12, fontWeight: pw.FontWeight.bold, color: _preto)),
        pw.SizedBox(height: 3),
        pw.Text(
          'O aporte será investido unicamente na Villamor, para finalizar as '
          'obras e os novos apartamentos necessários à transição do resort para '
          'o hotel em operação. As desistências (distratos) e as demais contas '
          'são cobertas pelo aporte mensal do resort — o retorno do investidor '
          'vem das vendas e da taxa de 15% do pool.',
          style: pw.TextStyle(fontSize: 10.5, color: _preto, lineSpacing: 2),
        ),
        pw.SizedBox(height: 16),

        // ── Distratos + Vendas lado a lado ──
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: _bloco('Desistências (distratos)', [
              ('Valor pago em contratos ativos*', _moeda.format(d.base)),
              ('Desistência (${(d.desistPct * 100).toStringAsFixed(0)}%)',
                  _moeda.format(d.totalDistrato)),
              ('Parcela (${d.distPrazo.toStringAsFixed(0)}x)',
                  '${_moeda.format(d.distParcela)}/mês'),
              ('Aporte do resort/mês', _moeda.format(d.resort)),
              (d.resortSobra >= 0 ? 'Sobra para outras contas' : 'Falta',
                  '${_moeda.format(d.resortSobra)}/mês'),
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
              ('Caixa em regime pleno', '${_moeda.format(d.vendaMes)}/mês'),
              ('Início do pool (15%)', 'mês ${d.poolInicio.toStringAsFixed(0)}'),
            ]),
          ),
        ]),
        pw.SizedBox(height: 16),

        // ── Tabela de retorno ──
        pw.Text('Retorno acumulado ao investidor',
            style: pw.TextStyle(
                fontSize: 12, fontWeight: pw.FontWeight.bold, color: _preto)),
        pw.SizedBox(height: 6),
        _tabelaRetorno(d),
        pw.Spacer(),

        pw.Divider(color: _borda),
        pw.Text(
          '*Base: soma do valor já pago nos contratos ativos, excluídos os '
          'contratos de Matheus Camelo e do próprio Reynaldo. Valores '
          'projetados, sujeitos às condições reais de vendas, ocupação do pool '
          'e cronograma de obras.',
          style: pw.TextStyle(fontSize: 8.5, color: _cinza, lineSpacing: 1.5),
        ),
      ],
    );
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

  static pw.Widget _tabelaRetorno(DadosReynaldo d) {
    pw.Widget cel(String t, {bool cab = false, bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Text(t,
              style: pw.TextStyle(
                  fontSize: cab ? 9.5 : 10,
                  fontWeight:
                      cab || bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: cab ? _cinza : _preto)),
        );
    return pw.Table(
      border: pw.TableBorder.all(color: _borda),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.1),
        1: pw.FlexColumnWidth(0.7),
        2: pw.FlexColumnWidth(1.8),
        3: pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _fundoCab),
          children: [
            cel('Data', cab: true),
            cel('Mês', cab: true),
            cel('Acumulado devolvido', cab: true),
            cel('% do aporte', cab: true),
          ],
        ),
        for (final m in d.marcos)
          pw.TableRow(children: [
            cel(d.dataDoMes(m.$1), bold: m.$3 >= 100),
            cel('${m.$1}', bold: m.$3 >= 100),
            cel(_moeda.format(m.$2), bold: m.$3 >= 100),
            cel('${m.$3.toStringAsFixed(0)}%', bold: m.$3 >= 100),
          ]),
      ],
    );
  }
}
