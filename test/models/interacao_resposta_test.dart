import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/interacao_model.dart';

/// Resposta do cliente registrada DEPOIS de uma interação sem resposta:
/// o texto é persistido, recuperado e copyWith marca houveResposta=true.
void main() {
  Future<Interacao> roundTrip(Interacao i) async {
    final db = FakeFirebaseFirestore();
    final ref = db.collection('interacoes').doc('x');
    await ref.set(i.toFirestore());
    return Interacao.fromFirestore(await ref.get());
  }

  test('toFirestore/fromFirestore preserva respostaCliente e respostaEm',
      () async {
    final quando = DateTime(2026, 6, 13, 9, 30);
    final i = Interacao(
      nota: 'Mandei msg',
      dataInteracao: DateTime(2026, 6, 10),
      houveResposta: true,
      respostaCliente: 'Pode ser sexta',
      respostaEm: quando,
    );

    final lido = await roundTrip(i);
    expect(lido.respostaCliente, 'Pode ser sexta');
    expect(lido.respostaEm, quando);
    expect(lido.houveResposta, isTrue);
  });

  test('sem resposta não grava os campos de resposta', () async {
    final i = Interacao(nota: 'Liguei', dataInteracao: DateTime(2026, 6, 10));
    expect(i.toFirestore().containsKey('respostaCliente'), isFalse);
    expect(i.toFirestore().containsKey('respostaEm'), isFalse);

    final lido = await roundTrip(i);
    expect(lido.respostaCliente, isNull);
    expect(lido.respostaEm, isNull);
  });

  test('respostaEm legado/ausente vira null sem quebrar', () {
    final doc = _FakeDoc({
      'nota': 'x',
      'dataInteracao': Timestamp.fromDate(DateTime(2026, 6, 10)),
      'respostaCliente': '',
    });
    final lido = Interacao.fromFirestore(doc);
    expect(lido.respostaCliente, isNull); // string vazia → null
    expect(lido.respostaEm, isNull);
  });

  test('copyWith adiciona a resposta e marca houveResposta', () {
    final original = Interacao(
      nota: 'Sem retorno',
      dataInteracao: DateTime(2026, 6, 10),
      houveResposta: false,
    );
    final nova = original.copyWith(
      respostaCliente: 'Aceito',
      respostaEm: DateTime(2026, 6, 13),
      houveResposta: true,
    );
    expect(nova.respostaCliente, 'Aceito');
    expect(nova.houveResposta, isTrue);
    expect(nova.nota, 'Sem retorno'); // demais campos preservados
  });
}

/// DocumentSnapshot mínimo para testar fromFirestore sem emulador.
class _FakeDoc implements DocumentSnapshot {
  final Map<String, dynamic> _data;
  _FakeDoc(this._data);
  @override
  Map<String, dynamic> data() => _data;
  @override
  String get id => 'fake';
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
