import 'package:csv/csv.dart';

import '../models/contrato_model.dart';

/// Converte o conteúdo de um CSV de contratos em uma lista de [Contrato].
///
/// Função pura (sem dependência de UI/web), extraída de `PosVendaScreen` para
/// ser testável. O comportamento é o mesmo do parser original.
List<Contrato> parsearCsvContratos(String conteudo) {
  // Normaliza CRLF (export do Excel/Sheets) para evitar que o \r residual
  // desincronize o estado de quoting do CsvToListConverter.
  final normalizado = conteudo.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final linhas = const CsvToListConverter(eol: '\n').convert(normalizado);
  if (linhas.isEmpty) throw Exception('Arquivo vazio');

  // Normaliza o cabeçalho removendo BOM e espaços
  final cabecalho = linhas.first
      .map((e) => e.toString().trim().replaceAll('﻿', ''))
      .toList();

  int idx(String nome) {
    final i = cabecalho.indexWhere(
      (h) => h.toLowerCase().contains(nome.toLowerCase()),
    );
    return i; // -1 se não encontrado
  }

  // Match exato (sem contains) — usado onde "contains" causaria ambiguidade,
  // ex.: "STATUS" casando com "STATUS ASSINATURA" ou "STATUS FINANCEIRO".
  int idxExato(String nome) {
    final i = cabecalho.indexWhere(
      (h) => h.toLowerCase() == nome.toLowerCase(),
    );
    return i;
  }

  final iLoc = idxExato('LOCALIZADOR');
  if (iLoc < 0) throw Exception('Coluna LOCALIZADOR não encontrada');

  final contratos = <Contrato>[];

  for (var r = 1; r < linhas.length; r++) {
    final row = linhas[r];
    if (row.isEmpty) continue;

    String cel(int i) =>
        i >= 0 && i < row.length ? row[i].toString().trim() : '';
    double dbl(int i) {
      final s = cel(i).replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(s) ?? 0.0;
    }

    final localizador = cel(iLoc);
    if (localizador.isEmpty || localizador.startsWith('Qtd:')) continue;

    DateTime? parseData(int i) {
      final s = cel(i);
      if (s.isEmpty) return null;
      try {
        // MM/DD/YYYY ou DD/MM/YYYY
        final partes = s.split('/');
        if (partes.length == 3) {
          return DateTime(
            int.parse(partes[2]),
            int.parse(partes[0]),
            int.parse(partes[1]),
          );
        }
      } catch (_) {}
      return null;
    }

    DateTime? parseDataNasc(int i) {
      final s = cel(i);
      if (s.isEmpty) return null;
      try {
        // DD/MM/YYYY
        final partes = s.split('/');
        if (partes.length == 3) {
          return DateTime(
            int.parse(partes[2]),
            int.parse(partes[1]),
            int.parse(partes[0]),
          );
        }
      } catch (_) {}
      return null;
    }

    final dataNasc1 = parseDataNasc(idx('DATA NASCIMENTO CESSIONÁRIO 1'));
    final dataNasc2 = parseDataNasc(idx('DATA NASCIMENTO CESSIONÁRIO 2'));

    contratos.add(
      Contrato(
        localizador: localizador,
        localizadorAtendimento: cel(idx('LOCALIZADOR ATENDIMENTO')),
        codigoContrato:
            cel(idxExato('CÓDIGO')).isEmpty ? null : cel(idxExato('CÓDIGO')),
        dataContrato: parseData(idxExato('DATA')),
        nomeComprador: cel(idx('CESSIONÁRIO 1')),
        cpfComprador: cel(idx('CPF/CNPJ cessionário 1')),
        emailComprador: cel(idx('E-mail cessionário 1')),
        telefoneComprador: cel(idx('Telefone cessionário 1')),
        dataNascimentoComprador: dataNasc1,
        diaNascimentoComprador: dataNasc1?.day,
        mesNascimentoComprador: dataNasc1?.month,
        nomeComprador2: cel(idx('CESSIONÁRIO 2')).isEmpty
            ? null
            : cel(idx('CESSIONÁRIO 2')),
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
        // idxExato evita que "STATUS" case "STATUS ASSINATURA"/"STATUS FINANCEIRO"
        status: cel(idxExato('STATUS')).isEmpty ? 'Ativo' : cel(idxExato('STATUS')),
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
        statusAssinatura: StatusAssinatura.fromCsvLabel(cel(idx('STATUS ASSINATURA'))),
      ),
    );
  }

  return contratos;
}
