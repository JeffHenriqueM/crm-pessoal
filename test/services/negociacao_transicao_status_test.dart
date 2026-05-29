import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/services/firestore_service.dart';

/// Risco #3 — fluxo de aprovação de negociação sem validação de transição.
///
/// Os métodos aprovarNegociacao/negarNegociacao/solicitarAprovacao fazem um
/// `update` CEGO do statusAprovacao, sem checar o estado atual. Isso permite
/// transições inválidas (ex.: aprovar algo que nunca foi solicitado, ou
/// reverter uma negação direto para aprovada). Ver ticket do risco #3.
///
/// Estes testes afirmam o COMPORTAMENTO CORRETO (a transição inválida não pode
/// se concretizar). Hoje ficam VERMELHOS — guarda de regressão até o time
/// adicionar a validação. Os de transição válida já passam.
void main() {
  late FakeFirebaseFirestore db;
  late FirestoreService service;

  setUp(() {
    db = FakeFirebaseFirestore();
    service = FirestoreService(db: db, auth: MockFirebaseAuth(signedIn: true));
  });

  Future<void> semearNegociacao(String id, String statusAprovacao) {
    return db.collection('negociacoes').doc(id).set({
      'titulo': 'Proposta',
      'valorOriginal': 1000,
      'status': 'ativa',
      'statusAprovacao': statusAprovacao,
    });
  }

  Future<String?> statusAtual(String id) async {
    final doc = await db.collection('negociacoes').doc(id).get();
    return doc.data()?['statusAprovacao'] as String?;
  }

  /// Executa a ação tolerando exceção — uma vez corrigido, o serviço pode
  /// rejeitar a transição lançando; o que importa é o estado final.
  Future<void> tentar(Future<void> Function() acao) async {
    try {
      await acao();
    } catch (_) {/* esperado quando a validação existir */}
  }

  group('Transições INVÁLIDAS devem ser rejeitadas (red — risco #3)', () {
    test('não aprova negociação que nunca foi solicitada (semSolicitacao)',
        () async {
      await semearNegociacao('n1', 'semSolicitacao');

      await tentar(() => service.aprovarNegociacao('n1'));

      expect(await statusAtual('n1'), isNot('aprovada'),
          reason:
              'Aprovou sem passar por "pendente" — transição inválida (#3).');
    });

    test('não nega negociação que nunca foi solicitada (semSolicitacao)',
        () async {
      await semearNegociacao('n2', 'semSolicitacao');

      await tentar(() => service.negarNegociacao('n2'));

      expect(await statusAtual('n2'), isNot('negada'),
          reason: 'Negou algo nunca submetido a aprovação — inválido (#3).');
    });

    test('não aprova negociação já negada (negada → aprovada)', () async {
      await semearNegociacao('n3', 'negada');

      await tentar(() => service.aprovarNegociacao('n3'));

      expect(await statusAtual('n3'), isNot('aprovada'),
          reason:
              'Reverteu negação direto para aprovada sem novo fluxo (#3).');
    });
  });

  group('Transições VÁLIDAS continuam funcionando (green)', () {
    test('solicitar aprovação: semSolicitacao → pendente', () async {
      await semearNegociacao('v1', 'semSolicitacao');

      await service.solicitarAprovacao('v1');

      expect(await statusAtual('v1'), 'pendente');
    });

    test('aprovar: pendente → aprovada', () async {
      await semearNegociacao('v2', 'pendente');

      await service.aprovarNegociacao('v2');

      expect(await statusAtual('v2'), 'aprovada');
    });

    test('negar: pendente → negada', () async {
      await semearNegociacao('v3', 'pendente');

      await service.negarNegociacao('v3');

      expect(await statusAtual('v3'), 'negada');
    });
  });
}
