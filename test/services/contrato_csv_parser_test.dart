import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/services/contrato_csv_parser.dart';

/// Parser de CSV de contratos (pós-venda).
///
/// O caminho feliz (cabeçalho bem-ordenado) é a garantia viva. As guardas
/// vermelhas documentam a fragilidade da resolução de coluna por `contains`
/// (primeiro match vence): quando duas colunas compartilham um prefixo/termo,
/// o campo entra trocado dependendo da ORDEM do cabeçalho. Ver ticket a abrir.
void main() {
  group('parsearCsvContratos — caminho feliz', () {
    test('mapeia as colunas e converte valores corretamente', () {
      const csv =
          'LOCALIZADOR,LOCALIZADOR ATENDIMENTO,DATA,CESSIONÁRIO 1,'
          'CPF/CNPJ cessionário 1,VALOR FINANCIADO,VALOR ATRASADO,'
          'STATUS FINANCEIRO\n'
          'LOC-1,AT-1,05/20/2024,Maria Silva,123.456.789-00,1500,0,Quitado\n';

      final contratos = parsearCsvContratos(csv);

      expect(contratos, hasLength(1));
      final c = contratos.first;
      expect(c.localizador, 'LOC-1');
      expect(c.localizadorAtendimento, 'AT-1');
      expect(c.nomeComprador, 'Maria Silva');
      expect(c.cpfComprador, '123.456.789-00');
      expect(c.valorFinanciado, 1500);
      expect(c.estaQuitado, isTrue);
      expect(c.dataContrato?.year, 2024);
      expect(c.dataContrato?.month, 5);
      expect(c.dataContrato?.day, 20);
    });

    test('captura o CÓDIGO (número do contrato) sem confundir com STATUS CRC', () {
      const csv = 'LOCALIZADOR,CÓDIGO,CESSIONÁRIO 1,STATUS CRC\n'
          'LOC-1,LMP-1590-320/Cota-15,Maria,OK\n'
          'LOC-2,,João,OK\n';

      final cs = parsearCsvContratos(csv);

      expect(cs[0].codigoContrato, 'LMP-1590-320/Cota-15');
      // Sem CÓDIGO → null (não string vazia).
      expect(cs[1].codigoContrato, isNull);
    });

    test('ignora linhas de rodapé "Qtd:" e cabeçalho sem dados', () {
      const csv = 'LOCALIZADOR,CESSIONÁRIO 1\n'
          'LOC-1,Ana\n'
          'Qtd:,1\n';

      final contratos = parsearCsvContratos(csv);

      expect(contratos.map((c) => c.localizador), ['LOC-1']);
    });
  });

  group('parsearCsvContratos — resolução de coluna (fragilidade)', () {
    test(
      'LOCALIZADOR não pode pegar a coluna LOCALIZADOR ATENDIMENTO',
      () {
        // Cabeçalho com "LOCALIZADOR ATENDIMENTO" ANTES de "LOCALIZADOR".
        const csv = 'LOCALIZADOR ATENDIMENTO,LOCALIZADOR,CESSIONÁRIO 1\n'
            'AT-99,LOC-1,Maria\n';

        final c = parsearCsvContratos(csv).first;

        expect(
          c.localizador,
          'LOC-1',
          reason:
              'idx("LOCALIZADOR") casou por contains com "LOCALIZADOR '
              'ATENDIMENTO" (primeiro match) — o id do contrato veio da coluna '
              'errada. A resolução deveria ser por nome exato de coluna.',
        );
      },
    );

    test(
      'DATA (contrato) não pode pegar uma coluna DATA NASCIMENTO/QUITAÇÃO',
      () {
        // "DATA NASCIMENTO CESSIONÁRIO 1" aparece ANTES da coluna "DATA".
        const csv =
            'LOCALIZADOR,DATA NASCIMENTO CESSIONÁRIO 1,DATA,CESSIONÁRIO 1\n'
            'LOC-1,15/03/1990,05/20/2024,Maria\n';

        final c = parsearCsvContratos(csv).first;

        expect(
          c.dataContrato?.year,
          2024,
          reason:
              'idx("DATA") casou por contains com "DATA NASCIMENTO '
              'CESSIONÁRIO 1" (primeiro match) — dataContrato pegou a data de '
              'nascimento em vez da data do contrato.',
        );
      },
    );
  });

  group('parsearCsvContratos — reversão (REVERTIDO / ORIGEM REVERSÃO)', () {
    test('lê revertido=true e origemReversao da planilha', () {
      const csv = 'LOCALIZADOR,CESSIONÁRIO 1,REVERTIDO,ORIGEM REVERSÃO\n'
          'LOC-1,Maria,Sim,LOC-ANTIGO\n';

      final c = parsearCsvContratos(csv).first;

      expect(c.revertido, isTrue);
      expect(c.origemReversao, 'LOC-ANTIGO');
    });

    test('revertido=false zera a origem (mesmo com coluna preenchida)', () {
      const csv = 'LOCALIZADOR,CESSIONÁRIO 1,REVERTIDO,ORIGEM REVERSÃO\n'
          'LOC-1,Maria,Não,LOC-ANTIGO\n';

      final c = parsearCsvContratos(csv).first;

      expect(c.revertido, isFalse);
      expect(c.origemReversao, isNull);
    });

    test('sem coluna REVERTIDO → false (não quebra)', () {
      const csv = 'LOCALIZADOR,CESSIONÁRIO 1\nLOC-1,Maria\n';
      final c = parsearCsvContratos(csv).first;
      expect(c.revertido, isFalse);
      expect(c.origemReversao, isNull);
    });
  });

  group('parsearExcelContratos — xlsx nativo', () {
    /// Monta um xlsx em memória com cabeçalho + linhas e devolve os bytes.
    Uint8List montarXlsx(List<List<CellValue?>> linhas) {
      final excel = Excel.createExcel();
      final aba = excel['Contratos'];
      for (final linha in linhas) {
        aba.appendRow(linha);
      }
      // Remove a aba padrão vazia ('Sheet1') para não confundir a seleção.
      if (excel.tables.containsKey('Sheet1')) excel.delete('Sheet1');
      return Uint8List.fromList(excel.encode()!);
    }

    test('mapeia números, datas (serial e tipada), texto e reversão', () {
      final bytes = montarXlsx([
        [
          TextCellValue('LOCALIZADOR'),
          TextCellValue('CESSIONÁRIO 1'),
          TextCellValue('DATA'),
          TextCellValue('VALOR INTEGRALIZADO'),
          TextCellValue('PERCENTUAL INTEGRALIZADO'),
          TextCellValue('STATUS FINANCEIRO'),
          TextCellValue('REVERTIDO'),
          TextCellValue('ORIGEM REVERSÃO'),
          TextCellValue('DATA NASCIMENTO CESSIONÁRIO 1'),
        ],
        [
          TextCellValue('4373'),
          TextCellValue('MARIA SILVA'),
          DateCellValue(year: 2026, month: 6, day: 13),
          DoubleCellValue(9084.43),
          DoubleCellValue(0),
          TextCellValue('Quitado'),
          BoolCellValue(true),
          TextCellValue('LOC-ANTIGO'),
          TextCellValue('15/03/1990'),
        ],
      ]);

      final contratos = parsearExcelContratos(bytes);

      expect(contratos, hasLength(1));
      final c = contratos.first;
      expect(c.localizador, '4373');
      expect(c.nomeComprador, 'MARIA SILVA');
      expect(c.valorIntegralizado, 9084.43);
      expect(c.dataContrato?.year, 2026);
      expect(c.dataContrato?.month, 6);
      expect(c.dataContrato?.day, 13);
      expect(c.dataNascimentoComprador?.year, 1990);
      expect(c.dataNascimentoComprador?.month, 3);
      expect(c.dataNascimentoComprador?.day, 15);
      // Quitado com 0% integralizado → percentualEfetivo = 100 (regra de negócio).
      expect(c.estaQuitado, isTrue);
      expect(c.percentualEfetivo, 100);
      expect(c.revertido, isTrue);
      expect(c.origemReversao, 'LOC-ANTIGO');
    });

    test('DATA como serial do Excel converte para a data correta', () {
      // Serial 44197 = 2021-01-01 (referência conhecida do Excel).
      final bytes = montarXlsx([
        [TextCellValue('LOCALIZADOR'), TextCellValue('DATA')],
        [TextCellValue('LOC-1'), DoubleCellValue(44197)],
      ]);

      final c = parsearExcelContratos(bytes).first;

      expect(c.dataContrato?.year, 2021);
      expect(c.dataContrato?.month, 1);
      expect(c.dataContrato?.day, 1);
    });

    test('serial inválido (negativo) preserva a data como nula', () {
      final bytes = montarXlsx([
        [TextCellValue('LOCALIZADOR'), TextCellValue('DATA')],
        [TextCellValue('LOC-1'), DoubleCellValue(-693593)],
      ]);

      final c = parsearExcelContratos(bytes).first;
      expect(c.dataContrato, isNull);
    });

    test('número como texto BR ("1.234,56") ainda é parseado', () {
      final bytes = montarXlsx([
        [TextCellValue('LOCALIZADOR'), TextCellValue('VALOR FINANCIADO')],
        [TextCellValue('LOC-1'), TextCellValue('1.234,56')],
      ]);

      final c = parsearExcelContratos(bytes).first;
      expect(c.valorFinanciado, 1234.56);
    });

    test('células numéricas vazias (<v></v>) não quebram a importação', () {
      // O export real da Central grava células numéricas vazias como <v></v>,
      // que faz num.parse('') estourar no leitor de xlsx. Aqui reproduzimos
      // isso esvaziando o <v> de uma célula e conferimos que parsearExcel
      // sanitiza e lê normalmente.
      final limpo = montarXlsx([
        [
          TextCellValue('LOCALIZADOR'),
          TextCellValue('VALOR INTEGRALIZADO'),
          TextCellValue('EXTRA'),
        ],
        [TextCellValue('LOC-1'), DoubleCellValue(1234), IntCellValue(999999)],
      ]);

      // Esvazia o <v> da célula EXTRA (999999) → simula o bug do export.
      final zip = ZipDecoder().decodeBytes(limpo);
      final saida = Archive();
      for (final f in zip.files) {
        if (f.isFile && f.name.startsWith('xl/worksheets/')) {
          final xml = utf8
              .decode(f.content as List<int>)
              .replaceAll('<v>999999</v>', '<v></v>');
          final d = utf8.encode(xml);
          saida.addFile(ArchiveFile(f.name, d.length, d));
        } else {
          saida.addFile(f);
        }
      }
      final corrompido = Uint8List.fromList(ZipEncoder().encode(saida)!);

      final contratos = parsearExcelContratos(corrompido);
      expect(contratos, hasLength(1));
      expect(contratos.first.localizador, 'LOC-1');
      expect(contratos.first.valorIntegralizado, 1234);
    });
  });

  group('parsearCsvContratos — terminador de linha e rodapé (export real)', () {
    test(
      'CRLF com campo entre aspas não pode perder linhas',
      () {
        // Export do Excel/Sheets vem em CRLF (\r\n) e com valores monetários
        // entre aspas. O parser fixa eol:'\n', deixando um \r após o " de
        // fechamento — o estado de aspas do CsvToListConverter desincroniza e
        // funde linhas. No arquivo real isso reduziu 500 contratos para 78.
        const csv = 'LOCALIZADOR,CESSIONÁRIO 1,VALOR FINANCIADO\r\n'
            'LOC-1,Maria,"1.500,00"\r\n'
            'LOC-2,João,"2.000,00"\r\n'
            'LOC-3,Ana,"3.000,00"\r\n';

        final cs = parsearCsvContratos(csv);

        expect(
          cs.map((c) => c.localizador),
          ['LOC-1', 'LOC-2', 'LOC-3'],
          reason:
              'CRLF + campo entre aspas funde linhas porque o parser usa '
              "eol:'\\n' e o \\r residual quebra o quoting. O conteúdo deveria "
              'ser normalizado (\\r\\n → \\n) ou o eol detectado antes do parse.',
        );
      },
    );

    test(
      'rodapé "Qtd: N" não pode entrar como contrato',
      () {
        // O rodapé real é "Qtd: 500 ", mas a guarda compara == 'Qtd:' (exato).
        const csv = 'LOCALIZADOR,CESSIONÁRIO 1\n'
            'LOC-1,Maria\n'
            'Qtd: 500 ,\n';

        final cs = parsearCsvContratos(csv);

        expect(
          cs.map((c) => c.localizador),
          ['LOC-1'],
          reason:
              "a guarda de rodapé compara localizador == 'Qtd:' (igualdade "
              'exata), mas o rodapé real é "Qtd: 500 " — vaza como um contrato '
              'fantasma. Deveria usar startsWith("Qtd:") após normalizar.',
        );
      },
    );
  });
}
