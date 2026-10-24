// Agenda de ocupação da Multipropriedade: entradas (check-in) e saídas
// (check-out) de sócios por dia, agregadas a partir dos contratos ativos
// cruzados com o calendário de rodízio.

/// Um sócio entrando ou saindo num dia.
class EventoOcupacao {
  final String localizador; // do contrato (p/ abrir a ficha depois)
  final String nome; // comprador
  final String bloco; // rótulo original ("B (HERA)")
  final String imovel;
  final String tier; // ouro | prata | bronze
  final int cota;
  final String dia; // dia de check-in
  final String tipoSemana; // 'Alta' | 'Média'
  final String feriado;

  const EventoOcupacao({
    required this.localizador,
    required this.nome,
    required this.bloco,
    required this.imovel,
    required this.tier,
    required this.cota,
    required this.dia,
    required this.tipoSemana,
    required this.feriado,
  });
}

/// Índice de ocupação por dia (chave ISO 'yyyy-MM-dd').
class OcupacaoMP {
  final Map<String, List<EventoOcupacao>> entradasPorDia;
  final Map<String, List<EventoOcupacao>> saidasPorDia;
  final int ativos; // contratos ativos considerados
  final int naoResolvidos; // ativos sem calendário (bloco/tier/dia faltando)

  const OcupacaoMP({
    required this.entradasPorDia,
    required this.saidasPorDia,
    required this.ativos,
    required this.naoResolvidos,
  });

  List<EventoOcupacao> entradasEm(DateTime d) =>
      entradasPorDia[_chave(d)] ?? const [];
  List<EventoOcupacao> saidasEm(DateTime d) =>
      saidasPorDia[_chave(d)] ?? const [];

  static String _chave(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
