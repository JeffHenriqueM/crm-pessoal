import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Gera um PDF formatado com roteiro de argumentos, perguntas e respostas/objeções
/// da transição para impressão ou download.
class ArgumentosPdf {
  static final _dataFmt = DateFormat('dd/MM/yyyy HH:mm');

  static Future<void> gerar({
    required List<String> porqueTrocar,
    required List<String> porqueMesmoValor,
    required List<(String, String)> objecoes,
    String? tituloExtra,
  }) async {
    final doc = pw.Document(
      title: 'Roteiro de Transição e Objeções — Hotel Villamor',
      author: 'CRM Villamor',
    );

    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {
      // Sem logo se não carregar
    }

    final agora = DateTime.now();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        header: (ctx) {
          if (ctx.pageNumber == 1) return pw.SizedBox.shrink();
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 8),
            margin: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Roteiro de Abordagem e Objeções — Transição Hotel Villamor',
                  style: const pw.TextStyle(
                    fontSize: 8.5,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  _dataFmt.format(agora),
                  style: const pw.TextStyle(
                    fontSize: 8.5,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          );
        },
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Hotel Villamor • Guia Comercial de Apoio ao Vendedor',
                style: const pw.TextStyle(
                    fontSize: 8, color: PdfColors.grey600),
              ),
              pw.Text(
                'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
                style: const pw.TextStyle(
                    fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
        build: (ctx) => [
          _cabecalho(logoImage, agora, tituloExtra),
          pw.SizedBox(height: 14),

          // Seção 1: Por que fazer a troca
          _secao(
            numero: '1',
            titulo: 'POR QUE FAZER A TROCA',
            subtitulo: 'Argumentos fundamentais de antecipação e eliminação de risco',
            itens: porqueTrocar,
            cor: PdfColors.blue800,
            fundo: PdfColors.blue50,
          ),
          pw.SizedBox(height: 14),

          // Seção 2: Por que o valor continua o mesmo
          _secao(
            numero: '2',
            titulo: 'POR QUE O VALOR CONTINUA O MESMO',
            subtitulo: 'Segurança contratual, equivalência de ativo e preservação patrimonial',
            itens: porqueMesmoValor,
            cor: PdfColors.teal800,
            fundo: PdfColors.teal50,
          ),
          pw.SizedBox(height: 18),

          // Cabeçalho da Seção 3: Objeções e Perguntas
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            decoration: pw.BoxDecoration(
              color: PdfColors.orange50,
              border: pw.Border.all(color: PdfColors.orange400, width: 0.8),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              children: [
                pw.Text(
                  '3. OBJEÇÕES DOS CLIENTES E COMO RESPONDER',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.orange900,
                  ),
                ),
                pw.Spacer(),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border.all(color: PdfColors.orange300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    '${objecoes.length} mapeadas',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.orange900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),

          // Lista de Objeções (Perguntas e Respostas)
          for (var i = 0; i < objecoes.length; i++) ...[
            _blocoObjecao(objecoes[i].$1, objecoes[i].$2, i + 1),
            pw.SizedBox(height: 8),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: 'argumentos-transicao-hotel-villamor.pdf',
    );
  }

  static pw.Widget _cabecalho(
    pw.MemoryImage? logo,
    DateTime agora,
    String? tituloExtra,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logo != null) ...[
            pw.SizedBox(height: 38, width: 38, child: pw.Image(logo)),
            pw.SizedBox(width: 12),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'HOTEL VILLAMOR — ROTEIRO DE TRANSIÇÃO',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900,
                    letterSpacing: 0.3,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  tituloExtra ??
                      'Guia de abordagem, argumentos-chave e respostas estruturadas para perguntas e objeções',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Emissão: ${_dataFmt.format(agora)}',
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                'Material de Uso Interno',
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _secao({
    required String numero,
    required String titulo,
    required String subtitulo,
    required List<String> itens,
    required PdfColor cor,
    required PdfColor fundo,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: fundo,
              borderRadius: const pw.BorderRadius.vertical(
                top: pw.Radius.circular(5),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Text(
                  '$numero. $titulo',
                  style: pw.TextStyle(
                    fontSize: 10.5,
                    fontWeight: pw.FontWeight.bold,
                    color: cor,
                  ),
                ),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < itens.length; i++) ...[
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        margin: const pw.EdgeInsets.only(top: 4, right: 6),
                        width: 4,
                        height: 4,
                        decoration: pw.BoxDecoration(
                          color: cor,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          itens[i],
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.black,
                            lineSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (i < itens.length - 1) pw.SizedBox(height: 5),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _blocoObjecao(
    String pergunta,
    String resposta,
    int indice,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.7),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Pergunta / Objeção
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.vertical(
                top: pw.Radius.circular(4.5),
              ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '#$indice  ',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.orange900,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    pergunta,
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Resposta sugerida
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(10, 6, 10, 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Resposta: ',
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    resposta,
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfColors.black,
                      lineSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
