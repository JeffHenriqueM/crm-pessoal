import 'package:flutter_test/flutter_test.dart';
import 'package:crm_pessoal/models/contato_embaixador_model.dart';
import 'package:crm_pessoal/models/interacao_model.dart' show Canal;
import 'package:crm_pessoal/widgets/contatos_embaixador_tab.dart'
    show parsearContatosColados;

void main() {
  group('Tentativa.respostaPendente', () {
    final hoje = DateTime(2026, 6, 7);

    test('pendente quando sem resposta e de dia anterior', () {
      final t = Tentativa(data: DateTime(2026, 6, 6), canal: Canal.whatsapp);
      expect(t.respostaPendente(hoje), isTrue);
    });

    test('não pendente no mesmo dia (preencher só amanhã)', () {
      final t = Tentativa(data: DateTime(2026, 6, 7, 10), canal: Canal.ligacao);
      expect(t.respostaPendente(hoje), isFalse);
    });

    test('não pendente quando já respondida', () {
      final t = Tentativa(
          data: DateTime(2026, 6, 1),
          canal: Canal.whatsapp,
          houveResposta: false);
      expect(t.respostaPendente(hoje), isFalse);
    });
  });

  group('ContatoEmbaixador getters', () {
    final hoje = DateTime(2026, 6, 7);

    test('ultimaTentativa é a de data mais recente', () {
      final c = ContatoEmbaixador(
        nome: 'João',
        telefone: '11999990000',
        tentativas: [
          Tentativa(data: DateTime(2026, 5, 1), canal: Canal.whatsapp),
          Tentativa(data: DateTime(2026, 6, 5), canal: Canal.ligacao),
          Tentativa(data: DateTime(2026, 4, 10), canal: Canal.whatsapp),
        ],
      );
      expect(c.ultimaTentativa?.data, DateTime(2026, 6, 5));
      expect(c.totalTentativas, 3);
    });

    test('temRespostaPendente quando há tentativa anterior sem resposta', () {
      final c = ContatoEmbaixador(
        nome: 'Maria',
        telefone: '11',
        tentativas: [
          Tentativa(data: DateTime(2026, 6, 6), canal: Canal.whatsapp),
          Tentativa(
              data: DateTime(2026, 6, 1),
              canal: Canal.ligacao,
              houveResposta: true),
        ],
      );
      expect(c.temRespostaPendente(hoje), isTrue);
      expect(c.respostasPendentes(hoje).length, 1);
    });
  });

  group('parsearContatosColados (formato planilha TAB)', () {
    test('nº ⇥ embaixador ⇥ cliente ⇥ telefone; nº ignorado', () {
      const txt = '801\tJefferson\tFRANCISCO NASCIMENTO\t61982731384\n'
          '802\tJefferson\tVICTOR HUGO MONTEIRO\t31998553080';
      final cs = parsearContatosColados(txt);
      expect(cs.length, 2);
      expect(cs[0].nome, 'FRANCISCO NASCIMENTO');
      expect(cs[0].responsavel, 'Jefferson');
      expect(cs[0].telefone, '61982731384');
      expect(cs[1].nome, 'VICTOR HUGO MONTEIRO');
    });

    test('linha sem telefone válido é descartada', () {
      const txt = '805\tJefferson\tALDO RESENDE\t\n'
          '806\tJefferson\tCURTO\t123\n'
          '807\tJefferson\tVALIDO\t61982731384';
      final cs = parsearContatosColados(txt);
      expect(cs.length, 1);
      expect(cs.single.nome, 'VALIDO');
    });

    test('mantém o "*" do nome e ignora linhas em branco', () {
      const txt = '\n'
          '803\tJefferson\t*ALESSANDRO RODRIGUES REIS\t31996132395\n'
          '   \n';
      final cs = parsearContatosColados(txt);
      expect(cs.length, 1);
      expect(cs[0].nome, '*ALESSANDRO RODRIGUES REIS');
    });

    test('aceita 3 colunas (sem o nº inicial)', () {
      const txt = 'Jefferson\tMARIA CAROLINA\t11982848080';
      final cs = parsearContatosColados(txt);
      expect(cs.length, 1);
      expect(cs[0].responsavel, 'Jefferson');
      expect(cs[0].nome, 'MARIA CAROLINA');
      expect(cs[0].telefone, '11982848080');
    });

    test('lista vazia retorna vazio', () {
      expect(parsearContatosColados('   \n  \n'), isEmpty);
    });
  });

  group('ContatoEmbaixador.toFirestore', () {
    test('inclui responsavel', () {
      final c = ContatoEmbaixador(
          nome: 'João', telefone: '11999990000', responsavel: 'Jefferson');
      final m = c.toFirestore();
      expect(m['responsavel'], 'Jefferson');
      expect(m['nome'], 'João');
    });
  });
}
