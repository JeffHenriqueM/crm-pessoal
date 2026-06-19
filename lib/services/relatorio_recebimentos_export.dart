// lib/services/relatorio_recebimentos_export.dart
//
// Gera o "Relatório de recebimentos" a partir da planilha da Central de
// Contratos enviada pelo usuário: preserva as colunas originais e ACRESCENTA
// UMA COLUNA POR MÊS selecionado ("RECEBIDO Mmm/aaaa"), com o valor que cada
// contrato pagou naquele mês. Remove os contratos que não tiveram pagamento em
// nenhum dos meses escolhidos.
//
// A Central não traz o código do contrato (documentoCar das baixas); por isso a
// ponte é: LOCALIZADOR (da Central) → contrato do app (localizador → codigoContrato)
// → baixas (documentoCar → valorPago), agrupadas por mesCreditoKey.

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';

import '../models/baixa_financeira_model.dart';
import '../models/contrato_model.dart';

class RelatorioRecebimentosExport {
  static const _meses = [
    'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
    'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
  ];

  /// "2026-05" → "Mai/2026".
  static String rotuloMes(String key) {
    final p = key.split('-');
    if (p.length != 2) return key;
    final m = int.tryParse(p[1]);
    if (m == null || m < 1 || m > 12) return key;
    return '${_meses[m - 1]}/${p[0]}';
  }

  /// Código-base: parte antes do "/Cota" (ex.: "LXP-62-334/Cota-02" → "LXP-62-334").
  static String _base(String codigo) => codigo.split('/').first.trim();

  /// Nome normalizado (MAIÚSCULAS, espaços colapsados) para casar cliente.
  static String _nome(String n) =>
      n.toUpperCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  /// `localizador → { mesKey → total recebido }`, restrito aos [mesKeys].
  ///
  /// Cada baixa é atribuída a UM contrato e TODAS as baixas são consideradas
  /// (várias no mesmo mês somam). A ligação é:
  ///   1. código exato (documentoCar == codigoContrato); senão
  ///   2. mesmo código-base (sem o /Cota) E mesmo nome de cliente, quando isso
  ///      identifica um único contrato — cobre o caso em que o número da cota
  ///      diverge entre a baixa e o cadastro do contrato (ex.: cliente Michel).
  @visibleForTesting
  static Map<String, Map<String, double>> mapaRecebidoPorLocalizadorPorMes(
    List<Contrato> contratos,
    List<BaixaFinanceira> baixas,
    List<String> mesKeys,
  ) {
    final selecionados = mesKeys.toSet();

    // Índices de contrato.
    final porCodigoExato = <String, String>{}; // codigo → localizador
    final porBaseNome = <String, List<String>>{}; // "base|nome" → [localizador]
    for (final c in contratos) {
      final loc = c.localizador.trim();
      final cod = (c.codigoContrato ?? '').trim();
      if (loc.isEmpty || cod.isEmpty) continue;
      porCodigoExato[cod] = loc;
      (porBaseNome['${_base(cod)}|${_nome(c.nomeComprador)}'] ??= []).add(loc);
    }

    String? localizadorDa(BaixaFinanceira b) {
      final cod = b.documentoCar.trim();
      if (cod.isEmpty) return null;
      final exato = porCodigoExato[cod];
      if (exato != null) return exato;
      final lista = porBaseNome['${_base(cod)}|${_nome(b.cliente)}'];
      if (lista != null && lista.length == 1) return lista.first;
      return null; // sem correspondência ou ambíguo
    }

    final porLoc = <String, Map<String, double>>{};
    for (final b in baixas) {
      if (!selecionados.contains(b.mesCreditoKey)) continue;
      final loc = localizadorDa(b);
      if (loc == null) continue;
      final dest = (porLoc[loc] ??= {});
      dest[b.mesCreditoKey] = (dest[b.mesCreditoKey] ?? 0) + b.valorPago;
    }
    return porLoc;
  }

  /// `codigo (documentoCar) → { mesKey → total recebido }`, restrito aos
  /// [mesKeys]. Usado quando a planilha já traz a coluna de código — casa direto
  /// com o `documentoCar` das baixas, sem precisar da ponte por LOCALIZADOR.
  @visibleForTesting
  static Map<String, Map<String, double>> recebidoPorCodigoPorMes(
    List<BaixaFinanceira> baixas,
    List<String> mesKeys,
  ) {
    final sel = mesKeys.toSet();
    final m = <String, Map<String, double>>{};
    for (final b in baixas) {
      if (!sel.contains(b.mesCreditoKey)) continue;
      final cod = b.documentoCar.trim();
      if (cod.isEmpty) continue;
      final dest = (m[cod] ??= {});
      dest[b.mesCreditoKey] = (dest[b.mesCreditoKey] ?? 0) + b.valorPago;
    }
    return m;
  }

  /// Detecta o índice da coluna de código na planilha (CÓDIGO / DOCUMENTO DO
  /// CAR). Retorna -1 se não houver.
  static int _indiceCodigo(List header) {
    for (var i = 0; i < header.length; i++) {
      final h = header[i]?.value?.toString().trim().toUpperCase();
      if (h == null) continue;
      if (h == 'CÓDIGO' ||
          h == 'CODIGO' ||
          h == 'DOCUMENTO DO CAR' ||
          (h.contains('DOCUMENTO') && h.contains('CAR'))) {
        return i;
      }
    }
    return -1;
  }

