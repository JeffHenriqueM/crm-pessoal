// lib/models/festa_espera.dart
//
// Lista de espera por categoria da Festa dos Sócios. Quando uma categoria está
// lotada, o gestor "estaciona" o hóspede aqui (liberando o quarto de origem) e,
// ao abrir vaga na categoria, traz a pessoa da espera para um quarto.

class FestaEspera {
  final String id; // id do documento (vazio ao criar)
  final String ocupante;
  final String categoria; // chave de categoria (rankCategoria): luxo, comfort, …
  final String? tier;
  final double? pct;
  final bool atrasado;
  final String? origem; // nº do quarto de onde saiu
  final String? quartoDesejado; // nº do quarto que o hóspede deseja (opcional)
  final String? contratoId;
  final String? categoriaManual;
  final String? adicionadoPorNome;

  const FestaEspera({
    this.id = '',
    required this.ocupante,
    required this.categoria,
    this.tier,
    this.pct,
    this.atrasado = false,
    this.origem,
    this.quartoDesejado,
    this.contratoId,
    this.categoriaManual,
    this.adicionadoPorNome,
  });

  Map<String, dynamic> toMap() => {
        'ocupante': ocupante,
        'categoria': categoria,
        if (tier != null) 'tier': tier,
        if (pct != null) 'pct': pct,
        'atrasado': atrasado,
        if (origem != null) 'origem': origem,
        if (quartoDesejado != null) 'quartoDesejado': quartoDesejado,
        if (contratoId != null) 'contratoId': contratoId,
        if (categoriaManual != null) 'categoriaManual': categoriaManual,
      };

  factory FestaEspera.fromMap(String id, Map<String, dynamic> d) => FestaEspera(
        id: id,
        ocupante: d['ocupante'] as String? ?? '',
        categoria: d['categoria'] as String? ?? '?',
        tier: d['tier'] as String?,
        pct: (d['pct'] as num?)?.toDouble(),
        atrasado: d['atrasado'] == true,
        origem: d['origem'] as String?,
        quartoDesejado: d['quartoDesejado'] as String?,
        contratoId: d['contratoId'] as String?,
        categoriaManual: d['categoriaManual'] as String?,
        adicionadoPorNome: d['adicionadoPorNome'] as String?,
      );
}
