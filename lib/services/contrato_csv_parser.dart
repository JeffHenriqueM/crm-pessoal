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
/// - [parsearCsvContratos] / [parsearCsvContratosResult]: texto CSV.
/// - [parsearExcelContratos] / [parsearExcelContratosResult]: xlsx nativo.
///
/// O que é gravado/preservado no Firestore é decidido pelo `toFirestore()` do
/// [Contrato] + `set(merge:true)` — ver `docs/importacao_contratos.md`.

/// Resultado da leitura de um arquivo (CSV ou Excel) de contratos.
class ContratosParseResult {
  final List<Contrato> contratos;
  final Set<String> camposPresentes;
  final List<String> colunasAusentes;

  const ContratosParseResult({
    required this.contratos,
    required this.camposPresentes,
    this.colunasAusentes = const [],
  });
}

/// Converte o conteúdo de um CSV de contratos em uma lista de [Contrato].
List<Contrato> parsearCsvContratos(String conteudo) =>
    parsearCsvContratosResult(conteudo).contratos;

/// Converte o conteúdo de um CSV em [ContratosParseResult], identificando
/// quais colunas estavam de fato presentes no arquivo.
ContratosParseResult parsearCsvContratosResult(String conteudo) {
  // Normaliza CRLF (export do Excel/Sheets) para evitar que o \r residual
  // desincronize o estado de quoting do CsvToListConverter.
  final normalizado = conteudo.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final linhas = const CsvToListConverter(eol: '\n').convert(normalizado);
  if (linhas.isEmpty) throw Exception('Arquivo vazio');
  return _mapearContratos(linhas);
}

/// Converte os bytes de um arquivo xlsx de contratos em uma lista de [Contrato].
List<Contrato> parsearExcelContratos(Uint8List bytes) =>
    parsearExcelContratosResult(bytes).contratos;

