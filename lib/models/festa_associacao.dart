// lib/models/festa_associacao.dart
//
// Ajuste MANUAL de um quarto da Festa dos Sócios, feito pelo gestor:
//  • vínculo a um contrato (sócio) — guarda snapshot de tier/% para recalcular; ou
//  • categoria manual — quando o hóspede não tem contrato (ex.: Carmem Lucia),
//    o gestor define direto a categoria de destino.

class FestaAssociacao {
  final String? contratoId;
  final String ocupante; // nome exibido
  final String? tier; // bronze/prata/ouro/diamante/integral (vínculo c/ contrato)
  final double? pct; // % integralizado (vínculo c/ contrato)
  final bool atrasado;
  final String? categoriaManual; // chave de categoria, quando definida à mão
  final bool vago; // quarto esvaziado por uma movimentação manual
  final String? origem; // nº do quarto de onde o ocupante veio (movimentação)
  final String? associadoPorNome;

  const FestaAssociacao({
    this.contratoId,
    required this.ocupante,
    this.tier,
    this.pct,
    this.atrasado = false,
    this.categoriaManual,
    this.vago = false,
    this.origem,
    this.associadoPorNome,
  });

  bool get ehManual => categoriaManual != null;

  Map<String, dynamic> toMap() => {
        if (contratoId != null) 'contratoId': contratoId,
        'ocupante': ocupante,
        if (tier != null) 'tier': tier,
        if (pct != null) 'pct': pct,
        'atrasado': atrasado,
        if (categoriaManual != null) 'categoriaManual': categoriaManual,
        if (vago) 'vago': true,
        if (origem != null) 'origem': origem,
      };

  factory FestaAssociacao.fromMap(Map<String, dynamic> d) => FestaAssociacao(
        contratoId: d['contratoId'] as String?,
        ocupante: d['ocupante'] as String? ?? '',
        tier: d['tier'] as String?,
        pct: (d['pct'] as num?)?.toDouble(),
        atrasado: d['atrasado'] == true,
        categoriaManual: d['categoriaManual'] as String?,
        vago: d['vago'] == true,
        origem: d['origem'] as String?,
        associadoPorNome: d['validadoPorNome'] as String? ??
            d['associadoPorNome'] as String?,
      );
}
