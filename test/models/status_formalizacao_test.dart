import 'package:flutter_test/flutter_test.dart';
import 'package:crm_pessoal/models/contrato_model.dart';

/// Categorias de formalização (ticket #54): 8 categorias em 3 grupos.
void main() {
  group('agrupamento das categorias', () {
    test('FORMALIZADOS: assinado, projeto atualizado e resgatado', () {
      for (final s in [
        StatusAssinatura.assinado,
        StatusAssinatura.projetoAtualizado,
        StatusAssinatura.resgatado,
      ]) {
        expect(s.grupo, GrupoFormalizacao.formalizado, reason: s.name);
        expect(s.formalizado, isTrue, reason: s.name);
      }
    });

    test('PENDENTES: pendente e projeto antigo', () {
      for (final s in [
        StatusAssinatura.pendente,
        StatusAssinatura.projetoAntigo,
      ]) {
        expect(s.grupo, GrupoFormalizacao.pendente, reason: s.name);
        expect(s.formalizado, isFalse, reason: s.name);
      }
    });

    test('EM ANDAMENTO: atualizando projeto, em andamento e em resgate', () {
      for (final s in [
        StatusAssinatura.atualizandoProjeto,
        StatusAssinatura.emAndamento,
        StatusAssinatura.emResgate,
      ]) {
        expect(s.grupo, GrupoFormalizacao.emAndamento, reason: s.name);
        expect(s.formalizado, isFalse, reason: s.name);
      }
    });

    test('todas as 8 categorias existem e nenhuma fica sem grupo', () {
      expect(StatusAssinatura.values.length, 8);
      for (final s in StatusAssinatura.values) {
        expect(GrupoFormalizacao.values.contains(s.grupo), isTrue);
      }
    });
  });

  group('persistência (value) e round-trip via fromString', () {
    test('cada categoria faz round-trip pelo seu value', () {
      for (final s in StatusAssinatura.values) {
        expect(StatusAssinatura.fromString(s.value), s, reason: s.name);
      }
    });

    test('values são únicos', () {
      final vs = StatusAssinatura.values.map((s) => s.value).toSet();
      expect(vs.length, StatusAssinatura.values.length);
    });
  });

  group('migração de dados legados', () {
    test('"nao_assinado" antigo migra para PENDENTE', () {
      expect(StatusAssinatura.fromString('nao_assinado'),
          StatusAssinatura.pendente);
    });

    test('"em_andamento" antigo permanece EM ANDAMENTO', () {
      expect(StatusAssinatura.fromString('em_andamento'),
          StatusAssinatura.emAndamento);
    });

    test('"assinado" antigo permanece ASSINADO', () {
      expect(
          StatusAssinatura.fromString('assinado'), StatusAssinatura.assinado);
    });

    test('valor desconhecido/nulo cai em PENDENTE', () {
      expect(StatusAssinatura.fromString(null), StatusAssinatura.pendente);
      expect(StatusAssinatura.fromString('xpto'), StatusAssinatura.pendente);
    });
  });

  group('fromCsvLabel reconhece os rótulos legíveis', () {
    final casos = {
      'Assinado': StatusAssinatura.assinado,
      'Projeto Atualizado': StatusAssinatura.projetoAtualizado,
      'Resgatado': StatusAssinatura.resgatado,
      'Pendente': StatusAssinatura.pendente,
      'Projeto Antigo': StatusAssinatura.projetoAntigo,
      'Atualizando Projeto': StatusAssinatura.atualizandoProjeto,
      'Em Andamento': StatusAssinatura.emAndamento,
      'Em Resgate': StatusAssinatura.emResgate,
    };

    casos.forEach((label, esperado) {
      test('"$label" → ${esperado.name}', () {
        expect(StatusAssinatura.fromCsvLabel(label), esperado);
      });
    });

    test('"em resgate" não é confundido com "resgatado"', () {
      expect(StatusAssinatura.fromCsvLabel('Em resgate'),
          StatusAssinatura.emResgate);
    });

    test('rótulo vazio cai em PENDENTE', () {
      expect(StatusAssinatura.fromCsvLabel(''), StatusAssinatura.pendente);
    });
  });
}
