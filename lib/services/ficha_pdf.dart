// lib/services/ficha_pdf.dart
//
// Gera o PDF da Ficha de Atendimento da Recepção — layout fiel ao formulário
// físico (A4 landscape, dois painéis separados por linha vertical).

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ── Dados necessários para gerar a ficha ────────────────────────────────────
class FichaAtendimentoData {
  final String nome;
  final String? idade;
  final String? profissao;
  final String? telefone;
  final String? conjuge;
  final String? idadeConjuge;
  final String? profissaoConjuge;
  final String? telefoneConjuge;
  final String? brinde;
  final String? captadorNome;
  final String? vendedorNome;
  final String sala;
  final String? pontoCapatcao;
  final int? numeroAtendimento;
  final DateTime dataEntrada;

  const FichaAtendimentoData({
    required this.nome,
    this.idade,
    this.profissao,
    this.telefone,
    this.conjuge,
    this.idadeConjuge,
    this.profissaoConjuge,
    this.telefoneConjuge,
    this.brinde,
    this.captadorNome,
    this.vendedorNome,
    required this.sala,
    this.pontoCapatcao,
    this.numeroAtendimento,
    required this.dataEntrada,
  });
}

// ── Gerador de PDF ───────────────────────────────────────────────────────────
class FichaAtendimentoPdf {
  static final _dataHoraFmt = DateFormat('dd/MM/yyyy HH:mm');
  static final _dataFmt = DateFormat('dd/MM/yyyy');

  // Cores
  static const _preto = PdfColors.black;
  static const _cinzaClaro = PdfColors.grey300;
  static const _laranja = PdfColor(0.90, 0.45, 0.0);

  // ── Método público ─────────────────────────────────────────────────────────
  static Future<void> gerar(FichaAtendimentoData data) async {
    final doc = pw.Document(
      title: 'Ficha de Atendimento - ${data.nome}',
    );

    final logoBytes = await rootBundle.load('assets/images/logo.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => _buildPage(ctx, data, logoImage),
      ),
    );

