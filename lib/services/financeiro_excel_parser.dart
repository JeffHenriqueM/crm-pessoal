// lib/services/financeiro_excel_parser.dart
//
// Parser de planilha Excel de baixas financeiras para importação no Firestore.
// Usa o pacote `excel: ^4.0.6` (já declarado em pubspec.yaml).
//
// Contrato:
//   • Sanitiza o xlsx antes de decodificar (remove <v></v> vazios que causam
//     FormatException no pacote `excel`).
//   • Lê a aba "Para Jefferson" ou, na ausência, a primeira aba disponível.
//   • Pula a linha 0 (cabeçalho).
//   • Colunas esperadas na ordem:
//       0  Cliente
//       1  Tipo
//       2  Documento do CAR
//       3  Vencimento         (DateTime ou serial Excel)
//       4  Valor pago parcela (double ou String com vírgula)
//       5  Data da baixa      (DateTime ou serial Excel)
//       6  Data de crédito    (DateTime ou serial Excel)
//       7  Status
//   • Erros por linha: registra via debugPrint e pula a linha — não aborta.
//   • Retorna List<BaixaFinanceira> pronta para importação em batch.

import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import '../models/baixa_financeira_model.dart';

class FinanceiroExcelParser {
  static const _abaAlvo = 'Para Jefferson';

  /// Posição fixa documentada de cada coluna (fallback se o cabeçalho não casar).
  static const _colunasPadrao = <String, int>{
    'cliente': 0,
    'tipo': 1,
    'documentoCar': 2,
    'vencimento': 3,
    'valorPago': 4,
    'dataBaixa': 5,
    'dataCredito': 6,
    'status': 7,
  };

  /// Palavras-chave (em minúsculas) para localizar cada coluna pelo cabeçalho.
  /// Cada lista é distinta o bastante para não colidir com as demais colunas.
  static const _palavrasChave = <String, List<String>>{
    'cliente': ['cliente'],
    'tipo': ['tipo', 'forma'],
    'documentoCar': ['documento', 'car'],
    'vencimento': ['vencimento', 'venc'],
    'valorPago': ['valor'],
    'dataBaixa': ['baixa'],
    'dataCredito': ['crédito', 'credito'],
    'status': ['status'],
  };

  /// Resolve o índice de cada coluna a partir do [cabecalho].
  /// Casa por palavra-chave (case-insensitive, `contains`); se não encontrar,
  /// usa a posição fixa de [_colunasPadrao] — garantindo que nunca fica pior
  /// que o layout posicional anterior.
  @visibleForTesting
  static Map<String, int> resolverColunas(List<String?> cabecalho) {
    final norm =
        cabecalho.map((c) => (c ?? '').toLowerCase().trim()).toList();
    final mapa = <String, int>{};
    _palavrasChave.forEach((campo, chaves) {
      var idx = -1;
      for (var i = 0; i < norm.length; i++) {
        if (chaves.any((k) => norm[i].contains(k))) {
          idx = i;
          break;
        }
      }
      mapa[campo] = idx >= 0 ? idx : _colunasPadrao[campo]!;
    });
    return mapa;
  }

  /// Parseia o [bytes] de um arquivo .xlsx e retorna as baixas válidas.
  ///
  /// [userId] e [userName] são gravados nos campos de auditoria de cada registro.
  static Future<List<BaixaFinanceira>> parseExcel(
    Uint8List bytes, {
    required String userId,
    required String userName,
  }) async {
    // Sanitiza antes de decodificar — remove <v></v> vazios que causam
    // FormatException no pacote excel (mesmo fix de baixas_excel_parser.dart).
    final excel = Excel.decodeBytes(_xlsxSanitizado(bytes));

    // Seleciona a aba pelo nome-alvo; cai na primeira se não encontrar.
    Sheet? sheet;
    if (excel.tables.containsKey(_abaAlvo)) {
      sheet = excel.tables[_abaAlvo];
    } else {
      if (excel.tables.isEmpty) {
        debugPrint('⚠️ FinanceiroExcelParser: planilha sem abas.');
        return [];
      }
      final primeiraAba = excel.tables.keys.first;
      debugPrint(
        '⚠️ FinanceiroExcelParser: aba "$_abaAlvo" não encontrada — '
        'usando "$primeiraAba".',
      );
      sheet = excel.tables[primeiraAba];
    }

    if (sheet == null || sheet.rows.isEmpty) {
      debugPrint('⚠️ FinanceiroExcelParser: aba vazia.');
      return [];
    }

    // Resolve as colunas pelo cabeçalho (linha 0). Se um cabeçalho não casar,
    // cai na posição fixa documentada — nunca pior que o comportamento anterior.
    final cabecalho =
        sheet.rows.first.map((c) => c?.value?.toString()).toList();
    final cols = resolverColunas(cabecalho);

    final agora = DateTime.now();
    final resultado = <BaixaFinanceira>[];
    int erros = 0;

    // Linha 0 = cabeçalho — pula.
    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];

