import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

import '../models/contrato_model.dart';

/// Parsers de importação de contratos da Central de Contratos (Pós-venda).
///
/// Dois formatos de entrada com o **mesmo** mapeamento de colunas → [Contrato]
/// (ver [_mapearContratos]):
/// - [parsearCsvContratos]: texto CSV (export "Salvar como CSV").
/// - [parsearExcelContratos]: xlsx nativo (números e datas tipados — mais
///   preciso; datas vêm como serial do Excel). Espelha o script Python
///   `scripts/importar_contratos_central.py`.
///
/// O que é gravado/preservado no Firestore é decidido pelo `toFirestore()` do
/// [Contrato] + `set(merge:true)` — ver `docs/importacao_contratos.md`.

/// Converte o conteúdo de um CSV de contratos em uma lista de [Contrato].
List<Contrato> parsearCsvContratos(String conteudo) {
  // Normaliza CRLF (export do Excel/Sheets) para evitar que o \r residual
  // desincronize o estado de quoting do CsvToListConverter.
  final normalizado = conteudo.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final linhas = const CsvToListConverter(eol: '\n').convert(normalizado);
  if (linhas.isEmpty) throw Exception('Arquivo vazio');
  return _mapearContratos(linhas);
}

/// Converte os bytes de um arquivo xlsx de contratos em uma lista de [Contrato].
///
/// Lê números e datas nativamente: dinheiro como `num` e datas como **serial do
/// Excel** (dias desde 1899-12-30). Datas de nascimento podem vir como string
/// `DD/MM/YYYY` ou como serial — ambos tratados em [_mapearContratos].
List<Contrato> parsearExcelContratos(Uint8List bytes) {
  final planilha = Excel.decodeBytes(_xlsxSanitizado(bytes));
  if (planilha.tables.isEmpty) throw Exception('Planilha vazia');

  // Escolhe a aba que tem a coluna LOCALIZADOR; se nenhuma, a primeira.
  Sheet? aba;
  for (final t in planilha.tables.values) {
    if (t.rows.isNotEmpty &&
        t.rows.first.any((c) =>
            _celulaParaValor(c).toString().trim().toLowerCase() ==
            'localizador')) {
      aba = t;
      break;
    }
  }
  aba ??= planilha.tables.values.first;

  final linhas =
      aba.rows.map((row) => row.map(_celulaParaValor).toList()).toList();
  if (linhas.isEmpty) throw Exception('Planilha vazia');
  return _mapearContratos(linhas);
}

/// Sanitiza os bytes de um xlsx antes de decodificar.
///
/// O export da Central grava milhares de células numéricas **vazias** como
/// `<v></v>` (em vez de omitir a célula). O leitor de xlsx faz `num.parse('')`
/// nesse valor e estoura `FormatException`, abortando a importação inteira.
/// Aqui removemos os `<v>` vazios das planilhas (worksheets), de modo que a
/// célula vira simplesmente vazia. Se algo falhar, devolve os bytes originais.
Uint8List _xlsxSanitizado(Uint8List bytes) {
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
        saida.addFile(ArchiveFile(f.name, dados.length, dados)..compress = false);
      } else {
        saida.addFile(f..compress = false);
      }
    }
    // STORE (sem deflate): este zip é descartável, descomprimido logo a seguir
    // pelo Excel.decodeBytes. Recomprimir só desperdiçaria a thread da UI —
    // o deflate da planilha inteira é o que mais trava a importação na web.
    final out = ZipEncoder().encode(saida, level: Deflate.NO_COMPRESSION);
    return out == null ? bytes : Uint8List.fromList(out);
  } catch (_) {
    return bytes; // melhor tentar decodificar o original do que falhar aqui
  }
}

/// Normaliza uma célula do xlsx para um valor Dart nativo (`String`, `num`,
/// `bool` ou `DateTime`), base para os conversores de [_mapearContratos].
dynamic _celulaParaValor(Data? cell) {
  final v = cell?.value;
  if (v == null) return '';
  return switch (v) {
    TextCellValue() => v.toString(),
    IntCellValue() => v.value,
    DoubleCellValue() => v.value,
    BoolCellValue() => v.value,
    DateCellValue() => DateTime(v.year, v.month, v.day),
    DateTimeCellValue() =>
      DateTime(v.year, v.month, v.day, v.hour, v.minute, v.second),
    _ => v.toString(),
  };
}

