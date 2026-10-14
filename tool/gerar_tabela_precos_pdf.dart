// tool/gerar_tabela_precos_pdf.dart
// ignore_for_file: avoid_print
//
// Script para gerar os PDFs da Tabela de Preços do Hotel Villamor:
// 1. Tabela Preenchida (valores oficiais em alta nitidez)
// 2. Tabela Em Branco (espaçosa para preenchimento manual à mão)
// 3. Tabela Completa (arquivo único com as duas versões)
//
// Otimizado para impressão Preto e Branco / Escala de Cinza em folha A4.

import 'dart:io';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ── Dados da Tabela ──────────────────────────────────────────────────────────

class LinhaPreco {
  final String categoria;
  final String? integral;
  final String? ouro;
  final String? titanio;
  final String? prata;
  final String? bronze;

  const LinhaPreco({
    required this.categoria,
    this.integral,
    this.ouro,
    this.titanio,
    this.prata,
    this.bronze,
  });
}

const List<LinhaPreco> dadosTabela = [
  LinhaPreco(
    categoria: 'LUXO',
    integral: 'R\$ 800.000',
    ouro: 'R\$ 90.000',
    titanio: 'R\$ 55.000',
    prata: 'R\$ 55.000',
    bronze: 'R\$ 33.000',
  ),
  LinhaPreco(
    categoria: 'STUDIO ROOM',
    integral: 'R\$ 1.300.000',
    ouro: 'R\$ 116.000',
    titanio: 'R\$ 67.000',
    prata: 'R\$ 67.000',
    bronze: 'R\$ 40.000',
  ),
  LinhaPreco(
    categoria: 'DUPLEX',
    integral: 'R\$ 1.650.000',
    ouro: 'R\$ 130.000',
    titanio: null,
    prata: 'R\$ 70.000',
    bronze: 'R\$ 44.100',
  ),
  LinhaPreco(
    categoria: 'TRIPLO',
    integral: 'R\$ 1.530.000',
    ouro: 'R\$ 121.000',
    titanio: null,
    prata: 'R\$ 66.000',
    bronze: 'R\$ 42.000',
  ),
  LinhaPreco(
    categoria: 'MASTER',
    integral: 'R\$ 1.530.000',
    ouro: 'R\$ 116.000',
    titanio: null,
    prata: 'R\$ 61.000',
    bronze: 'R\$ 37.000',
  ),
  LinhaPreco(
    categoria: 'COMFORT TÉRREO',
    integral: 'R\$ 1.530.000',
    ouro: 'R\$ 116.000',
    titanio: null,
    prata: 'R\$ 61.000',
    bronze: 'R\$ 37.000',
  ),
  LinhaPreco(
    categoria: 'COMFORT 1° ANDAR',
    integral: 'R\$ 1.530.000',
    ouro: 'R\$ 116.000',
    titanio: null,
    prata: 'R\$ 61.000',
    bronze: 'R\$ 37.000',
  ),
  LinhaPreco(
    categoria: 'COMFORT 2° ANDAR',
    integral: 'R\$ 1.530.000',
    ouro: 'R\$ 116.000',
    titanio: null,
    prata: 'R\$ 61.000',
    bronze: 'R\$ 37.000',
  ),
  LinhaPreco(
    categoria: 'SUÍTE VILLAMOR',
    integral: 'R\$ 2.000.000',
    ouro: 'R\$ 140.000',
    titanio: null,
    prata: 'R\$ 77.000',
    bronze: 'R\$ 45.000',
  ),
  LinhaPreco(
    categoria: 'SUÍTE DUPLEX',
    integral: 'R\$ 2.000.000',
    ouro: 'R\$ 140.000',
    titanio: null,
    prata: 'R\$ 77.000',
    bronze: 'R\$ 45.000',
  ),
  LinhaPreco(
    categoria: 'VILLAMOR (BANHEIRA)',
    integral: 'R\$ 2.000.000',
    ouro: 'R\$ 171.000',
    titanio: null,
    prata: 'R\$ 88.000',
    bronze: 'R\$ 51.000',
  ),
  LinhaPreco(
    categoria: 'BÂNGALO',
    integral: 'R\$ 3.500.000',
    ouro: null,
    titanio: null,
    prata: null,
    bronze: null,
  ),
];

