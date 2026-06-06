import 'package:flutter_test/flutter_test.dart';
import 'package:crm_pessoal/models/cliente_model.dart';
import 'package:crm_pessoal/models/fase_enum.dart';
import 'package:crm_pessoal/services/calibracao.dart';

void main() {
  final agora = DateTime(2026, 6, 6, 12, 0);

  Cliente lead({
    required FaseCliente fase,
    DateTime? dataVisita,
    DateTime? dataEntradaSala,
    String? statusMensagem,
  }) {
    return Cliente(
      nome: 'Lead',
      tipo: 'pf',
      fase: fase,
      dataCadastro: agora.subtract(const Duration(days: 30)),
      dataAtualizacao: agora,
      dataVisita: dataVisita,
      dataEntradaSala: dataEntradaSala,
      statusMensagem: statusMensagem,
    );
  }

  group('Calibração — amostra e taxa-base', () {
    test('considera apenas leads decididos (fechado/perdido)', () {
      final r = calibrarSinais([
        lead(fase: FaseCliente.fechado),
        lead(fase: FaseCliente.perdido),
        lead(fase: FaseCliente.contato), // ativo, ignorado
        lead(fase: FaseCliente.negociacao), // ativo, ignorado
      ]);
      expect(r.amostra, 2);
      expect(r.fechados, 1);
      expect(r.perdidos, 1);
      expect(r.taxaBase, 50);
    });

    test('amostra abaixo do mínimo é sinalizada como insuficiente', () {
      final r = calibrarSinais([
        lead(fase: FaseCliente.fechado),
        lead(fase: FaseCliente.perdido),
      ]);
      expect(r.amostraSuficiente, isFalse);
    });

    test('amostra grande o suficiente é considerada suficiente', () {
      final clientes = [
        ...List.generate(15, (_) => lead(fase: FaseCliente.fechado)),
        ...List.generate(15, (_) => lead(fase: FaseCliente.perdido)),
      ];
      final r = calibrarSinais(clientes);
      expect(r.amostra, 30);
      expect(r.amostraSuficiente, isTrue);
    });
  });

  group('Calibração — lift dos sinais', () {
    test('sinal que prevê fechamento tem lift positivo alto', () {
      // Quem visitou fecha; quem não visitou perde.
      final clientes = [
        ...List.generate(
            5, (_) => lead(fase: FaseCliente.fechado, dataVisita: agora)),
        ...List.generate(5, (_) => lead(fase: FaseCliente.perdido)),
      ];
      final r = calibrarSinais(clientes);
      final visitou = r.sinais.firstWhere((s) => s.rotulo == 'Visitou');
      expect(visitou.fechamentoComSinal, 100); // todos que visitaram fecharam
      expect(visitou.fechamentoSemSinal, 0); // ninguém sem visita fechou
      expect(visitou.lift, 100);
      expect(visitou.confiavel, isTrue);
    });

    test('sinal sem poder preditivo tem lift próximo de zero', () {
      // Visita distribuída igualmente entre fechados e perdidos.
      final clientes = [
        lead(fase: FaseCliente.fechado, dataVisita: agora),
        lead(fase: FaseCliente.fechado),
        lead(fase: FaseCliente.perdido, dataVisita: agora),
        lead(fase: FaseCliente.perdido),
        lead(fase: FaseCliente.fechado, dataVisita: agora),
        lead(fase: FaseCliente.perdido, dataVisita: agora),
      ];
      final r = calibrarSinais(clientes);
      final visitou = r.sinais.firstWhere((s) => s.rotulo == 'Visitou');
      expect(visitou.lift.abs(), lessThan(20));
    });

    test('"ficou sem responder" tende a lift negativo', () {
      final clientes = [
        ...List.generate(
            5,
            (_) => lead(
                fase: FaseCliente.fechado,
                statusMensagem: 'enviada_com_resposta')),
        ...List.generate(
            5,
            (_) => lead(
                fase: FaseCliente.perdido,
                statusMensagem: 'enviada_sem_resposta')),
      ];
      final r = calibrarSinais(clientes);
      final semResposta =
          r.sinais.firstWhere((s) => s.rotulo == 'Ficou sem responder');
      expect(semResposta.lift, lessThan(0));
    });

    test('sinais saem ordenados por lift desc', () {
      final clientes = [
        ...List.generate(
            5, (_) => lead(fase: FaseCliente.fechado, dataVisita: agora)),
        ...List.generate(5, (_) => lead(fase: FaseCliente.perdido)),
      ];
      final r = calibrarSinais(clientes);
      for (var i = 0; i < r.sinais.length - 1; i++) {
        expect(r.sinais[i].lift,
            greaterThanOrEqualTo(r.sinais[i + 1].lift));
      }
    });

    test('lado com poucos exemplos marca o sinal como não confiável', () {
      // Só 1 lead visitou → lado "com sinal" abaixo do mínimo.
      final clientes = [
        lead(fase: FaseCliente.fechado, dataVisita: agora),
        ...List.generate(9, (_) => lead(fase: FaseCliente.perdido)),
      ];
      final r = calibrarSinais(clientes);
      final visitou = r.sinais.firstWhere((s) => s.rotulo == 'Visitou');
      expect(visitou.confiavel, isFalse);
    });
  });

  group('Calibração — vazio', () {
    test('carteira sem decididos retorna amostra zero e taxa base zero', () {
      final r = calibrarSinais([
        lead(fase: FaseCliente.contato),
      ]);
      expect(r.amostra, 0);
      expect(r.taxaBase, 0);
      expect(r.amostraSuficiente, isFalse);
    });
  });
}
