import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../models/campanha_model.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../models/interacao_model.dart';
import '../models/negociacao_model.dart';
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
                (s) => s.docs.map((d) => Cliente.fromFirestore(d)).toList());
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
              result.sort((a, b) => b.dataAtualizacao.compareTo(a.dataAtualizacao));
              return result;
            },
          );
        })
        .switchMap((stream) => stream);
  }

  /// Stream de leads para o perfil recepção:
  /// leads que o usuário criou OU onde ele é o captador (OR via dois streams).
  Stream<List<Cliente>> getClientesRecepcaoStream() {
    final uid = _currentUserId;

    final streamCriados = _db
        .collection(_colClientes)
        .where('criadoPorId', isEqualTo: uid)
        .snapshots()
        .map((s) => s.docs.map((d) => Cliente.fromFirestore(d)).toList());

    final streamCaptador = _db
        .collection(_colClientes)
        .where('captadorId', isEqualTo: uid)
        .snapshots()
        .map((s) => s.docs.map((d) => Cliente.fromFirestore(d)).toList());

    // Merge dos dois streams, deduplicando por id
    return Rx.combineLatest2<List<Cliente>, List<Cliente>, List<Cliente>>(
      streamCriados,
      streamCaptador,
      (criados, captador) {
        final vistos = <String>{};
        final result = <Cliente>[];
        for (final c in [...criados, ...captador]) {
          if (c.id != null && vistos.add(c.id!)) result.add(c);
        }
        result.sort(
            (a, b) => b.dataAtualizacao.compareTo(a.dataAtualizacao));
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
    await _db.collection(_colClientes).doc(id).update({
      'fase': novaFase.toString().split('.').last,
      'motivoNaoVenda': motivo,
      'dataAtualizacao': FieldValue.serverTimestamp(),
      'atualizadoPorId': _currentUserId,
      'atualizadoPorNome': _currentUserName,
    });
    await _adicionarInteracaoAutomatica(
        id, 'Fase alterada para: ${novaFase.nomeDisplay}');
  }

  Future<void> atualizarClienteDetalhes(
      String id, Map<String, dynamic> dados) async {
    dados['dataAtualizacao'] = FieldValue.serverTimestamp();
    dados['atualizadoPorId'] = _currentUserId;
    dados['atualizadoPorNome'] = _currentUserName;
    await _db.collection(_colClientes).doc(id).update(dados);
  }

  Future<void> deletarCliente(String id) async {
    await _db.collection(_colClientes).doc(id).delete();
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
      String clienteId, String texto) async {
    await _db
        .collection(_colClientes)
        .doc(clienteId)
        .collection('interacoes')
        .add({
      'titulo': 'Evento do Sistema',
      'nota': texto,
      'dataInteracao': FieldValue.serverTimestamp(),
      'tipo': 'sistema',
      'autorNome': 'Sistema',
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
}
