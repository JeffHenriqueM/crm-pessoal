import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/ticket_model.dart';

/// Guarda do bug "aba Todos 100% vazia para super admin".
///
/// Causa: alguns tickets tiveram `dataAtualizacao` gravado como String ISO (não
/// Timestamp) por um script antigo. O `Ticket.fromFirestore` fazia
/// `as Timestamp?`, que ESTOURA num String — e como `getTicketsStream` mapeia
/// todos os docs de uma vez, um único doc ruim derrubava a lista inteira.
///
/// Comportamento correto: `fromFirestore` tolera data em texto/tipo inesperado
/// (parseia ou cai no fallback) e nunca lança.
void main() {
  Future<Ticket> ler(Map<String, dynamic> dados) async {
    final db = FakeFirebaseFirestore();
    final ref = db.collection('tickets').doc('x');
    await ref.set(dados);
    return Ticket.fromFirestore(await ref.get());
  }

  test('dataAtualizacao como String ISO não estoura e é parseada', () async {
    late Ticket t;
    expect(
      () async => t = await ler({
        'numero': 43,
        'titulo': 'Ticket legado',
        'status': 'aguardandoValidacao',
        'dataCriacao': Timestamp.fromDate(DateTime(2026, 5, 31)),
        'dataAtualizacao': '2026-06-18T18:59:17.573Z',
      }),
      returnsNormally,
    );
    t = await ler({
      'numero': 43,
      'titulo': 'Ticket legado',
      'status': 'aguardandoValidacao',
      'dataCriacao': Timestamp.fromDate(DateTime(2026, 5, 31)),
      'dataAtualizacao': '2026-06-18T18:59:17.573Z',
    });
    expect(t.dataAtualizacao, DateTime.parse('2026-06-18T18:59:17.573Z'));
    expect(t.numero, 43);
  });

  test('dataCriacao como String também é tolerada', () async {
    final t = await ler({
      'titulo': 'x',
      'dataCriacao': '2026-05-31T12:33:06.889Z',
      'dataAtualizacao': Timestamp.fromDate(DateTime(2026, 6, 1)),
    });
    expect(t.dataCriacao, DateTime.parse('2026-05-31T12:33:06.889Z'));
  });

  test('Timestamp normal continua funcionando', () async {
    final quando = DateTime(2026, 7, 3, 14, 34);
    final t = await ler({
      'numero': 68,
      'titulo': 'DISTRATOS',
      'dataAtualizacao': Timestamp.fromDate(quando),
    });
    expect(t.dataAtualizacao, quando);
    expect(t.numero, 68);
  });

  test('campos de data ausentes caem no fallback (não estoura)', () async {
    late Ticket t;
    expect(() async => t = await ler({'titulo': 'sem datas'}), returnsNormally);
    t = await ler({'titulo': 'sem datas'});
    expect(t.dataAtualizacao, isNotNull);
    expect(t.numero, 0);
  });

  test('numero como String numérica é parseado', () async {
    final t = await ler({
      'numero': '50',
      'titulo': 'x',
      'dataAtualizacao': Timestamp.fromDate(DateTime(2026, 6, 18)),
    });
    expect(t.numero, 50);
  });
}
