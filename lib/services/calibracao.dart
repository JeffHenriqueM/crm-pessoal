// lib/services/calibracao.dart
//
// Calibração — onde o "achismo vira medido". Os pesos do Lead Score e do Risco
// de Silêncio foram uma PROPOSTA inicial. Esta lógica os confronta com os
// DESFECHOS REAIS (fechado vs perdido) para responder: cada sinal que a gente
// acha que prevê fechamento realmente prevê?
//
// Método (backtest sobre o snapshot): entre os leads DECIDIDOS (fechado ou
// perdido), para cada sinal medimos a taxa de fechamento de quem TEM o sinal
// contra quem NÃO tem. A diferença ("lift", em pontos percentuais) é o poder
// preditivo real do sinal:
//   • lift alto e positivo  → sinal vale o peso que demos (ou merece mais)
//   • lift ~0               → sinal é ruído, peso deveria cair
//   • lift negativo         → sinal está INVERTIDO, contradiz a intuição
//
// Pura e determinística — sem Firestore, sem DateTime.now() — 100% testável.
// Esta é a fundação local; para calibrar com volume e reconstruir o funil por
// etapa (transições de fase ao longo do tempo) usa-se o histórico exportado
// para BigQuery (ver docs/bigquery_calibracao.md).

import '../models/cliente_model.dart';
import '../models/fase_enum.dart';

/// Amostra mínima de leads decididos para a calibração ser confiável.
const int kMinAmostraCalibracao = 20;

/// Amostra mínima de um lado (com/sem) para o lift de um sinal valer.
const int kMinPorLado = 3;

/// Resultado da calibração de um único sinal.
class SinalCalibrado {
  final String rotulo;
  final int comSinal; // nº de decididos COM o sinal
  final int semSinal; // nº de decididos SEM o sinal
  final double fechamentoComSinal; // % que fechou entre os com sinal
  final double fechamentoSemSinal; // % que fechou entre os sem sinal

  const SinalCalibrado({
    required this.rotulo,
    required this.comSinal,
    required this.semSinal,
    required this.fechamentoComSinal,
    required this.fechamentoSemSinal,
  });

  /// Poder preditivo em pontos percentuais (com − sem).
  double get lift => fechamentoComSinal - fechamentoSemSinal;

  /// Há amostra dos dois lados para o lift significar algo.
  bool get confiavel => comSinal >= kMinPorLado && semSinal >= kMinPorLado;
}

/// Relatório completo: amostra, taxa-base e os sinais ordenados por poder.
class RelatorioCalibracao {
  final int amostra; // total de decididos
  final int fechados;
  final int perdidos;
  final double taxaBase; // % de fechamento geral
  final List<SinalCalibrado> sinais; // ordenados por lift desc

  const RelatorioCalibracao({
    required this.amostra,
    required this.fechados,
    required this.perdidos,
    required this.taxaBase,
    required this.sinais,
  });

  bool get amostraSuficiente => amostra >= kMinAmostraCalibracao;
}

/// Predicado nomeado de um sinal a calibrar.
class _Sinal {
  final String rotulo;
  final bool Function(Cliente) tem;
  const _Sinal(this.rotulo, this.tem);
}

// Sinais testados — espelham os bônus do Lead Score que dependem de dados que
// SOBREVIVEM ao desfecho (não usar fase atual nem follow-up, que mudam ao
// fechar/perder e contaminariam o backtest).
final List<_Sinal> _sinais = [
  _Sinal('Visitou', (c) => c.dataVisita != null),
  _Sinal('Esteve na sala', (c) => c.dataEntradaSala != null),
  _Sinal('Respondeu às mensagens',
      (c) => c.statusMensagem == 'enviada_com_resposta'),
  _Sinal('Ficou sem responder',
      (c) => c.statusMensagem == 'enviada_sem_resposta'),
];

/// Calibra os sinais contra os desfechos reais da carteira informada.
RelatorioCalibracao calibrarSinais(List<Cliente> clientes) {
  final decididos = clientes
      .where((c) =>
          c.fase == FaseCliente.fechado || c.fase == FaseCliente.perdido)
      .toList();

  final fechados =
      decididos.where((c) => c.fase == FaseCliente.fechado).length;
  final perdidos = decididos.length - fechados;
  final taxaBase =
      decididos.isEmpty ? 0.0 : (fechados / decididos.length) * 100;

  double pctFechados(Iterable<Cliente> grupo) {
    final lista = grupo.toList();
    if (lista.isEmpty) return 0;
    final f = lista.where((c) => c.fase == FaseCliente.fechado).length;
    return (f / lista.length) * 100;
  }

  final sinais = _sinais.map((s) {
    final com = decididos.where(s.tem).toList();
    final sem = decididos.where((c) => !s.tem(c)).toList();
    return SinalCalibrado(
      rotulo: s.rotulo,
      comSinal: com.length,
      semSinal: sem.length,
      fechamentoComSinal: pctFechados(com),
      fechamentoSemSinal: pctFechados(sem),
    );
  }).toList()
    ..sort((a, b) => b.lift.compareTo(a.lift));

  return RelatorioCalibracao(
    amostra: decididos.length,
    fechados: fechados,
    perdidos: perdidos,
    taxaBase: taxaBase,
    sinais: sinais,
  );
}
