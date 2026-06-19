// lib/services/relatorio_recebimentos_export.dart
//
// Gera o "Relatório de recebimentos do mês" a partir da planilha da Central de
// Contratos enviada pelo usuário: preserva as colunas originais, ACRESCENTA
// "VALOR RECEBIDO NO MÊS" e REMOVE os contratos que não tiveram pagamento no
// mês escolhido.
//
// A Central não traz o código do contrato (documentoCar das baixas); por isso a
// ponte é: LOCALIZADOR (da Central) → contrato do app (localizador → codigoContrato)
// → baixas do mês (documentoCar → valorPago).

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';

import '../models/baixa_financeira_model.dart';
import '../models/contrato_model.dart';

class RelatorioRecebimentosExport {
  static const colunaRecebido = 'VALOR RECEBIDO NO MÊS';

  /// Mapa `localizador → total recebido` no [mesKey] ("yyyy-MM"), cruzando os
  /// contratos (localizador → codigoContrato) com as baixas (documentoCar →
  /// valorPago). Só inclui localizadores com recebimento > 0 no mês.
  @visibleForTesting
  static Map<String, double> mapaRecebidoPorLocalizador(
    List<Contrato> contratos,
    List<BaixaFinanceira> baixas,
    String mesKey,
  ) {
    final recebidoPorCodigo = <String, double>{};
    for (final b in baixas) {
      if (b.mesCreditoKey != mesKey) continue;
      final cod = b.documentoCar.trim();
      if (cod.isEmpty) continue;
      recebidoPorCodigo[cod] = (recebidoPorCodigo[cod] ?? 0) + b.valorPago;
    }

    final mapa = <String, double>{};
    for (final c in contratos) {
      final loc = c.localizador.trim();
      final cod = (c.codigoContrato ?? '').trim();
      if (loc.isEmpty || cod.isEmpty) continue;
      final r = recebidoPorCodigo[cod];
      if (r != null && r > 0) mapa[loc] = (mapa[loc] ?? 0) + r;
    }
    return mapa;
  }

  /// Gera o xlsx do relatório. Retorna os bytes + quantos contratos entraram e
  /// quantas linhas a planilha original tinha.
  static ({Uint8List bytes, int incluidos, int totalLinhas}) gerar({
    required Uint8List centralBytes,
    required String mesKey,
    required List<Contrato> contratos,
    required List<BaixaFinanceira> baixas,
  }) {
    final excel = Excel.decodeBytes(_sanitizar(centralBytes));
    if (excel.tables.isEmpty) throw Exception('Planilha sem abas.');
    final sheet = excel.tables[excel.tables.keys.first]!;
    if (sheet.rows.isEmpty) throw Exception('Planilha vazia.');

    final header = sheet.rows.first;
    final nCols = header.length;

    // Índice EXATO de "LOCALIZADOR" (não "LOCALIZADOR ATENDIMENTO").
    int locIdx = -1;
    for (var i = 0; i < nCols; i++) {
      if (header[i]?.value?.toString().trim().toUpperCase() == 'LOCALIZADOR') {
        locIdx = i;
        break;
      }
    }
    if (locIdx < 0) {
      throw Exception('Coluna "LOCALIZADOR" não encontrada na planilha.');
    }

    final recebido = mapaRecebidoPorLocalizador(contratos, baixas, mesKey);

    final out = Excel.createExcel();
    final outSheet = out[out.getDefaultSheet() ?? 'Sheet1'];

    // Cabeçalho original + nova coluna.
    outSheet.appendRow([
      for (var i = 0; i < nCols; i++) header[i]?.value ?? TextCellValue(''),
      TextCellValue(colunaRecebido),
    ]);

    var incluidos = 0;
    for (var r = 1; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      final loc =
          (locIdx < row.length ? row[locIdx]?.value?.toString() : null)?.trim() ??
              '';
      final val = recebido[loc] ?? 0;
      if (val <= 0) continue; // remove quem não teve pagamento no mês
      outSheet.appendRow([
        for (var i = 0; i < nCols; i++)
          (i < row.length ? row[i]?.value : null) ?? TextCellValue(''),
        DoubleCellValue(val),
      ]);
      incluidos++;
    }

    final bytes = out.encode();
    if (bytes == null) throw Exception('Falha ao codificar o arquivo.');
    return (
      bytes: Uint8List.fromList(bytes),
      incluidos: incluidos,
      totalLinhas: sheet.rows.length - 1,
    );
  }

  /// Remove `<v></v>` vazios dos XMLs das planilhas (bug do pacote `excel`).
  static Uint8List _sanitizar(Uint8List bytes) {
    try {
      final zip = ZipDecoder().decodeBytes(bytes);
      final saida = Archive();
      final vazioFechado = RegExp(r'<v[^>]*>\s*</v>');
      final vazioAuto = RegExp(r'<v\s*/>');
      for (final f in zip.files) {
        if (f.isFile &&
            f.name.startsWith('xl/worksheets/') &&
            f.name.endsWith('.xml')) {
          final xml = utf8
              .decode(f.content as List<int>, allowMalformed: true)
              .replaceAll(vazioFechado, '')
              .replaceAll(vazioAuto, '');
          final dados = utf8.encode(xml);
          saida.addFile(
            ArchiveFile(f.name, dados.length, dados)..compress = false,
          );
        } else {
          saida.addFile(f..compress = false);
        }
      }
      final out = ZipEncoder().encode(saida, level: Deflate.NO_COMPRESSION);
      return out == null ? bytes : Uint8List.fromList(out);
    } catch (_) {
      return bytes;
    }
  }
}
