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
