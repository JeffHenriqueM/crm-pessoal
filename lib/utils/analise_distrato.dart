import '../models/baixa_financeira_model.dart';
import '../models/contrato_model.dart';

/// Resultado da triagem de distrato (aba Distratar, Pós-Venda).
///
/// Dois rankings independentes — um contrato pode aparecer nos dois:
/// - [maioresAtrasos]: contratos com valor em atraso, do maior para o menor.
/// - [inadimplentes]: não-quitados com saldo que estão há 3+ meses sem pagar.
///
/// [ultimoPagamento] mapeia `localizador → data do último pagamento` (maior
/// `dataCredito` das baixas casadas), para a UI exibir a data; contrato ausente
/// do mapa = nenhuma baixa casada (nunca pagou).
class AnaliseDistrato {
  final List<Contrato> maioresAtrasos;
  final List<Contrato> inadimplentes;
  final Map<String, DateTime> ultimoPagamento;

  const AnaliseDistrato({
    required this.maioresAtrasos,
    required this.inadimplentes,
    required this.ultimoPagamento,
  });
}

/// Casa baixas a contratos e devolve o último pagamento (maior `dataCredito`)
/// por `localizador` de contrato.
///
/// Casamento por código (`BaixaFinanceira.documentoCar == Contrato.codigoContrato`,
/// normalizado em maiúsculas) — mesma chave que o relatório financeiro usa. Só
/// quando o contrato NÃO tem `codigoContrato` cai no casamento por nome
/// (`cliente == nomeComprador`). Não há fallback de código→nome para evitar que
/// o pagamento de uma cota mascare a inadimplência de outra do mesmo cliente.
Map<String, DateTime> ultimoPagamentoPorContrato(
  List<Contrato> contratos,
  List<BaixaFinanceira> baixas,
) {
  final maxPorCodigo = <String, DateTime>{};
  final maxPorNome = <String, DateTime>{};
  for (final b in baixas) {
    final cod = b.documentoCar.trim().toUpperCase();
    if (cod.isNotEmpty) {
      final atual = maxPorCodigo[cod];
      if (atual == null || b.dataCredito.isAfter(atual)) {
        maxPorCodigo[cod] = b.dataCredito;
      }
    }
    final nome = b.cliente.trim().toUpperCase();
    if (nome.isNotEmpty) {
      final atual = maxPorNome[nome];
      if (atual == null || b.dataCredito.isAfter(atual)) {
        maxPorNome[nome] = b.dataCredito;
      }
    }
  }

  final res = <String, DateTime>{};
  for (final c in contratos) {
    final cod = (c.codigoContrato ?? '').trim().toUpperCase();
    final DateTime? ultimo = cod.isNotEmpty
        ? maxPorCodigo[cod]
        : maxPorNome[c.nomeComprador.trim().toUpperCase()];
    if (ultimo != null) res[c.localizador] = ultimo;
  }
  return res;
}

/// Calcula os rankings da aba Distratar.
///
/// [hoje] permite injetar a data nos testes; [mesesInadimplencia] é o limiar de
/// "sem pagamento" (default 3 meses). Inadimplente = não-quitado +
/// `saldoRestante > 0` + (nunca pagou OU último pagamento antes de hoje−N meses).
AnaliseDistrato analisarDistrato(
  List<Contrato> contratos,
  List<BaixaFinanceira> baixas, {
  DateTime? hoje,
  int mesesInadimplencia = 3,
}) {
  final agora = hoje ?? DateTime.now();
  // DateTime normaliza o mês negativo (ex.: mês 0 → dezembro do ano anterior).
  final corte =
      DateTime(agora.year, agora.month - mesesInadimplencia, agora.day);
  final ultimos = ultimoPagamentoPorContrato(contratos, baixas);

  final maioresAtrasos =
      contratos.where((c) => c.estaAtivo && c.temAtrasos).toList()
        ..sort((a, b) => b.valorAtrasado.compareTo(a.valorAtrasado));

  final inadimplentes = contratos.where((c) {
    if (!c.estaAtivo) return false; // só contratos ativos podem ser distratados
    if (c.estaQuitado) return false;
    if (c.saldoRestante <= 0) return false;
    // Cruza com a fonte do contrato: precisa estar de fato em atraso. Sem isso,
    // "sem pagamento registrado" pega contratos cujas baixas só não casaram por
    // código (pagaram, mas R$ 0,00 em atraso) — falso positivo de inadimplência.
    if (!c.temAtrasos) return false;
    final ultimo = ultimos[c.localizador];
    if (ultimo == null) return true; // em atraso e nunca pagou
    return ultimo.isBefore(corte); // em atraso e último pagamento há N+ meses
  }).toList()
    ..sort((a, b) {
      final porAtraso = b.valorAtrasado.compareTo(a.valorAtrasado);
      if (porAtraso != 0) return porAtraso;
      return b.saldoRestante.compareTo(a.saldoRestante);
    });

  return AnaliseDistrato(
    maioresAtrasos: maioresAtrasos,
    inadimplentes: inadimplentes,
    ultimoPagamento: ultimos,
  );
}
