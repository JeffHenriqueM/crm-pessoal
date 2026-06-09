// lib/utils/negociacao_regras.dart
//
// Regras de negócio puras de negociação, isoladas para teste (#52).

/// Limite de parcelas que uma negociação pode ter SEM virar "Especial".
///
/// Produtos Diamante liberam até 100x (sem necessidade de negociação
/// especial); os demais mantêm o limite padrão de 80x. A identificação do
/// tier Diamante é feita pelo nome do produto, de forma consistente com a
/// detecção de Bronze/Prata/Ouro já usada no cálculo de economia.
int limiteParcelasNormais(String? nomeProduto) {
  final nome = (nomeProduto ?? '').toLowerCase();
  if (nome.contains('diamante')) return 100;
  return 80;
}
