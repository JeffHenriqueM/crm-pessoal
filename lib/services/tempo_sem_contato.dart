// lib/services/tempo_sem_contato.dart
//
// Alerta de "Tempo sem contato" (ticket #48) — lógica PURA e determinística
// que classifica há quantos dias um lead ATIVO está sem contato, em três
// faixas de cor:
//   🟡 Atenção → 15 a 19 dias sem contato (amarelo)
//   🟠 Alerta  → 20 a 29 dias sem contato (laranja)
//   🔴 Crítico → 30+ dias sem contato (vermelho) — meta: nenhum lead deve
//                passar de 30 dias sem uma mensagem.
//   ⚪ Em dia  → menos de 15 dias, ou lead não-ativo (fechado/perdido/atendimento)
//
// É um indicador SIMPLES por recência, separado do "Risco de Silêncio"
// (risco_silencio.dart), que é mais rico (follow-up vencido, sem-resposta) e
// usa outros thresholds. Aqui só importa o número de dias desde o último
// contato.
//
// Por que pura: não toca Firestore nem DateTime.now() — recebe `agora` como
// parâmetro, ficando 100% testável no `flutter test`. "Dias sem contato" usa
// `ultimoContato`; o chamador faz fallback para `dataAtualizacao` em leads
// antigos ainda sem interação registrada (ver avaliarTempoSemContatoCliente).

import 'package:flutter/material.dart';

import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import 'risco_silencio.dart' show faseEhAtiva;

/// Faixa de alerta por tempo sem contato.
enum AlertaTempoContato {
  emDia, // < 15 dias, ou lead não-ativo
  atencao, // 15–19 dias (amarelo)
  alerta, // 20–29 dias (laranja)
  critico, // 30+ dias (vermelho)
}

/// Thresholds (em dias) do ticket #48.
const int kDiasAtencao = 15;
const int kDiasAlerta = 20;
const int kDiasCritico = 30;

extension AlertaTempoContatoX on AlertaTempoContato {
  String get rotulo {
    switch (this) {
      case AlertaTempoContato.emDia:
        return 'Em dia';
      case AlertaTempoContato.atencao:
        return 'Atenção';
      case AlertaTempoContato.alerta:
        return 'Alerta';
      case AlertaTempoContato.critico:
        return 'Crítico';
    }
  }

  /// Cor do indicador. `emDia` não tem cor de alerta (retorna null).
  Color? get cor {
    switch (this) {
      case AlertaTempoContato.emDia:
        return null;
      case AlertaTempoContato.atencao:
        return const Color(0xFFF9A825); // amarelo (amber.shade800)
      case AlertaTempoContato.alerta:
        return const Color(0xFFEF6C00); // laranja (orange.shade800)
      case AlertaTempoContato.critico:
        return const Color(0xFFC62828); // vermelho (red.shade700)
    }
  }

  /// Severidade (maior = mais urgente) — para ordenar listas.
  int get severidade => index;

  /// Verdadeiro quando há alerta de cor (≥ 15 dias).
  bool get temAlerta => this != AlertaTempoContato.emDia;
}

/// Classifica a faixa a partir do número de dias sem contato.
AlertaTempoContato faixaPorDias(int dias) {
  if (dias >= kDiasCritico) return AlertaTempoContato.critico;
  if (dias >= kDiasAlerta) return AlertaTempoContato.alerta;
  if (dias >= kDiasAtencao) return AlertaTempoContato.atencao;
  return AlertaTempoContato.emDia;
}

/// Resultado: faixa + dias sem contato.
class AvaliacaoTempoContato {
  final AlertaTempoContato faixa;
  final int diasSemContato;

  const AvaliacaoTempoContato({
    required this.faixa,
    required this.diasSemContato,
  });

  bool get temAlerta => faixa.temAlerta;
}

/// Avalia o tempo sem contato a partir dos sinais primitivos.
/// Determinística: recebe `agora` em vez de chamar DateTime.now().
/// Leads não-ativos (fechado/perdido/atendimento) ficam sempre `emDia`.
AvaliacaoTempoContato avaliarTempoSemContato({
  required FaseCliente fase,
  required DateTime ultimoContato,
  required DateTime agora,
}) {
  if (!faseEhAtiva(fase)) {
    return const AvaliacaoTempoContato(
      faixa: AlertaTempoContato.emDia,
      diasSemContato: 0,
    );
  }
  final dias = agora.difference(ultimoContato).inDays;
  final diasNorm = dias < 0 ? 0 : dias;
  return AvaliacaoTempoContato(
    faixa: faixaPorDias(diasNorm),
    diasSemContato: diasNorm,
  );
}

/// Conveniência: avalia direto a partir de um [Cliente].
/// Usa `ultimoContato` quando existir; senão cai para `dataAtualizacao`
/// (leads antigos que ainda não tiveram interação registrada).
AvaliacaoTempoContato avaliarTempoSemContatoCliente(
  Cliente c, {
  required DateTime agora,
}) {
  return avaliarTempoSemContato(
    fase: c.fase,
    ultimoContato: c.ultimoContato ?? c.dataAtualizacao,
    agora: agora,
  );
}
