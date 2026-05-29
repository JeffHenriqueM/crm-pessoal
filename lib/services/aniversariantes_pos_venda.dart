import '../models/contrato_model.dart';

typedef Aniversariante = ({String nome, String localizador, String telefone});

/// Aniversariantes (compradores 1 e 2) cujo dia/mês de nascimento batem com
/// [dia]. Função pura extraída de `AbaPosVenda` — a data é injetada para ser
/// testável. Comportamento idêntico ao original (dedupe por nome).
List<Aniversariante> aniversariantesEm(List<Contrato> contratos, DateTime dia) {
  final d = dia.day;
  final m = dia.month;
  final vistos = <String>{};
  final resultado = <Aniversariante>[];

  for (final c in contratos) {
    if (c.diaNascimentoComprador == d &&
        c.mesNascimentoComprador == m &&
        c.nomeComprador.isNotEmpty &&
        vistos.add(c.nomeComprador)) {
      resultado.add((nome: c.nomeComprador, localizador: c.localizador, telefone: c.telefoneComprador));
    }
    final nome2 = c.nomeComprador2;
    if (nome2 != null &&
        nome2.isNotEmpty &&
        c.diaNascimentoComprador2 == d &&
        c.mesNascimentoComprador2 == m &&
        vistos.add(nome2)) {
      resultado.add((nome: nome2, localizador: c.localizador, telefone: c.telefoneComprador2 ?? ''));
    }
  }
  return resultado;
}
