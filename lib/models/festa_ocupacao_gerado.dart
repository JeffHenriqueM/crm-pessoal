// GERADO AUTOMATICAMENTE — não editar à mão.
// Fonte: tool/festa/gerar_ocupacao.mjs a partir de tool/festa/cafe_hospedin.json
// Ocupação da Festa dos Sócios.
// Base = só o nome do hóspede por quarto; tier/%/ação (sobe|desce|mantem) vêm da
// associação manual do contrato na tela (ocupacaoEfetiva). acao inicial:
// 'semContrato' até o gestor associar.
//
// 2027 (28/03 a 01/04/2027): ocupação-base ZERADA para abrir novas reservas
// manuais. Quando chegar a lista do café do Hospedin 2027, regenerar com
// gerar_ocupacao.mjs a partir do novo cafe_hospedin.json.
class OcupacaoQuarto {
  final String ocupante;
  final String? tier;
  final int? pct;
  final bool atrasado;
  final String acao;
  final String? recomendada;
  final String confianca; // ok | fuzzy | sem
  final List<String> flags;
  const OcupacaoQuarto({required this.ocupante, this.tier, this.pct, required this.atrasado, required this.acao, this.recomendada, required this.confianca, this.flags = const []});
  bool get deveTrocar => acao == 'sobe' || acao == 'desce';
}

const Map<String, OcupacaoQuarto> ocupacaoFesta = {};
