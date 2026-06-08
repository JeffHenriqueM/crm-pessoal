import 'package:flutter_test/flutter_test.dart';
import 'package:crm_pessoal/models/contrato_model.dart';
import 'package:crm_pessoal/services/analise_vendas.dart';

Contrato _c({
  required String id,
  DateTime? data,
  String cota = 'Cota-01',
  String produto = 'LUXO PRATA 1° / 2° / 3º',
  double valor = 50000,
  double saldo = 0,
  double atrasado = 0,
  String statusFin = 'Em andamento',
  String status = 'Ativo',
  String? origemReversao,
  DateTime? proxVenc,
  DateTime? atualizado,
}) {
  return Contrato(
    localizador: id,
    localizadorAtendimento: '',
    nomeComprador: 'C $id',
    dataContrato: data,
    cota: cota,
    produto: produto,
    valorTotalReajustado: valor,
    saldoRestante: saldo,
    valorAtrasado: atrasado,
    statusFinanceiro: statusFin,
    status: status,
    origemReversao: origemReversao,
    dataProximoVencimento: proxVenc,
    atualizadoEm: atualizado,
  );
}

void main() {
  group('vendasPorMes', () {
    test('agrupa por ano/mês e separa cotas de inteiros', () {
      final cs = [
        _c(id: '1', data: DateTime(2023, 5, 10), cota: 'Cota-01', valor: 10000),
        _c(id: '2', data: DateTime(2023, 5, 20), cota: 'Cota-02', valor: 20000),
        _c(id: '3', data: DateTime(2023, 5, 25), cota: 'Integral', valor: 70000),
        _c(id: '4', data: DateTime(2024, 1, 3), cota: 'Cota-01', valor: 30000),
      ];
      final r = vendasPorMes(cs);
      // ordenado: 2024-01 primeiro, depois 2023-05
      expect(r.first.ano, 2024);
      expect(r.first.mes, 1);
      final maio = r.firstWhere((m) => m.ano == 2023 && m.mes == 5);
      expect(maio.valor, 100000);
      expect(maio.cotas, 2);
      expect(maio.inteiros, 1);
      expect(maio.total, 3);
    });

    test('ignora contratos sem data', () {
      final r = vendasPorMes([_c(id: '1', data: null)]);
      expect(r, isEmpty);
    });
  });

  test('vendasPorAno agrupa por ano', () {
    final cs = [
      _c(id: '1', data: DateTime(2023, 5, 1)),
      _c(id: '2', data: DateTime(2024, 2, 1)),
      _c(id: '3', data: DateTime(2024, 6, 1)),
    ];
    final r = vendasPorAno(cs);
    expect(r[2024]!.length, 2);
    expect(r[2023]!.length, 1);
  });

  group('rankProduto', () {
    test('metal sobe Bronze<Prata<Ouro<Diamante<Integral', () {
      expect(rankProduto('LUXO BRONZE', 'Cota-01') <
          rankProduto('LUXO PRATA', 'Cota-01'), isTrue);
      expect(rankProduto('LUXO OURO', 'Cota-01') <
          rankProduto('LUXO DIAMANTE', 'Cota-01'), isTrue);
      // Integral (apto inteiro) é o topo do metal.
      expect(rankProduto('LUXO DIAMANTE', 'Cota-01') <
          rankProduto('LUXO PRATA', 'Integral'), isTrue);
    });
    test('linha sobe Luxo<Luxo Master<...<Villamor...<Bangalo', () {
      expect(rankProduto('LUXO PRATA', 'Cota-01') <
          rankProduto('LUXO MASTER PRATA', 'Cota-01'), isTrue);
      expect(rankProduto('LUXO PREMIUM PRATA', 'Cota-01') <
          rankProduto('VILLAMOR PRATA', 'Cota-01'), isTrue);
      expect(rankProduto('VILLAMOR SUPER MASTER PRATA', 'Cota-01') <
          rankProduto('BANGALO LUXURY PRATA', 'Cota-01'), isTrue);
    });
    test('linha tem prioridade sobre metal', () {
      // Luxo Master Bronze > Luxo Diamante (linha domina).
      expect(rankProduto('LUXO MASTER BRONZE', 'Cota-01') >
          rankProduto('LUXO DIAMANTE', 'Cota-01'), isTrue);
    });
  });

  group('raizReversao / classificarReversao', () {
    test('segue a cadeia até a raiz', () {
      final raiz = _c(id: 'R', produto: 'Luxo Prata', status: 'Revertido');
      final meio =
          _c(id: 'M', origemReversao: 'R', status: 'Revertido');
      final folha = _c(id: 'F', origemReversao: 'M');
      final porId = {for (final c in [raiz, meio, folha]) c.localizador: c};
      expect(raizReversao(folha, porId)?.localizador, 'R');
      expect(raizReversao(raiz, porId), isNull); // raiz não tem origem
    });

    test('mesmo produto = pura; tier maior = upgrade; menor = downgrade', () {
      final raiz = _c(id: 'R', produto: 'Luxo Prata 1/2/3', valor: 40000);
      final porId = {'R': raiz};
      final pura = _c(
          id: 'P', produto: 'LUXO PRATA 1° / 2° / 3º', origemReversao: 'R');
      final up = _c(
          id: 'U',
          produto: 'LUXO MASTER PRATA',
          origemReversao: 'R',
          valor: 55000);
      final down =
          _c(id: 'D', produto: 'LUXO BRONZE', origemReversao: 'R');
      expect(classificarReversao(pura, porId).tipo, TipoReversao.pura);
      final cu = classificarReversao(up, porId);
      expect(cu.tipo, TipoReversao.upgrade);
      expect(cu.ganho, 15000); // 55000 - 40000
      expect(classificarReversao(down, porId).tipo, TipoReversao.downgrade);
    });

    test('sem origem = nenhuma', () {
      expect(classificarReversao(_c(id: 'X'), {}).tipo, TipoReversao.nenhuma);
    });
  });

  group('vendasPorMesAjustado', () {
    test('reversão pura vai p/ a data da raiz, não a data nova', () {
      final raiz = _c(
          id: 'R',
          data: DateTime(2022, 3, 10),
          produto: 'Luxo Prata 1/2/3',
          status: 'Revertido');
      final novo = _c(
          id: 'N',
          data: DateTime(2025, 8, 1),
          produto: 'LUXO PRATA 1° / 2° / 3º',
          origemReversao: 'R',
          valor: 50000);
      final porId = {'R': raiz, 'N': novo};
      final r = vendasPorMesAjustado([novo], porId);
      // Só aparece em 2022-03 (data da raiz); nada em 2025-08.
      expect(r.length, 1);
      expect(r.first.ano, 2022);
      expect(r.first.mes, 3);
      expect(r.first.cotas, 1);
      expect(r.first.valor, 50000);
    });

    test('upgrade lança base na raiz e ganho na data nova', () {
      final raiz = _c(
          id: 'R',
          data: DateTime(2022, 3, 10),
          produto: 'Luxo Prata 1/2/3',
          valor: 40000,
          status: 'Revertido');
      final novo = _c(
          id: 'N',
          data: DateTime(2025, 8, 1),
          produto: 'LUXO MASTER PRATA',
          origemReversao: 'R',
          valor: 60000);
      final porId = {'R': raiz, 'N': novo};
      final r = vendasPorMesAjustado([novo], porId);
      final base = r.firstWhere((m) => m.ano == 2022);
      final ganhoMes = r.firstWhere((m) => m.ano == 2025);
      expect(base.valor, 40000); // base original
      expect(base.cotas, 1);
      expect(ganhoMes.ganhoUpgrade, 20000);
      expect(ganhoMes.upgrades, 1);
      expect(ganhoMes.cotas, 0); // não é unidade nova
      expect(ganhoMes.valor, 20000);
    });

    test('venda sem reversão fica na própria data', () {
      final c = _c(id: 'C', data: DateTime(2025, 1, 5), valor: 30000);
      final r = vendasPorMesAjustado([c], {'C': c});
      expect(r.first.ano, 2025);
      expect(r.first.valor, 30000);
      expect(r.first.cotas, 1);
    });
  });

  test('valorAReceber soma saldo dos não quitados', () {
    final cs = [
      _c(id: '1', saldo: 1000, statusFin: 'Em andamento'),
      _c(id: '2', saldo: 5000, statusFin: 'Quitado'), // ignora
      _c(id: '3', saldo: 2000, statusFin: 'Em andamento'),
    ];
    expect(valorAReceber(cs), 3000);
  });

  test('dataAtualizacaoDados pega o maior atualizadoEm', () {
    final cs = [
      _c(id: '1', atualizado: DateTime(2026, 1, 1)),
      _c(id: '2', atualizado: DateTime(2026, 5, 30)),
      _c(id: '3', atualizado: null),
    ];
    expect(dataAtualizacaoDados(cs), DateTime(2026, 5, 30));
  });

  group('permuta', () {
    test('identifica pelo comprador conhecido (acento/caixa/nome do meio)', () {
      expect(ehPermuta(_c(id: '1')), isFalse);
      final mateus = Contrato(
          localizador: 'p1',
          localizadorAtendimento: '',
          nomeComprador: 'MATEUS ANTONIO CAMILO');
      final mateus2 = Contrato(
          localizador: 'p2',
          localizadorAtendimento: '',
          nomeComprador: 'Mateus Antônio Camilo');
      final outro = Contrato(
          localizador: 'o1',
          localizadorAtendimento: '',
          nomeComprador: 'João da Silva');
      expect(ehPermuta(mateus), isTrue);
      expect(ehPermuta(mateus2), isTrue);
      expect(ehPermuta(outro), isFalse);
      expect(contratosPermuta([mateus, mateus2, outro]).length, 2);
    });
  });

  group('contratosSemPagamento', () {
    final agora = DateTime(2026, 6, 6);
    test('inclui em atraso e vencidos há muito; exclui quitados e em dia', () {
      final cs = [
        _c(id: 'atraso', atrasado: 500, statusFin: 'Em andamento'),
        _c(id: 'vencido', proxVenc: DateTime(2026, 1, 1), statusFin: 'Em andamento'),
        _c(id: 'emdia', proxVenc: DateTime(2026, 6, 30), statusFin: 'Em andamento'),
        _c(id: 'quitado', atrasado: 999, statusFin: 'Quitado'),
      ];
      final r = contratosSemPagamento(cs, agora: agora, diasMin: 60);
      final ids = r.map((c) => c.localizador).toList();
      expect(ids, containsAll(['atraso', 'vencido']));
      expect(ids, isNot(contains('emdia')));
      expect(ids, isNot(contains('quitado')));
    });

    test('ordena do vencimento mais antigo para o mais novo', () {
      final cs = [
        _c(id: 'novo', proxVenc: DateTime(2026, 2, 1), statusFin: 'Em andamento'),
        _c(id: 'antigo', proxVenc: DateTime(2025, 1, 1), statusFin: 'Em andamento'),
      ];
      final r = contratosSemPagamento(cs, agora: agora, diasMin: 30);
      expect(r.first.localizador, 'antigo');
    });
  });
}
