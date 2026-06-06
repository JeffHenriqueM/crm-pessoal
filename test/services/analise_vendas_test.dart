import 'package:flutter_test/flutter_test.dart';
import 'package:crm_pessoal/models/contrato_model.dart';
import 'package:crm_pessoal/services/analise_vendas.dart';

Contrato _c({
  required String id,
  DateTime? data,
  String cota = 'Cota-01',
  double valor = 50000,
  double saldo = 0,
  double atrasado = 0,
  String statusFin = 'Em andamento',
  DateTime? proxVenc,
  DateTime? atualizado,
}) {
  return Contrato(
    localizador: id,
    localizadorAtendimento: '',
    nomeComprador: 'C $id',
    dataContrato: data,
    cota: cota,
    valorTotalReajustado: valor,
    saldoRestante: saldo,
    valorAtrasado: atrasado,
    statusFinanceiro: statusFin,
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
