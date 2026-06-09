import 'package:flutter_test/flutter_test.dart';
import 'package:crm_pessoal/models/festa_regras.dart';

void main() {
  group('combinarContratosFesta — escada por pontos', () {
    test('contrato único mantém o próprio tier e %', () {
      final r = combinarContratosFesta([(tier: 'bronze', pct: 15)]);
      expect(r.tier, 'bronze');
      expect(r.pct, 15);
    });

    test('bronze + bronze = prata', () {
      final r =
          combinarContratosFesta([(tier: 'bronze', pct: 10), (tier: 'bronze', pct: 20)]);
      expect(r.tier, 'prata');
      expect(r.pct, 30); // soma dos %
    });

    test('prata + prata = ouro', () {
      final r =
          combinarContratosFesta([(tier: 'prata', pct: 12), (tier: 'prata', pct: 8)]);
      expect(r.tier, 'ouro');
      expect(r.pct, 20);
    });

    test('ouro + ouro = diamante', () {
      final r =
          combinarContratosFesta([(tier: 'ouro', pct: 5), (tier: 'ouro', pct: 5)]);
      expect(r.tier, 'diamante');
    });

    test('4 contratos bronze somam para ouro (1+1+1+1=4)', () {
      final r = combinarContratosFesta([
        (tier: 'bronze', pct: 10),
        (tier: 'bronze', pct: 10),
        (tier: 'bronze', pct: 10),
        (tier: 'bronze', pct: 10),
      ]);
      expect(r.tier, 'ouro');
      expect(r.pct, 40);
    });

    test('tier misto arredonda pra baixo (bronze+prata = 3 pts → prata)', () {
      final r =
          combinarContratosFesta([(tier: 'bronze', pct: 5), (tier: 'prata', pct: 5)]);
      expect(r.tier, 'prata');
    });

    test('soma de % é limitada a 100', () {
      final r = combinarContratosFesta(
          [(tier: 'prata', pct: 70), (tier: 'prata', pct: 60)]);
      expect(r.pct, 100);
    });

    test('integral domina', () {
      final r = combinarContratosFesta(
          [(tier: 'bronze', pct: 5), (tier: 'integral', pct: 30)]);
      expect(r.tier, 'integral');
    });

    test('lista vazia retorna tier indefinido', () {
      final r = combinarContratosFesta([]);
      expect(r.tier, '?');
      expect(r.pct, 0);
    });
  });

  group('tipoEventoFesta', () {
    test('sócio >10% e em dia = voucher', () {
      expect(tipoEventoFesta(socio: true, pct: 40, atrasado: false), 'voucher');
    });
    test('sócio com exatamente 10% e em dia = voucher', () {
      expect(tipoEventoFesta(socio: true, pct: 10, atrasado: false), 'voucher');
    });
    test('sócio com menos de 10% = pagante', () {
      expect(tipoEventoFesta(socio: true, pct: 9, atrasado: false), 'pagante');
    });
    test('sócio em atraso = pagante (mesmo com % alto)', () {
      expect(tipoEventoFesta(socio: true, pct: 80, atrasado: true), 'pagante');
    });
    test('não-sócio = pagante', () {
      expect(tipoEventoFesta(socio: false, pct: 50, atrasado: false), 'pagante');
    });
  });

  group('contarCasais', () {
    test('nome único = 1 casal', () {
      expect(contarCasais('Estela Ribas'), 1);
    });
    test('dois nomes juntos = 2 casais', () {
      expect(contarCasais('Estela + João'), 2);
    });
    test('quatro nomes = 4 casais', () {
      expect(contarCasais('A + B + C + D'), 4);
    });
    test('vazio = 0', () {
      expect(contarCasais(''), 0);
    });
  });
}