void main() async {
  print('Iniciando geração dos PDFs da Tabela de Preços...');

  // 1. Carregar Fontes TrueType (Arial)
  pw.ThemeData temaPdf;
  const pathArial = '/System/Library/Fonts/Supplemental/Arial.ttf';
  const pathArialBold = '/System/Library/Fonts/Supplemental/Arial Bold.ttf';
  const pathArialItalic = '/System/Library/Fonts/Supplemental/Arial Italic.ttf';
  const pathArialBoldItalic = '/System/Library/Fonts/Supplemental/Arial Bold Italic.ttf';

  if (File(pathArial).existsSync() && File(pathArialBold).existsSync()) {
    final fontBase = pw.Font.ttf(File(pathArial).readAsBytesSync().buffer.asByteData());
    final fontBold = pw.Font.ttf(File(pathArialBold).readAsBytesSync().buffer.asByteData());
    final fontItalic = File(pathArialItalic).existsSync()
        ? pw.Font.ttf(File(pathArialItalic).readAsBytesSync().buffer.asByteData())
        : fontBase;
    final fontBoldItalic = File(pathArialBoldItalic).existsSync()
        ? pw.Font.ttf(File(pathArialBoldItalic).readAsBytesSync().buffer.asByteData())
        : fontBold;

    temaPdf = pw.ThemeData.withFont(
      base: fontBase,
      bold: fontBold,
      italic: fontItalic,
      boldItalic: fontBoldItalic,
    );
  } else {
    temaPdf = pw.ThemeData();
  }

  // 2. Carregar Logo (preferência pela versão monocromática de alto contraste)
  pw.MemoryImage? logoImage;
  final logoBwFile = File('assets/images/logo_bw.png');
  final logoFile = File('assets/images/logo.png');
  if (logoBwFile.existsSync()) {
    logoImage = pw.MemoryImage(logoBwFile.readAsBytesSync());
  } else if (logoFile.existsSync()) {
    logoImage = pw.MemoryImage(logoFile.readAsBytesSync());
  }

  // 3. Gerar PDF Preenchido
  final pdfPreenchido = pw.Document(
    title: 'Tabela de Preços - Hotel Villamor (Preenchida)',
    author: 'Villamor CRM',
    theme: temaPdf,
  );
  pdfPreenchido.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 22),
      build: (ctx) => _buildTabelaPage(
        ctx,
        logo: logoImage,
        emBranco: false,
      ),
    ),
  );
  final filePreenchido = File('tabela_precos_hotel_preenchida.pdf');
  await filePreenchido.writeAsBytes(await pdfPreenchido.save());
  print('PDF Preenchido gerado: ${filePreenchido.path}');

  // 4. Gerar PDF Em Branco
  final pdfEmBranco = pw.Document(
    title: 'Tabela de Preços - Hotel Villamor (Em Branco para Preenchimento)',
    author: 'Villamor CRM',
    theme: temaPdf,
  );
  pdfEmBranco.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 22),
      build: (ctx) => _buildTabelaPage(
        ctx,
        logo: logoImage,
        emBranco: true,
      ),
    ),
  );
  final fileEmBranco = File('tabela_precos_hotel_em_branco.pdf');
  await fileEmBranco.writeAsBytes(await pdfEmBranco.save());
  print('PDF Em Branco gerado: ${fileEmBranco.path}');

  // 5. Gerar PDF Combinado (ambas as páginas em um só documento)
  final pdfCombinado = pw.Document(
    title: 'Tabela de Preços - Hotel Villamor (Completo)',
    author: 'Villamor CRM',
    theme: temaPdf,
  );
  pdfCombinado.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 22),
      build: (ctx) => _buildTabelaPage(
        ctx,
        logo: logoImage,
        emBranco: false,
      ),
    ),
  );
  pdfCombinado.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 22),
      build: (ctx) => _buildTabelaPage(
        ctx,
        logo: logoImage,
        emBranco: true,
      ),
    ),
  );
  final fileCombinado = File('tabela_precos_hotel_completo.pdf');
  await fileCombinado.writeAsBytes(await pdfCombinado.save());
  print('PDF Combinado gerado: ${fileCombinado.path}');

  print('Finalizado com sucesso!');
}

// ── Layout da Página ─────────────────────────────────────────────────────────

