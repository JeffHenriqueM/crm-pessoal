import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/modelo_mensagem_model.dart';
import 'package:crm_pessoal/services/firestore_service.dart';

/// Modelos de mensagem com canal (WhatsApp/E-mail) e assunto.
/// Regras verificadas:
/// - criar modelo de e-mail grava canal + assunto;
/// - doc legado sem `canal` é lido como WhatsApp (retrocompat);
/// - atualizar persiste canal e assunto.
void main() {
  FirestoreService serviceCom(FakeFirebaseFirestore db) => FirestoreService(
        db: db,
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'u1', displayName: 'Fulano'),
        ),
      );

  late FakeFirebaseFirestore db;
  setUp(() => db = FakeFirebaseFirestore());

  test('cria modelo de e-mail com canal e assunto', () async {
    final s = serviceCom(db);
    await s.criarModeloMensagem(const ModeloMensagem(
      titulo: 'Notificação de mora',
      texto: 'Olá {nome}, consta débito...',
      canal: 'email',
      assunto: 'Inadimplência — {primeiroNome}',
      padrao: true,
    ));

    final lidos = await s.getModelosMensagem();
    expect(lidos.length, 1);
    final m = lidos.first;
    expect(m.canal, 'email');
    expect(m.isEmail, isTrue);
    expect(m.assunto, 'Inadimplência — {primeiroNome}');
  });

  test('doc legado sem canal é tratado como WhatsApp', () async {
    await db.collection('modelos_mensagem').add({
      'titulo': 'Antigo',
      'texto': 'Oi {nome}',
      'padrao': true,
    });

    final s = serviceCom(db);
    final m = (await s.getModelosMensagem()).first;
    expect(m.canal, 'whatsapp');
    expect(m.isEmail, isFalse);
    expect(m.assunto, isNull);
  });

  test('atualizar persiste canal e assunto', () async {
    final s = serviceCom(db);
    final id = await s.criarModeloMensagem(
        const ModeloMensagem(titulo: 'X', texto: 'corpo', canal: 'whatsapp'));

    final atual = (await s.getModelosMensagem()).firstWhere((m) => m.id == id);
    await s.atualizarModeloMensagem(atual.copyWith(
      canal: 'email',
      assunto: 'Novo assunto',
      texto: 'novo corpo',
    ));

    final depois = (await s.getModelosMensagem()).firstWhere((m) => m.id == id);
    expect(depois.canal, 'email');
    expect(depois.assunto, 'Novo assunto');
    expect(depois.texto, 'novo corpo');
  });
}
