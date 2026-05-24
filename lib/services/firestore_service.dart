import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../models/interacao_model.dart';
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
          final perfisComVisaoTotal = ['admin', 'pós-venda', 'financeiro'];
          Query query = _db.collection(_colClientes);

          if (perfisComVisaoTotal.contains(perfil)) {
            if (vendedorId != null && vendedorId.isNotEmpty) {
              query = query.where('vendedorId', isEqualTo: vendedorId);
            }
          } else {
            query = query.where('vendedorId', isEqualTo: _currentUserId);
          }

          query = query.orderBy(ordenarPor, descending: descendente);

          return query.snapshots().map(
              (s) => s.docs.map((d) => Cliente.fromFirestore(d)).toList());
        })
        .switchMap((stream) => stream);
  }

  Future<void> adicionarCliente(Cliente cliente) async {
    final dados = cliente.toFirestore();
    dados['criadoPorId'] = _currentUserId;
    dados['criadoPorNome'] = _currentUserName;
    dados['atualizadoPorId'] = _currentUserId;
    dados['atualizadoPorNome'] = _currentUserName;
    dados['dataCadastro'] = FieldValue.serverTimestamp();
    dados['dataAtualizacao'] = FieldValue.serverTimestamp();
    await _db.collection(_colClientes).add(dados);
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

  // --- USUÁRIOS ---

  Future<List<Usuario>> getTodosUsuarios({String? perfil}) async {
    try {
      Query query = _db.collection('usuarios');
      if (perfil != null && perfil.isNotEmpty) {
        query = query.where('perfil', isEqualTo: perfil);
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
}
