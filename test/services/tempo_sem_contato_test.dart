import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm_pessoal/models/fase_enum.dart';
import 'package:crm_pessoal/services/tempo_sem_contato.dart';

/// Guarda do alerta de "Tempo sem contato" (ticket #48): faixas por dias
///   < 15 → em dia · 15–19 → atenção (amarelo) · 20–29 → alerta (laranja)
///   · 30+ → crítico (vermelho). Só leads ativos entram no radar.
void main() {
  final agora = DateTime(2026, 6, 18, 12, 0);

  AvaliacaoTempoContato avaliar({
    FaseCliente fase = FaseCliente.contato,
    required int diasSemContato,
  }) {
    return avaliarTempoSemContato(
      fase: fase,
      ultimoContato: agora.subtract(Duration(days: diasSemContato)),
      agora: agora,
    );
  }

  group('faixas por dias (limites)', () {
    test('14 dias ainda é em dia', () {
      expect(avaliar(diasSemContato: 14).faixa, AlertaTempoContato.emDia);
    });
    test('15 dias entra em atenção (amarelo)', () {
      final r = avaliar(diasSemContato: 15);
      expect(r.faixa, AlertaTempoContato.atencao);
      expect(r.temAlerta, isTrue);
    });
    test('19 dias ainda é atenção', () {
      expect(avaliar(diasSemContato: 19).faixa, AlertaTempoContato.atencao);
    });
    test('20 dias entra em alerta (laranja)', () {
      expect(avaliar(diasSemContato: 20).faixa, AlertaTempoContato.alerta);
    });
    test('29 dias ainda é alerta', () {
      expect(avaliar(diasSemContato: 29).faixa, AlertaTempoContato.alerta);
    });
    test('30 dias entra em crítico (vermelho)', () {
      final r = avaliar(diasSemContato: 30);
      expect(r.faixa, AlertaTempoContato.critico);
      expect(r.diasSemContato, 30);
    });
    test('90 dias segue crítico', () {
      expect(avaliar(diasSemContato: 90).faixa, AlertaTempoContato.critico);
    });
  });

  group('leads não-ativos nunca alertam', () {
    for (final fase in [
      FaseCliente.atendimento,
      FaseCliente.fechado,
      FaseCliente.perdido,
    ]) {
      test('fase ${fase.name} fica em dia mesmo com 90 dias', () {
        final r = avaliar(fase: fase, diasSemContato: 90);
        expect(r.faixa, AlertaTempoContato.emDia);
        expect(r.temAlerta, isFalse);
      });
    }
  });

  test('contato no futuro não vira negativo (clamp em 0)', () {
    expect(avaliar(diasSemContato: -5).diasSemContato, 0);
  });

  test('cores: amarelo, laranja, vermelho nas faixas certas', () {
    expect(AlertaTempoContato.emDia.cor, isNull);
    expect(AlertaTempoContato.atencao.cor, const Color(0xFFF9A825));
    expect(AlertaTempoContato.alerta.cor, const Color(0xFFEF6C00));
    expect(AlertaTempoContato.critico.cor, const Color(0xFFC62828));
  });
}
