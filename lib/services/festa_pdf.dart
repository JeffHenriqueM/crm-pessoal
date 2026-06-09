// lib/services/festa_pdf.dart
//
// Gera um PDF da ocupação da Festa dos Sócios (quem ficou em cada quarto),
// para o setor de reservas lançar no outro sistema. Reflete o estado ATUAL
// (mapa-base + movimentações/associações manuais) + a lista de espera.
// Abre o diálogo nativo de impressão/salvar do navegador.

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

typedef LinhaQuarto = ({
  String numero,
  String ocupante,
  String? tier,
  int? pct,
  String? origem,
  String? obs,
});
typedef GrupoCategoria = ({String categoria, List<LinhaQuarto> linhas});
typedef LinhaEspera = ({
  String categoria,
  String ocupante,
  String? tier,
  int? pct,
  String? origem,
  String? quartoDesejado,
});

class FestaPdf {
  static final _dataHoraFmt = DateFormat('dd/MM/yyyy HH:mm');

  static const _roxo = PdfColor(0.20, 0.13, 0.42); // indigo900-ish
  static const _cinzaTexto = PdfColors.grey700;
  static const _divisor = PdfColors.grey300;
  static const _fundoCab = PdfColor(0.93, 0.91, 0.98);
  static const _ambar = PdfColor(0.98, 0.75, 0.14);

  /// [agora] é injetável para testes; em produção passe DateTime.now().
  static Future<void> gerar({
    required String periodo,
    required List<GrupoCategoria> grupos,
    required List<LinhaEspera> espera,
    required DateTime agora,
  }) async {
    final doc = pw.Document(title: 'Ocupação — Festa dos Sócios');

    pw.MemoryImage? logo;
    try {
      final bytes = await rootBundle.load('assets/images/logo.png');
      logo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      logo = null;
    }

    final totalQuartos =
        grupos.fold<int>(0, (s, g) => s + g.linhas.length);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.SizedBox()
            : pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text('Festa dos Sócios — ocupação',
                    style:
                        pw.TextStyle(fontSize: 9, color: _cinzaTexto))),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text('Página ${ctx.pageNumber}/${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 9, color: _cinzaTexto)),
        ),
        build: (ctx) => [
          _cabecalho(logo, periodo, totalQuartos, espera.length, agora),
          pw.SizedBox(height: 14),
          for (final g in grupos) ...[
            _tituloCategoria(g.categoria, g.linhas.length),
            _tabela(g.linhas),
            pw.SizedBox(height: 12),
          ],
          if (espera.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            _tituloEspera(espera.length),
            _tabelaEspera(espera),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: 'festa-socios-ocupacao.pdf',
    );
  }

  static pw.Widget _cabecalho(pw.MemoryImage? logo, String periodo,
      int totalQuartos, int totalEspera, DateTime agora) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logo != null) ...[
              pw.SizedBox(height: 40, width: 40, child: pw.Image(logo)),
              pw.SizedBox(width: 12),
            ],
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Festa dos Sócios — Ocupação dos quartos',
                      style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: _roxo)),
                  pw.SizedBox(height: 2),
                  pw.Text('Período de utilização: $periodo',
                      style:
                          pw.TextStyle(fontSize: 11, color: _cinzaTexto)),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('$totalQuartos quartos ocupados',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
                if (totalEspera > 0)
                  pw.Text('$totalEspera em lista de espera',
                      style:
                          pw.TextStyle(fontSize: 10, color: _cinzaTexto)),
                pw.Text('Emitido em ${_dataHoraFmt.format(agora)}',
                    style: pw.TextStyle(fontSize: 9, color: _cinzaTexto)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: _divisor, height: 1),
      ],
    );
  }

  static pw.Widget _tituloCategoria(String cat, int n) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        margin: const pw.EdgeInsets.only(bottom: 4),
        decoration: const pw.BoxDecoration(color: _fundoCab),
        child: pw.Text('$cat  ·  $n',
            style: pw.TextStyle(
                fontSize: 12, fontWeight: pw.FontWeight.bold, color: _roxo)),
      );

  static pw.Widget _tabela(List<LinhaQuarto> linhas) {
    return pw.Table(
      border: pw.TableBorder.symmetric(
          inside: const pw.BorderSide(color: _divisor, width: .5)),
      columnWidths: const {
        0: pw.FixedColumnWidth(42),
        1: pw.FlexColumnWidth(1.3),
        2: pw.FixedColumnWidth(80),
        3: pw.FixedColumnWidth(52),
        4: pw.FlexColumnWidth(1.2),
      },
      children: [
        _linhaCab(['Quarto', 'Hóspede', 'Cota / %', 'Origem', 'Obs.']),
        for (final l in linhas)
          pw.TableRow(children: [
            _cel(l.numero, bold: true),
            _cel(l.ocupante),
            _cel(l.tier == null
                ? '—'
                : '${l.tier!.toUpperCase()}${l.pct != null ? ' · ${l.pct}%' : ''}'),
            _cel(l.origem != null ? 'veio do ${l.origem}' : '—'),
            _cel((l.obs ?? '').isEmpty ? '—' : l.obs!),
          ]),
      ],
    );
  }

  static pw.Widget _tituloEspera(int n) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        margin: const pw.EdgeInsets.only(bottom: 4),
        decoration: const pw.BoxDecoration(color: _ambar),
        child: pw.Text('Lista de espera (aguardando vaga)  ·  $n',
            style: pw.TextStyle(
                fontSize: 12, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _tabelaEspera(List<LinhaEspera> espera) {
    return pw.Table(
      border: pw.TableBorder.symmetric(
          inside: const pw.BorderSide(color: _divisor, width: .5)),
      columnWidths: const {
        0: pw.FixedColumnWidth(100),
        1: pw.FlexColumnWidth(),
        2: pw.FixedColumnWidth(82),
        3: pw.FixedColumnWidth(62),
        4: pw.FixedColumnWidth(62),
      },
      children: [
        _linhaCab(
            ['Categoria alvo', 'Hóspede', 'Cota / %', 'Saiu de', 'Desejado']),
        for (final e in espera)
          pw.TableRow(children: [
            _cel(e.categoria, bold: true),
            _cel(e.ocupante),
            _cel(e.tier == null
                ? '—'
                : '${e.tier!.toUpperCase()}${e.pct != null ? ' · ${e.pct}%' : ''}'),
            _cel(e.origem != null ? 'quarto ${e.origem}' : '—'),
            _cel(e.quartoDesejado ?? '—', bold: e.quartoDesejado != null),
          ]),
      ],
    );
  }

  static pw.TableRow _linhaCab(List<String> textos) => pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
        children: textos
            .map((t) => pw.Padding(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.Text(t,
                      style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _cinzaTexto)),
                ))
            .toList(),
      );

  static pw.Widget _cel(String txt, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Text(txt,
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );
}
