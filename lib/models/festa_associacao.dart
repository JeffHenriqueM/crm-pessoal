// lib/models/festa_associacao.dart
//
// Ajuste MANUAL de um quarto da Festa dos Sócios, feito pelo gestor:
//  • vínculo a um contrato (sócio) — guarda snapshot de tier/% para recalcular; ou
//  • categoria manual — quando o hóspede não tem contrato (ex.: Carmem Lucia),
//    o gestor define direto a categoria de destino.

class FestaAssociacao {
  final String? contratoId;
  final List<String> contratosIds; // localizadores combinados (multi-contrato)
  final String ocupante; // nome exibido
  final String? tier; // bronze/prata/ouro/diamante/integral (vínculo c/ contrato)
  final double? pct; // % integralizado (vínculo c/ contrato)
  final bool atrasado;
  final String? categoriaManual; // chave de categoria, quando definida à mão
  final String? tipo; // 'pagante' | 'convidado' (null = sócio)
  final String? observacao; // anotação livre do gestor sobre a reserva
  final bool vago; // quarto esvaziado por uma movimentação manual
  final String? origem; // nº do quarto de onde o ocupante veio (movimentação)
  final String? associadoPorNome;

  const FestaAssociacao({
    this.contratoId,
    this.contratosIds = const [],
    required this.ocupante,
    this.tier,
    this.pct,
    this.atrasado = false,
    this.categoriaManual,
    this.tipo,
    this.observacao,
    this.vago = false,
    this.origem,
    this.associadoPorNome,
  });

  bool get ehManual => categoriaManual != null;

  /// Quantos contratos estão combinados neste vínculo (mín. 1 se há contrato).
  int get qtdContratos =>
      contratosIds.isNotEmpty ? contratosIds.length : (contratoId != null ? 1 : 0);

  Map<String, dynamic> toMap() => {
        if (contratoId != null) 'contratoId': contratoId,
        if (contratosIds.isNotEmpty) 'contratosIds': contratosIds,
        'ocupante': ocupante,
        if (tier != null) 'tier': tier,
        if (pct != null) 'pct': pct,
        'atrasado': atrasado,
        if (categoriaManual != null) 'categoriaManual': categoriaManual,
        if (tipo != null) 'tipo': tipo,
        if (observacao != null) 'observacao': observacao,
        if (vago) 'vago': true,
        if (origem != null) 'origem': origem,
      };

  factory FestaAssociacao.fromMap(Map<String, dynamic> d) => FestaAssociacao(
        contratoId: d['contratoId'] as String?,
        contratosIds: (d['contratosIds'] as List?)?.cast<String>() ?? const [],
        ocupante: d['ocupante'] as String? ?? '',
        tier: d['tier'] as String?,
        pct: (d['pct'] as num?)?.toDouble(),
        atrasado: d['atrasado'] == true,
        categoriaManual: d['categoriaManual'] as String?,
        tipo: d['tipo'] as String?,
        observacao: d['observacao'] as String?,
        vago: d['vago'] == true,
        origem: d['origem'] as String?,
        associadoPorNome: d['validadoPorNome'] as String? ??
            d['associadoPorNome'] as String?,
      );
}
