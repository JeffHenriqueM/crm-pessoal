// lib/services/proposta_pdf.dart
//
// Gera um PDF formatado da proposta comercial e abre o diálogo de impressão/download
// do navegador (Printing.layoutPdf). O usuário pode salvar como PDF ou imprimir.

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/negociacao_model.dart';

class PropostaPdf {
  static final _moeda =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _dataFmt = DateFormat('dd/MM/yyyy');
  static final _dataHoraFmt = DateFormat('dd/MM/yyyy HH:mm');

  // ── Cores ─────────────────────────────────────────────────────────────────
  static const _azulEscuro = PdfColors.blueGrey800;
  static const _azulMedio = PdfColors.blueGrey700;
  static const _cinzaTexto = PdfColors.blueGrey500;
  static const _divisor = PdfColors.blueGrey200;
  static const _fundo = PdfColors.blueGrey50;
  static const _verdeEscuro = PdfColor(0.18, 0.49, 0.20); // green800
  static const _vermelho = PdfColor(0.78, 0.06, 0.06);    // red800

  // ── Método público ────────────────────────────────────────────────────────
  /// Gera e exibe o PDF da [negociacao]. Abre o diálogo nativo do browser.
  static Future<void> gerar(Negociacao negociacao) async {
    final doc = pw.Document(title: negociacao.titulo);

    // Carrega logo dos assets
    final logoBytes = await rootBundle.load('assets/images/logo.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 44),
        build: (ctx) => _buildPage(ctx, negociacao, logoImage),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: '${negociacao.titulo}.pdf',
    );
  }

