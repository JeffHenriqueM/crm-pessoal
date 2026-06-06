import 'package:flutter_test/flutter_test.dart';
import 'package:crm_pessoal/models/fase_enum.dart';
import 'package:crm_pessoal/services/risco_silencio.dart';

void main() {
  // Âncora temporal fixa para deixar os testes determinísticos.
  final agora = DateTime(2026, 6, 6, 12, 0);

  // Lead "saudável" de referência: ativo, contato recente, follow-up futuro,
  // respondendo. Cada teste muda só o sinal que quer exercitar.
  AvaliacaoRisco avaliar({
    FaseCliente fase = FaseCliente.contato,
    int diasSemContato = 0,
    DateTime? proximoContato,
    String? statusMensagem,
    int noResponseCount = 0,
  }) {
    return avaliarRiscoSilencio(
      fase: fase,
      ultimoContato: agora.subtract(Duration(days: diasSemContato)),
      agora: agora,
      proximoContato: proximoContato ?? agora.add(const Duration(days: 2)),
      statusMensagem: statusMensagem,
      noResponseCount: noResponseCount,
    );
  }

  group('RiscoSilencio — leads não-ativos nunca entram no radar', () {
    for (final fase in [
      FaseCliente.atendimento,
      FaseCliente.fechado,
      FaseCliente.perdido,
    ]) {
      test('fase ${fase.name} retorna nenhum, mesmo com sinais ruins', () {
        final r = avaliar(
          fase: fase,
          diasSemContato: 90,
          proximoContato: agora.subtract(const Duration(days: 60)),
          statusMensagem: 'enviada_sem_resposta',
          noResponseCount: 5,
        );
        expect(r.nivel, NivelRisco.nenhum);
        expect(r.exigeAcao, isFalse);
        expect(r.motivos, isEmpty);
      });
    }
  });

  group('RiscoSilencio — Crítico', () {
    test('contato atrasado (follow-up vencido) é crítico, mesmo recém-falado',
        () {
      final r = avaliar(
        diasSemContato: 0, // falado hoje
        proximoContato: agora.subtract(const Duration(days: 1)), // vencido
      );
      expect(r.nivel, NivelRisco.critico);
      expect(r.contatoAtrasado, isTrue);
      expect(r.motivos.any((m) => m.contains('Follow-up vencido')), isTrue);
    });

    test('mais de 15 dias sem contato é crítico', () {
      final r = avaliar(diasSemContato: 16);
      expect(r.nivel, NivelRisco.critico);
      expect(r.motivos, contains('16 dias sem contato'));
    });

    test('exatamente 15 dias ainda é esfriando (não crítico)', () {
      final r = avaliar(diasSemContato: 15);
      expect(r.nivel, NivelRisco.esfriando);
    });
  });

  group('RiscoSilencio — Esfriando (8 a 15 dias)', () {
    test('8 dias sem contato é esfriando', () {
      final r = avaliar(diasSemContato: 8);
      expect(r.nivel, NivelRisco.esfriando);
      expect(r.motivos, contains('8 dias sem contato'));
    });

    test('exatamente 7 dias NÃO é esfriando', () {
      final r = avaliar(diasSemContato: 7);
      expect(r.nivel, isNot(NivelRisco.esfriando));
    });
  });

  group('RiscoSilencio — Observar (≤7 dias com sinal de alerta)', () {
    test('recente e sem resposta vai para observar', () {
      final r = avaliar(diasSemContato: 3, noResponseCount: 1);
      expect(r.nivel, NivelRisco.observar);
      expect(r.exigeAcao, isTrue);
      expect(r.motivos, contains('1 mensagem sem resposta'));
    });

    test('recente com statusMensagem enviada_sem_resposta vai para observar',
        () {
      final r =
          avaliar(diasSemContato: 2, statusMensagem: 'enviada_sem_resposta');
      expect(r.nivel, NivelRisco.observar);
      expect(r.motivos, contains('Última mensagem enviada sem resposta'));
    });

    test('várias sem resposta recentes citam a quantidade', () {
      final r = avaliar(diasSemContato: 1, noResponseCount: 3);
      expect(r.nivel, NivelRisco.observar);
      expect(r.motivos, contains('3 mensagens seguidas sem resposta'));
    });
  });

  group('RiscoSilencio — Sem risco (lead saudável fica fora do radar)', () {
    test('recente, respondendo e com follow-up futuro = nenhum', () {
      final r = avaliar(diasSemContato: 1);
      expect(r.nivel, NivelRisco.nenhum);
      expect(r.exigeAcao, isFalse);
      expect(r.motivos, isEmpty);
    });

    test('recente sem resposta NÃO escala além de observar', () {
      final r = avaliar(diasSemContato: 5, noResponseCount: 5);
      expect(r.nivel, NivelRisco.observar); // recência manda; só observar
    });
  });

  group('RiscoSilencio — precedência das regras', () {
    test('atrasado vence recência (mesmo com poucos dias sem contato)', () {
      final r = avaliar(
        diasSemContato: 2,
        proximoContato: agora.subtract(const Duration(days: 5)),
        noResponseCount: 1,
      );
      expect(r.nivel, NivelRisco.critico);
    });

    test('crítico por recência lista os dias sem contato', () {
      final r = avaliar(diasSemContato: 40);
      expect(r.nivel, NivelRisco.critico);
      expect(r.diasSemContato, 40);
      expect(r.motivos, contains('40 dias sem contato'));
    });
  });

  group('RiscoSilencio — severidade para ordenação', () {
    test('a ordem de severidade é crescente', () {
      expect(NivelRisco.nenhum.severidade, lessThan(NivelRisco.observar.severidade));
      expect(NivelRisco.observar.severidade,
          lessThan(NivelRisco.esfriando.severidade));
      expect(NivelRisco.esfriando.severidade,
          lessThan(NivelRisco.critico.severidade));
    });
  });
}
