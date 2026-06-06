import 'package:flutter_test/flutter_test.dart';
import 'package:crm_pessoal/models/fase_enum.dart';
import 'package:crm_pessoal/services/lead_score.dart';

void main() {
  final agora = DateTime(2026, 6, 6, 12, 0);

  ScoreLead avaliar({
    FaseCliente fase = FaseCliente.contato,
    int diasSemContato = 30, // por padrão, "antigo", para isolar cada sinal
    DateTime? proximoContato,
    DateTime? dataVisita,
    DateTime? dataEntradaSala,
    String? statusMensagem,
    int noResponseCount = 0,
  }) {
    return avaliarLeadScore(
      fase: fase,
      ultimoContato: agora.subtract(Duration(days: diasSemContato)),
      agora: agora,
      proximoContato: proximoContato,
      dataVisita: dataVisita,
      dataEntradaSala: dataEntradaSala,
      statusMensagem: statusMensagem,
      noResponseCount: noResponseCount,
    );
  }

  group('LeadScore — escopo', () {
    for (final fase in [
      FaseCliente.atendimento,
      FaseCliente.fechado,
      FaseCliente.perdido,
    ]) {
      test('fase ${fase.name} não tem score (ativo=false)', () {
        final r = avaliar(fase: fase);
        expect(r.ativo, isFalse);
        expect(r.pontuacao, 0);
        expect(r.sinais, isEmpty);
      });
    }

    test('fase ativa tem score e sinais', () {
      final r = avaliar(fase: FaseCliente.negociacao);
      expect(r.ativo, isTrue);
      expect(r.sinais, isNotEmpty);
    });
  });

  group('LeadScore — estágio é monotônico', () {
    test('visita > negociacao > contato > prospeccao', () {
      final p = avaliar(fase: FaseCliente.prospeccao).pontuacao;
      final c = avaliar(fase: FaseCliente.contato).pontuacao;
      final n = avaliar(fase: FaseCliente.negociacao).pontuacao;
      final v = avaliar(fase: FaseCliente.visita).pontuacao;
      expect(p, lessThan(c));
      expect(c, lessThan(n));
      expect(n, lessThan(v));
    });
  });

  group('LeadScore — sinais aumentam ou diminuem o score', () {
    test('visita registrada aumenta', () {
      final sem = avaliar(fase: FaseCliente.negociacao).pontuacao;
      final com = avaliar(fase: FaseCliente.negociacao, dataVisita: agora)
          .pontuacao;
      expect(com, greaterThan(sem));
    });

    test('esteve na sala aumenta', () {
      final sem = avaliar(fase: FaseCliente.negociacao).pontuacao;
      final com =
          avaliar(fase: FaseCliente.negociacao, dataEntradaSala: agora)
              .pontuacao;
      expect(com, greaterThan(sem));
    });

    test('respondendo às mensagens aumenta e cita o sinal', () {
      final r = avaliar(
          fase: FaseCliente.negociacao,
          statusMensagem: 'enviada_com_resposta');
      expect(r.sinais, contains('Respondendo às mensagens'));
      final sem = avaliar(fase: FaseCliente.negociacao).pontuacao;
      expect(r.pontuacao, greaterThan(sem));
    });

    test('contato recente aumenta', () {
      final recente = avaliar(fase: FaseCliente.contato, diasSemContato: 2);
      final antigo = avaliar(fase: FaseCliente.contato, diasSemContato: 30);
      expect(recente.pontuacao, greaterThan(antigo.pontuacao));
      expect(recente.sinais, contains('Contato recente'));
    });

    test('mensagens sem resposta diminuem', () {
      final r = avaliar(fase: FaseCliente.negociacao, noResponseCount: 3);
      final sem = avaliar(fase: FaseCliente.negociacao).pontuacao;
      expect(r.pontuacao, lessThan(sem));
      expect(r.sinais, contains('3 mensagens sem resposta'));
    });

    test('follow-up agendado aumenta', () {
      final r = avaliar(
          fase: FaseCliente.contato,
          proximoContato: agora.add(const Duration(days: 2)));
      expect(r.sinais, contains('Follow-up agendado'));
    });
  });

  group('LeadScore — faixas de temperatura', () {
    test('negociação respondendo e recente é quente', () {
      final r = avaliar(
        fase: FaseCliente.negociacao, // 40
        diasSemContato: 1, // +12
        statusMensagem: 'enviada_com_resposta', // +15
        proximoContato: agora.add(const Duration(days: 1)), // +5
      ); // 72
      expect(r.temperatura, TemperaturaLead.quente);
      expect(r.pontuacao, greaterThanOrEqualTo(60));
    });

    test('prospecção parada é frio', () {
      final r = avaliar(fase: FaseCliente.prospeccao, diasSemContato: 30);
      expect(r.temperatura, TemperaturaLead.frio);
    });

    test('contato recente cai em morno', () {
      final r = avaliar(fase: FaseCliente.contato, diasSemContato: 2); // 20+12=32
      // 32 ainda é frio; garante a fronteira não estourar para quente
      expect(r.temperatura, isNot(TemperaturaLead.quente));
    });
  });

  group('LeadScore — limites de pontuação', () {
    test('nunca passa de 100', () {
      final r = avaliar(
        fase: FaseCliente.visita,
        diasSemContato: 1,
        dataVisita: agora,
        dataEntradaSala: agora,
        statusMensagem: 'enviada_com_resposta',
        proximoContato: agora.add(const Duration(days: 1)),
      );
      expect(r.pontuacao, lessThanOrEqualTo(100));
    });

    test('nunca fica abaixo de 0', () {
      final r = avaliar(
        fase: FaseCliente.prospeccao, // 5
        diasSemContato: 60, // -12
        noResponseCount: 9, // -15
      );
      expect(r.pontuacao, greaterThanOrEqualTo(0));
    });
  });

  group('LeadScore — severidade para ordenação', () {
    test('quente > morno > frio', () {
      expect(TemperaturaLead.frio.severidade,
          lessThan(TemperaturaLead.morno.severidade));
      expect(TemperaturaLead.morno.severidade,
          lessThan(TemperaturaLead.quente.severidade));
    });
  });
}
