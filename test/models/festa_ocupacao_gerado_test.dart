import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/festa_ocupacao_gerado.dart';
import 'package:crm_pessoal/models/quarto_festa_socios.dart';

/// Guarda do arquivo gerado `festa_ocupacao_gerado.dart` (saída de
/// tool/festa/gerar_ocupacao.mjs a partir da lista do café do Hospedin).
///
/// Testa o CONTRATO da geração — não fixa nomes de hóspedes (que mudam a cada
/// lista de café). A associação de contrato (tier/%/ação) é feita à mão na tela;
/// por isso a base sai sempre "sem contrato".
void main() {
  final numerosFisicos = quartosFestaSocios.map((q) => q.numero).toSet();

  test('todo quarto ocupado existe no mapa físico (sem sobras que não renderizam)',
      () {
    final sobras =
        ocupacaoFesta.keys.where((n) => !numerosFisicos.contains(n)).toList();
    expect(sobras, isEmpty,
        reason: 'Quartos fora de quartosFestaSocios não aparecem na tela: $sobras');
  });

  test('301 não entra (fora do mapa físico) e 55/135/161 ficam vagos', () {
    for (final vago in ['301', '55', '135', '161']) {
      expect(ocupacaoFesta.containsKey(vago), isFalse,
          reason: 'Quarto $vago não deveria ter ocupação-base.');
    }
  });

  test('base sai sempre "sem contrato" (associação é manual na tela)', () {
    expect(ocupacaoFesta, isNotEmpty);
    for (final entry in ocupacaoFesta.entries) {
      final o = entry.value;
      expect(o.acao, 'semContrato', reason: 'quarto ${entry.key}');
      expect(o.tier, isNull, reason: 'quarto ${entry.key}');
      expect(o.pct, isNull, reason: 'quarto ${entry.key}');
      expect(o.confianca, 'sem', reason: 'quarto ${entry.key}');
      expect(o.atrasado, isFalse, reason: 'quarto ${entry.key}');
      expect(o.flags, isEmpty, reason: 'quarto ${entry.key}');
      expect(o.deveTrocar, isFalse, reason: 'quarto ${entry.key}');
      expect(o.ocupante.trim(), isNotEmpty, reason: 'quarto ${entry.key}');
    }
  });
}
