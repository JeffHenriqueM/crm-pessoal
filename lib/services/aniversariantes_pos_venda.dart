import '../models/contrato_model.dart';

typedef Aniversariante = ({String nome, String localizador, String telefone});

/// Aniversariantes (compradores 1 e 2) cujo dia/mês de nascimento batem com
/// [dia]. Função pura extraída de `AbaPosVenda` — a data é injetada para ser
/// testável. Dedupe por CPF (identidade estável); quando CPF está vazio, usa
/// chave única por posição no contrato para não descartar homônimos distintos.
List<Aniversariante> aniversariantesEm(List<Contrato> contratos, DateTime dia) {
  final d = dia.day;
  final m = dia.month;
  final vistos = <String>{};
  final resultado = <Aniversariante>[];

  for (final c in contratos) {
    if (c.diaNascimentoComprador == d &&
        c.mesNascimentoComprador == m &&
        c.nomeComprador.isNotEmpty) {
      final chave = c.cpfComprador.isNotEmpty
          ? c.cpfComprador
          : '${c.localizador}_c1';
      if (vistos.add(chave)) {
        resultado.add((nome: c.nomeComprador, localizador: c.localizador, telefone: c.telefoneComprador));
      }
    }
    final nome2 = c.nomeComprador2;
    if (nome2 != null &&
        nome2.isNotEmpty &&
        c.diaNascimentoComprador2 == d &&
        c.mesNascimentoComprador2 == m) {
      final chave2 = (c.cpfComprador2 ?? '').isNotEmpty
          ? c.cpfComprador2!
          : '${c.localizador}_c2';
      if (vistos.add(chave2)) {
        resultado.add((nome: nome2, localizador: c.localizador, telefone: c.telefoneComprador2 ?? ''));
      }
    }
  }
  return resultado;
}
