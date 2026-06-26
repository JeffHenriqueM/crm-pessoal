import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/baixa_financeira_model.dart';
import 'package:crm_pessoal/models/contrato_model.dart';
import 'package:crm_pessoal/utils/analise_distrato.dart';

/// Lógica pura da aba Distratar (Pós-Venda):
/// - ranking de maiores valores em atraso;
/// - inadimplentes = não-quitado + saldo > 0 + 3+ meses sem pagamento.
void main() {
  Contrato contrato({
    required String loc,
    required String nome,
    String? codigo,
    double atrasado = 0,
    double saldo = 0,
    String statusFinanceiro = 'Em andamento',
    String status = 'Ativo',
  }) =>
      Contrato(
        localizador: loc,
        localizadorAtendimento: loc,
        nomeComprador: nome,
        codigoContrato: codigo,
        valorAtrasado: atrasado,
        saldoRestante: saldo,
        statusFinanceiro: statusFinanceiro,
        status: status,
      );

  BaixaFinanceira baixa({
    required String cliente,
    required String doc,
    required DateTime credito,
  }) =>
      BaixaFinanceira(
        cliente: cliente,
        tipo: '018 - PIX',
        documentoCar: doc,
        vencimento: credito,
        valorPago: 100,
        dataBaixa: credito,
        dataCredito: credito,
        status: 'Baixado',
        mesCreditoKey: BaixaFinanceira.buildMesKey(credito),
        importadoEm: credito,
        importadoPorId: 'x',
        importadoPorNome: 'X',
      );

  final hoje = DateTime(2026, 6, 20); // corte de inadimplência = 2026-03-20

  group('maioresAtrasos', () {
    test('ordena por valorAtrasado desc e exclui quem não tem atraso', () {
      final r = analisarDistrato([
        contrato(loc: 'A', nome: 'A', atrasado: 500),
        contrato(loc: 'B', nome: 'B', atrasado: 0),
        contrato(loc: 'C', nome: 'C', atrasado: 1500),
      ], [], hoje: hoje);

      expect(r.maioresAtrasos.map((c) => c.localizador), ['C', 'A']);
    });

    test('exclui contrato não-ativo mesmo com atraso', () {
      final r = analisarDistrato([
        contrato(loc: 'A', nome: 'A', atrasado: 500),
        contrato(loc: 'X', nome: 'X', atrasado: 9000, status: 'Cancelado'),
      ], [], hoje: hoje);

      expect(r.maioresAtrasos.map((c) => c.localizador), ['A']);
    });
  });

  group('inadimplentes', () {
    test('inclui em atraso, não-quitado, último pagamento há 3+ meses', () {
      final r = analisarDistrato(
        [contrato(loc: 'A', nome: 'A', codigo: 'CAR-A', saldo: 1000, atrasado: 200)],
        [baixa(cliente: 'A', doc: 'CAR-A', credito: DateTime(2026, 1, 10))],
        hoje: hoje,
      );
      expect(r.inadimplentes.map((c) => c.localizador), ['A']);
      expect(r.ultimoPagamento['A'], DateTime(2026, 1, 10));
    });

    test('exclui quem pagou há menos de 3 meses', () {
      final r = analisarDistrato(
        [contrato(loc: 'A', nome: 'A', codigo: 'CAR-A', saldo: 1000, atrasado: 200)],
        [baixa(cliente: 'A', doc: 'CAR-A', credito: DateTime(2026, 5, 1))],
        hoje: hoje,
      );
      expect(r.inadimplentes, isEmpty);
    });

    test('inclui quem está em atraso e nunca pagou (sem baixa casada)', () {
      final r = analisarDistrato(
        [contrato(loc: 'A', nome: 'A', codigo: 'CAR-A', saldo: 1000, atrasado: 200)],
        [],
        hoje: hoje,
      );
      expect(r.inadimplentes.map((c) => c.localizador), ['A']);
      expect(r.ultimoPagamento.containsKey('A'), isFalse);
    });

    test('exclui "sem pagamento" mas R\$ 0,00 em atraso (baixa não casada)', () {
      // Falso positivo: nenhuma baixa casou, mas a fonte diz atraso = 0
      // (pagou, só não cruzou por código). Não é inadimplente de verdade.
      final r = analisarDistrato(
        [contrato(loc: 'A', nome: 'A', codigo: 'CAR-A', saldo: 1000, atrasado: 0)],
        [],
        hoje: hoje,
      );
      expect(r.inadimplentes, isEmpty);
    });

    test('exclui contrato quitado mesmo sem pagamento recente', () {
      final r = analisarDistrato(
        [
          contrato(
            loc: 'A',
            nome: 'A',
            codigo: 'CAR-A',
            saldo: 0,
            statusFinanceiro: 'Quitado',
          )
        ],
        [],
        hoje: hoje,
      );
      expect(r.inadimplentes, isEmpty);
    });

    test('exclui contrato não-ativo (cancelado/inativo) mesmo sem pagamento', () {
      final r = analisarDistrato(
        [
          contrato(
            loc: 'A',
            nome: 'A',
            codigo: 'CAR-A',
            saldo: 1000,
            status: 'Cancelado',
          )
        ],
        [],
        hoje: hoje,
      );
      expect(r.inadimplentes, isEmpty);
    });

    test('exclui contrato sem saldo devedor', () {
      final r = analisarDistrato(
        [contrato(loc: 'A', nome: 'A', codigo: 'CAR-A', saldo: 0)],
        [],
        hoje: hoje,
      );
      expect(r.inadimplentes, isEmpty);
    });

    test('pagamento de outra cota do mesmo cliente não mascara a inadimplência',
        () {
      // A (cota CAR-A) sem baixa; mesma pessoa pagou recente na cota CAR-B.
      // Casamento por código não pode vazar o pagamento de CAR-B para CAR-A.
      final r = analisarDistrato(
        [
          contrato(loc: 'A', nome: 'FULANO', codigo: 'CAR-A', saldo: 1000, atrasado: 200),
          contrato(loc: 'B', nome: 'FULANO', codigo: 'CAR-B', saldo: 1000, atrasado: 200),
        ],
        [baixa(cliente: 'FULANO', doc: 'CAR-B', credito: DateTime(2026, 6, 1))],
        hoje: hoje,
      );
      expect(r.inadimplentes.map((c) => c.localizador), ['A']);
    });

    test('contrato sem código casa o último pagamento por nome', () {
      final r = analisarDistrato(
        [contrato(loc: 'A', nome: 'FULANO', saldo: 1000, atrasado: 200)],
        [baixa(cliente: 'FULANO', doc: 'QUALQUER', credito: DateTime(2026, 1, 5))],
        hoje: hoje,
      );
      expect(r.inadimplentes.map((c) => c.localizador), ['A']);
      expect(r.ultimoPagamento['A'], DateTime(2026, 1, 5));
    });
  });
}
