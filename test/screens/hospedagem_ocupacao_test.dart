import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/festa_associacao.dart';
import 'package:crm_pessoal/models/quarto_festa_socios.dart';
import 'package:crm_pessoal/screens/hospedagem_screen.dart';

/// Sinal "ATRASADO" do mapa da Hospedagem.
///
/// Regra: quando o mapa `atrasoPorContrato` (localizador → tem atraso) conhece
/// algum contrato vinculado ao quarto, o atraso é calculado **ao vivo** a partir
/// dele (refletindo a última importação). Sem o mapa, ou para contratos
/// desconhecidos, mantém-se o snapshot salvo na associação (`a.atrasado`).
void main() {
  const quarto = QuartoFestaSocios('52', CategoriaQuarto.luxo);

  FestaAssociacao assoc({
    List<String> contratos = const ['LOC-1'],
    bool atrasado = false,
  }) =>
      FestaAssociacao(
        contratoId: contratos.isNotEmpty ? contratos.first : null,
        contratosIds: contratos,
        ocupante: 'Maria Silva',
        tier: 'prata',
        pct: 15,
        atrasado: atrasado,
      );

  group('ocupacaoEfetiva — atraso ao vivo', () {
    test('contrato em atraso na planilha → ATRASADO mesmo se snapshot era false',
        () {
      final o = ocupacaoEfetiva(
        quarto,
        {'52': assoc(atrasado: false)},
        atrasoPorContrato: {'LOC-1': true},
      );

      expect(o?.atrasado, isTrue);
      expect(o?.flags, contains('ATRASADO'));
    });

    test('contrato sem atraso na planilha → limpa o ATRASADO antigo (snapshot true)',
        () {
      final o = ocupacaoEfetiva(
        quarto,
        {'52': assoc(atrasado: true)},
        atrasoPorContrato: {'LOC-1': false},
      );

      expect(o?.atrasado, isFalse);
      expect(o?.flags, isNot(contains('ATRASADO')));
    });

    test('sem o mapa → preserva o snapshot da associação', () {
      final semAtraso = ocupacaoEfetiva(quarto, {'52': assoc(atrasado: false)});
      final comAtraso = ocupacaoEfetiva(quarto, {'52': assoc(atrasado: true)});

      expect(semAtraso?.atrasado, isFalse);
      expect(comAtraso?.atrasado, isTrue);
    });

    test('contrato vinculado fora do mapa → cai no snapshot (não inventa atraso)',
        () {
      final o = ocupacaoEfetiva(
        quarto,
        {'52': assoc(contratos: ['LOC-9'], atrasado: false)},
        atrasoPorContrato: {'LOC-1': true}, // não cobre LOC-9
      );

      expect(o?.atrasado, isFalse);
    });

    test('multi-contrato: basta um em atraso para marcar ATRASADO', () {
      final o = ocupacaoEfetiva(
        quarto,
        {'52': assoc(contratos: ['LOC-1', 'LOC-2'], atrasado: false)},
        atrasoPorContrato: {'LOC-1': false, 'LOC-2': true},
      );

      expect(o?.atrasado, isTrue);
    });
  });
}