pw.Widget _buildTabelaPage(
  pw.Context ctx, {
  pw.MemoryImage? logo,
  required bool emBranco,
}) {
  final hojeStr = DateFormat('dd/MM/yyyy').format(DateTime.now());

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      // ── CABEÇALHO ──────────────────────────────────────────────────────────
      pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.black, width: 1.5),
          ),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            // Logo + Identificação
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logo != null)
                  pw.Container(
                    width: 44,
                    height: 44,
                    margin: const pw.EdgeInsets.only(right: 12),
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'VILLAMOR TAMBABA RESORT',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.2,
                        color: PdfColors.grey800,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'TABELA DE PREÇOS — HOTEL',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                        letterSpacing: 0.3,
                      ),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      emBranco
                          ? 'Formulário de Cotação e Proposta • Preenchimento Manual'
                          : 'Preço de venda por categoria de apartamento e cota',
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Selo do Documento
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1.0),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                color: emBranco ? PdfColors.white : const PdfColor.fromInt(0xffeaeaea),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    emBranco ? 'CÓPIA PARA PREENCHIMENTO' : 'TABELA OFICIAL',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Emissão: $hojeStr',
                    style: const pw.TextStyle(
                      fontSize: 7.5,
                      color: PdfColors.grey800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      pw.SizedBox(height: 10),

      // ── TABELA DE PREÇOS ───────────────────────────────────────────────────
      _buildTabelaGrid(emBranco),

      pw.SizedBox(height: 10),

      // ── RODAPÉ / ÁREA DE ANOTAÇÕES OU OBSERVAÇÕES ──────────────────────────
      _buildRodape(emBranco),
    ],
  );
}

// ── Grid da Tabela ───────────────────────────────────────────────────────────

pw.Widget _buildTabelaGrid(bool emBranco) {
  // Largura total imprimível: 595.28 - 52 = 543.28 pt
  // Categoria: 153 pt, 5 colunas de cotas: 78 pt cada
  const colCategoriaWidth = 153.0;
  const colCotaWidth = 78.0;

  // Altura das linhas:
  // Preenchida: 32 pt (ótima leitura e equilíbrio vertical)
  // Em Branco: 37 pt (espaço super confortável para escrita manual com caneta)
  final double alturaLinha = emBranco ? 37.0 : 32.0;

  final cabecalhos = [
    'CATEGORIA',
    'INTEGRAL',
    'OURO',
    'TITÂNIO',
    'PRATA',
    'BRONZE',
  ];

  return pw.Table(
    border: pw.TableBorder.all(
      color: PdfColors.black,
      width: 0.9,
    ),
    columnWidths: {
      0: const pw.FixedColumnWidth(colCategoriaWidth),
      1: const pw.FixedColumnWidth(colCotaWidth),
      2: const pw.FixedColumnWidth(colCotaWidth),
      3: const pw.FixedColumnWidth(colCotaWidth),
      4: const pw.FixedColumnWidth(colCotaWidth),
      5: const pw.FixedColumnWidth(colCotaWidth),
    },
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    children: [
      // Cabeçalho da Tabela
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          color: PdfColor.fromInt(0xffdcdcdc),
        ),
        children: cabecalhos.asMap().entries.map((entry) {
          final idx = entry.key;
          final title = entry.value;
          final isFirst = idx == 0;

          return pw.Container(
            height: 26,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6),
            alignment: isFirst ? pw.Alignment.centerLeft : pw.Alignment.center,
            child: pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          );
        }).toList(),
      ),

      // Linhas da Tabela
      ...dadosTabela.asMap().entries.map((entry) {
        final index = entry.key;
        final row = entry.value;

        // Fundo zebrado sutil na versão preenchida
        final bgCor = emBranco
            ? PdfColors.white
            : (index.isEven ? PdfColors.white : const PdfColor.fromInt(0xfff4f4f4));

        return pw.TableRow(
          decoration: pw.BoxDecoration(color: bgCor),
          children: [
            // Categoria
            pw.Container(
              height: alturaLinha,
              padding: const pw.EdgeInsets.symmetric(horizontal: 8),
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                row.categoria,
                style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ),

            // Integral
            _buildCelulaValor(
              valor: emBranco ? null : row.integral,
              emBranco: emBranco,
              height: alturaLinha,
            ),

            // Ouro
            _buildCelulaValor(
              valor: emBranco ? null : row.ouro,
              emBranco: emBranco,
              height: alturaLinha,
            ),

            // Titânio
            _buildCelulaValor(
              valor: emBranco ? null : row.titanio,
              emBranco: emBranco,
              height: alturaLinha,
            ),

            // Prata
            _buildCelulaValor(
              valor: emBranco ? null : row.prata,
              emBranco: emBranco,
              height: alturaLinha,
            ),

            // Bronze
            _buildCelulaValor(
              valor: emBranco ? null : row.bronze,
              emBranco: emBranco,
              height: alturaLinha,
            ),
          ],
        );
      }),
    ],
  );
}