/// Converte um serial de data do Excel (dias desde 1899-12-30) em [DateTime].
/// Seriais inválidos (negativos ou absurdos) viram `null` para preservar o
/// campo no merge.
DateTime? _serialExcelParaData(num serial) {
  if (serial < 1 || serial > 80000) return null; // ~1900..~2119
  return DateTime(1899, 12, 30).add(Duration(days: serial.floor()));
}

/// Núcleo compartilhado: recebe `linhas` (cabeçalho + dados, células já como
/// valores nativos — `String` no CSV, tipadas no xlsx) e devolve os contratos.
List<Contrato> _mapearContratos(List<List<dynamic>> linhas) {
  // Normaliza o cabeçalho removendo BOM e espaços.
  final cabecalho = linhas.first
      .map((e) => (e ?? '').toString().trim().replaceAll('﻿', ''))
      .toList();

  int idx(String nome) =>
      cabecalho.indexWhere((h) => h.toLowerCase().contains(nome.toLowerCase()));

  // Match exato (sem contains) — usado onde "contains" causaria ambiguidade,
  // ex.: "STATUS" casando com "STATUS ASSINATURA" ou "STATUS FINANCEIRO".
  int idxExato(String nome) =>
      cabecalho.indexWhere((h) => h.toLowerCase() == nome.toLowerCase());

  final iLoc = idxExato('LOCALIZADOR');
  if (iLoc < 0) throw Exception('Coluna LOCALIZADOR não encontrada');

  final contratos = <Contrato>[];

  for (var r = 1; r < linhas.length; r++) {
    final row = linhas[r];
    if (row.isEmpty) continue;

    dynamic bruto(int i) => (i >= 0 && i < row.length) ? row[i] : null;

    String cel(int i) {
      final v = bruto(i);
      return v == null ? '' : v.toString().trim();
    }

    double dbl(int i) {
      final v = bruto(i);
      if (v is num) return v.toDouble(); // xlsx: número nativo
      final s = (v?.toString() ?? '').trim();
      if (s.isEmpty) return 0.0;
      // CSV: formato BR "1.234,56" → 1234.56
      return double.tryParse(s.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;
    }

    final localizador = cel(iLoc);
    if (localizador.isEmpty || localizador.startsWith('Qtd:')) continue;

    // Datas de contrato/quitação/vencimento: serial do Excel (xlsx),
    // DateTime tipado, ou string MM/DD/YYYY (CSV).
    DateTime? parseData(int i) {
      final v = bruto(i);
      // Trunca a hora: a Central exporta o serial com fração de tempo (ex.:
      // 46232.875 = 21:00, 46179.0004 = 00:00:35). Esses campos são datas de
      // calendário — manter a hora empurra a data para o dia seguinte ao
      // comparar/gravar em UTC e gera falsas "alterações" no import.
      if (v is DateTime) return DateTime(v.year, v.month, v.day);
      if (v is num) return _serialExcelParaData(v);
      final s = (v?.toString() ?? '').trim();
      if (s.isEmpty) return null;
      final p = s.split('/');
      if (p.length == 3) {
        try {
          return DateTime(int.parse(p[2]), int.parse(p[0]), int.parse(p[1]));
        } catch (_) {}
      }
      return null;
    }

    // Datas de nascimento: serial do Excel, DateTime, ou string DD/MM/YYYY.
    DateTime? parseDataNasc(int i) {
      final v = bruto(i);
      if (v is DateTime) return DateTime(v.year, v.month, v.day); // trunca hora
      if (v is num) return _serialExcelParaData(v);
      final s = (v?.toString() ?? '').trim();
      if (s.isEmpty) return null;
      final p = s.split('/');
      if (p.length == 3) {
        try {
          return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
        } catch (_) {}
      }
      return null;
    }

    final dataNasc1 = parseDataNasc(idx('DATA NASCIMENTO CESSIONÁRIO 1'));
    final dataNasc2 = parseDataNasc(idx('DATA NASCIMENTO CESSIONÁRIO 2'));

    // Reversão de projeto: lida da planilha (REVERTIDO / ORIGEM REVERSÃO).
    final revertido = const ['sim', 'true', '1', 'verdadeiro']
        .contains(cel(idx('REVERTIDO')).toLowerCase());
    final origemRaw = cel(idx('ORIGEM REVERSÃO'));
    final origemReversao =
        (revertido && origemRaw.isNotEmpty && origemRaw != '0')
            ? origemRaw
            : null;

    final codigo = cel(idxExato('CÓDIGO'));

    contratos.add(
      Contrato(
        localizador: localizador,
        localizadorAtendimento: cel(idx('LOCALIZADOR ATENDIMENTO')),
        codigoContrato: codigo.isEmpty ? null : codigo,
        dataContrato: parseData(idxExato('DATA')),
        nomeComprador: cel(idx('CESSIONÁRIO 1')),
        cpfComprador: cel(idx('CPF/CNPJ cessionário 1')),
        emailComprador: cel(idx('E-mail cessionário 1')),
        telefoneComprador: cel(idx('Telefone cessionário 1')),
        dataNascimentoComprador: dataNasc1,
        diaNascimentoComprador: dataNasc1?.day,
        mesNascimentoComprador: dataNasc1?.month,
        nomeComprador2:
            cel(idx('CESSIONÁRIO 2')).isEmpty ? null : cel(idx('CESSIONÁRIO 2')),
        cpfComprador2: cel(idx('CPF/CNPJ cessionário 2')).isEmpty
            ? null
            : cel(idx('CPF/CNPJ cessionário 2')),
        emailComprador2: cel(idx('E-mail cessionário 2')).isEmpty
            ? null
            : cel(idx('E-mail cessionário 2')),
        telefoneComprador2: cel(idx('Telefone cessionário 2')).isEmpty
            ? null
            : cel(idx('Telefone cessionário 2')),
        dataNascimentoComprador2: dataNasc2,
        diaNascimentoComprador2: dataNasc2?.day,
        mesNascimentoComprador2: dataNasc2?.month,
        logradouro: cel(idx('LOGRADOURO')),
        numero: cel(idx('NÚMERO')),
        complemento: cel(idx('COMPLEMENTO')),
        bairro: cel(idx('BAIRRO')),
        cidade: cel(idx('CIDADE')),
        estado: cel(idx('ESTADO')),
        pais: cel(idx('PAÍS')).isEmpty ? 'Brasil' : cel(idx('PAÍS')),
        sala: cel(idx('SALA')),
        bloco: cel(idx('BLOCO')),
        imovel: cel(idx('IMÓVEL')),
        produto: cel(idx('PRODUTO')),
        cota: cel(idx('COTA')),
        revertido: revertido,
        origemReversao: origemReversao,
        // idxExato evita que "STATUS" case "STATUS ASSINATURA"/"STATUS FINANCEIRO"
        status:
            cel(idxExato('STATUS')).isEmpty ? 'Ativo' : cel(idxExato('STATUS')),
        statusFinanceiro: cel(idxExato('STATUS FINANCEIRO')).isEmpty
            ? 'Em andamento'
            : cel(idxExato('STATUS FINANCEIRO')),
        dataQuitacao: parseData(idx('DATA QUITAÇÃO')),
        entrada: dbl(idx('ENTRADA')),
        saldoRestante: dbl(idx('SALDO RESTANTE')),
        valorFinanciado: dbl(idx('VALOR FINANCIADO')),
        valorIntegralizado: dbl(idx('VALOR INTEGRALIZADO')),
        valorAtrasado: dbl(idx('VALOR ATRASADO')),
        percentualIntegralizado: dbl(idx('PERCENTUAL INTEGRALIZADO')),
        valorTotalReajustado: dbl(idx('VALOR TOTAL REAJUSTADO')),
        dataProximoVencimento: parseData(idx('DATA PRÓXIMO VENCIMENTO')),
        vendedorCloser: cel(idx('VENDEDOR CLOSER')),
        captador: cel(idx('CAPTADOR')),
        vendedorLiner: cel(idx('VENDEDOR LINER')),
        pontoCapatcao: cel(idx('PONTO DE CAPTAÇÃO')),
        statusAssinatura:
            StatusAssinatura.fromCsvLabel(cel(idx('STATUS ASSINATURA'))),
      ),
    );
  }

  return contratos;
}
