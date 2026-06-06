// lib/services/desempenho_vendedor.dart
//
// Desempenho de Vendedor — lógica PURA e determinística que diagnostica como
// cada vendedor performa e ONDE ele vaza, comparando-o à média da equipe.
//
// Filosofia: número solto não diz nada. "Fechou 5" só vira insight quando
// comparado: 5 é acima ou abaixo do time? O diagnóstico aqui sempre mede o
// vendedor CONTRA o benchmark da equipe e aponta a dimensão mais fraca.
//
// Quatro dimensões medidas a partir do snapshot dos leads:
//   • Conversão        — fechados / decididos (fechado+perdido)     [maior=melhor]
//   • Velocidade       — dias médios para fechar (ciclo)            [menor=melhor]
//   • Resposta         — % de leads contatados que responderam      [maior=melhor]
//   • Comparecimento   — % de leads que visitaram/entraram na sala  [maior=melhor]
//
// Pura: recebe `agora` e nunca toca Firestore — 100% testável e portável a uma
// Cloud Function. Limitação conhecida: o snapshot guarda só a fase ATUAL, então
// um funil cumulativo por etapa (e o vazamento exato por estágio) exige o
// histórico/BigQuery (ver docs/bigquery_calibracao.md). Aqui medimos o que o
// snapshot permite com honestidade.

import '../models/cliente_model.dart';
import '../models/fase_enum.dart';

/// Amostra mínima de leads decididos para emitir diagnóstico confiável.
const int kMinAmostraDecididos = 3;

/// Métricas cruas de um vendedor (sem comparação com o time).
class MetricasVendedor {
  final String vendedorId;
  final String vendedorNome;

  final int totalLeads;
  final int decididos; // fechado + perdido
  final int fechados;
  final int perdidos;
  final int ativos;

  /// % de conversão entre os decididos (0–100). 0 se não há decididos.
  final double taxaConversao;

  /// Dias médios entre cadastro e fechamento. null se nenhum fechado datado.
  final double? cicloMedioDias;

  /// % dos leads contatados que responderam (0–100). null se ninguém contatado.
  final double? taxaResposta;

  /// % dos leads que visitaram ou entraram na sala (0–100).
  final double taxaComparecimento;

  /// Soma de valorVendido entre fechados.
  final double valorTotal;

  /// Valor médio por fechamento. null se nenhum fechado com valor.
  final double? ticketMedio;

  const MetricasVendedor({
    required this.vendedorId,
    required this.vendedorNome,
    required this.totalLeads,
    required this.decididos,
    required this.fechados,
    required this.perdidos,
    required this.ativos,
    required this.taxaConversao,
    required this.cicloMedioDias,
    required this.taxaResposta,
    required this.taxaComparecimento,
    required this.valorTotal,
    required this.ticketMedio,
  });

  /// Há amostra suficiente para comparar/diagnosticar este vendedor.
  bool get amostraSuficiente => decididos >= kMinAmostraDecididos;

