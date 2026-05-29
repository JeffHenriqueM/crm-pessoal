import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/contrato_model.dart';
import 'package:crm_pessoal/services/aniversariantes_pos_venda.dart';

/// Regra de aniversariantes do pós-venda.
///
/// Garantias vivas (green): casa por dia/mês ignorando o ano; comprador 2 conta;
/// campos vazios não entram. A guarda vermelha documenta o dedupe por NOME:
/// dois clientes distintos (CPFs diferentes) com o mesmo nome e aniversário hoje
/// resultam em apenas um na lista — o outro some. Ver ticket a abrir.
Contrato _comNascimento({
  required String localizador,
  required String nome,
  int? dia,
  int? mes,
  String? nome2,
  int? dia2,
  int? mes2,
  String? cpf,
}) {
  return Contrato(
    localizador: localizador,
    localizadorAtendimento: 'AT-$localizador',
    nomeComprador: nome,
    cpfComprador: cpf ?? '',
    diaNascimentoComprador: dia,
    mesNascimentoComprador: mes,
    nomeComprador2: nome2,
    diaNascimentoComprador2: dia2,
    mesNascimentoComprador2: mes2,
  );
}

void main() {
  group('aniversariantesEm', () {
    test('casa por dia/mês ignorando o ano de nascimento', () {
      final contratos = [
        _comNascimento(localizador: 'A', nome: 'Maria', dia: 15, mes: 3),
      ];

      final r = aniversariantesEm(contratos, DateTime(2024, 3, 15));

      expect(r, hasLength(1));
      expect(r.first.nome, 'Maria');
      expect(r.first.localizador, 'A');
    });

    test('não inclui quem faz aniversário em outro dia/mês', () {
      final contratos = [
        _comNascimento(localizador: 'A', nome: 'Maria', dia: 15, mes: 3),
      ];

      expect(aniversariantesEm(contratos, DateTime(2024, 4, 15)), isEmpty);
      expect(aniversariantesEm(contratos, DateTime(2024, 3, 16)), isEmpty);
    });

    test('inclui o comprador 2 quando é o aniversariante', () {
      final contratos = [
        _comNascimento(
          localizador: 'A',
          nome: 'Maria',
          dia: 1,
          mes: 1,
          nome2: 'José',
          dia2: 15,
          mes2: 3,
        ),
      ];

      final r = aniversariantesEm(contratos, DateTime(2024, 3, 15));

      expect(r.map((a) => a.nome), ['José']);
    });

    test('ignora contratos sem data de nascimento', () {
      final contratos = [
        _comNascimento(localizador: 'A', nome: 'Maria'),
        _comNascimento(localizador: 'B', nome: ''),
      ];

      expect(aniversariantesEm(contratos, DateTime(2024, 3, 15)), isEmpty);
    });

    test('mesma pessoa em vários contratos aparece uma vez', () {
      final contratos = [
        _comNascimento(
            localizador: 'A', nome: 'Maria', dia: 15, mes: 3, cpf: '111'),
        _comNascimento(
            localizador: 'B', nome: 'Maria', dia: 15, mes: 3, cpf: '111'),
      ];

      final r = aniversariantesEm(contratos, DateTime(2024, 3, 15));

      expect(r, hasLength(1));
    });

    test(
      'dois clientes distintos com o mesmo nome devem ser greetáveis',
      () {
        // Mesmo nome, CPFs diferentes → pessoas diferentes.
        final contratos = [
          _comNascimento(
              localizador: 'A', nome: 'João Silva', dia: 15, mes: 3, cpf: '111'),
          _comNascimento(
              localizador: 'B', nome: 'João Silva', dia: 15, mes: 3, cpf: '222'),
        ];

        final r = aniversariantesEm(contratos, DateTime(2024, 3, 15));

        expect(
          r,
          hasLength(2),
          reason:
              'Dedupe por nome descartou um cliente distinto (CPF diferente) '
              'que também faz aniversário hoje — o pós-venda deixa de parabenizá-lo. '
              'A deduplicação deveria usar uma identidade estável (ex.: CPF).',
        );
      },
      tags: 'bug-aberto',
    );
  });
}