    final nomeArquivo =
        'Ficha_${data.nome.replaceAll(' ', '_')}_${data.numeroAtendimento ?? ''}.pdf';

    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: nomeArquivo,
    );
  }

  // ── Página principal ───────────────────────────────────────────────────────
  static pw.Widget _buildPage(
    pw.Context ctx,
    FichaAtendimentoData d,
    pw.MemoryImage logo,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Painel esquerdo: perguntas do liner/closer
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(20, 16, 18, 14),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                right: pw.BorderSide(color: _cinzaClaro, width: 1.2),
              ),
            ),
            child: _buildPainelEsquerdo(logo, d),
          ),
        ),
        // Painel direito: dados do cliente
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(18, 16, 20, 14),
            child: _buildPainelDireito(d, logo),
          ),
        ),
      ],
    );
  }

  // ── Painel esquerdo: perguntas ─────────────────────────────────────────────
  static pw.Widget _buildPainelEsquerdo(
      pw.MemoryImage logo, FichaAtendimentoData d) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Image(logo, width: 72, height: 52, fit: pw.BoxFit.contain),
        pw.SizedBox(height: 14),

        _pergunta('Há quanto tempo conhecem a Villamor?'),
        _linhaEmBranco(),
        pw.SizedBox(height: 10),

        _pergunta('Quem dos dois influenciou o outro ao meio liberal?'),
        _linhaEmBranco(),
        pw.SizedBox(height: 10),

        _pergunta('Quantas semanas por ano conseguem aproveitar em casal?'),
        _linhaEmBranco(),
        pw.SizedBox(height: 10),

        _pergunta('O que falta na Pousada Villamor?'),
        _linhaEmBranco(),
        pw.SizedBox(height: 10),

        _pergunta('Já conhecem algum outro local liberal/naturista?'),
        pw.SizedBox(height: 6),
        _labelComLinha('Nacional:'),
        pw.SizedBox(height: 5),
        _labelComLinha('Internacional:'),
        pw.SizedBox(height: 5),
        _pergunta('Investimento médio anual em lazer em casal?'),
        _linhaEmBranco(),
        pw.SizedBox(height: 10),

        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _cinzaClaro, width: 0.6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pergunta(
                  'Importância, em uma escala de zero a dez, deste momento para o casal:'),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Expanded(child: _labelComLinha('ELE:')),
                  pw.SizedBox(width: 16),
                  pw.Expanded(child: _labelComLinha('ELA:')),
                ],
              ),
            ],
          ),
        ),

        pw.Expanded(child: pw.SizedBox()),

        pw.Divider(color: _cinzaClaro, thickness: 0.6),
        pw.SizedBox(height: 4),

        // Rodapé esquerdo — papéis da equipe
        _rodapeItem('Data:', _dataFmt.format(d.dataEntrada)),
        _rodapeItem('Gerente:', null),
        _rodapeItem('Supervisor de MKT:', null),
        _rodapeItem('Promotor de MKT:', null),
        _rodapeItem('Liner:', null),
        _rodapeItem('Closer:', d.vendedorNome),
        _rodapeItem('Pep:', d.captadorNome),
        _rodapeItem('MNV:', null),
        _rodapeItem('Brinde:', d.brinde),
      ],
    );
  }

  // ── Painel direito: dados do cliente ──────────────────────────────────────
  static pw.Widget _buildPainelDireito(
      FichaAtendimentoData d, pw.MemoryImage logo) {
    final isTambaba = d.sala.toUpperCase() == 'TAMBABA';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Cabeçalho: logo + número atendimento
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Image(logo, width: 72, height: 52, fit: pw.BoxFit.contain),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    pw.Text('Atendimento Nº.: ',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(
                      d.numeroAtendimento?.toString().padLeft(6, '0') ??
                          '_____________________',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),

        // Sala + Data
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _cinzaClaro, width: 0.5),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Row(
                  children: [
                    pw.Text('Sala: ',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(d.sala.toUpperCase(),
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Row(
                  children: [
                    pw.Text('Data: ',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(
                      _dataHoraFmt.format(d.dataEntrada),
                      style: pw.TextStyle(
                          fontSize: 9, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 4),

        // Ponto Captação + Sistema
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _cinzaClaro, width: 0.5),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: _labelComValorOuLinha(
                    'Ponto Captação:', d.pontoCapatcao),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child:
                    _labelComValorOuLinha('Sistema:', d.captadorNome),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 8),

        pw.Divider(color: _cinzaClaro, thickness: 0.7),
        pw.SizedBox(height: 6),

        // Nome em destaque
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _cinzaClaro, width: 0.5),
          ),
          child: pw.Row(
            children: [
              pw.Text('Nome: ', style: const pw.TextStyle(fontSize: 9)),
              pw.Text(
                d.nome.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _preto,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 4),

        _linhaGrade(pw.Row(
          children: [
            pw.Expanded(child: _labelComValorOuLinha('Idade:', d.idade)),
            pw.SizedBox(width: 12),
            pw.Expanded(child: _labelComValorOuLinha('Profissão:', d.profissao)),
          ],
        )),
        pw.SizedBox(height: 3),

        // Telefone titular com destaque laranja
        _linhaGrade(
          pw.Row(
            children: [
              pw.Text('Telefone: ',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _laranja)),
              pw.Text(
                d.telefone ?? '_________________________________',
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: d.telefone != null ? _laranja : _cinzaClaro),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 3),

        _linhaGrade(_labelComValorOuLinha('Cônjuge:', d.conjuge)),
        pw.SizedBox(height: 3),

        _linhaGrade(pw.Row(
          children: [
            pw.Expanded(child: _labelComValorOuLinha('Idade Cônjuge:', d.idadeConjuge)),
            pw.SizedBox(width: 12),
            pw.Expanded(child: _labelComValorOuLinha('Profissão:', d.profissaoConjuge)),
          ],
        )),
        pw.SizedBox(height: 3),

        // Telefone cônjuge com destaque laranja
        _linhaGrade(
          pw.Row(
            children: [
              pw.Text('Telefone Cônjuge: ',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _laranja)),
              pw.Text(
                d.telefoneConjuge ?? '_________________________',
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: d.telefoneConjuge != null ? _laranja : _cinzaClaro),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 3),

        _linhaGrade(pw.Row(
          children: [
            pw.Expanded(child: _labelComLinha('Tipo de Relacionamento:')),
            pw.SizedBox(width: 12),
            pw.Expanded(child: _labelComLinha('Tempo de Relacionamento:')),
          ],
        )),
        pw.SizedBox(height: 3),

        _linhaGrade(_labelComLinha('Estado:')),
        pw.SizedBox(height: 3),
        pw.SizedBox(height: 6),

        // Valor de diária + linhas em branco para notas
        _labelComLinha('Valor de diária:'),
        for (int i = 0; i < 6; i++) ...[
          pw.SizedBox(height: 9),
          pw.Divider(color: _cinzaClaro, thickness: 0.4),
        ],

        pw.Expanded(child: pw.SizedBox()),

        pw.Divider(color: _cinzaClaro, thickness: 0.7),
        pw.SizedBox(height: 6),

        // Hospede / Salas / Aptos
        pw.Row(
          children: [
            pw.Text('HOSPEDE  ',
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold)),
            _checkbox(), pw.SizedBox(width: 4),
            pw.Text('SIM', style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(width: 12),
            _checkbox(), pw.SizedBox(width: 4),
            pw.Text('NÃO', style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Row(
          children: [
            pw.Text('TAMBABA ',
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold)),
            _checkbox(marcado: isTambaba),
            pw.SizedBox(width: 8),
            pw.Text('APTO: ____________',
                style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          children: [
            pw.Text('VILLA       ',
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold)),
            _checkbox(marcado: !isTambaba),
            pw.SizedBox(width: 8),
            pw.Text('APTO: ____________',
                style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static pw.Widget _pergunta(String texto) => pw.Text(
        texto,
        style: const pw.TextStyle(fontSize: 9, color: _preto),
      );

  static pw.Widget _linhaEmBranco() => pw.Column(
        children: [
          pw.SizedBox(height: 7),
          pw.Divider(color: _cinzaClaro, thickness: 0.5),
        ],
      );

  static pw.Widget _labelComLinha(String label) => pw.Row(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(width: 4),
          pw.Expanded(
              child: pw.Divider(color: _cinzaClaro, thickness: 0.4)),
        ],
      );

  static pw.Widget _labelComValorOuLinha(String label, String? valor) {
    return pw.Row(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(width: 4),
        if (valor != null && valor.isNotEmpty)
          pw.Text(valor,
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold))
        else
          pw.Expanded(
              child: pw.Divider(color: _cinzaClaro, thickness: 0.4)),
      ],
    );
  }

  static pw.Widget _linhaGrade(pw.Widget child) => pw.Container(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        margin: const pw.EdgeInsets.only(bottom: 2),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _cinzaClaro, width: 0.5),
        ),
        child: child,
      );

  static pw.Widget _rodapeItem(String label, String? valor) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.8),
        child: pw.Row(
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
            pw.SizedBox(width: 4),
            if (valor != null && valor.isNotEmpty)
              pw.Text(valor,
                  style: pw.TextStyle(
                      fontSize: 8, fontWeight: pw.FontWeight.bold))
            else
              pw.Expanded(
                  child: pw.Divider(color: _cinzaClaro, thickness: 0.3)),
          ],
        ),
      );

  static pw.Widget _checkbox({bool marcado = false}) => pw.Container(
        width: 10,
        height: 10,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _preto, width: 0.8),
        ),
        child: marcado
            ? pw.Center(
                child: pw.Text('X',
                    style: const pw.TextStyle(fontSize: 7)))
            : null,
      );
}
