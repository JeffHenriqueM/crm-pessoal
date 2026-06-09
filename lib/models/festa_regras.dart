// lib/models/festa_regras.dart
//
// Regras de alocação da Festa dos Sócios em Dart (espelho da análise que gera
// festa_ocupacao_gerado.dart). Usadas para RECALCULAR a recomendação quando o
// gestor associa manualmente um quarto a um contrato.
import 'quarto_festa_socios.dart';

/// Ranking de valor das categorias (1 = mais simples … 8 = melhor).
const Map<String, int> rankCategoria = {
  'luxo': 1,
  'studio': 2,
  'triplo': 3,
  'comfort': 4,
  'master': 5,
  'duplex': 6,
  'suiteDuplex': 7,
  'suiteVillamor': 8,
};

/// Mapeia a categoria física do quarto (enum) para a chave de ranking.
String categoriaKey(CategoriaQuarto c) {
  switch (c) {
    case CategoriaQuarto.luxo:
      return 'luxo';
    case CategoriaQuarto.studioRoom:
      return 'studio';
    case CategoriaQuarto.triplo:
      return 'triplo';
    case CategoriaQuarto.master:
      return 'master';
    case CategoriaQuarto.comfortTerreo:
    case CategoriaQuarto.comfort1Andar:
    case CategoriaQuarto.comfort2Andar:
      return 'comfort';
    case CategoriaQuarto.duplex:
      return 'duplex';
    case CategoriaQuarto.suiteDuplex:
      return 'suiteDuplex';
    case CategoriaQuarto.suiteVillamor:
      return 'suiteVillamor';
  }
}

/// Deriva o tier da cota a partir do nome do produto (+ cota 'Integral').
String tierDeProduto(String produto, String cota) {
  final p = produto.toUpperCase();
  if (cota.toLowerCase() == 'integral') return 'integral';
  if (p.contains('DIAMANTE')) return 'diamante';
  if (p.contains('OURO')) return 'ouro';
  if (p.contains('PRATA')) return 'prata';
  if (p.contains('BRONZE')) return 'bronze';
  return '?';
}

class RecomendacaoFesta {
  final String? categoria; // chave de rankCategoria
  final List<String> flags;
  final bool naoVem;
  const RecomendacaoFesta(this.categoria, this.flags, this.naoVem);
}

/// Aplica as regras cota × % integralizado → categoria recomendada + flags.
RecomendacaoFesta recomendarFesta(String tier, num pct) {
  final flags = <String>[];
  final p = pct.round();
  if (p < 9) flags.add('<9%');
  if (tier == 'integral' || tier == 'diamante') {
    return RecomendacaoFesta('suiteVillamor', flags, false);
  }
  if (tier == 'ouro') {
    if (p < 9) {
      flags.add('OURO<9% não deveria vir');
      return RecomendacaoFesta('comfort', flags, true);
    }
    return RecomendacaoFesta('comfort', flags, false);
  }
  if (tier == 'prata') {
    return RecomendacaoFesta(pct < 20 ? 'luxo' : 'comfort', flags, false);
  }
  if (tier == 'bronze') {
    return RecomendacaoFesta(pct < 50 ? 'luxo' : 'comfort', flags, false);
  }
  return RecomendacaoFesta(null, flags, false);
}

/// Pontos por tier para combinar contratos ("escada por pontos"):
/// bronze+bronze=prata, prata+prata=ouro, ouro+ouro=diamante.
const Map<String, int> _pontosTier = {
  'bronze': 1,
  'prata': 2,
  'ouro': 4,
  'diamante': 8,
  'integral': 8,
};

String? _tierDePontos(int pts) {
  if (pts >= 8) return 'diamante';
  if (pts >= 4) return 'ouro';
  if (pts >= 2) return 'prata';
  if (pts >= 1) return 'bronze';
  return null;
}

/// Combina vários contratos (tier + %) de um mesmo sócio/casal num único par
/// efetivo: soma os "pontos" dos tiers (escada) e soma os % (limitado a 100).
/// 'integral' domina (vira sempre suíte Villamor pela regra). Um único contrato
/// retorna o próprio tier/%, mantendo o comportamento anterior.
({String tier, double pct}) combinarContratosFesta(
    List<({String tier, double pct})> contratos) {
  if (contratos.isEmpty) return (tier: '?', pct: 0);
  final pctSoma =
      contratos.fold<double>(0, (s, c) => s + c.pct).clamp(0, 100).toDouble();
  if (contratos.any((c) => c.tier == 'integral')) {
    return (tier: 'integral', pct: pctSoma);
  }
  final pontos =
      contratos.fold<int>(0, (s, c) => s + (_pontosTier[c.tier] ?? 0));
  return (tier: _tierDePontos(pontos) ?? '?', pct: pctSoma);
}

/// Classificação do hóspede no evento:
///  • 'voucher'  → sócio com mais de 10% pago e em dia (sem atraso);
///  • 'pagante'  → não-sócios, sócios em atraso, ou sócios com menos de 10% pago.
/// (10% conta como atingido → voucher.)
String tipoEventoFesta({
  required bool socio,
  required num pct,
  required bool atrasado,
}) {
  if (socio && !atrasado && pct >= 10) return 'voucher';
  return 'pagante';
}

/// Conta "casais" num quarto: cada nome separado por " + " conta como 1 casal.
int contarCasais(String ocupante) => ocupante
    .split('+')
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .length;

/// Ação ao comparar categoria atual com a recomendada.
String acaoFesta(String catAtual, String? recomendada) {
  if (recomendada == null) return 'mantem';
  final ra = rankCategoria[recomendada] ?? 0;
  final rc = rankCategoria[catAtual] ?? 0;
  if (ra > rc) return 'sobe';
  if (ra < rc) return 'desce';
  return 'mantem';
}
