import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm_pessoal/services/firestore_service.dart';

/// Guarda do carregamento de produtos (bug do "Nenhum produto cadastrado" na
/// Nova Proposta). A causa era combinar where('ativo') com orderBy('ordem'),
/// que exige índice composto inexistente — a query falhava em silêncio. A
/// correção filtra `ativo` no cliente. Estes testes pinam o comportamento.
void main() {
  late FakeFirebaseFirestore db;
  late FirestoreService service;

  setUp(() {
    db = FakeFirebaseFirestore();
    service = FirestoreService(db: db, auth: MockFirebaseAuth(signedIn: true));
  });

  Future<void> semear() async {
    await db.collection('produtos').doc('p1').set(
        {'nome': 'Villamor Bronze', 'ativo': true, 'ordem': 20});
    await db.collection('produtos').doc('p2').set(
        {'nome': 'Luxo Bronze', 'ativo': true, 'ordem': 10});
    await db.collection('produtos').doc('p3').set(
        {'nome': 'Arquivado', 'ativo': false, 'ordem': 5});
  }

  test('apenasAtivos (default) retorna só ativos, ordenados por ordem',
      () async {
    await semear();
    final lista = await service.getProdutosStream().first;
    expect(lista.map((p) => p.nome), ['Luxo Bronze', 'Villamor Bronze']);
    expect(lista.every((p) => p.ativo), isTrue);
  });

  test('apenasAtivos:false retorna todos, inclusive arquivados', () async {
    await semear();
    final lista = await service.getProdutosStream(apenasAtivos: false).first;
    expect(lista.length, 3);
    expect(lista.any((p) => !p.ativo), isTrue);
  });

  test('coleção vazia retorna lista vazia', () async {
    final lista = await service.getProdutosStream().first;
    expect(lista, isEmpty);
  });
}
