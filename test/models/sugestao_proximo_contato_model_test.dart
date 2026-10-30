import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/cliente_model.dart';
import 'package:crm_pessoal/models/interacao_model.dart';

/// Round-trip da sugestão de próximo contato (texto) nos dois models que a
/// carregam: `Interacao` (histórico, por interação) e `Cliente` (próximo passo
/// atual do lead).
void main() {
  group('Interacao.sugestaoProximoContato', () {
    Future<Interacao> ler(Map<String, dynamic> dados) async {
      final db = FakeFirebaseFirestore();
      final ref = db.collection('interacoes').doc('x');
      await ref.set(dados);
      return Interacao.fromFirestore(await ref.get());
    }

    test('faz round-trip por toFirestore/fromFirestore', () async {
      const texto = 'Ligar oferecendo desconto na entrada';
      final i = Interacao(
        nota: 'Conversa',
        dataInteracao: DateTime(2026, 7, 11),
        sugestaoProximoContato: texto,
      );
      final lida = await ler(i.toFirestore());
      expect(lida.sugestaoProximoContato, texto);
    });

    test('sugestão vazia não é serializada', () {
      final i = Interacao(
        nota: 'Conversa',
        dataInteracao: DateTime(2026, 7, 11),
        sugestaoProximoContato: '',
      );
      expect(i.toFirestore().containsKey('sugestaoProximoContato'), isFalse);
    });

    test('interação antiga (sem o campo) lê como null', () async {
      final lida = await ler({
        'nota': 'Conversa antiga',
        'canal': 'whatsapp',
      });
      expect(lida.sugestaoProximoContato, isNull);
    });

    test('não se confunde com oQueCombinamos', () async {
      final i = Interacao(
        nota: 'Conversa',
        dataInteracao: DateTime(2026, 7, 11),
        oQueCombinamos: 'Cliente pediu para ligar sexta',
        sugestaoProximoContato: 'Levar a proposta com desconto',
      );
      final lida = await ler(i.toFirestore());
      expect(lida.oQueCombinamos, 'Cliente pediu para ligar sexta');
      expect(lida.sugestaoProximoContato, 'Levar a proposta com desconto');
    });

    test('copyWith preserva a sugestão', () {
      final i = Interacao(
        nota: 'Conversa',
        dataInteracao: DateTime(2026, 7, 11),
        sugestaoProximoContato: 'Reforçar a condição de pagamento',
      );
      expect(i.copyWith(nota: 'Outra').sugestaoProximoContato,
          'Reforçar a condição de pagamento');
    });
  });

  group('Cliente.sugestaoProximoContato', () {
    test('lê a sugestão gravada no lead', () async {
      final db = FakeFirebaseFirestore();
      final ref = db.collection('clientes').doc('lead1');
      await ref.set({
        'nome': 'Fulano',
        'fase': 'prospeccao',
        'sugestaoProximoContato': 'Retomar falando da planta nova',
      });
      final c = Cliente.fromFirestore(await ref.get());
      expect(c.sugestaoProximoContato, 'Retomar falando da planta nova');
    });

    test('lead sem o campo lê como null', () async {
      final db = FakeFirebaseFirestore();
      final ref = db.collection('clientes').doc('lead1');
      await ref.set({'nome': 'Fulano', 'fase': 'prospeccao'});
      final c = Cliente.fromFirestore(await ref.get());
      expect(c.sugestaoProximoContato, isNull);
    });
  });
}
