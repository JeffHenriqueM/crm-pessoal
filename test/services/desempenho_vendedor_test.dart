import 'package:flutter_test/flutter_test.dart';
import 'package:crm_pessoal/models/cliente_model.dart';
import 'package:crm_pessoal/models/fase_enum.dart';
import 'package:crm_pessoal/services/desempenho_vendedor.dart';

void main() {
  final agora = DateTime(2026, 6, 6, 12, 0);

  // Helper para criar um lead com os campos relevantes ao desempenho.
  Cliente lead({
    FaseCliente fase = FaseCliente.contato,
    DateTime? dataCadastro,
    DateTime? dataFechamento,
    DateTime? dataVisita,
    DateTime? dataEntradaSala,
    String? statusMensagem,
    double? valorVendido,
  }) {
    return Cliente(
      nome: 'Lead',
      tipo: 'pf',
      fase: fase,
      dataCadastro: dataCadastro ?? agora.subtract(const Duration(days: 30)),
      dataAtualizacao: agora,
      dataFechamento: dataFechamento,
      dataVisita: dataVisita,
      dataEntradaSala: dataEntradaSala,
      statusMensagem: statusMensagem,
      valorVendido: valorVendido,
    );
  }

  group('MetricasVendedor — contagens e conversão', () {
    test('conversão = fechados / (fechados+perdidos)', () {
      final m = MetricasVendedor.de('v1', 'Ana', [
        lead(fase: FaseCliente.fechado),
        lead(fase: FaseCliente.fechado),
        lead(fase: FaseCliente.fechado),
        lead(fase: FaseCliente.perdido),
        lead(fase: FaseCliente.contato), // ativo, não conta na conversão
      ], agora: agora);

      expect(m.fechados, 3);
      expect(m.perdidos, 1);
      expect(m.decididos, 4);
      expect(m.ativos, 1);
      expect(m.totalLeads, 5);
      expect(m.taxaConversao, 75); // 3/4
    });

    test('sem decididos, conversão é 0 e amostra insuficiente', () {
      final m = MetricasVendedor.de('v1', 'Ana', [
        lead(fase: FaseCliente.contato),
      ], agora: agora);
      expect(m.taxaConversao, 0);
      expect(m.amostraSuficiente, isFalse);
    });
  });

  group('MetricasVendedor — velocidade (ciclo)', () {
    test('ciclo médio é a média de cadastro→fechamento dos fechados', () {
      final m = MetricasVendedor.de('v1', 'Ana', [
        lead(
            fase: FaseCliente.fechado,
            dataCadastro: agora.subtract(const Duration(days: 10)),
            dataFechamento: agora), // 10 dias
        lead(
            fase: FaseCliente.fechado,
            dataCadastro: agora.subtract(const Duration(days: 20)),
            dataFechamento: agora), // 20 dias
      ], agora: agora);
      expect(m.cicloMedioDias, 15);
    });

    test('fechados sem dataFechamento não entram no ciclo', () {
      final m = MetricasVendedor.de('v1', 'Ana', [
        lead(fase: FaseCliente.fechado), // sem dataFechamento
      ], agora: agora);
      expect(m.cicloMedioDias, isNull);
    });
  });

  group('MetricasVendedor — resposta e comparecimento', () {
    test('taxa de resposta = respondeu / contatados', () {
      final m = MetricasVendedor.de('v1', 'Ana', [
        lead(statusMensagem: 'enviada_com_resposta'),
        lead(statusMensagem: 'enviada_com_resposta'),
        lead(statusMensagem: 'enviada_sem_resposta'),
        lead(statusMensagem: null), // não contatado, fora do denominador
      ], agora: agora);
      expect(m.taxaResposta, closeTo(66.66, 0.1)); // 2/3
    });

    test('sem ninguém contatado, taxa de resposta é null', () {
      final m = MetricasVendedor.de('v1', 'Ana', [
        lead(statusMensagem: null),
      ], agora: agora);
      expect(m.taxaResposta, isNull);
    });

    test('comparecimento conta visita OU sala sobre o total', () {
      final m = MetricasVendedor.de('v1', 'Ana', [
        lead(dataVisita: agora),
        lead(dataEntradaSala: agora),
        lead(), // não compareceu
        lead(), // não compareceu
      ], agora: agora);
      expect(m.taxaComparecimento, 50); // 2/4
    });
  });

  group('MetricasVendedor — valor', () {
    test('valor total e ticket médio sobre fechados com valor', () {
      final m = MetricasVendedor.de('v1', 'Ana', [
        lead(fase: FaseCliente.fechado, valorVendido: 1000),
        lead(fase: FaseCliente.fechado, valorVendido: 3000),
        lead(fase: FaseCliente.fechado, valorVendido: null), // sem valor
      ], agora: agora);
      expect(m.valorTotal, 4000);
      expect(m.ticketMedio, 2000); // média de 1000 e 3000
    });
  });

  group('Benchmark e diagnóstico', () {
    // Equipe: Ana converte muito acima, Beto muito abaixo.
    List<({String id, String nome, List<Cliente> clientes})> equipe() => [
          (
            id: 'ana',
            nome: 'Ana',
            clientes: [
              // 8 fechados, 2 perdidos → 80% conversão
              ...List.generate(8, (_) => lead(fase: FaseCliente.fechado)),
              ...List.generate(2, (_) => lead(fase: FaseCliente.perdido)),
            ]
          ),
          (
            id: 'beto',
            nome: 'Beto',
            clientes: [
              // 2 fechados, 8 perdidos → 20% conversão
              ...List.generate(2, (_) => lead(fase: FaseCliente.fechado)),
              ...List.generate(8, (_) => lead(fase: FaseCliente.perdido)),
            ]
          ),
        ];

    test('benchmark só considera vendedores com amostra suficiente', () {
      final metricas = [
        MetricasVendedor.de('a', 'A', [
          lead(fase: FaseCliente.fechado),
          lead(fase: FaseCliente.perdido),
          lead(fase: FaseCliente.fechado),
        ], agora: agora), // 3 decididos → conta
        MetricasVendedor.de('b', 'B', [
          lead(fase: FaseCliente.fechado),
        ], agora: agora), // 1 decidido → fora do benchmark
      ];
      final bench = BenchmarkEquipe.de(metricas);
      expect(bench.vendedoresConsiderados, 1);
    });

    test('vendedor acima da média vira ponto forte; abaixo vira fraco', () {
      final diags = avaliarEquipe(equipe(), agora: agora);
      final ana = diags.firstWhere((d) => d.metricas.vendedorNome == 'Ana');
      final beto = diags.firstWhere((d) => d.metricas.vendedorNome == 'Beto');

      final convAna =
          ana.dimensoes.firstWhere((d) => d.rotulo == 'Conversão');
      final convBeto =
          beto.dimensoes.firstWhere((d) => d.rotulo == 'Conversão');

      expect(convAna.posicao, Posicao.acima);
      expect(convAna.ehPontoForte, isTrue);
      expect(convBeto.posicao, Posicao.abaixo);
      expect(convBeto.ehPontoFraco, isTrue);
    });

    test('gargalo é a dimensão mais fraca do vendedor', () {
      final diags = avaliarEquipe(equipe(), agora: agora);
      final beto = diags.firstWhere((d) => d.metricas.vendedorNome == 'Beto');
      expect(beto.gargalo, isNotNull);
      expect(beto.gargalo!.rotulo, 'Conversão');
    });

    test('ordena diagnósticos por conversão desc', () {
      final diags = avaliarEquipe(equipe(), agora: agora);
      expect(diags.first.metricas.vendedorNome, 'Ana');
      expect(diags.last.metricas.vendedorNome, 'Beto');
    });

    test('velocidade: menor ciclo é melhor (acima da média)', () {
      // Rápido fecha em 5 dias; Lento em 40. Média ~22.5.
      final eq = [
        (
          id: 'rapido',
          nome: 'Rápido',
          clientes: [
            ...List.generate(
                3,
                (_) => lead(
                    fase: FaseCliente.fechado,
                    dataCadastro: agora.subtract(const Duration(days: 5)),
                    dataFechamento: agora)),
            lead(fase: FaseCliente.perdido),
          ]
        ),
        (
          id: 'lento',
          nome: 'Lento',
          clientes: [
            ...List.generate(
                3,
                (_) => lead(
                    fase: FaseCliente.fechado,
                    dataCadastro: agora.subtract(const Duration(days: 40)),
                    dataFechamento: agora)),
            lead(fase: FaseCliente.perdido),
          ]
        ),
      ];
      final diags = avaliarEquipe(eq, agora: agora);
      final rapido =
          diags.firstWhere((d) => d.metricas.vendedorNome == 'Rápido');
      final lento =
          diags.firstWhere((d) => d.metricas.vendedorNome == 'Lento');
      final velRapido =
          rapido.dimensoes.firstWhere((d) => d.rotulo == 'Velocidade');
      final velLento =
          lento.dimensoes.firstWhere((d) => d.rotulo == 'Velocidade');
      expect(velRapido.posicao, Posicao.acima); // ciclo menor = melhor
      expect(velLento.posicao, Posicao.abaixo);
    });

    test('vendedor sem amostra suficiente é marcado como tal', () {
      final eq = [
        (
          id: 'novo',
          nome: 'Novo',
          clientes: [lead(fase: FaseCliente.contato)],
        ),
      ];
      final diags = avaliarEquipe(eq, agora: agora);
      expect(diags.first.amostraSuficiente, isFalse);
    });
  });
}