  /// Gera o xlsx. Retorna os bytes + nº de contratos incluídos + nº de linhas
  /// da planilha original.
  ///
  /// Se a planilha tiver coluna de CÓDIGO, casa direto com o `documentoCar` das
  /// baixas. Caso contrário, cai na ponte LOCALIZADOR → contrato → baixas.
  static ({
    Uint8List bytes,
    int incluidos,
    int totalLinhas,
    int naoCasaramQtd,
    double naoCasaramTotal,
  }) gerar({
    required Uint8List centralBytes,
    required List<String> mesKeys,
    required List<Contrato> contratos,
    required List<BaixaFinanceira> baixas,
  }) {
    final meses = [...mesKeys]..sort(); // cronológico
    if (meses.isEmpty) throw Exception('Selecione ao menos um mês.');

    final excel = Excel.decodeBytes(_sanitizar(centralBytes));
    if (excel.tables.isEmpty) throw Exception('Planilha sem abas.');
    final sheet = excel.tables[excel.tables.keys.first]!;
    if (sheet.rows.isEmpty) throw Exception('Planilha vazia.');

    final header = sheet.rows.first;
    final nCols = header.length;

    // Preferência: coluna de CÓDIGO (casa direto com documentoCar das baixas).
    final codIdx = _indiceCodigo(header);

    int locIdx = -1;
    for (var i = 0; i < nCols; i++) {
      if (header[i]?.value?.toString().trim().toUpperCase() == 'LOCALIZADOR') {
        locIdx = i;
        break;
      }
    }

    // Mapa chave → {mes → valor} e índice da coluna-chave na planilha.
    final Map<String, Map<String, double>> recebido;
    final int chaveIdx;
    if (codIdx >= 0) {
      recebido = recebidoPorCodigoPorMes(baixas, meses);
      chaveIdx = codIdx;
    } else if (locIdx >= 0) {
      recebido = mapaRecebidoPorLocalizadorPorMes(contratos, baixas, meses);
      chaveIdx = locIdx;
    } else {
      throw Exception(
          'Planilha precisa ter a coluna "CÓDIGO" ou "LOCALIZADOR".');
    }

    // Baixas que NÃO casaram com nenhum código da planilha (modo código).
    // Vão para uma aba "Não casaram" para conferência manual.
    final naoCasaramCliente = <String, String>{}; // documentoCar → cliente
    final naoCasaramMeses = <String, Map<String, double>>{}; // documentoCar → mes → valor
    if (codIdx >= 0) {
      final chavesPlanilha = <String>{};
      for (var r = 1; r < sheet.rows.length; r++) {
        final linha = sheet.rows[r];
        final cod = (codIdx < linha.length
                ? linha[codIdx]?.value?.toString()
                : null)
            ?.trim();
        if (cod != null && cod.isNotEmpty) chavesPlanilha.add(cod);
      }
      for (final b in baixas) {
        if (!meses.contains(b.mesCreditoKey)) continue;
        final cod = b.documentoCar.trim();
        if (cod.isEmpty || chavesPlanilha.contains(cod)) continue;
        naoCasaramCliente[cod] = b.cliente;
        final dest = (naoCasaramMeses[cod] ??= {});
        dest[b.mesCreditoKey] = (dest[b.mesCreditoKey] ?? 0) + b.valorPago;
      }
    }

    final out = Excel.createExcel();
    final outSheet = out[out.getDefaultSheet() ?? 'Sheet1'];

    // Cabeçalho original + uma coluna por mês.
    outSheet.appendRow([
      for (var i = 0; i < nCols; i++) header[i]?.value ?? TextCellValue(''),
      for (final mes in meses) TextCellValue('RECEBIDO ${rotuloMes(mes)}'),
    ]);

    var incluidos = 0;
    for (var r = 1; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      final chave =
          (chaveIdx < row.length ? row[chaveIdx]?.value?.toString() : null)
                  ?.trim() ??
              '';
      final porMes = recebido[chave];
      final total =
          porMes == null ? 0.0 : porMes.values.fold(0.0, (s, v) => s + v);
      if (total <= 0) continue; // sem pagamento em nenhum dos meses → remove

      outSheet.appendRow([
        for (var i = 0; i < nCols; i++)
          (i < row.length ? row[i]?.value : null) ?? TextCellValue(''),
        for (final mes in meses) DoubleCellValue(porMes?[mes] ?? 0),
      ]);
      incluidos++;
    }

    // Aba de conferência: baixas sem código correspondente na planilha.
    if (naoCasaramMeses.isNotEmpty) {
      final aba = out['Não casaram'];
      aba.appendRow([
        TextCellValue('CLIENTE'),
        TextCellValue('CÓDIGO (baixa)'),
        for (final mes in meses) TextCellValue('RECEBIDO ${rotuloMes(mes)}'),
        TextCellValue('TOTAL'),
      ]);
      final cods = naoCasaramMeses.keys.toList()
        ..sort((a, b) =>
            (naoCasaramCliente[a] ?? '').compareTo(naoCasaramCliente[b] ?? ''));
      for (final cod in cods) {
        final m = naoCasaramMeses[cod]!;
        aba.appendRow([
          TextCellValue(naoCasaramCliente[cod] ?? ''),
          TextCellValue(cod),
          for (final mes in meses) DoubleCellValue(m[mes] ?? 0),
          DoubleCellValue(m.values.fold(0.0, (s, v) => s + v)),
        ]);
      }
    }

    final naoCasaramTotal = naoCasaramMeses.values
        .fold(0.0, (s, m) => s + m.values.fold(0.0, (a, b) => a + b));

    final bytes = out.encode();
    if (bytes == null) throw Exception('Falha ao codificar o arquivo.');
    return (
      bytes: Uint8List.fromList(bytes),
      incluidos: incluidos,
      totalLinhas: sheet.rows.length - 1,
      naoCasaramQtd: naoCasaramMeses.length,
      naoCasaramTotal: naoCasaramTotal,
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
