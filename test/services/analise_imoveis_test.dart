import 'package:flutter_test/flutter_test.dart';
import 'package:crm_pessoal/models/contrato_model.dart';
import 'package:crm_pessoal/models/imovel_model.dart';
import 'package:crm_pessoal/services/analise_imoveis.dart';

/// Cria um contrato mínimo para os testes de ligação/análise.
Contrato _contrato({
  required String localizador,
  String bloco = 'B (HERA)',
  String imovel = '101',
  String produto = 'LUXO PRATA 1° / 2° / 3º',
  String cota = 'Cota-01',
  String nome = 'Comprador Teste',
  double valor = 50000,
  String statusFinanceiro = 'Em andamento',
}) {
  return Contrato(
    localizador: localizador,
    localizadorAtendimento: '',
    nomeComprador: nome,
    bloco: bloco,
    imovel: imovel,
    produto: produto,
    cota: cota,
    valorTotalReajustado: valor,
    statusFinanceiro: statusFinanceiro,
  );
}

void main() {
  group('inventário da 1ª etapa', () {
    final inv = inventarioPrimeiraEtapa();

    test('soma 228 unidades (98 + 118 + 12)', () {
      expect(inv.length, 228);
      expect(inv.where((i) => i.bloco == 'B').length, 98);
      expect(inv.where((i) => i.bloco == 'C').length, 118);
      expect(inv.where((i) => i.bloco == 'BANGALO').length, 12);
    });

    test('térreo pula 06 e 15; andares têm os 20', () {
      final terreoB = inv.where((i) => i.bloco == 'B' && i.pavimento == 'terreo');
      expect(terreoB.length, 18);
      expect(terreoB.any((i) => i.numero == '6'), isFalse);
      expect(terreoB.any((i) => i.numero == '15'), isFalse);
      final and1B = inv.where((i) => i.bloco == 'B' && i.pavimento == '1');
      expect(and1B.length, 20);
    });

    test('tipos e metragens especiais do Bloco B', () {
      Imovel b(String id) => inv.firstWhere((i) => i.id == id);
      expect(b('B-1').tipo, 'LUXO MASTER');
      expect(b('B-1').metragem, 59.81);
      expect(b('B-20').tipo, 'LUXO PREMIUM');
      expect(b('B-20').metragem, 53.96);
      expect(b('B-102').tipo, 'LUXO');
      expect(b('B-102').metragem, 46.20);
      expect(b('B-420').tipo, 'LUXO PREMIUM');
    });

    test('tipos especiais do Bloco C', () {
      Imovel c(String id) => inv.firstWhere((i) => i.id == id);
      expect(c('C-1').tipo, 'VILLAMOR SUPER MASTER');
      expect(c('C-301').tipo, 'VILLAMOR PREMIUM');
      expect(c('C-520').tipo, 'VILLAMOR PREMIUM');
      expect(c('C-102').tipo, 'VILLAMOR');
      expect(c('C-102').metragem, 52.42);
      // Bloco C tem 5 andares + térreo
      expect(inv.any((i) => i.id == 'C-501'), isTrue);
      expect(inv.any((i) => i.id == 'B-501'), isFalse);
    });

    test('bangalôs são F–Q, tipo BANGALO, metragem nula', () {
      final bang = inv.where((i) => i.bloco == 'BANGALO').toList();
      expect(bang.map((i) => i.numero).toSet(), kLetrasBangalos.toSet());
      expect(bang.every((i) => i.tipo == 'BANGALO'), isTrue);
      expect(bang.every((i) => i.metragem == null), isTrue);
      expect(inv.any((i) => i.id == 'BANG-F'), isTrue);
    });
  });

  group('normalizarBloco', () {
    test('mapeia B/C/Bangalô', () {
      expect(normalizarBloco('B (HERA)'), 'B');
      expect(normalizarBloco('C (AFRODITE)'), 'C');
      expect(normalizarBloco('Bangalo'), 'BANGALO');
      expect(normalizarBloco('BANGALO LUXURY'), 'BANGALO');
    });
    test('rejeita blocos fora da 1ª etapa', () {
      expect(normalizarBloco('3° PAVIMENTO'), isNull);
      expect(normalizarBloco('D (ATENA)'), isNull);
      expect(normalizarBloco('TÉRREO'), isNull);
    });
  });

  group('imovelIdDoContrato', () {
    test('liga apto válido', () {
      expect(imovelIdDoContrato(_contrato(localizador: '1', imovel: '101')), 'B-101');
      expect(imovelIdDoContrato(_contrato(localizador: '2', imovel: '5')), 'B-5');
      expect(
        imovelIdDoContrato(_contrato(localizador: '3', bloco: 'C (AFRODITE)', imovel: '501')),
        'C-501',
      );
    });
    test('rejeita número inválido (06/15 do térreo e fora de range)', () {
      expect(imovelIdDoContrato(_contrato(localizador: '4', imovel: '6')), isNull);
      expect(imovelIdDoContrato(_contrato(localizador: '5', imovel: '15')), isNull);
      expect(imovelIdDoContrato(_contrato(localizador: '6', imovel: '235')), isNull);
      // 501 não existe no Bloco B
      expect(imovelIdDoContrato(_contrato(localizador: '7', imovel: '501')), isNull);
    });
    test('contrato de projeto antigo vira avulso (null)', () {
      expect(
        imovelIdDoContrato(_contrato(localizador: '8', bloco: '3° PAVIMENTO', imovel: '313')),
        isNull,
      );
    });
    test('bangalô liga por letra F–Q', () {
      expect(
        imovelIdDoContrato(_contrato(localizador: '9', bloco: 'Bangalo', imovel: 'F')),
        'BANG-F',
      );
      expect(
        imovelIdDoContrato(_contrato(localizador: '10', bloco: 'Bangalo', imovel: 'Z')),
        isNull,
      );
    });
  });

  group('tierDoProduto', () {
    test('lê tier do nome do produto', () {
      expect(tierDoProduto('LUXO PRATA 1° / 2° / 3º', 'Cota-01'), TierCota.prata);
      expect(tierDoProduto('LUXO BRONZE T', 'Cota-30'), TierCota.bronze);
      expect(tierDoProduto('LUXO OURO 4º / 5º', 'Cota-02'), TierCota.ouro);
      expect(tierDoProduto('BANGALO LUXURY DIAMANTE', 'Cota-01'), TierCota.diamante);
    });
    test('cota Integral tem prioridade', () {
      expect(tierDoProduto('LUXO PRATA', 'Integral'), TierCota.integral);
    });
    test('produto desconhecido retorna null', () {
      expect(tierDoProduto('Produto Qualquer', 'Cota-01'), isNull);
    });
  });

  group('analisarEmpreendimento', () {
    final inv = inventarioPrimeiraEtapa();

    test('imóvel sem contrato fica indefinido', () {
      final r = analisarEmpreendimento(inv, []);
      final a = r.imoveis.firstWhere((i) => i.imovel.id == 'B-101');
      expect(a.situacao, SituacaoImovel.indefinido);
      expect(a.tier, isNull);
      expect(a.cotasVendidas, 0);
      expect(a.cotasTotal, isNull);
      expect(r.totalUnidades, 228);
      expect(r.totalComVenda, 0);
    });

    test('prata parcial: 3 de 26 cotas vendidas', () {
      final contratos = [
        _contrato(localizador: 'a', imovel: '101', cota: 'Cota-01'),
        _contrato(localizador: 'b', imovel: '101', cota: 'Cota-02'),
        _contrato(localizador: 'c', imovel: '101', cota: 'Cota-03'),
      ];
      final r = analisarEmpreendimento(inv, contratos);
      final a = r.imoveis.firstWhere((i) => i.imovel.id == 'B-101');
      expect(a.tier, TierCota.prata);
      expect(a.cotasVendidas, 3);
      expect(a.cotasTotal, 26);
      expect(a.disponiveis, 23);
      expect(a.situacao, SituacaoImovel.parcial);
      expect(a.ocupacaoPct, closeTo(11.5, 0.1));
      // agregação por tier
      expect(r.porTier[TierCota.prata]!.cotasVendidas, 3);
      expect(r.porTier[TierCota.prata]!.cotasTotal, 26);
      expect(r.porTier[TierCota.prata]!.disponiveis, 23);
    });

    test('diamante (1 cota) fica esgotado', () {
      final contratos = [
        _contrato(localizador: 'd', imovel: '102', produto: 'LUXO DIAMANTE', cota: 'Cota-01'),
      ];
      final r = analisarEmpreendimento(inv, contratos);
      final a = r.imoveis.firstWhere((i) => i.imovel.id == 'B-102');
      expect(a.tier, TierCota.diamante);
      expect(a.cotasTotal, 1);
      expect(a.disponiveis, 0);
      expect(a.situacao, SituacaoImovel.esgotado);
    });

    test('integral fica esgotado com 1 cota', () {
      final contratos = [
        _contrato(localizador: 'i', imovel: '103', produto: 'LUXO PRATA T/4/5/6', cota: 'Integral'),
      ];
      final r = analisarEmpreendimento(inv, contratos);
      final a = r.imoveis.firstWhere((i) => i.imovel.id == 'B-103');
      expect(a.tier, TierCota.integral);
      expect(a.situacao, SituacaoImovel.esgotado);
    });

    test('detecta conflito de tier no mesmo imóvel', () {
      final contratos = [
        _contrato(localizador: 'e', imovel: '104', produto: 'LUXO PRATA', cota: 'Cota-01'),
        _contrato(localizador: 'f', imovel: '104', produto: 'LUXO OURO', cota: 'Cota-02'),
      ];
      final r = analisarEmpreendimento(inv, contratos);
      final a = r.imoveis.firstWhere((i) => i.imovel.id == 'B-104');
      expect(a.conflitoTier, isTrue);
      expect(a.temAlerta, isTrue);
      expect(r.comAlerta.any((i) => i.imovel.id == 'B-104'), isTrue);
    });

    test('detecta cota duplicada', () {
      final contratos = [
        _contrato(localizador: 'g', imovel: '105', cota: 'Cota-07'),
        _contrato(localizador: 'h', imovel: '105', cota: 'Cota-07'),
      ];
      final r = analisarEmpreendimento(inv, contratos);
      final a = r.imoveis.firstWhere((i) => i.imovel.id == 'B-105');
      expect(a.cotasDuplicadas, contains('Cota-07'));
      expect(a.cotasVendidas, 1); // distintas
      expect(a.temAlerta, isTrue);
    });

    test('contrato fora da 1ª etapa entra como avulso', () {
      final contratos = [
        _contrato(localizador: 'x', bloco: 'D (ATENA)', imovel: '999'),
        _contrato(localizador: 'y', imovel: '106'), // andar 1 tem o 06 → liga
      ];
      final r = analisarEmpreendimento(inv, contratos);
      expect(r.avulsos.length, 1); // só o D (ATENA); o 106 é andar 1 válido
      expect(r.avulsos.first.localizador, 'x');
    });

    test('receita soma os valores das cotas do imóvel', () {
      final contratos = [
        _contrato(localizador: 'r1', imovel: '107', cota: 'Cota-01', valor: 30000),
        _contrato(localizador: 'r2', imovel: '107', cota: 'Cota-02', valor: 20000),
      ];
      final r = analisarEmpreendimento(inv, contratos);
      final a = r.imoveis.firstWhere((i) => i.imovel.id == 'B-107');
      expect(a.receita, 50000);
      expect(r.porBloco['B']!.receita, 50000);
    });
  });
}
