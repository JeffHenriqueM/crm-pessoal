import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../models/campanha_model.dart';
import '../models/cliente_model.dart';
import '../models/contato_embaixador_model.dart';
import '../models/contrato_model.dart';
import '../models/cota_model.dart';
import '../models/fase_enum.dart';
import '../models/festa_associacao.dart';
import '../models/festa_espera.dart';
import '../models/festa_validacao.dart';
import '../models/imovel_model.dart';
import '../models/interacao_model.dart';
import '../models/modelo_mensagem_model.dart';
import '../models/negociacao_model.dart';
import '../models/notificacao_inapp_model.dart';
import '../models/produto_model.dart';
import '../models/ticket_model.dart';
import '../models/usuario_model.dart';
import 'analise_imoveis.dart';

class FirestoreService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  static const _colClientes = 'clientes';
  static const _colContratos = 'contratos';
  static const _colContatosEmbaixador = 'contatos_embaixador';
  static const _colModelosMensagem = 'modelos_mensagem';
  static const _colFestaValidacoes = 'festa_socios_validacoes';
  static const _colFestaAssociacoes = 'festa_socios_associacoes';
  static const _colFestaEspera = 'festa_socios_espera';

  /// Permite injetar instâncias falsas em testes. Sem argumentos, usa as
  /// instâncias reais do Firebase (comportamento de produção inalterado).
  FirestoreService({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String get _currentUserId => _auth.currentUser?.uid ?? 'sistema';
  String get _currentUserName => _auth.currentUser?.displayName ?? 'Usuário';

  // ── Modo teste (staging) ──────────────────────────────────────────────────
  /// Quando true, todos os documentos criados recebem isTeste:true + expireAt:amanhã.
  /// Ativado automaticamente em ambiente staging via main.dart.
  static bool modoTeste = false;

  /// Aplica a flag de teste ao mapa de dados, se estiver em modo teste.
  Map<String, dynamic> _flagTeste(Map<String, dynamic> dados) {
    if (!modoTeste) return dados;
    return {
      ...dados,
      'isTeste': true,
      'expireAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 1)),
      ),
    };
  }

  // --- FESTA DOS SÓCIOS: validação de trocas de quarto ---

  /// Stream das validações de troca, indexadas pelo número do quarto.
  Stream<Map<String, FestaValidacao>> getValidacoesFestaStream() {
    return _db.collection(_colFestaValidacoes).snapshots().map((snap) {
      final m = <String, FestaValidacao>{};
      for (final d in snap.docs) {
        m[d.id] = FestaValidacao.fromMap(d.data());
      }
      return m;
    });
  }

  /// Registra (ou limpa) a decisão de troca de um quarto.
  /// [status] = 'aprovada' | 'recusada'; null remove a validação (volta a pendente).
  Future<void> setValidacaoFesta(String numeroQuarto, String? status) async {
    final ref = _db.collection(_colFestaValidacoes).doc(numeroQuarto);
    if (status == null) {
      await ref.delete();
      return;
    }
    await ref.set(
      _flagTeste({
        'status': status,
        'validadoPorId': _currentUserId,
        'validadoPorNome': _currentUserName,
        'validadoEm': FieldValue.serverTimestamp(),
      }),
    );
  }

  /// Stream das associações manuais (quarto → contrato), por número do quarto.
  Stream<Map<String, FestaAssociacao>> getAssociacoesFestaStream() {
    return _db.collection(_colFestaAssociacoes).snapshots().map((snap) {
      final m = <String, FestaAssociacao>{};
      for (final d in snap.docs) {
        m[d.id] = FestaAssociacao.fromMap(d.data());
      }
      return m;
    });
  }

  /// Vincula (ou remove) manualmente um quarto a um contrato/sócio.
  Future<void> setAssociacaoFesta(
      String numeroQuarto, FestaAssociacao? assoc) async {
    final ref = _db.collection(_colFestaAssociacoes).doc(numeroQuarto);
    if (assoc == null) {
      await ref.delete();
      return;
    }
    await ref.set(_flagTeste({
      ...assoc.toMap(),
      'validadoPorNome': _currentUserName,
      'validadoPorId': _currentUserId,
      'associadoEm': FieldValue.serverTimestamp(),
    }));
  }

  /// Move (manualmente) o ocupante de [origem] para [destino].
  /// Grava o ocupante em [destino] (já com `origem` preenchida) e, salvo se
  /// [esvaziarOrigem] for falso (caso de "juntar" no mesmo quarto de destino),
  /// marca o quarto [origem] como vago.
  Future<void> moverOcupanteFesta({
    required String origem,
    required String destino,
    required FestaAssociacao ocupanteDestino,
    bool esvaziarOrigem = true,
  }) async {
    final batch = _db.batch();
    batch.set(
      _db.collection(_colFestaAssociacoes).doc(destino),
      _flagTeste({
        ...ocupanteDestino.toMap(),
        'validadoPorNome': _currentUserName,
        'validadoPorId': _currentUserId,
        'associadoEm': FieldValue.serverTimestamp(),
      }),
    );
    if (esvaziarOrigem && origem != destino) {
      batch.set(
        _db.collection(_colFestaAssociacoes).doc(origem),
        _flagTeste({
          ...const FestaAssociacao(ocupante: '', vago: true).toMap(),
          'validadoPorNome': _currentUserName,
          'validadoPorId': _currentUserId,
          'associadoEm': FieldValue.serverTimestamp(),
        }),
      );
    }
    await batch.commit();
  }

  // --- LISTA DE ESPERA DA FESTA ---

  Stream<List<FestaEspera>> getEsperaFestaStream() {
    return _db.collection(_colFestaEspera).snapshots().map((snap) =>
        snap.docs.map((d) => FestaEspera.fromMap(d.id, d.data())).toList());
  }

  /// Tira o ocupante do quarto [origem] (deixa vago) e o coloca na lista de
  /// espera da categoria.
  Future<void> enviarParaEsperaFesta({
    required String origem,
    required FestaEspera espera,
  }) async {
    final batch = _db.batch();
    batch.set(
      _db.collection(_colFestaEspera).doc(),
      _flagTeste({
        ...espera.toMap(),
        'adicionadoPorNome': _currentUserName,
        'adicionadoPorId': _currentUserId,
        'adicionadoEm': FieldValue.serverTimestamp(),
      }),
    );
    batch.set(
      _db.collection(_colFestaAssociacoes).doc(origem),
      _flagTeste({
        ...const FestaAssociacao(ocupante: '', vago: true).toMap(),
        'validadoPorNome': _currentUserName,
        'validadoPorId': _currentUserId,
        'associadoEm': FieldValue.serverTimestamp(),
      }),
    );
    await batch.commit();
  }

  /// Coloca alguém da lista de espera em [destino] e o remove da espera.
  Future<void> colocarDaEsperaFesta({
    required String esperaId,
    required String destino,
    required FestaAssociacao ocupanteDestino,
  }) async {
    final batch = _db.batch();
    batch.set(
      _db.collection(_colFestaAssociacoes).doc(destino),
      _flagTeste({
        ...ocupanteDestino.toMap(),
        'validadoPorNome': _currentUserName,
        'validadoPorId': _currentUserId,
        'associadoEm': FieldValue.serverTimestamp(),
      }),
    );
    batch.delete(_db.collection(_colFestaEspera).doc(esperaId));
    await batch.commit();
  }

  Future<void> removerEsperaFesta(String esperaId) =>
      _db.collection(_colFestaEspera).doc(esperaId).delete();

  // --- CLIENTES ---

  Stream<List<Cliente>> getTodosClientesStream({
    String? vendedorId,
    String? perfilOverride,
    String ordenarPor = 'dataAtualizacao',
    bool descendente = true,
  }) {
    final futurePerf = perfilOverride != null
        ? Future<String>.value(perfilOverride)
        : _getCurrentUserProfile();
    return Stream.fromFuture(futurePerf)
        .asyncMap((perfil) {
          debugPrint('[Firestore] perfil=$perfil | filtro=$vendedorId | ordenar=$ordenarPor');
          final perfisComVisaoTotal = ['admin', 'pós-venda', 'financeiro', 'super admin', 'recepcao'];
          final uid = _currentUserId;

          // Admins e perfis com visão total
          if (perfisComVisaoTotal.contains(perfil)) {
            Query query = _db.collection(_colClientes);
            if (vendedorId != null && vendedorId.isNotEmpty) {
              query = query.where('vendedorId', isEqualTo: vendedorId);
            }
            query = query.orderBy(ordenarPor, descending: descendente);
            return query.snapshots().map(
                (s) => s.docs
                    .map((d) => Cliente.fromFirestore(d))
                    // Atendimentos ficam apenas na tela de recepção
                    .where((c) => c.fase != FaseCliente.atendimento)
                    // Exclui registros soft-deleted
                    .where((c) => !c.deletado)
                    .toList());
          }

          // Vendedor/captador: vê leads onde é vendedor (closer/FTB) OU liner
          final streamVendedor = _db
              .collection(_colClientes)
              .where('vendedorId', isEqualTo: uid)
              .snapshots()
              .map((s) => s.docs.map((d) => Cliente.fromFirestore(d)).toList());

          final streamLiner = _db
              .collection(_colClientes)
              .where('linerId', isEqualTo: uid)
              .snapshots()
              .map((s) => s.docs.map((d) => Cliente.fromFirestore(d)).toList());

          return Rx.combineLatest2<List<Cliente>, List<Cliente>, List<Cliente>>(
            streamVendedor,
            streamLiner,
            (vendedores, liners) {
              final vistos = <String>{};
              final result = <Cliente>[];
              for (final c in [...vendedores, ...liners]) {
                if (c.id != null && vistos.add(c.id!)) result.add(c);
              }
              // Atendimentos ainda não promovidos ficam apenas na tela de recepção
              result.removeWhere((c) => c.fase == FaseCliente.atendimento);
              // Exclui registros soft-deleted
              result.removeWhere((c) => c.deletado);
              result.sort((a, b) => b.dataAtualizacao.compareTo(a.dataAtualizacao));
              return result;
            },
          );
        })
        .switchMap((stream) => stream);
  }

  /// Stream de atendimentos para a tela de recepção.
  /// Perfil 'recepcao': todos os atendimentos de todos os embaixadores.
  /// Outros perfis: apenas os atendimentos vinculados ao usuário logado.
  Stream<List<Cliente>> getClientesRecepcaoStream() {
    return Stream.fromFuture(_getCurrentUserProfile()).asyncMap((perfil) {
      if (perfil == 'recepcao') {
        return _db
            .collection(_colClientes)
            .where('fase', isEqualTo: 'atendimento')
            .snapshots()
            .map((s) {
              final result = s.docs
                  .map<Cliente>(Cliente.fromFirestore)
                  .where((c) => !c.deletado)
                  .toList();
              result.sort((a, b) {
                final da = a.dataEntradaSala ?? a.dataCadastro;
                final db = b.dataEntradaSala ?? b.dataCadastro;
                return db.compareTo(da);
              });
              return result;
            });
      }

      final uid = _currentUserId;

      List<Cliente> fromSnap(s) =>
          s.docs.map<Cliente>((d) => Cliente.fromFirestore(d)).toList();

      final streamCriados = _db
          .collection(_colClientes)
          .where('criadoPorId', isEqualTo: uid)
          .snapshots()
          .map(fromSnap);

      final streamCaptador = _db
          .collection(_colClientes)
          .where('captadorId', isEqualTo: uid)
          .snapshots()
          .map(fromSnap);

      final streamLiner = _db
          .collection(_colClientes)
          .where('linerId', isEqualTo: uid)
          .snapshots()
          .map(fromSnap);

      return Rx.combineLatest3<List<Cliente>, List<Cliente>, List<Cliente>,
          List<Cliente>>(
        streamCriados,
        streamCaptador,
        streamLiner,
        (criados, captados, liners) {
          final vistos = <String>{};
          final result = <Cliente>[];
          for (final c in [...criados, ...captados, ...liners]) {
            if (c.id != null && vistos.add(c.id!)) result.add(c);
          }
          result.retainWhere((c) => c.fase == FaseCliente.atendimento);
          result.removeWhere((c) => c.deletado);
          result.sort((a, b) {
            final da = a.dataEntradaSala ?? a.dataCadastro;
            final db = b.dataEntradaSala ?? b.dataCadastro;
            return db.compareTo(da);
          });
          return result;
        },
      );
    }).switchMap((stream) => stream);
  }

  /// Stream de leads que já avançaram no funil.
  /// Perfil 'recepcao': todos os leads de todos os embaixadores.
  /// Outros perfis: apenas leads criados pelo usuário logado.
  Stream<List<Cliente>> getFunilRecepcaoStream() {
    return Stream.fromFuture(_getCurrentUserProfile()).asyncMap((perfil) {
      debugPrint('[FunilRecepcao] perfil=$perfil');
      if (perfil == 'recepcao') {
        return _db
            .collection(_colClientes)
            .orderBy('dataAtualizacao', descending: true)
            .snapshots()
            .map((s) => s.docs
                .map<Cliente>(Cliente.fromFirestore)
                .where((c) => c.fase != FaseCliente.atendimento && !c.deletado)
                .toList());
      }

      final uid = _currentUserId;
      return _db
          .collection(_colClientes)
          .where('criadoPorId', isEqualTo: uid)
          .orderBy('dataAtualizacao', descending: true)
          .snapshots()
          .map((s) => s.docs
              .map<Cliente>(Cliente.fromFirestore)
              .where((c) => c.fase != FaseCliente.atendimento && !c.deletado)
              .toList());
    }).switchMap((stream) => stream);
  }

  Future<String> adicionarCliente(Cliente cliente) async {
    final dados = cliente.toFirestore();
    dados['criadoPorId'] = _currentUserId;
    dados['criadoPorNome'] = _currentUserName;
    dados['atualizadoPorId'] = _currentUserId;
    dados['atualizadoPorNome'] = _currentUserName;
    dados['dataCadastro'] = FieldValue.serverTimestamp();
    dados['dataAtualizacao'] = FieldValue.serverTimestamp();
    final docRef = await _db.collection(_colClientes).add(_flagTeste(dados));
    return docRef.id;
  }

  /// Retorna o próximo número de atendimento (atômico via transação Firestore).
  Future<int> proximoNumeroAtendimento() async {
    final ref = _db.collection('config').doc('contadores');
    return await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final atual = (snap.data()?['atendimentos'] ?? 0) as int;
      final proximo = atual + 1;
      tx.set(ref, {'atendimentos': proximo}, SetOptions(merge: true));
      return proximo;
    });
  }

  Future<void> atualizarFaseCliente(String id, FaseCliente novaFase,
      {String? motivo}) async {
    final dados = {
      'fase': novaFase.toString().split('.').last,
      'motivoNaoVenda': motivo,
      'dataAtualizacao': FieldValue.serverTimestamp(),
      'atualizadoPorId': _currentUserId,
      'atualizadoPorNome': _currentUserName,
    };
    await _db.collection(_colClientes).doc(id).update(dados);
    await _adicionarInteracaoAutomatica(
        id, 'Fase alterada para: ${novaFase.nomeDisplay}');
    // Snapshot de histórico (#19)
    await _salvarSnapshotCliente(id, dados, tipo: 'mudanca_fase');
  }

  /// Vincula (ou desvincula, passando null) um lead a um contrato fechado.
  /// Usado ao mover o lead para a fase Fechado.
  Future<void> vincularContratoACliente(
      String clienteId, String? contratoId, String? contratoNome) async {
    await _db.collection(_colClientes).doc(clienteId).set({
      'contratoVinculadoId': contratoId,
      'contratoVinculadoNome': contratoNome,
    }, SetOptions(merge: true));
  }

  Future<void> atualizarClienteDetalhes(
      String id, Map<String, dynamic> dados) async {
    dados['dataAtualizacao'] = FieldValue.serverTimestamp();
    dados['atualizadoPorId'] = _currentUserId;
    dados['atualizadoPorNome'] = _currentUserName;
    await _db.collection(_colClientes).doc(id).update(dados);
    // Salva snapshot do estado atual para histórico (#19)
    await _salvarSnapshotCliente(id, dados, tipo: 'edicao');
  }

  /// Soft-delete: marca como deletado em vez de apagar permanentemente (#19).
  /// Registra na coleção audit_log para rastreamento crítico.
  Future<void> deletarCliente(String id) async {
    final nomeCliente = await _db
        .collection(_colClientes)
        .doc(id)
        .get()
        .then((d) => d.data()?['nome'] as String? ?? 'Cliente');

    // Soft-delete + auditoria em transação atômica:
    // se o audit_log não puder ser gravado, o soft-delete também não persiste.
    final clienteRef = _db.collection(_colClientes).doc(id);
    final auditRef   = _db.collection('audit_log').doc();

    await _db.runTransaction((tx) async {
      tx.update(clienteRef, {
        'deletado': true,
        'excluidoPorId': _currentUserId,
        'excluidoPorNome': _currentUserName,
        'dataExclusao': FieldValue.serverTimestamp(),
        'dataAtualizacao': FieldValue.serverTimestamp(),
      });
      tx.set(auditRef, {
        'tipo': 'exclusao_cliente',
        'clienteId': id,
        'clienteNome': nomeCliente,
        'autorId': _currentUserId,
        'autorNome': _currentUserName,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  // --- INTERAÇÕES ---

  Stream<List<Interacao>> getInteracoesStream(String clienteId) {
    return _db
        .collection(_colClientes)
        .doc(clienteId)
        .collection('interacoes')
        .orderBy('dataInteracao', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Interacao.fromFirestore(d)).toList());
  }

  /// Registra uma interação no lead.
  ///
  /// Se [proximoContato] for informado, agenda o próximo contato na MESMA
  /// escrita — é isto que tira o lead do estado "em atraso" (o badge depende
  /// de `proximoContato` estar no passado). Sem ele, mantém o comportamento
  /// anterior (só atualiza contadores e `ultimoContato`).
  Future<void> adicionarInteracao(
    String clienteId,
    Interacao interacao, {
    DateTime? proximoContato,
  }) async {
    final dados = interacao.toFirestore();
    dados['autorId']       = _currentUserId;
    dados['autorNome']     = _currentUserName;
    dados['dataInteracao'] = FieldValue.serverTimestamp();
    dados['criadoEm']      = FieldValue.serverTimestamp();

    final clienteRef = _db.collection(_colClientes).doc(clienteId);
    await Future.wait([
      clienteRef.collection('interacoes').add(_flagTeste(dados)),
      clienteRef.update({
        'interaction_count': FieldValue.increment(1),
        // Marca a data do último contato real (base do "Risco de Silêncio").
        'ultimoContato': FieldValue.serverTimestamp(),
        // Agenda o próximo contato junto com a interação (tira do "em atraso").
        if (proximoContato != null)
          'proximoContato': Timestamp.fromDate(proximoContato),
        if (!interacao.houveResposta)
          'no_response_count': FieldValue.increment(1),
        if (interacao.houveResposta)
          'no_response_count': 0,
      }),
      // Contador mensal de interações do autor (meta "mensagens enviadas").
      _incrementarContadorInteracaoUsuario(),
    ]);
  }

  /// Chave do mês no formato 'AAAA-M' (ex.: '2026-6'), usada no mapa
  /// `interacoesPorMes` do usuário. Mantida em um único lugar para que
  /// gravação (contador) e leitura (progresso da meta) usem o mesmo formato.
  static String chaveMesDe(DateTime dt) => '${dt.year}-${dt.month}';
  String chaveMesAtual() => chaveMesDe(DateTime.now());

  /// Incrementa em 1 o contador de interações do usuário logado no mês corrente.
  /// Grava no próprio doc (permitido pelas regras como campo de meta/contador).
  Future<void> _incrementarContadorInteracaoUsuario() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('usuarios').doc(uid).set({
      'interacoesPorMes': {chaveMesAtual(): FieldValue.increment(1)},
    }, SetOptions(merge: true));
  }

  Future<void> atualizarInteracao(String clienteId, Interacao interacao) async {
    await _db
        .collection(_colClientes)
        .doc(clienteId)
        .collection('interacoes')
        .doc(interacao.id)
        .update(interacao.toFirestore());
  }

  Future<void> excluirInteracao(String clienteId, String interacaoId) async {
    final ref = _db
        .collection(_colClientes)
        .doc(clienteId)
        .collection('interacoes')
        .doc(interacaoId);
    await Future.wait([
      ref.delete(),
      _db.collection(_colClientes).doc(clienteId).update({
        'interaction_count': FieldValue.increment(-1),
      }),
    ]);
  }

  Future<void> _adicionarInteracaoAutomatica(
    String clienteId,
    String texto, {
    String titulo = 'Evento do Sistema',
  }) async {
    await _db
        .collection(_colClientes)
        .doc(clienteId)
        .collection('interacoes')
        .add({
      'titulo':        titulo,
      'nota':          texto,
      'canal':         'sistema',
      'modalidade':    'online',
      'houveResposta': true,
      'dataInteracao': FieldValue.serverTimestamp(),
      'criadoEm':      FieldValue.serverTimestamp(),
      'autorNome':     'Sistema',
    });
  }

  /// Salva snapshot parcial dos dados alterados na subcoleção historico/ (#19).
  /// Não faz leitura prévia do documento — armazena apenas os campos modificados
  /// junto com metadados de autoria e timestamp.
  Future<void> _salvarSnapshotCliente(
    String clienteId,
    Map<String, dynamic> dados, {
    String tipo = 'edicao',
  }) async {
    // Remove valores de FieldValue (serverTimestamp) para serialização correta
    final snapshot = Map<String, dynamic>.from(dados)
      ..removeWhere((_, v) => v is FieldValue);
    await _db
        .collection(_colClientes)
        .doc(clienteId)
        .collection('historico')
        .add({
      'tipo': tipo,
      'autorId': _currentUserId,
      'autorNome': _currentUserName,
      'timestamp': FieldValue.serverTimestamp(),
      'dados': snapshot,
    });
  }

  /// Registra o resultado do rastreamento de mensagem:
  /// salva interação automática + atualiza statusMensagem no cliente.
  Future<void> registrarRastreamentoMensagem({
    required String clienteId,
    required String status,
    String? motivo,
  }) async {
    String titulo, nota;
    switch (status) {
      case 'nao_enviada':
        titulo = 'Mensagem não enviada';
        nota = (motivo != null && motivo.isNotEmpty)
            ? 'Motivo: $motivo'
            : 'Mensagem não foi enviada ao cliente.';
      case 'enviada_sem_resposta':
        titulo = 'Mensagem enviada — aguardando resposta';
        nota = 'Mensagem enviada. Cliente ainda sem retorno.';
      case 'enviada_com_resposta':
        titulo = 'Mensagem enviada — obteve resposta';
        nota = 'Mensagem enviada e cliente respondeu.';
      default:
        return;
    }

    await _db.collection(_colClientes).doc(clienteId).update({
      'statusMensagem': status,
      'dataAtualizacao': FieldValue.serverTimestamp(),
      'atualizadoPorId': _currentUserId,
    });
    await _adicionarInteracaoAutomatica(
      clienteId,
      nota,
      titulo: titulo,
    );
  }

  /// Limpa o statusMensagem (chamado quando nova data de contato é confirmada).
  Future<void> limparStatusMensagem(String clienteId) async {
    await _db.collection(_colClientes).doc(clienteId).update({
      'statusMensagem': null,
      'dataAtualizacao': FieldValue.serverTimestamp(),
      'atualizadoPorId': _currentUserId,
    });
  }

  // --- NEGOCIAÇÕES (coleção raiz) ---

  static const _colNegociacoes = 'negociacoes';

  /// Stream de negociações filtrado por clienteId (aba do cliente).
  /// Ordenação feita em Dart para evitar dependência de índice composto no Firestore.
  Stream<List<Negociacao>> getNegociacoesStream(String clienteId) {
    return _db
        .collection(_colNegociacoes)
        .where('clienteId', isEqualTo: clienteId)
        .snapshots()
        .map((s) {
          final lista = s.docs.map((d) => Negociacao.fromFirestore(d)).toList();
          lista.sort((a, b) => a.dataCriacao.compareTo(b.dataCriacao));
          return lista;
        });
  }

  /// Stream global: admin vê todas; embaixador vê as suas.
  Stream<List<Negociacao>> getNegociacoesGlobaisStream({
    String? embaixadorId,
    String? statusAprovacao,
  }) {
    Query query = _db.collection(_colNegociacoes);
    if (embaixadorId != null && embaixadorId.isNotEmpty) {
      query = query.where('embaixadorId', isEqualTo: embaixadorId);
    }
    if (statusAprovacao != null && statusAprovacao.isNotEmpty) {
      query = query.where('statusAprovacao', isEqualTo: statusAprovacao);
    }
    return query
        .orderBy('dataCriacao', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Negociacao.fromFirestore(d)).toList());
  }

  /// Stream de negociações especiais pendentes de aprovação (para admin).
  Stream<List<Negociacao>> getNegociacoesPendentesStream() {
    return _db
        .collection(_colNegociacoes)
        .where('statusAprovacao', isEqualTo: 'pendente')
        .orderBy('dataSolicitacaoAprovacao', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => Negociacao.fromFirestore(d)).toList());
  }

  Future<String> adicionarNegociacao(Negociacao negociacao) async {
    final dados = negociacao.toFirestore();
    dados['dataCriacao'] = FieldValue.serverTimestamp();
    dados['criadoPorId'] = _currentUserId;
    dados['criadoPorNome'] = _currentUserName;
    dados['editadoPorId'] = _currentUserId;
    dados['editadoPorNome'] = _currentUserName;
    final docRef = await _db.collection(_colNegociacoes).add(_flagTeste(dados));
    // Atualiza dataAtualizacao do cliente vinculado, se houver
    if (negociacao.clienteId != null) {
      await _db.collection(_colClientes).doc(negociacao.clienteId).update({
        'dataAtualizacao': FieldValue.serverTimestamp(),
        'atualizadoPorId': _currentUserId,
        'atualizadoPorNome': _currentUserName,
      });
    }
    return docRef.id;
  }

  Future<void> atualizarNegociacao(Negociacao negociacao) async {
    final dados = negociacao.toFirestore();
    dados.remove('dataCriacao'); // mantém o original
    dados['editadoPorId'] = _currentUserId;
    dados['editadoPorNome'] = _currentUserName;
    await _db
        .collection(_colNegociacoes)
        .doc(negociacao.id!)
        .update(dados);
  }

  Future<void> deletarNegociacao(String negociacaoId) async {
    await _db.collection(_colNegociacoes).doc(negociacaoId).delete();
  }

  // ── Fluxo de aprovação ────────────────────────────────────────────────────

  Future<void> solicitarAprovacao(
      String negId, {DateTime? prazoResposta}) async {
    final dados = <String, dynamic>{
      'statusAprovacao': 'pendente',
      'dataSolicitacaoAprovacao': FieldValue.serverTimestamp(),
      'editadoPorId': _currentUserId,
      'editadoPorNome': _currentUserName,
    };
    if (prazoResposta != null) {
      dados['prazoResposta'] = Timestamp.fromDate(prazoResposta);
    }
    await _db.collection(_colNegociacoes).doc(negId).update(dados);
  }

  Future<void> aprovarNegociacao(String negId, {String? comentario}) async {
    final doc = await _db.collection(_colNegociacoes).doc(negId).get();
    final atual = (doc.data()?['statusAprovacao'] as String?) ?? 'semSolicitacao';
    if (atual != 'pendente') {
      throw StateError(
        'Transição inválida: "$atual" → "aprovada". '
        'A negociação precisa estar "pendente".',
      );
    }
    await _db.collection(_colNegociacoes).doc(negId).update({
      'statusAprovacao': 'aprovada',
      'dataAprovacao': FieldValue.serverTimestamp(),
      'aprovadoPorId': _currentUserId,
      'aprovadoPorNome': _currentUserName,
      'comentarioAprovacao': comentario,
      'editadoPorId': _currentUserId,
      'editadoPorNome': _currentUserName,
    });
  }

  Future<void> negarNegociacao(String negId, {String? comentario}) async {
    final doc = await _db.collection(_colNegociacoes).doc(negId).get();
    final atual = (doc.data()?['statusAprovacao'] as String?) ?? 'semSolicitacao';
    if (atual != 'pendente') {
      throw StateError(
        'Transição inválida: "$atual" → "negada". '
        'A negociação precisa estar "pendente".',
      );
    }
    await _db.collection(_colNegociacoes).doc(negId).update({
      'statusAprovacao': 'negada',
      'comentarioAprovacao': comentario,
      'editadoPorId': _currentUserId,
      'editadoPorNome': _currentUserName,
    });
  }

  Future<void> solicitarAtualizacaoNegociacao(
      String negId, {String? comentario}) async {
    await _db.collection(_colNegociacoes).doc(negId).update({
      'statusAprovacao': 'aguardandoAtualizacao',
      'comentarioAprovacao': comentario,
      'editadoPorId': _currentUserId,
      'editadoPorNome': _currentUserName,
    });
  }

  Future<void> inativarNegociacao(String negId, String motivo) async {
    await _db.collection(_colNegociacoes).doc(negId).update({
      'status': 'inativa',
      'motivoInativacao': motivo,
      'editadoPorId': _currentUserId,
      'editadoPorNome': _currentUserName,
    });
  }

  Future<void> reativarNegociacao(String negId) async {
    await _db.collection(_colNegociacoes).doc(negId).update({
      'status': 'ativa',
      'motivoInativacao': null,
      'editadoPorId': _currentUserId,
      'editadoPorNome': _currentUserName,
    });
  }

  // --- USUÁRIOS ---

  // ── Metas mensais (#12) ──────────────────────────────────────────────────

  /// Retorna configuração completa de meta de um usuário.
  /// Suporta retrocompatibilidade com campo legado [metaMensal].
  /// Retorna null quando nenhuma meta está definida.
  Future<Map<String, dynamic>?> getMeta(String userId) async {
    try {
      final doc = await _db.collection('usuarios').doc(userId).get();
      final data = doc.data();
      if (data == null) return null;

      // Novo formato: tipoMeta + valorMeta
      if (data['valorMeta'] != null) {
        return {
          'tipoMeta': data['tipoMeta'] as String? ?? 'fechamentos',
          'valorMeta': (data['valorMeta'] as num).toDouble(),
        };
      }
      // Retrocompatibilidade: metaMensal legado (fechamentos)
      final legado = data['metaMensal'] as int?;
      if (legado != null) {
        return {'tipoMeta': 'fechamentos', 'valorMeta': legado.toDouble()};
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Define ou remove a meta do usuário (valor null = remover).
  Future<void> atualizarMeta(
      String userId, String tipoMeta, double? valor) async {
    await _db.collection('usuarios').doc(userId).update({
      'tipoMeta': tipoMeta,
      'valorMeta': valor,
      'metaMensal': null, // limpa campo legado
    });
  }

  /// Retorna o mapa de metas do usuário {tipoMeta: valorAlvo}, permitindo
  /// várias metas simultâneas. Retrocompatível com o formato antigo (meta
  /// única em tipoMeta/valorMeta) e o legado (metaMensal → fechamentos).
  Future<Map<String, double>> getMetas(String userId) async {
    try {
      final doc = await _db.collection('usuarios').doc(userId).get();
      final data = doc.data();
      if (data == null) return {};

      final raw = data['metas'];
      if (raw is Map && raw.isNotEmpty) {
        return raw.map((k, v) => MapEntry(k as String, (v as num).toDouble()));
      }
      // Retrocompatibilidade: meta única antiga.
      if (data['valorMeta'] != null) {
        return {
          (data['tipoMeta'] as String?) ?? 'fechamentos':
              (data['valorMeta'] as num).toDouble(),
        };
      }
      // Legado: metaMensal (fechamentos).
      final legado = data['metaMensal'] as int?;
      if (legado != null) return {'fechamentos': legado.toDouble()};
      return {};
    } catch (_) {
      return {};
    }
  }

  /// Substitui o conjunto de metas do usuário. Passe o mapa completo
  /// {tipoMeta: valor}; um mapa vazio remove todas as metas. Limpa os campos
  /// legados de meta única.
  ///
  /// O campo `metas` é apagado antes de ser regravado para garantir a
  /// substituição (e não um merge) das chaves — comportamento consistente
  /// entre o Firestore real e o fake usado nos testes.
  Future<void> definirMetas(String userId, Map<String, double> metas) async {
    final ref = _db.collection('usuarios').doc(userId);
    await ref.update({
      'metas': FieldValue.delete(),
      'tipoMeta': null,
      'valorMeta': null,
      'metaMensal': null,
    });
    if (metas.isNotEmpty) {
      await ref.update({'metas': metas});
    }
  }

  /// Leads captados por um captador/recepção (campo captadorId). Usado para
  /// medir o progresso das metas de captação (casais captados, vendas captadas).
  Future<List<Cliente>> getClientesCaptados(String captadorId) async {
    try {
      final snap = await _db
          .collection(_colClientes)
          .where('captadorId', isEqualTo: captadorId)
          .get();
      return snap.docs
          .map((d) => Cliente.fromFirestore(d))
          .where((c) => !c.deletado)
          .toList();
    } catch (e) {
      debugPrint('[Firestore] Erro ao buscar clientes captados: $e');
      return [];
    }
  }

  /// Total de interações registradas pelo usuário no mês corrente — usado para
  /// medir o progresso da meta "mensagens enviadas". Retorna 0 se não houver.
  Future<int> getInteracoesMesAtual(String userId) async {
    try {
      final doc = await _db.collection('usuarios').doc(userId).get();
      final mapa = doc.data()?['interacoesPorMes'] as Map<String, dynamic>?;
      if (mapa == null) return 0;
      return (mapa[chaveMesAtual()] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// [Legado] Retorna a meta mensal atual de um usuário.
  @Deprecated('Use getMeta() instead')
  Future<int?> getMetaMensal(String userId) async {
    try {
      final doc = await _db.collection('usuarios').doc(userId).get();
      return doc.data()?['metaMensal'] as int?;
    } catch (_) {
      return null;
    }
  }

  /// [Legado] Define ou remove a meta mensal do usuário (null = remover).
  @Deprecated('Use atualizarMeta() instead')
  Future<void> atualizarMetaMensal(String userId, int? meta) async {
    await _db.collection('usuarios').doc(userId).update({
      'metaMensal': meta,
    });
  }

  Future<List<Usuario>> getTodosUsuarios({
    String? perfil,
    bool apenasAtivos = false,
  }) async {
    try {
      Query query = _db.collection('usuarios');
      if (perfil != null && perfil.isNotEmpty) {
        query = query.where('perfil', isEqualTo: perfil);
      }
      if (apenasAtivos) {
        query = query.where('ativo', isEqualTo: true);
      }
      final snapshot = await query.get();
      return snapshot.docs
          .map((d) => Usuario.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
    } catch (e) {
      debugPrint('[Firestore] Erro ao buscar usuários: $e');
      return [];
    }
  }

  /// Stream em tempo real de todos os usuários (para a tela de gerenciamento).
  Stream<List<Usuario>> getTodosUsuariosStream() {
    return _db
        .collection('usuarios')
        .orderBy('nome')
        .snapshots()
        .map((s) => s.docs
            .map((d) => Usuario.fromMap(d.data(), d.id))
            .toList());
  }

  Future<void> atualizarUsuario({
    required String id,
    required String nome,
    required String perfil,
  }) async {
    try {
      await _db.collection('usuarios').doc(id).update({
        'nome': nome,
        'perfil': perfil,
      });
    } catch (e) {
      debugPrint('[Firestore] Erro ao atualizar usuário: $e');
      throw 'Ocorreu um erro ao salvar as alterações do usuário.';
    }
  }

  /// Ativa ou inativa um usuário. Usuários inativos são bloqueados no login.
  Future<void> alterarStatusUsuario({
    required String id,
    required bool ativo,
  }) async {
    try {
      await _db.collection('usuarios').doc(id).update({'ativo': ativo});
    } catch (e) {
      debugPrint('[Firestore] Erro ao alterar status: $e');
      throw 'Não foi possível alterar o status do usuário.';
    }
  }

  /// Verifica se o usuário logado está ativo no Firestore.
  Future<bool> isUsuarioAtivo(String uid) async {
    try {
      final doc = await _db.collection('usuarios').doc(uid).get();
      if (!doc.exists) return true; // usuário sem documento = considera ativo
      return doc.data()?['ativo'] ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<String> _getCurrentUserProfile() async {
    if (_auth.currentUser == null) return 'vendedor';
    try {
      final doc =
          await _db.collection('usuarios').doc(_currentUserId).get();
      return doc.exists ? (doc.data()?['perfil'] ?? 'vendedor') : 'vendedor';
    } catch (e) {
      debugPrint('[Firestore] Erro ao buscar perfil: $e');
      return 'vendedor';
    }
  }

  // --- CAMPANHAS ---

  static const _colCampanhas = 'campanhas';

  /// Stream de todas as campanhas (admin).
  Stream<List<Campanha>> getCampanhasStream() {
    return _db
        .collection(_colCampanhas)
        .orderBy('dataInicio', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Campanha.fromFirestore(d)).toList());
  }

  /// Stream de campanhas vigentes para o sino de notificações.
  Stream<List<Campanha>> getCampanhasVigentesStream() {
    return _db
        .collection(_colCampanhas)
        .where('ativa', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => Campanha.fromFirestore(d))
            .where((c) => c.vigente)
            .toList());
  }

  Future<void> criarCampanha(Campanha campanha) async {
    final dados = campanha.toFirestore();
    dados['criadoPorId'] = _currentUserId;
    dados['criadoPorNome'] = _currentUserName;
    dados['criadoEm'] = FieldValue.serverTimestamp();
    await _db.collection(_colCampanhas).add(_flagTeste(dados));
  }

  Future<void> atualizarCampanha(Campanha campanha) async {
    await _db
        .collection(_colCampanhas)
        .doc(campanha.id!)
        .update(campanha.toFirestore());
  }

  Future<void> publicarCampanha(String campanhaId, bool ativa) async {
    await _db
        .collection(_colCampanhas)
        .doc(campanhaId)
        .update({'ativa': ativa});
  }

  Future<void> deletarCampanha(String campanhaId) async {
    await _db.collection(_colCampanhas).doc(campanhaId).delete();
  }

  // ── TICKETS ──────────────────────────────────────────────────────────────────

  static const _colTickets = 'tickets';

  /// Stream de todos os tickets, ordenados por data de atualização.
  Stream<List<Ticket>> getTicketsStream() {
    return _db
        .collection(_colTickets)
        .orderBy('dataAtualizacao', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Ticket.fromFirestore).toList());
  }

  /// Stream de tickets criados pelo usuário atual.
  Stream<List<Ticket>> getMeusTicketsStream(String userId) {
    return _db
        .collection(_colTickets)
        .where('criadoPorId', isEqualTo: userId)
        .orderBy('dataAtualizacao', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Ticket.fromFirestore).toList());
  }

  /// Stream de comentários de um ticket.
  Stream<List<ComentarioTicket>> getComentariosStream(String ticketId) {
    return _db
        .collection(_colTickets)
        .doc(ticketId)
        .collection('comentarios')
        .orderBy('data', descending: false)
        .snapshots()
        .map((s) => s.docs.map(ComentarioTicket.fromFirestore).toList());
  }

  /// Retorna o próximo número de ticket (atômico via transação Firestore).
  Future<int> proximoNumeroTicket() async {
    final ref = _db.collection('config').doc('contadores');
    return await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final atual = (snap.data()?['tickets'] ?? 0) as int;
      final proximo = atual + 1;
      tx.set(ref, {'tickets': proximo}, SetOptions(merge: true));
      return proximo;
    });
  }

  /// Cria um novo ticket com número sequencial automático.
  /// Se a transação do contador falhar (ex: regras do Firestore para não-admin),
  /// o ticket é criado sem número sequencial (numero = 0).
  Future<String> criarTicket(Ticket ticket) async {
    int numero = 0;
    try {
      numero = await proximoNumeroTicket();
    } catch (e) {
      debugPrint('[Firestore] proximoNumeroTicket falhou, ticket sem número: $e');
    }
    final dados = _flagTeste(ticket.toFirestore());
    dados['numero'] = numero;
    final ref = await _db.collection(_colTickets).add(dados);
    return ref.id;
  }

  /// Atualiza campos de um ticket.
  Future<void> atualizarTicket(String ticketId, Map<String, dynamic> dados) async {
    dados['dataAtualizacao'] = Timestamp.now();
    await _db.collection(_colTickets).doc(ticketId).update(dados);
  }

  /// Adiciona um comentário e incrementa o contador.
  Future<void> adicionarComentario(String ticketId, ComentarioTicket comentario) async {
    final batch = _db.batch();
    final comentariosRef = _db
        .collection(_colTickets)
        .doc(ticketId)
        .collection('comentarios')
        .doc();
    batch.set(comentariosRef, _flagTeste(comentario.toFirestore()));
    batch.update(
      _db.collection(_colTickets).doc(ticketId),
      {
        'totalComentarios': FieldValue.increment(1),
        'dataAtualizacao': Timestamp.now(),
      },
    );
    await batch.commit();
  }

  /// Deleta um ticket (apenas admin).
  Future<void> deletarTicket(String ticketId) async {
    await _db.collection(_colTickets).doc(ticketId).delete();
  }

  // ── CONTRATOS PÓS-VENDA ──────────────────────────────────────────────────

  /// Stream de todos os contratos ativos, ordenados por nome do comprador.
  Stream<List<Contrato>> getContratosStream() {
    return _db
        .collection(_colContratos)
        .orderBy('nomeComprador')
        .snapshots()
        .map((snap) => snap.docs.map(Contrato.fromFirestore).toList());
  }

  /// Stream das interações de um contrato específico.
  Stream<List<Interacao>> getInteracoesContrato(String contratoId) {
    return _db
        .collection(_colContratos)
        .doc(contratoId)
        .collection('interacoes')
        .orderBy('dataInteracao', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Interacao.fromFirestore).toList());
  }

  /// Salva (upsert) um contrato. Usa o localizador como ID do documento.
  Future<void> salvarContrato(Contrato c) async {
    final docRef = _db.collection(_colContratos).doc(c.localizador);
    final existing = await docRef.get();
    final dados = _flagTeste({
      ...c.toFirestore(),
      // criadoEm só é gravado na criação; reimportações preservam a data original.
      if (!existing.exists || existing.data()!['criadoEm'] == null)
        'criadoEm': FieldValue.serverTimestamp(),
    });
    await docRef.set(dados, SetOptions(merge: true));
  }

  /// Salva uma lista de contratos em lotes (máx 500 por batch).
  Future<void> salvarContratosLote(List<Contrato> contratos) async {
    const batchSize = 400;
    for (var i = 0; i < contratos.length; i += batchSize) {
      final fatia = contratos.skip(i).take(batchSize).toList();

      // Lê existência dos docs para preservar criadoEm nas reimportações.
      final refs = fatia
          .map((c) => _db.collection(_colContratos).doc(c.localizador))
          .toList();
      final snaps = await Future.wait(refs.map((r) => r.get()));
      final temCriadoEm = {
        for (final s in snaps)
          s.id: s.exists && s.data()?['criadoEm'] != null
      };

      final batch = _db.batch();
      for (var j = 0; j < fatia.length; j++) {
        final c = fatia[j];
        final dados = _flagTeste({
          ...c.toFirestore(),
          if (!(temCriadoEm[c.localizador] ?? false))
            'criadoEm': FieldValue.serverTimestamp(),
        });
        batch.set(refs[j], dados, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  /// Salva (ou remove, se vazio) o link do PDF do contrato no Drive.
  Future<void> salvarLinkContrato(String localizador, String? url) async {
    final limpo = url?.trim();
    await _db.collection(_colContratos).doc(localizador).set({
      'linkContratoDrive': (limpo == null || limpo.isEmpty) ? null : limpo,
    }, SetOptions(merge: true));
  }

  /// Registra uma interação na subcoleção do contrato.
  Future<void> adicionarInteracaoContrato(
    String contratoId,
    Interacao interacao,
  ) async {
    final ref = _db.collection(_colContratos).doc(contratoId);
    await Future.wait([
      ref.collection('interacoes').add(_flagTeste(interacao.toFirestore())),
      // Marca o contrato como contatado no mês (meta de pós-venda).
      ref.set({
        'interacoesPorMes': {chaveMesAtual(): FieldValue.increment(1)},
      }, SetOptions(merge: true)),
    ]);
  }

  /// Busca única de todos os contratos (não-stream) — usado para calcular o
  /// progresso da meta de pós-venda (% de contratos contatados no mês).
  Future<List<Contrato>> getContratos() async {
    try {
      final snap = await _db.collection(_colContratos).get();
      return snap.docs.map(Contrato.fromFirestore).toList();
    } catch (e) {
      debugPrint('[Firestore] Erro ao buscar contratos: $e');
      return [];
    }
  }

  // ── Contatos do embaixador (Recepção) ─────────────────────────────────────

  /// Stream de todos os contatos do embaixador, mais recentes primeiro.
  Stream<List<ContatoEmbaixador>> getContatosEmbaixadorStream() {
    return _db
        .collection(_colContatosEmbaixador)
        .orderBy('criadoEm', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ContatoEmbaixador.fromFirestore).toList());
  }

  /// Cria um novo contato do embaixador. Retorna o id criado.
  Future<String> criarContatoEmbaixador(ContatoEmbaixador c) async {
    final dados = _flagTeste({
      ...c.toFirestore(),
      'criadoPorId': _currentUserId,
      'criadoPorNome': _currentUserName,
    });
    final ref = await _db.collection(_colContatosEmbaixador).add(dados);
    return ref.id;
  }

  /// Inclui vários contatos de uma vez (importação / adicionar em lote).
  Future<void> criarContatosEmbaixadorLote(
      List<ContatoEmbaixador> contatos) async {
    final batch = _db.batch();
    for (final c in contatos) {
      final ref = _db.collection(_colContatosEmbaixador).doc();
      batch.set(
        ref,
        _flagTeste({
          ...c.toFirestore(),
          'criadoPorId': _currentUserId,
          'criadoPorNome': _currentUserName,
        }),
      );
    }
    await batch.commit();
  }

  /// Atualiza os dados editáveis de um contato (nome, esposa, telefone, obs,
  /// responsável pelo próximo contato).
  Future<void> atualizarContatoEmbaixador(ContatoEmbaixador c) async {
    await _db.collection(_colContatosEmbaixador).doc(c.id).set({
      'nome': c.nome,
      'nomeEsposa': c.nomeEsposa,
      'telefone': c.telefone,
      'observacao': c.observacao,
      'responsavel': c.responsavel,
    }, SetOptions(merge: true));
  }


  /// Regrava a lista completa de tentativas de um contato (append/edição da
  /// resposta de uma tentativa específica é feita via read-modify-write).
  Future<void> salvarTentativasContato(
      String contatoId, List<Tentativa> tentativas) async {
    await _db.collection(_colContatosEmbaixador).doc(contatoId).set({
      'tentativas': tentativas.map((t) => t.toMap()).toList(),
    }, SetOptions(merge: true));
  }

  /// Exclui um contato do embaixador.
  Future<void> deletarContatoEmbaixador(String contatoId) async {
    await _db.collection(_colContatosEmbaixador).doc(contatoId).delete();
  }

  // ── Modelos de mensagem (WhatsApp) ─────────────────────────────────────────

  /// Stream de todos os modelos de mensagem (padrão + individuais). A filtragem
  /// "padrão ou meus" é feita na UI, pois a coleção é pequena.
  Stream<List<ModeloMensagem>> getModelosMensagemStream() {
    return _db
        .collection(_colModelosMensagem)
        .orderBy('titulo')
        .snapshots()
        .map((s) => s.docs.map(ModeloMensagem.fromFirestore).toList());
  }

  /// Busca única dos modelos de mensagem (para o seletor ao abrir o WhatsApp).
  Future<List<ModeloMensagem>> getModelosMensagem() async {
    try {
      final snap = await _db.collection(_colModelosMensagem).get();
      return snap.docs.map(ModeloMensagem.fromFirestore).toList();
    } catch (e) {
      debugPrint('[Firestore] Erro ao buscar modelos de mensagem: $e');
      return [];
    }
  }

  /// Cria um modelo de mensagem. Retorna o id criado.
  Future<String> criarModeloMensagem(ModeloMensagem m) async {
    final dados = _flagTeste({
      ...m.toFirestore(),
      'criadoPorId': _currentUserId,
      'criadoPorNome': _currentUserName,
    });
    final ref = await _db.collection(_colModelosMensagem).add(dados);
    return ref.id;
  }

  /// Atualiza título, texto e flag padrão de um modelo de mensagem.
  Future<void> atualizarModeloMensagem(ModeloMensagem m) async {
    await _db.collection(_colModelosMensagem).doc(m.id).set({
      'titulo': m.titulo,
      'texto': m.texto,
      'padrao': m.padrao,
    }, SetOptions(merge: true));
  }

  /// Exclui um modelo de mensagem.
  Future<void> deletarModeloMensagem(String id) async {
    await _db.collection(_colModelosMensagem).doc(id).delete();
  }

  /// Exclui uma interação da subcoleção de um contrato.
  Future<void> deletarInteracaoContrato(
    String contratoId,
    String interacaoId,
  ) async {
    await _db
        .collection(_colContratos)
        .doc(contratoId)
        .collection('interacoes')
        .doc(interacaoId)
        .delete();
  }

  /// Atualiza apenas o status de assinatura de um contrato.
  /// Quando o contrato entra no grupo "Formalizados" (transição a partir de um
  /// status não-formalizado), conta a formalização conseguida para o usuário
  /// logado (meta de pós-venda).
  Future<void> atualizarStatusAssinatura(
    String contratoId,
    StatusAssinatura status,
  ) async {
    final ref = _db.collection(_colContratos).doc(contratoId);
    final snap = await ref.get();
    final anterior =
        StatusAssinatura.fromString(snap.data()?['statusAssinatura'] as String?);
    await ref.update({
      'statusAssinatura': status.value,
      'atualizadoEm': FieldValue.serverTimestamp(),
    });
    if (status.formalizado && !anterior.formalizado) {
      await _incrementarContadorUsuario('assinaturas');
    }
  }

  /// Incrementa um contador mensal + total no doc do usuário logado.
  /// Usado para metas de pós-venda (assinaturas, upgrades).
  Future<void> _incrementarContadorUsuario(String nome) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('usuarios').doc(uid).set({
      '${nome}PorMes': {chaveMesAtual(): FieldValue.increment(1)},
      '${nome}Total': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  /// Marca que um upgrade foi OFERECIDO ao cliente do contrato (idempotente).
  Future<void> registrarUpgradeOferecido(String contratoId) async {
    final ref = _db.collection(_colContratos).doc(contratoId);
    final snap = await ref.get();
    if (snap.data()?['upgradeOferecidoEm'] != null) return;
    await ref.set(
      {'upgradeOferecidoEm': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  /// Marca que um upgrade foi REALIZADO (conta para a meta do usuário logado).
  /// Idempotente: só conta na primeira vez. Realizar implica ter sido oferecido.
  Future<void> registrarUpgradeRealizado(String contratoId) async {
    final ref = _db.collection(_colContratos).doc(contratoId);
    final snap = await ref.get();
    final data = snap.data();
    if (data?['upgradeRealizadoEm'] != null) return;
    final updates = <String, dynamic>{
      'upgradeRealizadoEm': FieldValue.serverTimestamp(),
    };
    if (data?['upgradeOferecidoEm'] == null) {
      updates['upgradeOferecidoEm'] = FieldValue.serverTimestamp();
    }
    await ref.set(updates, SetOptions(merge: true));
    await _incrementarContadorUsuario('upgrades');
  }

  /// Lê um usuário específico (para contadores de meta de pós-venda).
  Future<Usuario?> getUsuario(String userId) async {
    try {
      final doc = await _db.collection('usuarios').doc(userId).get();
      if (!doc.exists) return null;
      return Usuario.fromMap(doc.data()!, doc.id);
    } catch (e) {
      debugPrint('[Firestore] Erro ao buscar usuário: $e');
      return null;
    }
  }

  // ── Notificações in-app ───────────────────────────────────────────────────

  /// Stream de notificações não lidas do usuário (tickets e afins).
  Stream<List<NotificacaoInApp>> getNotificacoesTicketStream(String uid) {
    return _db
        .collection('notificacoes')
        .doc(uid)
        .collection('itens')
        .where('lida', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs
            .map(NotificacaoInApp.fromFirestore)
            .toList()
          ..sort((a, b) =>
              (b.criadoEm ?? DateTime(0)).compareTo(a.criadoEm ?? DateTime(0))));
  }

  Future<void> marcarNotificacaoLida(String uid, String notifId) async {
    await _db
        .collection('notificacoes')
        .doc(uid)
        .collection('itens')
        .doc(notifId)
        .update({'lida': true});
  }

  Future<Ticket?> getTicketById(String ticketId) async {
    final doc = await _db.collection(_colTickets).doc(ticketId).get();
    if (!doc.exists) return null;
    return Ticket.fromFirestore(doc);
  }

  Future<Cliente?> getClienteById(String clienteId) async {
    final doc = await _db.collection(_colClientes).doc(clienteId).get();
    if (!doc.exists) return null;
    return Cliente.fromFirestore(doc);
  }

  // ── IMÓVEIS E COTAS (Análise da Pós-Venda) ───────────────────────────────

  static const _colImoveis = 'imoveis';

  /// Stream do inventário de imóveis (228 unidades da 1ª etapa).
  Stream<List<Imovel>> getImoveisStream() {
    return _db
        .collection(_colImoveis)
        .snapshots()
        .map((s) => s.docs.map(Imovel.fromFirestore).toList());
  }

  /// Stream das cotas (vendidas) de um imóvel específico — usado no detalhe.
  Stream<List<Cota>> getCotasDoImovel(String imovelId) {
    return _db
        .collection(_colImoveis)
        .doc(imovelId)
        .collection('cotas')
        .snapshots()
        .map((s) => s.docs.map(Cota.fromFirestore).toList());
  }

  /// Semeia/atualiza o inventário da 1ª etapa (idempotente, merge). Cria os
  /// 228 documentos de `imoveis` a partir das plantas. Seguro rodar de novo.
  Future<void> semearInventario() async {
    final imoveis = inventarioPrimeiraEtapa();
    const lote = 400;
    for (var i = 0; i < imoveis.length; i += lote) {
      final fatia = imoveis.skip(i).take(lote);
      final batch = _db.batch();
      for (final im in fatia) {
        batch.set(
          _db.collection(_colImoveis).doc(im.id),
          _flagTeste(im.toFirestore()),
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }
  }

  /// Projeta os contratos linkáveis nas subcoleções `imoveis/{id}/cotas`.
  /// Reconciliação: grava as cotas atuais e remove as órfãs (cotas cujo
  /// contrato deixou de apontar para aquele rótulo). Contratos que não casam
  /// com a 1ª etapa ficam apenas em `contratos` (avulsos), sem virar cota.
  ///
  /// Retorna um resumo da sincronização.
  Future<({int imoveisAfetados, int cotas, int avulsos})>
      sincronizarCotas() async {
    final snap = await _db.collection(_colContratos).get();
    // Só contratos vigentes (Ativo) viram cota; cancelados/revertidos ficam
    // apenas na coleção `contratos`.
    final contratos =
        contratosEfetivos(snap.docs.map(Contrato.fromFirestore).toList());

    final mapa = projetarCotas(contratos);
    final avulsos = contratosAvulsos(contratos).length;
    var totalCotas = 0;

    for (final entry in mapa.entries) {
      final col =
          _db.collection(_colImoveis).doc(entry.key).collection('cotas');

      // Dedup por rótulo (cota duplicada não pode gerar 2 writes no mesmo doc).
      final porNumero = <String, Cota>{};
      for (final c in entry.value) {
        porNumero[c.numero] = c;
      }

      final existentes = await col.get();
      final batch = _db.batch();
      for (final doc in existentes.docs) {
        if (!porNumero.containsKey(doc.id)) batch.delete(doc.reference);
      }
      for (final c in porNumero.values) {
        batch.set(col.doc(c.numero), _flagTeste(c.toFirestore()),
            SetOptions(merge: true));
      }
      await batch.commit();
      totalCotas += porNumero.length;
    }

    return (imoveisAfetados: mapa.length, cotas: totalCotas, avulsos: avulsos);
  }

  // --- PRODUTOS ---

  static const _colProdutos = 'produtos';

  Stream<List<Produto>> getProdutosStream({bool apenasAtivos = true}) {
    // Filtra `ativo` no CLIENTE de propósito: combinar where('ativo') com
    // orderBy('ordem') exigiria um índice composto no Firestore. Sem ele, a
    // query falhava silenciosamente e a tela de proposta mostrava "Nenhum
    // produto cadastrado" mesmo com produtos ativos. Ordenar por 'ordem' (campo
    // único) usa o índice automático; o filtro de ativos é trivial em memória.
    return _db
        .collection(_colProdutos)
        .orderBy('ordem')
        .snapshots()
        .map((s) {
      final lista = s.docs.map((d) => Produto.fromFirestore(d)).toList();
      return apenasAtivos ? lista.where((p) => p.ativo).toList() : lista;
    });
  }

  Future<void> salvarProduto(Map<String, dynamic> dados, {String? id}) async {
    if (id != null) {
      await _db.collection(_colProdutos).doc(id).update(dados);
    } else {
      await _db.collection(_colProdutos).add(dados);
    }
  }

  Future<void> arquivarProduto(String id) async {
    await _db.collection(_colProdutos).doc(id).update({'ativo': false});
  }

  Future<void> reativarProduto(String id) async {
    await _db.collection(_colProdutos).doc(id).update({'ativo': true});
  }
}
