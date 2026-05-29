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
