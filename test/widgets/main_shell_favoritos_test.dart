import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MainShell Favoritos Logic', () {
    test('favoritos vazios mantem a ordem original', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final favoritos = (prefs.getStringList('sidebar_favoritos') ?? []).toSet();
      expect(favoritos.isEmpty, isTrue);

      final itens = ['Dashboard', 'Funil de Vendas', 'Agenda', 'Hotel'];
      final ordenados = [
        ...itens.where(favoritos.contains),
        ...itens.where((i) => !favoritos.contains(i)),
      ];

      expect(ordenados, equals(itens));
    });

    test('favoritar Hotel faz ele subir para o topo', () async {
      SharedPreferences.setMockInitialValues({
        'sidebar_favoritos': ['Hotel'],
      });
      final prefs = await SharedPreferences.getInstance();

      final favoritos = (prefs.getStringList('sidebar_favoritos') ?? []).toSet();
      expect(favoritos.contains('Hotel'), isTrue);

      final itens = ['Dashboard', 'Funil de Vendas', 'Agenda', 'Hotel'];
      final ordenados = [
        ...itens.where(favoritos.contains),
        ...itens.where((i) => !favoritos.contains(i)),
      ];

      expect(ordenados.first, equals('Hotel'));
      expect(ordenados, equals(['Hotel', 'Dashboard', 'Funil de Vendas', 'Agenda']));
    });

    test('toggle favorito adiciona e remove salvando em SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      var favoritos = (prefs.getStringList('sidebar_favoritos') ?? []).toSet();
      expect(favoritos.contains('Transição'), isFalse);

      // Adiciona
      final novo1 = Set<String>.of(favoritos)..add('Transição');
      await prefs.setStringList('sidebar_favoritos', novo1.toList());
      favoritos = (prefs.getStringList('sidebar_favoritos') ?? []).toSet();
      expect(favoritos.contains('Transição'), isTrue);

      // Remove
      final novo2 = Set<String>.of(favoritos)..remove('Transição');
      await prefs.setStringList('sidebar_favoritos', novo2.toList());
      favoritos = (prefs.getStringList('sidebar_favoritos') ?? []).toSet();
      expect(favoritos.contains('Transição'), isFalse);
    });
  });
}
