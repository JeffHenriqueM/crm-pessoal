import 'package:flutter_test/flutter_test.dart';
import 'package:crm_pessoal/models/quarto_festa_socios.dart';

/// Integridade do catálogo fixo de quartos (Hospedagem → Festa dos Sócios).
void main() {
  final numeros = quartosFestaSocios.map((q) => q.numero).toList();

  test('não há números de quarto duplicados', () {
    expect(numeros.toSet().length, numeros.length,
        reason: 'cada quarto deve aparecer uma única vez no mapa');
  });

  test('o quarto 113 não existe no mapa', () {
    expect(numeros.contains('113'), isFalse);
  });

  test('todos os números são inteiros válidos', () {
    for (final n in numeros) {
      expect(int.tryParse(n), isNotNull, reason: 'número inválido: $n');
    }
  });

  test('spot-check de categorias conforme a legenda do mapa', () {
    CategoriaQuarto cat(String numero) =>
        quartosFestaSocios.firstWhere((q) => q.numero == numero).categoria;

    expect(cat('51'), CategoriaQuarto.luxo);
    expect(cat('71'), CategoriaQuarto.studioRoom);
    expect(cat('101'), CategoriaQuarto.triplo);
    expect(cat('105'), CategoriaQuarto.triplo);
    expect(cat('128'), CategoriaQuarto.duplex);
    expect(cat('130'), CategoriaQuarto.duplex);
    expect(cat('143'), CategoriaQuarto.suiteVillamor);
    expect(cat('144'), CategoriaQuarto.comfortTerreo);
    expect(cat('162'), CategoriaQuarto.comfort2Andar);
    expect(cat('201'), CategoriaQuarto.master);
  });

  test('toda categoria do enum tem cor e rótulo definidos', () {
    for (final c in CategoriaQuarto.values) {
      expect(c.label.trim(), isNotEmpty);
      // corTexto deriva da cor; só garante que não lança.
      expect(c.corTexto, isNotNull);
    }
  });
}
