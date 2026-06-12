import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/interacao_model.dart';
import 'package:crm_pessoal/services/firestore_service.dart';

/// Comportamento esperado: ao registrar uma interação, é possível agendar o
/// próximo contato na mesma ação, fazendo o lead sair do "em atraso"
/// (que depende de `proximoContato` estar no passado).
void main() {
  group('FirestoreService.adicionarInteracao — próximo contato', () {
    late FakeFirebaseFirestore db;
    late FirestoreService service;

    setUp(() async {
      db = FakeFirebaseFirestore();
      service = FirestoreService(
        db: db,
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'vendedor_a', displayName: 'Vendedor A'),
        ),
      );
      await db.collection('usuarios').doc('vendedor_a').set({
        'nome': 'Vendedor A',
        'perfil': 'vendedor',
      });
      // Lead começa ATRASADO: proximoContato no passado.
      await db.collection('clientes').doc('lead1').set({
        'nome': 'Lead Teste',
        'fase': 'prospeccao',
        'proximoContato': Timestamp.fromDate(DateTime(2026, 6, 9)),
      });
    });

    Interacao novaInteracao() => Interacao(
          titulo: 'Contato',
          nota: 'Mensagem de retomada enviada',
          canal: Canal.whatsapp,
          houveResposta: false,
          dataInteracao: DateTime.now(),
        );

    test('agenda o proximoContato informado no lead', () async {
      final novaData = DateTime(2026, 6, 15);
      await service.adicionarInteracao('lead1', novaInteracao(),
          proximoContato: novaData);

      final doc = await db.collection('clientes').doc('lead1').get();
      final ts = doc.data()?['proximoContato'] as Timestamp?;
      expect(ts, isNotNull);
      expect(ts!.toDate(), novaData);
    });

    test('lead deixa de estar em atraso após agendar via interação', () async {
      final futuro = DateTime.now().add(const Duration(days: 5));
      await service.adicionarInteracao('lead1', novaInteracao(),
          proximoContato: futuro);

      final doc = await db.collection('clientes').doc('lead1').get();
      final ts = doc.data()?['proximoContato'] as Timestamp;
      // "em atraso" = proximoContato antes de agora. Agora não está mais.
      expect(ts.toDate().isAfter(DateTime.now()), isTrue);
    });

    test('sem proximoContato, não altera o agendamento existente', () async {
      await service.adicionarInteracao('lead1', novaInteracao());

      final doc = await db.collection('clientes').doc('lead1').get();
      final ts = doc.data()?['proximoContato'] as Timestamp;
      // Mantém o valor original (não foi tocado).
      expect(ts.toDate(), DateTime(2026, 6, 9));
      // Mas a interação foi registrada normalmente.
      expect(doc.data()?['interaction_count'], 1);
    });
  });

  group('FirestoreService.adicionarInteracao — statusMensagem', () {
    late FakeFirebaseFirestore db;
    late FirestoreService service;

    setUp(() async {
      db = FakeFirebaseFirestore();
      service = FirestoreService(
        db: db,
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'vendedor_a', displayName: 'Vendedor A'),
        ),
      );
      await db.collection('usuarios').doc('vendedor_a').set({
        'nome': 'Vendedor A',
        'perfil': 'vendedor',
      });
      // Lead com mensagem pendente (badge vermelho "Msg. não enviada").
      await db.collection('clientes').doc('lead1').set({
        'nome': 'Lead Teste',
        'fase': 'negociacao',
        'statusMensagem': 'nao_enviada',
      });
    });

    Interacao interacaoComResposta(bool houve) => Interacao(
          titulo: 'Contato',
          nota: 'Mensagem de acompanhamento',
          canal: Canal.whatsapp,
          houveResposta: houve,
          dataInteracao: DateTime.now(),
        );

    test('interação sem resposta marca mensagem como enviada (aguardando)',
        () async {
      await service.adicionarInteracao('lead1', interacaoComResposta(false));

      final doc = await db.collection('clientes').doc('lead1').get();
      // Saiu de "nao_enviada": conta como enviada, aguardando resposta.
      expect(doc.data()?['statusMensagem'], 'enviada_sem_resposta');
    });

    test('interação com resposta marca mensagem como respondida', () async {
      await service.adicionarInteracao('lead1', interacaoComResposta(true));

      final doc = await db.collection('clientes').doc('lead1').get();
      expect(doc.data()?['statusMensagem'], 'enviada_com_resposta');
    });
  });

  group('FirestoreService.adicionarInteracao — data retroativa', () {
    late FakeFirebaseFirestore db;
    late FirestoreService service;

    setUp(() async {
      db = FakeFirebaseFirestore();
      service = FirestoreService(
        db: db,
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'vendedor_a', displayName: 'Vendedor A'),
        ),
      );
      await db.collection('usuarios').doc('vendedor_a').set({
        'nome': 'Vendedor A',
        'perfil': 'vendedor',
      });
      await db.collection('clientes').doc('lead1').set({
        'nome': 'Lead Teste',
        'fase': 'prospeccao',
      });
    });

    test('persiste a dataInteracao informada (não sobrescreve com "agora")',
        () async {
      final dataAntiga = DateTime(2025, 11, 3, 10, 0);
      await service.adicionarInteracao(
        'lead1',
        Interacao(
          nota: 'Conversa antiga importada do WhatsApp',
          canal: Canal.whatsapp,
          houveResposta: true,
          dataInteracao: dataAntiga,
        ),
      );

      final snap =
          await db.collection('clientes').doc('lead1').collection('interacoes').get();
      expect(snap.docs.length, 1);
      final ts = snap.docs.first.data()['dataInteracao'] as Timestamp;
      expect(ts.toDate(), dataAntiga);
    });

    test('ultimoContato reflete a data informada na interação', () async {
      final dataAntiga = DateTime(2025, 11, 3, 10, 0);
      await service.adicionarInteracao(
        'lead1',
        Interacao(
          nota: 'Conversa antiga',
          canal: Canal.whatsapp,
          houveResposta: false,
          dataInteracao: dataAntiga,
        ),
      );

      final doc = await db.collection('clientes').doc('lead1').get();
      final ts = doc.data()?['ultimoContato'] as Timestamp;
      expect(ts.toDate(), dataAntiga);
    });
  });
}
