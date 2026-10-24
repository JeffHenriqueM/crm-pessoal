/// Uma semana do rodízio da Multipropriedade (calendário importado da planilha
/// "Calendário Multipropriedade Villamor"). Cada cota, dentro de um tier e dia
/// de check-in, recebe um conjunto fixo de semanas ao longo dos anos
/// (2027–2078). Dado estático, só leitura.
class SemanaMP {
  final int ano;
  final String entrada; // ISO yyyy-MM-dd
  final String saida; // ISO yyyy-MM-dd
  final String tipo; // 'Alta' | 'Média' (temporada)
  final String feriado; // '' se não houver

  const SemanaMP({
    required this.ano,
    required this.entrada,
    required this.saida,
    required this.tipo,
    required this.feriado,
  });

  bool get temFeriado => feriado.isNotEmpty;

  /// Chaves curtas vêm da importação (a=ano, e=entrada, s=saída, t=tipo,
  /// f=feriado) para manter os documentos do Firestore compactos.
  factory SemanaMP.fromMap(Map<String, dynamic> m) => SemanaMP(
        ano: (m['a'] as num?)?.toInt() ?? 0,
        entrada: m['e'] as String? ?? '',
        saida: m['s'] as String? ?? '',
        tipo: m['t'] as String? ?? '',
        feriado: m['f'] as String? ?? '',
      );
}