      // Linha totalmente vazia (todas as células nulas ou em branco) → ignora.
      final temConteudo = row.any((c) {
        final v = c?.value;
        return v != null && v.toString().trim().isNotEmpty;
      });
      if (!temConteudo) continue;

      try {
        final cliente =
            _textoOuErro(row, cols['cliente']!, i, 'Cliente').toUpperCase().trim();
        final tipo = _textoOuErro(row, cols['tipo']!, i, 'Tipo');
        final documentoCar =
            _textoOuErro(row, cols['documentoCar']!, i, 'Documento do CAR');
        final vencimento = _dataOuErro(row, cols['vencimento']!, i, 'Vencimento');
        final valorPago =
            _valorOuErro(row, cols['valorPago']!, i, 'Valor pago parcela');
        final dataBaixa = _dataOuErro(row, cols['dataBaixa']!, i, 'Data da baixa');
        final dataCredito =
            _dataOuErro(row, cols['dataCredito']!, i, 'Data de crédito');
        final status = _texto(row, cols['status']!) ?? 'Baixado';

        resultado.add(BaixaFinanceira(
          cliente: cliente,
          tipo: tipo,
          documentoCar: documentoCar,
          vencimento: vencimento,
          valorPago: valorPago,
          dataBaixa: dataBaixa,
          dataCredito: dataCredito,
          status: status,
          mesCreditoKey: BaixaFinanceira.buildMesKey(dataCredito),
          importadoEm: agora,
          importadoPorId: userId,
          importadoPorNome: userName,
        ));
      } catch (e) {
        erros++;
        debugPrint('⚠️ FinanceiroExcelParser: linha ${i + 1} ignorada — $e');
      }
    }

    debugPrint(
      'FinanceiroExcelParser: ${resultado.length} registros importados'
      '${erros > 0 ? ", $erros erros ignorados" : ""}.',
    );
    return resultado;
  }

  // ── Sanitização xlsx ────────────────────────────────────────────────────────

  /// Remove tags `<v></v>` e `<v/>` vazias dos XMLs internos do .xlsx.
  /// Esses nós aparecem em exports de certos sistemas e causam FormatException
  /// no decodificador do pacote `excel`.
  static Uint8List _xlsxSanitizado(Uint8List bytes) {
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
      // Se a sanitização falhar por qualquer motivo, passa os bytes originais.
      return bytes;
    }
  }

  // ── Helpers de célula ──────────────────────────────────────────────────────

  /// Lê texto da célula [col] na [row], lança se vazio/nulo.
  static String _textoOuErro(
    List<Data?> row,
    int col,
    int rowIndex,
    String campo,
  ) {
    final v = _texto(row, col);
    if (v == null || v.isEmpty) {
      throw FormatException('Campo "$campo" ausente na coluna ${col + 1}');
    }
    return v;
  }

  /// Lê texto da célula [col] ou retorna null.
  static String? _texto(List<Data?> row, int col) {
    if (col >= row.length) return null;
    final cell = row[col];
    if (cell == null) return null;
    final v = cell.value;
    if (v == null) return null;
    return v.toString().trim().isEmpty ? null : v.toString().trim();
  }

  /// Lê DateTime da célula [col], tratando tanto DateTimeCellValue quanto serial
  /// numérico Excel quanto String no formato "dd/MM/yyyy". Lança se inválido.
  static DateTime _dataOuErro(
    List<Data?> row,
    int col,
    int rowIndex,
    String campo,
  ) {
    if (col >= row.length || row[col] == null) {
      throw FormatException('Campo "$campo" ausente na coluna ${col + 1}');
    }
    final cell = row[col]!;
    final v = cell.value;

    if (v == null) {
      throw FormatException('Campo "$campo" nulo na coluna ${col + 1}');
    }

    // O pacote excel representa datas como DateTimeCellValue.
    if (v is DateTimeCellValue) {
      return DateTime(v.year, v.month, v.day, v.hour, v.minute, v.second);
    }

    // Fallback: serial numérico Excel (dias desde 1899-12-30).
    if (v is IntCellValue) {
      return _serialParaData(v.value);
    }
    if (v is DoubleCellValue) {
      return _serialParaData(v.value.truncate());
    }

    // Último recurso: String "dd/MM/yyyy" ou "yyyy-MM-dd".
    final texto = v.toString().trim();
    if (texto.isEmpty) {
      throw FormatException('Campo "$campo" vazio na coluna ${col + 1}');
    }
    return _parseDataString(texto, campo);
  }

  /// Converte serial numérico do Excel em DateTime.
  /// Excel: dia 1 = 1900-01-01 (com o bug histórico do dia 29/02/1900).
  static DateTime _serialParaData(int serial) {
    // Base: 1899-12-30 (correção do bug do Excel que conta 1900-02-29).
    final base = DateTime(1899, 12, 30);
    return base.add(Duration(days: serial));
  }

  /// Tenta parsear string de data nos formatos "dd/MM/yyyy" e "yyyy-MM-dd".
  static DateTime _parseDataString(String texto, String campo) {
    // Formato BR: dd/MM/yyyy
    final partesBR = texto.split('/');
    if (partesBR.length == 3) {
      final dia = int.tryParse(partesBR[0]);
      final mes = int.tryParse(partesBR[1]);
      final ano = int.tryParse(partesBR[2].split(' ').first); // ignora hora
      if (dia != null && mes != null && ano != null) {
        return DateTime(ano, mes, dia);
      }
    }

    // Formato ISO: yyyy-MM-dd
    final iso = DateTime.tryParse(texto);
    if (iso != null) return iso;

    throw FormatException(
      'Campo "$campo": formato de data não reconhecido — "$texto"',
    );
  }

  /// Lê double da célula [col]; aceita String com vírgula decimal.
  static double _valorOuErro(
    List<Data?> row,
    int col,
    int rowIndex,
    String campo,
  ) {
    if (col >= row.length || row[col] == null) {
      throw FormatException('Campo "$campo" ausente na coluna ${col + 1}');
    }
    final v = row[col]!.value;

    if (v == null) {
      throw FormatException('Campo "$campo" nulo na coluna ${col + 1}');
    }

    if (v is DoubleCellValue) return v.value;
    if (v is IntCellValue) return v.value.toDouble();

    final parsed = parseMoeda(v.toString());
    if (parsed == null) {
      throw FormatException(
        'Campo "$campo": valor numérico inválido — "${v.toString()}"',
      );
    }
    return parsed;
  }

  /// Converte uma string monetária em double, tolerando os formatos usuais.
  ///
  /// - pt-BR com milhar e decimal: "1.234,56" → 1234.56
  /// - só vírgula decimal: "1234,56" → 1234.56
  /// - só ponto, ambíguo:
  ///     • "1.234"   (3+ casas após o único ponto) → milhar → 1234.0
  ///     • "1234.56" (2 casas após o único ponto)  → decimal US → 1234.56
  /// - múltiplos pontos sem vírgula: "1.234.567" → milhar → 1234567.0
  @visibleForTesting
  static double? parseMoeda(String bruto) {
    var s = bruto.trim().replaceAll(RegExp(r'[^\d,.\-]'), ''); // tira R$, espaços
    if (s.isEmpty) return null;

    final temVirgula = s.contains(',');
    final temPonto = s.contains('.');

    if (temVirgula && temPonto) {
      // ponto = milhar, vírgula = decimal (pt-BR)
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else if (temVirgula) {
      s = s.replaceAll(',', '.');
    } else if (temPonto) {
      final partes = s.split('.');
      final ultima = partes.last;
      // Único ponto com exatamente 2 casas → decimal (formato US). Caso
      // contrário, o(s) ponto(s) são separador(es) de milhar.
      if (!(partes.length == 2 && ultima.length == 2)) {
        s = s.replaceAll('.', '');
      }
    }

    return double.tryParse(s);
  }
}
