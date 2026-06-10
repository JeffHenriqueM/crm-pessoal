import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/utils/datas_uteis.dart';

/// Comportamento esperado: `adicionarDiasUteis` avança N dias úteis,
/// pulando sábado e domingo, e nunca cai num fim de semana.
void main() {
  group('adicionarDiasUteis', () {
    test('+3 a partir de uma quarta cai na segunda seguinte', () {
      // Qua 2026-06-10 → Qui 11, Sex 12, (pula Sáb/Dom) → Seg 15
      final base = DateTime(2026, 6, 10);
      final r = adicionarDiasUteis(base, 3);
      expect(r, DateTime(2026, 6, 15));
      expect(r.weekday, DateTime.monday);
    });

    test('+1 a partir de uma sexta cai na segunda (pula o fim de semana)', () {
      final sexta = DateTime(2026, 6, 12);
      final r = adicionarDiasUteis(sexta, 1);
      expect(r, DateTime(2026, 6, 15));
    });

    test('+3 a partir de uma sexta cai na quarta seguinte', () {
      // Sex 12 → Seg 15, Ter 16, Qua 17
      final sexta = DateTime(2026, 6, 12);
      final r = adicionarDiasUteis(sexta, 3);
      expect(r, DateTime(2026, 6, 17));
    });

    test('resultado nunca cai em sábado ou domingo', () {
      for (var dia = 1; dia <= 30; dia++) {
        final r = adicionarDiasUteis(DateTime(2026, 6, dia), 3);
        expect(r.weekday == DateTime.saturday, isFalse);
        expect(r.weekday == DateTime.sunday, isFalse);
      }
    });

    test('descarta o horário da base (retorna meia-noite local)', () {
      final base = DateTime(2026, 6, 10, 16, 31, 53);
      final r = adicionarDiasUteis(base, 3);
      expect(r.hour, 0);
      expect(r.minute, 0);
      expect(r.second, 0);
    });

    test('dias <= 0 retorna o próprio dia (sem horário)', () {
      final base = DateTime(2026, 6, 10, 9, 0);
      expect(adicionarDiasUteis(base, 0), DateTime(2026, 6, 10));
    });
  });
}
