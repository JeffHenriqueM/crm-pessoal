import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/services/firestore_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreService service;

  setUp(() {
    db = FakeFirebaseFirestore();
    service = FirestoreService(
      db: db,
      auth: MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user-admin', displayName: 'Admin Teste'),
      ),
    );
  });

  group('FirestoreService — Transição: atualizações de sócios', () {
    test('retorna mapa vazio quando documento ainda não existe', () async {
      final mapa = await service.getAtualizacoesSociosTransicao();
      expect(mapa, isEmpty);
    });

    test('salva e recupera atualização de sócio com status, fases e distrato', () async {
      await service.salvarAtualizacaoSocioTransicao(
        nomeSocio: 'JOÃO DA SILVA',
        status: 'Aceitar',
        fases: ['Informado', 'Aguardando contrato'],
        negociacaoDistrato: '',
        observacoes: 'Cliente confirmou por telefone.',
      );

      final mapa = await service.getAtualizacoesSociosTransicao();
      expect(mapa.containsKey('JOÃO DA SILVA'), isTrue);
      final dados = mapa['JOÃO DA SILVA']!;
      expect(dados['nome'], 'JOÃO DA SILVA');
      expect(dados['status'], 'Aceitar');
      expect(dados['fases'], ['Informado', 'Aguardando contrato']);
      expect(dados['negociacaoDistrato'], '');
      expect(dados['observacoes'], 'Cliente confirmou por telefone.');
      expect(dados['atualizadoPorNome'], 'Admin Teste');
    });

    test('salva e recupera sócio que solicitou distrato com negociação preenchida', () async {
      await service.salvarAtualizacaoSocioTransicao(
        nomeSocio: 'MARIA SOUZA',
        status: 'Recusar',
        fases: ['Informado', 'Solicitou distrato'],
        negociacaoDistrato: 'Acordo de devolução de R\$ 40.000 em 5x',
        observacoes: 'Não tem interesse no hotel.',
      );

      final mapa = await service.getAtualizacoesSociosTransicao();
      expect(mapa.containsKey('MARIA SOUZA'), isTrue);
      final dados = mapa['MARIA SOUZA']!;
      expect(dados['status'], 'Recusar');
      expect(dados['fases'], contains('Solicitou distrato'));
      expect(dados['negociacaoDistrato'], 'Acordo de devolução de R\$ 40.000 em 5x');
    });

    test('removerAtualizacaoSocioTransicao apaga os dados do sócio', () async {
      await service.salvarAtualizacaoSocioTransicao(
        nomeSocio: 'CARLOS EDUARDO',
        status: 'Aguardando Resposta',
        fases: ['Informado'],
      );

      var mapa = await service.getAtualizacoesSociosTransicao();
      expect(mapa.containsKey('CARLOS EDUARDO'), isTrue);

      await service.removerAtualizacaoSocioTransicao('CARLOS EDUARDO');

      mapa = await service.getAtualizacoesSociosTransicao();
      expect(mapa.containsKey('CARLOS EDUARDO'), isFalse);
    });

    test('permite múltiplas fases simultâneas e preserva outros sócios', () async {
      await service.salvarAtualizacaoSocioTransicao(
        nomeSocio: 'SOCIO A',
        status: 'Aceitar',
        fases: ['Informado', 'Aguardando contrato', 'Contrato Hotel Villamor assinado'],
      );

      await service.salvarAtualizacaoSocioTransicao(
        nomeSocio: 'SOCIO B',
        status: 'Aguardando Resposta',
        fases: ['Informado', 'Pagamento congelado'],
      );

      final mapa = await service.getAtualizacoesSociosTransicao();
      expect(mapa.length, 2);
      expect(mapa['SOCIO A']?['fases'], hasLength(3));
      expect(mapa['SOCIO B']?['fases'], ['Informado', 'Pagamento congelado']);

      // Remove apenas SOCIO A
      await service.removerAtualizacaoSocioTransicao('SOCIO A');
      final mapaAposRemocao = await service.getAtualizacoesSociosTransicao();
      expect(mapaAposRemocao.containsKey('SOCIO A'), isFalse);
      expect(mapaAposRemocao.containsKey('SOCIO B'), isTrue);
    });
  });
}