  // ── Página completa ───────────────────────────────────────────────────────
  static pw.Widget _buildPage(
    pw.Context ctx,
    Negociacao n,
    pw.MemoryImage logoImage,
  ) {
    final isEspecial = n.tipo == TipoNegociacao.especial;
    final temDesconto = n.desconto > 0;
    final temEntrada = (n.valorEntrada ?? 0) > 0;
    final temParcelas = (n.quantidadeParcelas ?? 0) > 0;

    // Cor do status
    PdfColor statusCor;
    switch (n.status) {
      case StatusNegociacao.aceita:
        statusCor = _verdeEscuro;
        break;
      case StatusNegociacao.recusada:
        statusCor = _vermelho;
        break;
      default:
        statusCor = PdfColors.blueGrey700;
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── Cabeçalho ───────────────────────────────────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Image(logoImage, width: 64, height: 64,
                fit: pw.BoxFit.contain),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'VILLAMOR TAMBABA RESORT',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: _azulEscuro,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Proposta Comercial',
                  style: const pw.TextStyle(
                      fontSize: 9, color: _cinzaTexto),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: _divisor, thickness: 0.8),
        pw.SizedBox(height: 16),

        // ── Título da proposta ───────────────────────────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                n.titulo,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: _azulEscuro,
                ),
              ),
            ),
            pw.SizedBox(width: 12),
            // Badge de status
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: pw.BoxDecoration(
                color: statusCor,
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(20)),
              ),
              child: pw.Text(
                n.status.nomeDisplay.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 14),

        // ── Informações gerais ───────────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: const pw.BoxDecoration(
            color: _fundo,
            borderRadius:
                pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            children: [
              if (n.clienteNome?.isNotEmpty == true)
                _infoRow('Cliente', n.clienteNome!),
              if (n.embaixadorNome?.isNotEmpty == true)
                _infoRow('Embaixador', n.embaixadorNome!),
              _infoRow('Data da proposta', _dataFmt.format(n.dataCriacao)),
              if (isEspecial)
                _infoRow('Tipo', 'Negociação Especial'),
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // ── Seção de valores ─────────────────────────────────────────────
        _secTitle('VALORES'),
        pw.SizedBox(height: 8),
        _linhaValor(
            'Valor de tabela', _moeda.format(n.valorOriginal)),
        if (temDesconto) ...[
          pw.SizedBox(height: 5),
          _linhaValor(
            n.tipoDesconto == TipoDesconto.percentual
                ? 'Desconto (${n.desconto.toStringAsFixed(1).replaceAll('.', ',')}%)'
                : 'Desconto',
            '- ${_moeda.format(n.tipoDesconto == TipoDesconto.percentual ? n.valorOriginal * n.desconto / 100 : n.desconto)}',
            cor: _vermelho,
          ),
        ],
        pw.SizedBox(height: 8),
        pw.Divider(color: _divisor, thickness: 0.5),
        pw.SizedBox(height: 8),
        _linhaValor(
          'Valor final',
          _moeda.format(n.valorFinal),
          bold: true,
          grande: true,
          cor: _azulEscuro,
        ),

        // Parcelas / entrada
        if (temEntrada || temParcelas) ...[
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _divisor, width: 0.6),
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              children: [
                if (temEntrada)
                  _infoRow('Entrada', _moeda.format(n.valorEntrada!)),
                if (temParcelas && n.valorParcela != null)
                  _infoRow(
                    'Parcelamento',
                    '${n.quantidadeParcelas}x de ${_moeda.format(n.valorParcela!)}',
                  ),
              ],
            ),
          ),
        ],

        // ── Condição especial ────────────────────────────────────────────
        if (isEspecial && n.condicaoEspecial?.isNotEmpty == true) ...[
          pw.SizedBox(height: 20),
          _secTitle('CONDIÇÃO ESPECIAL'),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.orange50,
              border:
                  pw.Border.all(color: PdfColors.orange200, width: 0.6),
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Text(
              n.condicaoEspecial!,
              style:
                  const pw.TextStyle(fontSize: 11, color: _azulEscuro),
            ),
          ),
          if (n.prazoResposta != null) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              'Prazo para resposta: ${_dataFmt.format(n.prazoResposta!)}',
              style: const pw.TextStyle(
                  fontSize: 10, color: _cinzaTexto),
            ),
          ],
        ],

        // ── Status de aprovação (especial) ───────────────────────────────
        if (isEspecial &&
            n.statusAprovacao != StatusAprovacao.semSolicitacao) ...[
          pw.SizedBox(height: 12),
          _infoRow('Aprovação', n.statusAprovacao.nomeDisplay),
          if (n.aprovadoPorNome != null)
            _infoRow('Aprovado por', n.aprovadoPorNome!),
          if (n.dataAprovacao != null)
            _infoRow(
                'Data da aprovação', _dataFmt.format(n.dataAprovacao!)),
        ],

        // ── Comentário de aprovação ──────────────────────────────────────
        if (n.comentarioAprovacao?.isNotEmpty == true) ...[
          pw.SizedBox(height: 20),
          _secTitle('COMENTÁRIO'),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: const pw.BoxDecoration(
              color: _fundo,
              borderRadius:
                  pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Text(
              n.comentarioAprovacao!,
              style:
                  const pw.TextStyle(fontSize: 11, color: _azulEscuro),
            ),
          ),
        ],

        // ── Observações ──────────────────────────────────────────────────
        if (n.observacoes?.isNotEmpty == true) ...[
          pw.SizedBox(height: 20),
          _secTitle('OBSERVAÇÕES'),
          pw.SizedBox(height: 8),
          pw.Text(
            n.observacoes!,
            style: const pw.TextStyle(fontSize: 11, color: _azulEscuro),
          ),
        ],

        pw.Expanded(child: pw.SizedBox()),

        // ── Rodapé ──────────────────────────────────────────────────────
        pw.Divider(color: _divisor, thickness: 0.5),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Villamor Tambaba Resort — Proposta comercial',
              style: const pw.TextStyle(
                  fontSize: 7, color: _cinzaTexto),
            ),
            pw.Text(
              'Gerado em ${_dataHoraFmt.format(DateTime.now())}',
              style: const pw.TextStyle(
                  fontSize: 7, color: _cinzaTexto),
            ),
          ],
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static pw.Widget _secTitle(String title) => pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: _azulMedio,
          letterSpacing: 0.8,
        ),
      );

  static pw.Widget _infoRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(
                  fontSize: 10, color: _cinzaTexto),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _azulEscuro,
              ),
            ),
          ],
        ),
      );

  static pw.Widget _linhaValor(
    String label,
    String valor, {
    bool bold = false,
    bool grande = false,
    PdfColor? cor,
  }) {
    final size = grande ? 13.0 : 11.0;
    final weight =
        bold ? pw.FontWeight.bold : pw.FontWeight.normal;
    final color = cor ?? _azulEscuro;

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                fontSize: size, fontWeight: weight, color: color)),
        pw.Text(valor,
            style: pw.TextStyle(
                fontSize: size, fontWeight: weight, color: color)),
      ],
    );
  }
}
