// lib/services/lead_score.dart
//
// Lead Score (propensão de fechamento) — lógica PURA e determinística que
// estima quão "quente" está um lead ativo (probabilidade de virar venda).
//
// É o complemento do Risco de Silêncio: lá medimos quem está esfriando; aqui
// medimos quem tem MOMENTUM de compra, para o time priorizar o esforço.
//
// Proposta inicial de pesos (ajustável com dados reais depois). O sinal
// dominante é o ESTÁGIO no funil; sobre ele somam-se bônus de engajamento e
// presença física, e descontam-se sinais de esfriamento.
//
//   Estágio:           prospecção +5 · contato +20 · negociação +40 · visita +50
//   Visitou/entrou:    dataVisita +10 · dataEntradaSala +8
//   Responde:          statusMensagem == enviada_com_resposta +15
//   Contato recente:   ≤ 7 dias +12
//   Follow-up futuro:  +5
//   Sem resposta:      −15
//   > 15 dias sem contato: −12
//
// Faixas: 🔥 Quente ≥ 60 · 🌤 Morno 35–59 · ❄️ Frio < 35
//
// Pura: recebe `agora` (não chama DateTime.now()) → 100% testável e pronta para
// migrar a uma Cloud Function. "Dias sem contato" usa `ultimoContato`, com
// fallback para `dataAtualizacao` em leads antigos (ver avaliarLeadScoreCliente).

import '../models/cliente_model.dart';
import '../models/fase_enum.dart';

/// Temperatura do lead (propensão de fechamento).
enum TemperaturaLead { frio, morno, quente }

extension TemperaturaLeadX on TemperaturaLead {
  String get rotulo {
    switch (this) {
      case TemperaturaLead.frio:
        return 'Frio';
      case TemperaturaLead.morno:
        return 'Morno';
      case TemperaturaLead.quente:
        return 'Quente';
    }
  }

  int get severidade {
    switch (this) {
      case TemperaturaLead.frio:
        return 0;
      case TemperaturaLead.morno:
        return 1;
      case TemperaturaLead.quente:
        return 2;
    }
  }
}

/// Resultado: temperatura, pontuação 0–100, sinais que pesaram e se está no
/// escopo (apenas leads ativos têm score).
class ScoreLead {
  final TemperaturaLead temperatura;
  final int pontuacao; // 0–100 (quanto maior, mais propenso a fechar)
  final List<String> sinais;
  final bool ativo;

  const ScoreLead({
    required this.temperatura,
    required this.pontuacao,
    required this.sinais,
    required this.ativo,
  });
}

/// Mesmas fases ativas do Risco de Silêncio: só leads em andamento têm score.
bool _faseAtiva(FaseCliente fase) {
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

int _pontosEstagio(FaseCliente fase) {
  switch (fase) {
    case FaseCliente.prospeccao:
      return 5;
    case FaseCliente.contato:
      return 20;
    case FaseCliente.negociacao:
      return 40;
    case FaseCliente.visita:
      return 50;
    case FaseCliente.atendimento:
    case FaseCliente.fechado:
    case FaseCliente.perdido:
      return 0;
  }
}

/// Avalia o lead score a partir dos sinais primitivos.
ScoreLead avaliarLeadScore({
  required FaseCliente fase,
  required DateTime ultimoContato,
  required DateTime agora,
  DateTime? proximoContato,
  DateTime? dataVisita,
  DateTime? dataEntradaSala,
  String? statusMensagem,
  int noResponseCount = 0,
}) {
  if (!_faseAtiva(fase)) {
    return const ScoreLead(
        temperatura: TemperaturaLead.frio,
        pontuacao: 0,
        sinais: [],
        ativo: false);
  }

  final sinais = <String>[];
  var pontos = _pontosEstagio(fase);

  // Estágio sempre vira um sinal (contexto principal).
  sinais.add('Estágio: ${fase.nomeDisplay}');

  // Presença física — forte indício de compra num resort.
  if (dataVisita != null) {
    pontos += 10;
    sinais.add('Visita registrada');
  }
  if (dataEntradaSala != null) {
    pontos += 8;
    sinais.add('Esteve na sala de vendas');
  }

  // Engajamento.
  if (statusMensagem == 'enviada_com_resposta') {
    pontos += 15;
    sinais.add('Respondendo às mensagens');
  }
  if (noResponseCount >= 2) {
    pontos -= 15;
    sinais.add('$noResponseCount mensagens sem resposta');
  }

  // Recência de contato.
  final dias = agora.difference(ultimoContato).inDays;
  if (dias <= 7) {
    pontos += 12;
    sinais.add('Contato recente');
  } else if (dias > 15) {
    pontos -= 12;
    sinais.add('$dias dias sem contato');
  }

  // Próximo passo combinado.
  if (proximoContato != null && proximoContato.isAfter(agora)) {
    pontos += 5;
    sinais.add('Follow-up agendado');
  }

  if (pontos < 0) pontos = 0;
  if (pontos > 100) pontos = 100;

  final temperatura = _temperaturaDe(pontos);
  return ScoreLead(
      temperatura: temperatura,
      pontuacao: pontos,
      sinais: sinais,
      ativo: true);
}

TemperaturaLead _temperaturaDe(int pontos) {
  if (pontos >= 60) return TemperaturaLead.quente;
  if (pontos >= 35) return TemperaturaLead.morno;
  return TemperaturaLead.frio;
}

/// Conveniência: avalia direto a partir de um [Cliente].
ScoreLead avaliarLeadScoreCliente(Cliente c, {required DateTime agora}) {
  return avaliarLeadScore(
    fase: c.fase,
    ultimoContato: c.ultimoContato ?? c.dataAtualizacao,
    agora: agora,
    proximoContato: c.proximoContato,
    dataVisita: c.dataVisita,
    dataEntradaSala: c.dataEntradaSala,
    statusMensagem: c.statusMensagem,
    noResponseCount: c.noResponseCount,
  );
}
