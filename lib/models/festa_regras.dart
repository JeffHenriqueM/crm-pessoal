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

/// Ação ao comparar categoria atual com a recomendada.
String acaoFesta(String catAtual, String? recomendada) {
  if (recomendada == null) return 'mantem';
  final ra = rankCategoria[recomendada] ?? 0;
  final rc = rankCategoria[catAtual] ?? 0;
  if (ra > rc) return 'sobe';
  if (ra < rc) return 'desce';
  return 'mantem';
}
