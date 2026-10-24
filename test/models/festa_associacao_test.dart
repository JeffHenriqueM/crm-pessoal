import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/festa_associacao.dart';

/// Lookup reverso quarto→contrato que alimenta a variável `{apartamento}` dos
/// modelos de mensagem: dado o localizador do contrato, achar o número do
/// quarto vinculado nas associações manuais da Festa dos Sócios.
void main() {
  group('quartoDoContrato', () {
    final assocs = {
      '133': const FestaAssociacao(ocupante: 'Fulano', contratoId: 'LOC-1'),
      '208': const FestaAssociacao(
        ocupante: 'Casal',
        contratosIds: ['LOC-2', 'LOC-3'],
      ),
      '55': const FestaAssociacao(ocupante: '', vago: true),
    };

    test('acha o quarto pelo contratoId', () {
      expect(quartoDoContrato(assocs, 'LOC-1'), '133');
    });

    test('acha o quarto por qualquer um dos contratosIds combinados', () {
      expect(quartoDoContrato(assocs, 'LOC-2'), '208');
      expect(quartoDoContrato(assocs, 'LOC-3'), '208');
    });

    test('contrato não associado retorna null', () {
      expect(quartoDoContrato(assocs, 'LOC-999'), isNull);
    });

    test('localizador vazio/nulo retorna null', () {
      expect(quartoDoContrato(assocs, ''), isNull);
      expect(quartoDoContrato(assocs, '   '), isNull);
      expect(quartoDoContrato(assocs, null), isNull);
    });

    test('ignora quartos vagos mesmo que tivessem o vínculo', () {
      final comVago = {
        '55': const FestaAssociacao(
            ocupante: '', vago: true, contratoId: 'LOC-9'),
      };
      expect(quartoDoContrato(comVago, 'LOC-9'), isNull);
    });
  });
}
