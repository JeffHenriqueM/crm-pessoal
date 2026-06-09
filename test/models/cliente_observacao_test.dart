import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm_pessoal/models/cliente_model.dart';
import 'package:crm_pessoal/models/fase_enum.dart';

/// Guarda do campo livre "Observação sobre o cliente" (#53 — Jefferson).
/// O campo deve sobreviver ao round-trip de/para o Firestore em qualquer fase.
void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  Future<Cliente> salvarELer(Cliente c) async {
    await db.collection('clientes').doc('x').set(c.toFirestore());
    final doc = await db.collection('clientes').doc('x').get();
    return Cliente.fromFirestore(doc);
  }

  Cliente base({String? observacao}) => Cliente(
        nome: 'Lead Teste',
        tipo: 'Individual',
        fase: FaseCliente.prospeccao,
        dataCadastro: DateTime(2026, 1, 1),
        dataAtualizacao: DateTime(2026, 1, 1),
        observacao: observacao,
      );

  test('observacao preenchida persiste no round-trip', () async {
    final lido =
        await salvarELer(base(observacao: 'Cliente prefere contato à tarde.'));
    expect(lido.observacao, 'Cliente prefere contato à tarde.');
  });

  test('observacao nula permanece nula', () async {
    final lido = await salvarELer(base(observacao: null));
    expect(lido.observacao, isNull);
  });

  test('documento legado sem o campo lê observacao como nula', () async {
    await db.collection('clientes').doc('y').set({
      'nome': 'Lead Antigo',
      'tipo': 'Casal',
      'fase': 'negociacao',
    });
    final doc = await db.collection('clientes').doc('y').get();
    final c = Cliente.fromFirestore(doc);
    expect(c.observacao, isNull);
  });
}
