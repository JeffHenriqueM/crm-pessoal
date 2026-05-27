import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../models/campanha_model.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../models/interacao_model.dart';
import '../models/negociacao_model.dart';
import '../models/ticket_model.dart';
import '../models/usuario_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const _colClientes = 'clientes';

  String get _currentUserId => _auth.currentUser?.uid ?? 'sistema';
  String get _currentUserName => _auth.currentUser?.displayName ?? 'Usuário';

  // --- CLIENTES ---

  Stream<List<Cliente>> getTodosClientesStream({
    String? vendedorId,
    String ordenarPor = 'dataAtualizacao',
    bool descendente = true,
  }) {
    return Stream.fromFuture(_getCurrentUserProfile())
        .asyncMap((perfil) {
          debugPrint('[Firestore] perfil=$perfil | filtro=$vendedorId | ordenar=$ordenarPor');
          final perfisComVisaoTotal = ['admin', 'pós-venda', 'financeiro', 'super admin'];
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

  /// Stream de atendimentos para a tela de recepção:
  /// registros com fase=atendimento onde o usuário criou, é captador ou liner.
  Stream<List<Cliente>> getClientesRecepcaoStream() {
    final uid = _currentUserId;

    List<Cliente> _fromSnap(s) =>
        s.docs.map<Cliente>((d) => Cliente.fromFirestore(d)).toList();

    final streamCriados = _db
        .collection(_colClientes)
        .where('criadoPorId', isEqualTo: uid)
        .snapshots()
        .map(_fromSnap);

    final streamCaptador = _db
        .collection(_colClientes)
        .where('captadorId', isEqualTo: uid)
        .snapshots()
        .map(_fromSnap);

    final streamLiner = _db
        .collection(_colClientes)
        .where('linerId', isEqualTo: uid)
        .snapshots()
        .map(_fromSnap);

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
        // Só mostra atendimentos (fase pré-lead)
        result.retainWhere((c) => c.fase == FaseCliente.atendimento);
        // Exclui soft-deleted
        result.removeWhere((c) => c.deletado);
        result.sort((a, b) {
          final da = a.dataEntradaSala ?? a.dataCadastro;
          final db = b.dataEntradaSala ?? b.dataCadastro;
          return db.compareTo(da);
        });
        return result;
      },
    );
  }

  Future<String> adicionarCliente(Cliente cliente) async {
    final dados = cliente.toFirestore();
    dados['criadoPorId'] = _currentUserId;
    dados['criadoPorNome'] = _currentUserName;
    dados['atualizadoPorId'] = _currentUserId;
    dados['atualizadoPorNome'] = _currentUserName;
    dados['dataCadastro'] = FieldValue.serverTimestamp();
    dados['dataAtualizacao'] = FieldValue.serverTimestamp();
    final docRef = await _db.collection(_colClientes).add(dados);
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

    // Soft-delete no documento
    await _db.collection(_colClientes).doc(id).update({
      'deletado': true,
      'excluidoPorId': _currentUserId,
      'excluidoPorNome': _currentUserName,
      'dataExclusao': FieldValue.serverTimestamp(),
      'dataAtualizacao': FieldValue.serverTimestamp(),
    });

    // Registro de auditoria em coleção dedicada
    await _db.collection('audit_log').add({
      'tipo': 'exclusao_cliente',
      'clienteId': id,
      'clienteNome': nomeCliente,
      'autorId': _currentUserId,
      'autorNome': _currentUserName,
      'timestamp': FieldValue.serverTimestamp(),
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

  Future<void> adicionarInteracao(String clienteId, Interacao interacao) async {
    final dados = interacao.toFirestore();
    dados['autorId'] = _currentUserId;
    dados['autorNome'] = _currentUserName;
    dados['dataInteracao'] = FieldValue.serverTimestamp();
    await _db
        .collection(_colClientes)
        .doc(clienteId)
        .collection('interacoes')
        .add(dados);
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
    await _db
        .collection(_colClientes)
        .doc(clienteId)
        .collection('interacoes')
        .doc(interacaoId)
        .delete();
  }

  Future<void> _adicionarInteracaoAutomatica(
    String clienteId,
    String texto, {
    String titulo = 'Evento do Sistema',
    String tipo = 'sistema',
  }) async {
    await _db
        .collection(_colClientes)
        .doc(clienteId)
        .collection('interacoes')
        .add({
      'titulo': titulo,
      'nota': texto,
      'dataInteracao': FieldValue.serverTimestamp(),
      'tipo': tipo,
      'autorNome': 'Sistema',
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
      tipo: 'mensagem',
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
  Stream<List<Negociacao>> getNegociacoesStream(String clienteId) {
    return _db
        .collection(_colNegociacoes)
        .where('clienteId', isEqualTo: clienteId)
        .orderBy('dataCriacao', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => Negociacao.fromFirestore(d)).toList());
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
    final docRef = await _db.collection(_colNegociacoes).add(dados);
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
    await _db.collection(_colCampanhas).add(dados);
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

  /// Cria um novo ticket.
  Future<String> criarTicket(Ticket ticket) async {
    final ref = await _db.collection(_colTickets).add(ticket.toFirestore());
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
    batch.set(comentariosRef, comentario.toFirestore());
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
}