  /// Calcula as métricas de um vendedor a partir da sua carteira de leads.
  factory MetricasVendedor.de(
    String vendedorId,
    String vendedorNome,
    List<Cliente> clientes, {
    required DateTime agora,
  }) {
    final fechadosList =
        clientes.where((c) => c.fase == FaseCliente.fechado).toList();
    final perdidos =
        clientes.where((c) => c.fase == FaseCliente.perdido).length;
    final fechados = fechadosList.length;
    final decididos = fechados + perdidos;
    final ativos = clientes
        .where((c) =>
            c.fase != FaseCliente.fechado && c.fase != FaseCliente.perdido)
        .length;

    final taxaConversao = decididos == 0 ? 0.0 : (fechados / decididos) * 100;

    // Ciclo: média dos dias (cadastro → fechamento) entre fechados datados.
    final ciclos = <int>[];
    for (final c in fechadosList) {
      final fim = c.dataFechamento;
      if (fim == null) continue;
      final dias = fim.difference(c.dataCadastro).inDays;
      if (dias >= 0) ciclos.add(dias);
    }
    final cicloMedioDias = ciclos.isEmpty
        ? null
        : ciclos.reduce((a, b) => a + b) / ciclos.length;

    // Resposta: entre os que receberam mensagem, quantos responderam.
    final contatados = clientes
        .where((c) =>
            c.statusMensagem == 'enviada_sem_resposta' ||
            c.statusMensagem == 'enviada_com_resposta')
        .length;
    final responderam = clientes
        .where((c) => c.statusMensagem == 'enviada_com_resposta')
        .length;
    final taxaResposta =
        contatados == 0 ? null : (responderam / contatados) * 100;

    // Comparecimento: visitou OU esteve na sala de vendas.
    final comparecimentos = clientes
        .where((c) => c.dataVisita != null || c.dataEntradaSala != null)
        .length;
    final taxaComparecimento = clientes.isEmpty
        ? 0.0
        : (comparecimentos / clientes.length) * 100;

    // Valor.
    final valores =
        fechadosList.map((c) => c.valorVendido ?? 0).where((v) => v > 0);
    final valorTotal = valores.fold<double>(0, (s, v) => s + v);
    final ticketMedio =
        valores.isEmpty ? null : valorTotal / valores.length;

    return MetricasVendedor(
      vendedorId: vendedorId,
      vendedorNome: vendedorNome,
      totalLeads: clientes.length,
      decididos: decididos,
      fechados: fechados,
      perdidos: perdidos,
      ativos: ativos,
      taxaConversao: taxaConversao,
      cicloMedioDias: cicloMedioDias,
      taxaResposta: taxaResposta,
      taxaComparecimento: taxaComparecimento,
      valorTotal: valorTotal,
      ticketMedio: ticketMedio,
    );
  }
}

/// Médias da equipe — benchmark contra o qual cada vendedor é comparado.
/// Considera apenas vendedores com amostra suficiente, para não distorcer.
class BenchmarkEquipe {
  final double taxaConversao;
  final double? cicloMedioDias;
  final double? taxaResposta;
  final double taxaComparecimento;
  final int vendedoresConsiderados;

  const BenchmarkEquipe({
    required this.taxaConversao,
    required this.cicloMedioDias,
    required this.taxaResposta,
    required this.taxaComparecimento,
    required this.vendedoresConsiderados,
  });

  factory BenchmarkEquipe.de(List<MetricasVendedor> todos) {
    final base = todos.where((m) => m.amostraSuficiente).toList();
    if (base.isEmpty) {
      return const BenchmarkEquipe(
        taxaConversao: 0,
        cicloMedioDias: null,
        taxaResposta: null,
        taxaComparecimento: 0,
        vendedoresConsiderados: 0,
      );
    }

    double mediaDe(Iterable<double> xs) =>
        xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
    double? mediaOpc(Iterable<double?> xs) {
      final vals = xs.whereType<double>().toList();
      return vals.isEmpty ? null : vals.reduce((a, b) => a + b) / vals.length;
    }

    return BenchmarkEquipe(
      taxaConversao: mediaDe(base.map((m) => m.taxaConversao)),
      cicloMedioDias: mediaOpc(base.map((m) => m.cicloMedioDias)),
      taxaResposta: mediaOpc(base.map((m) => m.taxaResposta)),
      taxaComparecimento: mediaDe(base.map((m) => m.taxaComparecimento)),
      vendedoresConsiderados: base.length,
    );
  }
}

/// Como o vendedor se posiciona numa dimensão frente ao benchmark.
enum Posicao { acima, naMedia, abaixo, semDados }

/// Avaliação de uma dimensão: valor do vendedor, média e veredito.
class DimensaoDesempenho {
  final String rotulo;
  final double? valor;
  final double? media;
  final String unidade; // '%', 'dias'
  final bool maiorEhMelhor;
  final Posicao posicao;

  const DimensaoDesempenho({
    required this.rotulo,
    required this.valor,
    required this.media,
    required this.unidade,
    required this.maiorEhMelhor,
    required this.posicao,
  });

  /// É um ponto fraco (onde o vendedor vaza).
  bool get ehPontoFraco => posicao == Posicao.abaixo;

  /// É um ponto forte.
  bool get ehPontoForte => posicao == Posicao.acima;
}

/// Diagnóstico completo de um vendedor: métricas + dimensões comparadas.
class DiagnosticoVendedor {
  final MetricasVendedor metricas;
  final List<DimensaoDesempenho> dimensoes;
  final bool amostraSuficiente;

