import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/cliente_model.dart';
import 'package:crm_pessoal/models/fase_enum.dart';
import 'package:crm_pessoal/screens/recepcao_screen.dart';

/// `fichaDeCliente` monta os dados da ficha de atendimento a partir de um
/// Cliente já salvo, para reimprimir pela lista (não só logo após registrar).
void main() {
  Cliente base({DateTime? entrada, String? sala}) => Cliente(
        nome: 'JOÃO SILVA',
        tipo: 'Casal',
        fase: FaseCliente.atendimento,
        dataCadastro: DateTime(2026, 8, 1, 9, 30),
        dataAtualizacao: DateTime(2026, 8, 1, 9, 30),
        idade: '40',
        profissao: 'Engenheiro',
        telefoneContato: '11999998888',
        nomeEsposa: 'MARIA SILVA',
        idadeConjuge: '38',
        profissaoConjuge: 'Médica',
        telefone2: '11988887777',
        brinde: 'Voucher',
        captadorNome: 'Ana',
        linerNome: 'Bruno',
        vendedorNome: 'Carlos',
        origem: 'Presencial',
        numeroAtendimento: 88,
        sala: sala,
        dataEntradaSala: entrada,
      );

  test('mapeia os campos do cliente para a ficha', () {
    final f = fichaDeCliente(base(entrada: DateTime(2026, 8, 2, 10)));
    expect(f.nome, 'JOÃO SILVA');
    expect(f.telefone, '11999998888'); // telefoneContato → telefone
    expect(f.conjuge, 'MARIA SILVA'); // nomeEsposa → conjuge
    expect(f.telefoneConjuge, '11988887777'); // telefone2 → telefoneConjuge
    expect(f.pontoCapatcao, 'Presencial'); // origem → pontoCapatcao
    expect(f.numeroAtendimento, 88);
    expect(f.idadeConjuge, '38');
    expect(f.captadorNome, 'Ana');
    expect(f.linerNome, 'Bruno');
    expect(f.vendedorNome, 'Carlos');
    expect(f.dataEntrada, DateTime(2026, 8, 2, 10));
  });

  test('sala ausente vira string vazia (campo obrigatório da ficha)', () {
    expect(fichaDeCliente(base(sala: null)).sala, '');
    expect(fichaDeCliente(base(sala: 'Sala 3')).sala, 'Sala 3');
  });

  test('sem dataEntradaSala usa a dataCadastro como entrada', () {
    final f = fichaDeCliente(base(entrada: null));
    expect(f.dataEntrada, DateTime(2026, 8, 1, 9, 30));
  });
}
