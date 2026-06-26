import 'package:flutter_test/flutter_test.dart';
import 'package:crm_pessoal/models/modelo_mensagem_model.dart';

void main() {
  group('aplicarVariaveisMensagem', () {
    test('substitui {nome}, {esposa} e {responsavel}', () {
      const t = 'Olá {nome}, tudo bem? Mande lembranças à {esposa}. '
          'Responsável: {responsavel}.';
      final r = aplicarVariaveisMensagem(
        t,
        nome: 'Francisco Nascimento',
        esposa: 'Maria',
        responsavel: 'Jefferson',
      );
      expect(
          r,
          'Olá Francisco Nascimento, tudo bem? Mande lembranças à Maria. '
          'Responsável: Jefferson.');
    });

    test('{primeiroNome} usa só o primeiro nome', () {
      final r = aplicarVariaveisMensagem('Oi {primeiroNome}!',
          nome: 'Francisco Nascimento');
      expect(r, 'Oi Francisco!');
    });

    test('variáveis sem valor viram vazio', () {
      final r = aplicarVariaveisMensagem('Oi {nome} {esposa}', nome: 'João');
      expect(r, 'Oi João ');
    });

    test('texto sem variáveis é preservado', () {
      const t = 'Mensagem fixa, sem variáveis.';
      expect(aplicarVariaveisMensagem(t, nome: 'X'), t);
    });

    test('nomes em CAIXA ALTA viram Title Case (conectivos minúsculos)', () {
      final r = aplicarVariaveisMensagem(
        'Olá {nome}, e {esposa}?',
        nome: 'LAIS FERREIRA DA SILVA',
        esposa: 'MARIA DAS DORES',
      );
      expect(r, 'Olá Lais Ferreira da Silva, e Maria das Dores?');
    });

    test('{primeiroNome} e {primeiroNomeEsposa} também capitalizam', () {
      final r = aplicarVariaveisMensagem(
        '{primeiroNome} e {primeiroNomeEsposa}',
        nome: 'PAULO HENRIQUE',
        esposa: 'ANA CLARA',
      );
      expect(r, 'Paulo e Ana');
    });

    test('{primeiroNomeEsposa} sem esposa vira vazio', () {
      final r = aplicarVariaveisMensagem('Oi {primeiroNomeEsposa}', nome: 'X');
      expect(r, 'Oi ');
    });

    test('variáveis de contrato entram já formatadas (sem capitalizar)', () {
      const t = 'Contrato {contrato} ({cota}) — atraso {valorAtrasado}, '
          'saldo {saldo}, prazo até {dataLimite}.';
      final r = aplicarVariaveisMensagem(
        t,
        contrato: 'LXP-61-334/Cota-01',
        cota: 'Cota-01',
        valorAtrasado: r'R$ 1.200,00',
        saldo: r'R$ 50.000,00',
        dataLimite: '05/07/2026',
      );
      expect(
          r,
          'Contrato LXP-61-334/Cota-01 (Cota-01) — atraso R\$ 1.200,00, '
          'saldo R\$ 50.000,00, prazo até 05/07/2026.');
    });

    test('variáveis de contrato sem valor viram vazio', () {
      final r = aplicarVariaveisMensagem('[{valorAtrasado}]', nome: 'X');
      expect(r, '[]');
    });
  });

  group('capitalizarNome', () {
    test('1ª maiúscula, resto minúsculo por palavra', () {
      expect(capitalizarNome('JOÃO PEDRO'), 'João Pedro');
      expect(capitalizarNome('maria'), 'Maria');
    });
    test('conectivos ficam minúsculos, exceto na 1ª palavra', () {
      expect(capitalizarNome('PEDRO DE ALCANTARA'), 'Pedro de Alcantara');
      expect(capitalizarNome('DA SILVA'), 'Da Silva');
    });
    test('vazio/nulo vira vazio', () {
      expect(capitalizarNome(null), '');
      expect(capitalizarNome('   '), '');
    });
  });

  group('ModeloMensagem', () {
    test('toFirestore inclui titulo, texto e padrao', () {
      const m = ModeloMensagem(
          titulo: 'Saudação', texto: 'Olá {nome}', padrao: true);
      final f = m.toFirestore();
      expect(f['titulo'], 'Saudação');
      expect(f['texto'], 'Olá {nome}');
      expect(f['padrao'], true);
    });

    test('copyWith altera campos e mantém o resto', () {
      const m = ModeloMensagem(
          id: 'X',
          titulo: 'A',
          texto: 'a',
          padrao: false,
          criadoPorId: 'u1');
      final n = m.copyWith(titulo: 'B', padrao: true);
      expect(n.id, 'X');
      expect(n.titulo, 'B');
      expect(n.texto, 'a');
      expect(n.padrao, true);
      expect(n.criadoPorId, 'u1');
    });
  });
}