  const DiagnosticoVendedor({
    required this.metricas,
    required this.dimensoes,
    required this.amostraSuficiente,
  });

  List<DimensaoDesempenho> get pontosFortes =>
      dimensoes.where((d) => d.ehPontoForte).toList();

  List<DimensaoDesempenho> get pontosFracos =>
      dimensoes.where((d) => d.ehPontoFraco).toList();

  /// A dimensão mais fraca (maior gargalo) — onde o vendedor mais vaza.
  DimensaoDesempenho? get gargalo {
    final fracos = pontosFracos;
    if (fracos.isEmpty) return null;
    fracos.sort((a, b) {
      final ga = _gap(a);
      final gb = _gap(b);
      return gb.compareTo(ga); // maior gap primeiro
    });
    return fracos.first;
  }

  static double _gap(DimensaoDesempenho d) {
    if (d.valor == null || d.media == null || d.media == 0) return 0;
    final raz = (d.valor! - d.media!).abs() / d.media!;
    return raz;
  }
}

/// Margem relativa (±) para considerar "na média". Fora dela, vira forte/fraco.
const double _tolerancia = 0.15; // 15%

Posicao _posicao({
  required double? valor,
  required double? media,
  required bool maiorEhMelhor,
}) {
  if (valor == null || media == null || media == 0) return Posicao.semDados;
  final razao = valor / media;
  if (razao >= 1 + _tolerancia) {
    return maiorEhMelhor ? Posicao.acima : Posicao.abaixo;
  }
  if (razao <= 1 - _tolerancia) {
    return maiorEhMelhor ? Posicao.abaixo : Posicao.acima;
  }
  return Posicao.naMedia;
}

/// Monta o diagnóstico de um vendedor frente ao benchmark da equipe.
DiagnosticoVendedor diagnosticar(
  MetricasVendedor m,
  BenchmarkEquipe bench,
) {
  final dims = <DimensaoDesempenho>[
    DimensaoDesempenho(
      rotulo: 'Conversão',
      valor: m.taxaConversao,
      media: bench.taxaConversao,
      unidade: '%',
      maiorEhMelhor: true,
      posicao: _posicao(
          valor: m.taxaConversao,
          media: bench.taxaConversao,
          maiorEhMelhor: true),
    ),
    DimensaoDesempenho(
      rotulo: 'Velocidade',
      valor: m.cicloMedioDias,
      media: bench.cicloMedioDias,
      unidade: 'dias',
      maiorEhMelhor: false,
      posicao: _posicao(
          valor: m.cicloMedioDias,
          media: bench.cicloMedioDias,
          maiorEhMelhor: false),
    ),
    DimensaoDesempenho(
      rotulo: 'Resposta',
      valor: m.taxaResposta,
      media: bench.taxaResposta,
      unidade: '%',
      maiorEhMelhor: true,
      posicao: _posicao(
          valor: m.taxaResposta,
          media: bench.taxaResposta,
          maiorEhMelhor: true),
    ),
    DimensaoDesempenho(
      rotulo: 'Comparecimento',
      valor: m.taxaComparecimento,
      media: bench.taxaComparecimento,
      unidade: '%',
      maiorEhMelhor: true,
      posicao: _posicao(
          valor: m.taxaComparecimento,
          media: bench.taxaComparecimento,
          maiorEhMelhor: true),
    ),
  ];

  return DiagnosticoVendedor(
    metricas: m,
    dimensoes: dims,
    amostraSuficiente: m.amostraSuficiente,
  );
}

/// Avalia a equipe inteira: calcula métricas, o benchmark e diagnostica cada um.
///
/// Entrada: lista de (id, nome, carteira de leads) por vendedor.
/// Saída: diagnósticos ordenados por conversão (desc).
List<DiagnosticoVendedor> avaliarEquipe(
  List<({String id, String nome, List<Cliente> clientes})> vendedores, {
  required DateTime agora,
}) {
  final metricas = vendedores
      .map((v) => MetricasVendedor.de(v.id, v.nome, v.clientes, agora: agora))
      .toList();

  final bench = BenchmarkEquipe.de(metricas);

  final diags = metricas.map((m) => diagnosticar(m, bench)).toList()
    ..sort((a, b) =>
        b.metricas.taxaConversao.compareTo(a.metricas.taxaConversao));

  return diags;
}
