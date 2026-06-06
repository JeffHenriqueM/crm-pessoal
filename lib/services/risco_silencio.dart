// lib/services/risco_silencio.dart
//
// Risco de Silêncio (churn) — lógica PURA e determinística para classificar
// quão "frio" está um lead ativo, orientada por RECÊNCIA DE CONTATO.
//
// Regras de negócio (definidas com o time comercial):
//   🔴 Crítico   → follow-up vencido (contato atrasado) OU > 15 dias sem contato
//   🔷 Esfriando → 8 a 15 dias sem contato
//   🟡 Observar  → ≤ 7 dias sem contato, mas com sinal de alerta (sem resposta)
//   ⚪ Sem risco → ≤ 7 dias e respondendo (fica fora do radar)
//
// Por que pura: não toca Firestore nem DateTime.now() internamente — recebe
// `agora` como parâmetro. Isso a torna 100% testável no `flutter test` (sem
// emulador/Java) e pronta para ser movida a uma Cloud Function depois, sem
// reescrever a regra.
//
// "Dias sem contato" usa `ultimoContato` (gravado ao lançar uma interação).
// Para leads antigos ainda sem esse dado, o chamador faz fallback para
// `dataAtualizacao` (ver avaliarRiscoCliente).

import '../models/cliente_model.dart';
import '../models/fase_enum.dart';

/// Nível de risco de um lead parar de responder.
enum NivelRisco {
  nenhum, // engajado / sem sinais — ou lead não-ativo (fechado/perdido/atendimento)
  observar, // recente, mas com sinal de alerta
  esfriando, // 8–15 dias sem contato
  critico, // follow-up vencido ou > 15 dias sem contato
}

extension NivelRiscoX on NivelRisco {
  String get rotulo {
    switch (this) {
      case NivelRisco.nenhum:
        return 'Sem risco';
      case NivelRisco.observar:
        return 'Observar';
      case NivelRisco.esfriando:
        return 'Esfriando';
      case NivelRisco.critico:
        return 'Crítico';
    }
  }

  /// Ordem de severidade (maior = mais urgente) — usada para ordenar a lista.
  int get severidade {
    switch (this) {
      case NivelRisco.nenhum:
        return 0;
      case NivelRisco.observar:
        return 1;
      case NivelRisco.esfriando:
        return 2;
      case NivelRisco.critico:
        return 3;
    }
  }

  /// Verdadeiro para níveis que pedem ação do vendedor.
  bool get exigeAcao => severidade >= NivelRisco.observar.severidade;
}

/// Resultado: nível, dias sem contato, se há follow-up vencido e motivos.
class AvaliacaoRisco {
  final NivelRisco nivel;
  final int diasSemContato;
  final bool contatoAtrasado;
  final List<String> motivos;

  const AvaliacaoRisco({
    required this.nivel,
    required this.diasSemContato,
    required this.contatoAtrasado,
    required this.motivos,
  });

  bool get exigeAcao => nivel.exigeAcao;
}

/// Fases consideradas "ativas" — só elas podem estar em risco de silêncio.
/// `atendimento` ainda não é lead efetivo; `fechado`/`perdido` são desfechos.
bool faseEhAtiva(FaseCliente fase) {
  switch (fase) {
    case FaseCliente.prospeccao:
    case FaseCliente.contato:
    case FaseCliente.negociacao:
    case FaseCliente.visita:
      return true;
    case FaseCliente.atendimento:
    case FaseCliente.fechado:
    case FaseCliente.perdido:
      return false;
  }
}

/// Avalia o risco de silêncio a partir dos sinais primitivos.
///
/// Determinística: recebe `agora` em vez de chamar DateTime.now().
AvaliacaoRisco avaliarRiscoSilencio({
  required FaseCliente fase,
  required DateTime ultimoContato,
  required DateTime agora,
  DateTime? proximoContato,
  String? statusMensagem,
  int noResponseCount = 0,
}) {
  // Leads não-ativos não entram no radar de churn.
  if (!faseEhAtiva(fase)) {
    return const AvaliacaoRisco(
        nivel: NivelRisco.nenhum,
        diasSemContato: 0,
        contatoAtrasado: false,
        motivos: []);
  }

  final dias = agora.difference(ultimoContato).inDays;
  final atrasado =
      proximoContato != null && proximoContato.isBefore(agora);
  final semResposta =
      noResponseCount > 0 || statusMensagem == 'enviada_sem_resposta';

  // ── Classificação (a mais severa vence) ──────────────────────────────────
  final NivelRisco nivel;
  if (atrasado || dias > 15) {
    nivel = NivelRisco.critico;
  } else if (dias > 7) {
    nivel = NivelRisco.esfriando;
  } else if (semResposta) {
    nivel = NivelRisco.observar;
  } else {
    nivel = NivelRisco.nenhum;
  }

  if (nivel == NivelRisco.nenhum) {
    return AvaliacaoRisco(
        nivel: nivel,
        diasSemContato: dias < 0 ? 0 : dias,
        contatoAtrasado: false,
        motivos: const []);
  }

  // ── Motivos legíveis ─────────────────────────────────────────────────────
  final motivos = <String>[];
  if (atrasado) {
    final d = agora.difference(proximoContato).inDays;
    motivos.add('Follow-up vencido há $d dia(s)');
  }
  if (dias > 7) {
    motivos.add('$dias dias sem contato');
  }
  if (semResposta) {
    if (noResponseCount >= 2) {
      motivos.add('$noResponseCount mensagens seguidas sem resposta');
    } else if (noResponseCount == 1) {
      motivos.add('1 mensagem sem resposta');
    } else {
      motivos.add('Última mensagem enviada sem resposta');
    }
  }

  return AvaliacaoRisco(
    nivel: nivel,
    diasSemContato: dias < 0 ? 0 : dias,
    contatoAtrasado: atrasado,
    motivos: motivos,
  );
}

/// Conveniência: avalia direto a partir de um [Cliente].
///
/// Usa `ultimoContato` quando existir; senão cai para `dataAtualizacao`
/// (leads antigos que ainda não tiveram interação registrada).
AvaliacaoRisco avaliarRiscoCliente(Cliente c, {required DateTime agora}) {
  return avaliarRiscoSilencio(
    fase: c.fase,
    ultimoContato: c.ultimoContato ?? c.dataAtualizacao,
    agora: agora,
    proximoContato: c.proximoContato,
    statusMensagem: c.statusMensagem,
    noResponseCount: c.noResponseCount,
  );
}
