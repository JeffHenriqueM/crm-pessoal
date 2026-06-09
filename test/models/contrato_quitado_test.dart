import 'package:flutter_test/flutter_test.dart';
import 'package:crm_pessoal/models/contrato_model.dart';

void main() {
  Contrato base({String statusFinanceiro = 'Em andamento', double pct = 0}) =>
      Contrato(
        localizador: 'L1',
        localizadorAtendimento: 'A1',
        nomeComprador: 'Fulano',
        statusFinanceiro: statusFinanceiro,
        percentualIntegralizado: pct,
      );

  test('contrato quitado conta como 100% mesmo com pct 0', () {
    final c = base(statusFinanceiro: 'Quitado', pct: 0);
    expect(c.estaQuitado, isTrue);
    expect(c.percentualEfetivo, 100);
  });

  test('contrato não quitado usa o pct informado', () {
    final c = base(statusFinanceiro: 'Em andamento', pct: 35);
    expect(c.estaQuitado, isFalse);
    expect(c.percentualEfetivo, 35);
  });

  test('estaQuitado é case-insensitive', () {
    expect(base(statusFinanceiro: 'quitado').percentualEfetivo, 100);
    expect(base(statusFinanceiro: 'QUITADO').percentualEfetivo, 100);
  });
}
