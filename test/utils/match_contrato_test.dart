import 'package:flutter_test/flutter_test.dart';
import 'package:crm_pessoal/models/contrato_model.dart';
import 'package:crm_pessoal/utils/match_contrato.dart';

Contrato _contrato(String loc, String nome,
        {String tel = '', String? nome2, String? tel2}) =>
    Contrato(
      localizador: loc,
      localizadorAtendimento: loc,
      nomeComprador: nome,
      telefoneComprador: tel,
      nomeComprador2: nome2,
      telefoneComprador2: tel2,
    );

void main() {
  group('normalizarTelefone', () {
    test('remove 55, zeros à esquerda e não-dígitos', () {
      expect(normalizarTelefone('+55 (61) 98273-1384'), '61982731384');
      expect(normalizarTelefone('061982731384'), '61982731384');
    });
  });

  group('telefoneValido', () {
    test('10 ou 11 dígitos é válido', () {
      expect(telefoneValido('6199100516'), isTrue); // 10
      expect(telefoneValido('61982731384'), isTrue); // 11
      expect(telefoneValido('+55 61 98273-1384'), isTrue);
    });
    test('vazio ou curto é inválido', () {
      expect(telefoneValido(''), isFalse);
      expect(telefoneValido('123'), isFalse);
      expect(telefoneValido(null), isFalse);
    });
  });

  group('normalizarNome', () {
    test('tira acentos, "*" e baixa', () {
      expect(normalizarNome('*JOÃO  Antônio'), 'joao antonio');
    });
  });

  group('sugerirContratos', () {
    test('telefone igual pontua mais que nome', () {
      final contratos = [
        _contrato('A', 'Outro Nome', tel: '5561982731384'),
        _contrato('B', 'Fulano Qualquer', tel: '11111111111'),
      ];
      final sug = sugerirContratos(
          nome: 'Fulano Qualquer',
          telefone: '61982731384',
          contratos: contratos);
      expect(sug.first.contrato.localizador, 'A');
      expect(sug.first.motivo, 'Telefone igual');
    });

    test('nome igual casa quando não há telefone', () {
      final contratos = [
        _contrato('A', 'Maria Silva', tel: '11999990000'),
        _contrato('B', 'FRANCISCO NASCIMENTO', tel: '21988880000'),
      ];
      final sug = sugerirContratos(
          nome: 'Francisco Nascimento', telefone: '', contratos: contratos);
      expect(sug.length, 1);
      expect(sug.first.contrato.localizador, 'B');
    });

    test('sem match retorna vazio', () {
      final contratos = [_contrato('A', 'Maria Silva', tel: '11999990000')];
      final sug = sugerirContratos(
          nome: 'Zzz Nobody', telefone: '00000000000', contratos: contratos);
      expect(sug, isEmpty);
    });
  });
}