/// Converte os bytes de um arquivo xlsx em [ContratosParseResult], identificando
/// quais colunas estavam de fato presentes no arquivo.
ContratosParseResult parsearExcelContratosResult(Uint8List bytes) {
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
/// valores nativos — `String` no CSV, tipadas no xlsx) e devolve o resultado
/// com os contratos, os campos presentes no cabeçalho e as colunas ausentes.
ContratosParseResult _mapearContratos(List<List<dynamic>> linhas) {
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

  // Mapeamento e detecção de colunas presentes no arquivo:
  final camposPresentes = <String>{'localizador'};

  final iLocAtend = idx('LOCALIZADOR ATENDIMENTO');
  if (iLocAtend >= 0) camposPresentes.add('localizadorAtendimento');

  final iCod = idxExato('CÓDIGO');
  if (iCod >= 0) camposPresentes.add('codigoContrato');

  final iData = idxExato('DATA');
  if (iData >= 0) camposPresentes.add('dataContrato');

  final iNome1 = idx('CESSIONÁRIO 1');
  if (iNome1 >= 0) camposPresentes.add('nomeComprador');

  final iCpf1 = idx('CPF/CNPJ cessionário 1');
  if (iCpf1 >= 0) camposPresentes.add('cpfComprador');

  final iEmail1 = idx('E-mail cessionário 1');
  if (iEmail1 >= 0) camposPresentes.add('emailComprador');

  final iTel1 = idx('Telefone cessionário 1');
  if (iTel1 >= 0) camposPresentes.add('telefoneComprador');

  final iNasc1 = idx('DATA NASCIMENTO CESSIONÁRIO 1');
  if (iNasc1 >= 0) {
    camposPresentes.addAll([
      'dataNascimentoComprador',
      'diaNascimentoComprador',
      'mesNascimentoComprador',
    ]);
  }

  final iNome2 = idx('CESSIONÁRIO 2');
  if (iNome2 >= 0) camposPresentes.add('nomeComprador2');

  final iCpf2 = idx('CPF/CNPJ cessionário 2');
  if (iCpf2 >= 0) camposPresentes.add('cpfComprador2');

  final iEmail2 = idx('E-mail cessionário 2');
  if (iEmail2 >= 0) camposPresentes.add('emailComprador2');

  final iTel2 = idx('Telefone cessionário 2');
  if (iTel2 >= 0) camposPresentes.add('telefoneComprador2');

  final iNasc2 = idx('DATA NASCIMENTO CESSIONÁRIO 2');
  if (iNasc2 >= 0) {
    camposPresentes.addAll([
      'dataNascimentoComprador2',
      'diaNascimentoComprador2',
      'mesNascimentoComprador2',
    ]);
  }

  final iLogradouro = idx('LOGRADOURO');
  if (iLogradouro >= 0) camposPresentes.add('logradouro');

  final iNumero = idx('NÚMERO');
  if (iNumero >= 0) camposPresentes.add('numero');

  final iComplemento = idx('COMPLEMENTO');
  if (iComplemento >= 0) camposPresentes.add('complemento');

  final iBairro = idx('BAIRRO');
  if (iBairro >= 0) camposPresentes.add('bairro');

  final iCidade = idx('CIDADE');
  if (iCidade >= 0) camposPresentes.add('cidade');

  final iEstado = idx('ESTADO');
  if (iEstado >= 0) camposPresentes.add('estado');

  final iPais = idx('PAÍS');
  if (iPais >= 0) camposPresentes.add('pais');

  final iSala = idx('SALA');
  if (iSala >= 0) camposPresentes.add('sala');

  final iBloco = idx('BLOCO');
  if (iBloco >= 0) camposPresentes.add('bloco');

  final iImovel = idx('IMÓVEL');
  if (iImovel >= 0) camposPresentes.add('imovel');

  final iProduto = idx('PRODUTO');
  if (iProduto >= 0) camposPresentes.add('produto');

  final iCota = idx('COTA');
  if (iCota >= 0) camposPresentes.add('cota');

  final iRevertido = idx('REVERTIDO');
  if (iRevertido >= 0) camposPresentes.add('revertido');

  final iOrigemReversao = idx('ORIGEM REVERSÃO');
  if (iOrigemReversao >= 0) camposPresentes.add('origemReversao');

  final iStatus = idxExato('STATUS');
  if (iStatus >= 0) camposPresentes.add('status');

  final iStatusFinanceiro = idxExato('STATUS FINANCEIRO');
  if (iStatusFinanceiro >= 0) camposPresentes.add('statusFinanceiro');

  final iDataQuitacao = idx('DATA QUITAÇÃO');
  if (iDataQuitacao >= 0) camposPresentes.add('dataQuitacao');

  final iEntrada = idx('ENTRADA');
  if (iEntrada >= 0) camposPresentes.add('entrada');

  final iSaldoRestante = idx('SALDO RESTANTE');
  if (iSaldoRestante >= 0) camposPresentes.add('saldoRestante');

  final iValorFinanciado = idx('VALOR FINANCIADO');
  if (iValorFinanciado >= 0) camposPresentes.add('valorFinanciado');

  final iValorIntegralizado = idx('VALOR INTEGRALIZADO');
  if (iValorIntegralizado >= 0) camposPresentes.add('valorIntegralizado');

  final iValorAtrasado = idx('VALOR ATRASADO');
  if (iValorAtrasado >= 0) camposPresentes.add('valorAtrasado');

  final iPercentualIntegralizado = idx('PERCENTUAL INTEGRALIZADO');
  if (iPercentualIntegralizado >= 0) camposPresentes.add('percentualIntegralizado');

  final iValorTotalReajustado = idx('VALOR TOTAL REAJUSTADO');
  if (iValorTotalReajustado >= 0) camposPresentes.add('valorTotalReajustado');

  final iDataProximoVencimento = idx('DATA PRÓXIMO VENCIMENTO');
  if (iDataProximoVencimento >= 0) camposPresentes.add('dataProximoVencimento');

  final iVendedorCloser = idx('VENDEDOR CLOSER');
  if (iVendedorCloser >= 0) camposPresentes.add('vendedorCloser');

  final iCaptador = idx('CAPTADOR');
  if (iCaptador >= 0) camposPresentes.add('captador');

  final iVendedorLiner = idx('VENDEDOR LINER');
  if (iVendedorLiner >= 0) camposPresentes.add('vendedorLiner');

  final iPontoCapatcao = idx('PONTO DE CAPTAÇÃO');
  if (iPontoCapatcao >= 0) camposPresentes.add('pontoCapatcao');

  final iStatusAssinatura = idx('STATUS ASSINATURA');

  // Colunas de dados importantes que costumam estar no export completo:
  final colunasAusentes = <String>[];
  if (iCpf1 < 0) colunasAusentes.add('CPF');
  if (iEmail1 < 0) colunasAusentes.add('E-mail');
  if (iTel1 < 0) colunasAusentes.add('Telefone');
  if (iLogradouro < 0) colunasAusentes.add('Endereço');
  if (iBloco < 0) colunasAusentes.add('Bloco');
  if (iSala < 0) colunasAusentes.add('Sala');
  if (iCaptador < 0) colunasAusentes.add('Captador');
  if (iSaldoRestante < 0) colunasAusentes.add('Saldo Restante');
  if (iPercentualIntegralizado < 0) colunasAusentes.add('% Integralizado');
  if (iValorTotalReajustado < 0) colunasAusentes.add('Valor Reajustado');
  if (iLocAtend < 0) colunasAusentes.add('Loc. Atendimento');

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

    final dataNasc1 = parseDataNasc(iNasc1);
    final dataNasc2 = parseDataNasc(iNasc2);

    // Reversão de projeto: lida da planilha (REVERTIDO / ORIGEM REVERSÃO).
    final revertido = const ['sim', 'true', '1', 'verdadeiro']
        .contains(cel(iRevertido).toLowerCase());
    final origemRaw = cel(iOrigemReversao);
    final origemReversao =
        (revertido && origemRaw.isNotEmpty && origemRaw != '0')
            ? origemRaw
            : null;

    final codigo = cel(iCod);

    contratos.add(
      Contrato(
        localizador: localizador,
        localizadorAtendimento: cel(iLocAtend),
        codigoContrato: codigo.isEmpty ? null : codigo,
        dataContrato: parseData(iData),
        nomeComprador: cel(iNome1),
        cpfComprador: cel(iCpf1),
        emailComprador: cel(iEmail1),
        telefoneComprador: cel(iTel1),
        dataNascimentoComprador: dataNasc1,
        diaNascimentoComprador: dataNasc1?.day,
        mesNascimentoComprador: dataNasc1?.month,
        nomeComprador2:
            cel(iNome2).isEmpty ? null : cel(iNome2),
        cpfComprador2: cel(iCpf2).isEmpty
            ? null
            : cel(iCpf2),
        emailComprador2: cel(iEmail2).isEmpty
            ? null
            : cel(iEmail2),
        telefoneComprador2: cel(iTel2).isEmpty
            ? null
            : cel(iTel2),
        dataNascimentoComprador2: dataNasc2,
        diaNascimentoComprador2: dataNasc2?.day,
        mesNascimentoComprador2: dataNasc2?.month,
        logradouro: cel(iLogradouro),
        numero: cel(iNumero),
        complemento: cel(iComplemento),
        bairro: cel(iBairro),
        cidade: cel(iCidade),
        estado: cel(iEstado),
        pais: cel(iPais).isEmpty ? 'Brasil' : cel(iPais),
        sala: cel(iSala),
        bloco: cel(iBloco),
        imovel: cel(iImovel),
        produto: cel(iProduto),
        cota: cel(iCota),
        revertido: revertido,
        origemReversao: origemReversao,
        // idxExato evita que "STATUS" case "STATUS ASSINATURA"/"STATUS FINANCEIRO"
        status:
            cel(iStatus).isEmpty ? 'Ativo' : cel(iStatus),
        statusFinanceiro: cel(iStatusFinanceiro).isEmpty
            ? 'Em andamento'
            : cel(iStatusFinanceiro),
        dataQuitacao: parseData(iDataQuitacao),
        entrada: dbl(iEntrada),
        saldoRestante: dbl(iSaldoRestante),
        valorFinanciado: dbl(iValorFinanciado),
        valorIntegralizado: dbl(iValorIntegralizado),
        valorAtrasado: dbl(iValorAtrasado),
        percentualIntegralizado: dbl(iPercentualIntegralizado),
        valorTotalReajustado: dbl(iValorTotalReajustado),
        dataProximoVencimento: parseData(iDataProximoVencimento),
        vendedorCloser: cel(iVendedorCloser),
        captador: cel(iCaptador),
        vendedorLiner: cel(iVendedorLiner),
        pontoCapatcao: cel(iPontoCapatcao),
        statusAssinatura:
            StatusAssinatura.fromCsvLabel(cel(iStatusAssinatura)),
      ),
    );
  }

  return ContratosParseResult(
    contratos: contratos,
    camposPresentes: camposPresentes,
    colunasAusentes: colunasAusentes,
  );
}
