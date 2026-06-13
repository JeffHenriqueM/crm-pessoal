import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/contrato_model.dart';
import 'package:crm_pessoal/services/contrato_import_diff.dart';

/// Análise de importação: mostra apenas o que **realmente** muda comparado ao
/// estado atual da base, com os rótulos dos campos alterados.
void main() {
  Contrato base({
    String loc = 'LOC-1',
    String nome = 'MARIA SILVA',
    double integralizado = 1000,
    double atrasado = 0,
    String statusFin = 'Em andamento',
    StatusAssinatura assinatura = StatusAssinatura.pendente,
    bool revertido = false,
  }) =>
      Contrato(
        localizador: loc,
        localizadorAtendimento: 'AT-1',
        nomeComprador: nome,
        valorIntegralizado: integralizado,
        valorAtrasado: atrasado,
        statusFinanceiro: statusFin,
        statusAssinatura: assinatura,
        revertido: revertido,
      );

  test('contrato idêntico → inalterado (nenhuma gravação)', () {
    final r = analisarImportContratos([base()], {'LOC-1': base()});
    expect(r.inalterados, 1);
    expect(r.alterados, isEmpty);
    expect(r.novos, isEmpty);
    expect(r.paraGravar, isEmpty);
  });

  test('mudança financeira → alterado com o rótulo do campo', () {
    final r = analisarImportContratos(
      [base(integralizado: 5000, atrasado: 200)],
      {'LOC-1': base(integralizado: 1000, atrasado: 0)},
    );
    expect(r.alterados, hasLength(1));
    expect(r.alterados.first.campos,
        containsAll(['valor integralizado', 'valor atrasado']));
    expect(r.inalterados, 0);
    expect(r.paraGravar, hasLength(1));
  });

  test('contrato inexistente → novo', () {
    final r = analisarImportContratos([base(loc: 'LOC-9')], {'LOC-1': base()});
    expect(r.novos, hasLength(1));
    expect(r.novos.first.localizador, 'LOC-9');
    expect(r.paraGravar, hasLength(1));
  });

  test('mudança só em campo NOSSO (assinatura) não conta como alteração', () {
    final r = analisarImportContratos(
      [base(assinatura: StatusAssinatura.assinado)],
      {'LOC-1': base(assinatura: StatusAssinatura.pendente)},
    );
    expect(r.inalterados, 1);
    expect(r.alterados, isEmpty);
  });

  test('reversão (revertido) é detectada como mudança', () {
    final r = analisarImportContratos(
      [base(revertido: true)],
      {'LOC-1': base(revertido: false)},
    );
    expect(r.alterados, hasLength(1));
    expect(r.alterados.first.campos, contains('reversão'));
  });

  test('rótulos não se repetem (endereço colapsa vários campos)', () {
    final novo = Contrato(
      localizador: 'LOC-1',
      localizadorAtendimento: 'AT-1',
      nomeComprador: 'MARIA',
      logradouro: 'RUA NOVA',
      bairro: 'CENTRO',
      cidade: 'SP',
    );
    final atual = Contrato(
      localizador: 'LOC-1',
      localizadorAtendimento: 'AT-1',
      nomeComprador: 'MARIA',
      logradouro: 'RUA VELHA',
      bairro: 'JARDIM',
      cidade: 'RJ',
    );
    final r = analisarImportContratos([novo], {'LOC-1': atual});
    final campos = r.alterados.first.campos;
    expect(campos.where((c) => c == 'endereço'), hasLength(1));
  });
}