// ── Célula de Valor ──────────────────────────────────────────────────────────

pw.Widget _buildCelulaValor({
  required String? valor,
  required bool emBranco,
  required double height,
}) {
  if (emBranco) {
    // Na versão em branco: célula limpa com prefixo discreto "R$" no topo para orientar a escrita
    return pw.Container(
      height: height,
      padding: const pw.EdgeInsets.only(left: 6, top: 4),
      alignment: pw.Alignment.topLeft,
      child: pw.Text(
        'R\$',
        style: const pw.TextStyle(
          fontSize: 7.5,
          color: PdfColor.fromInt(0xffa5a5a5),
        ),
      ),
    );
  }

  // Versão preenchida
  final temValor = valor != null && valor.isNotEmpty;

  return pw.Container(
    height: height,
    padding: const pw.EdgeInsets.symmetric(horizontal: 4),
    alignment: pw.Alignment.center,
    child: pw.Text(
      temValor ? valor : '—',
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: temValor ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: temValor ? PdfColors.black : PdfColors.grey600,
      ),
    ),
  );
}

// ── Rodapé / Observações / Formulário Manual ─────────────────────────────────

pw.Widget _buildRodape(bool emBranco) {
  if (emBranco) {
    // Versão em branco: caixa completa de negociação para anotações em reuniões
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: pw.BoxDecoration(
        border: pw.TableBorder.all(color: PdfColors.black, width: 0.9),
        color: PdfColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'PROPOSTA COMERCIAL / CONDIÇÕES DE PAGAMENTO:',
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              pw.Text(
                'Unidade / Fração Negociada: _______________________',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
              ),
            ],
          ),
          pw.SizedBox(height: 8),

          // Campos de entrada e parcelamento rápidos
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  'Entrada (Ato): R\$ _______________________',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  'Parcelas: _____ x de R\$ _________________',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  'Saldo Financiado: R\$ ___________________',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),

          // Linhas pautadas para anotações gerais
          for (int i = 0; i < 3; i++)
            pw.Container(
              height: 1,
              color: const PdfColor.fromInt(0xffcccccc),
              margin: const pw.EdgeInsets.only(bottom: 14),
            ),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Consultor: _________________________________',
                style: const pw.TextStyle(fontSize: 7.5),
              ),
              pw.Text(
                'Cliente / Investidor: _________________________________',
                style: const pw.TextStyle(fontSize: 7.5),
              ),
              pw.Text(
                'Data: _____ / _____ / _________',
                style: const pw.TextStyle(fontSize: 7.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Versão preenchida: notas comerciais completas, regras de comercialização e assinatura
  return pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
    decoration: pw.BoxDecoration(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.9),
      color: PdfColors.white,
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'INFORMAÇÕES E DIRETRIZES COMERCIAIS:',
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
            pw.Text(
              'Regime de Multipropriedade Imobiliária',
              style: pw.TextStyle(
                fontSize: 7.5,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          '1. Valores expressos em Reais (R\$), referentes às frações imobiliárias (cotas) ou integralidade da unidade especificada.',
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey900),
        ),
        pw.Text(
          '2. Os campos identificados com travessão (—) representam frações sem cota disponível para comercialização no momento.',
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey900),
        ),
        pw.Text(
          '3. A unidade BÂNGALO é comercializada exclusivamente no modelo Integral (propriedade de 100% do imóvel).',
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey900),
        ),
        pw.Text(
          '4. Tabela sujeita a alterações de preços, reajustes monetários e confirmação prévia de disponibilidade de inventário.',
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey900),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Villamor Tambaba Resort • Documento Oficial de Uso Comercial',
              style: pw.TextStyle(
                fontSize: 7,
                color: PdfColors.grey700,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
            pw.Text(
              'Assinatura do Consultor Comercial: _______________________________________',
              style: const pw.TextStyle(fontSize: 7.5),
            ),
          ],
        ),
      ],
    ),
  );
}
