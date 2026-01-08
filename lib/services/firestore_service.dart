// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../models/interacao_model.dart'; // <--- IMPORTAR O MODELO DE INTERAÇÃO
import '../models/usuario_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _colecaoClientes = 'clientes';

  // HELPER: Obtém dados do usuário logado atualmente.
  String get _currentUserId => _auth.currentUser?.uid ?? 'sistema_offline';
  String get _currentUserName => _auth.currentUser?.displayName ?? 'Usuário Sem Nome';

  // --- MÉTODOS DE BUSCA DE CLIENTES (STREAMS) ---
  Stream<List<Cliente>> getTodosClientesStream() {
    return _db
        .collection(_colecaoClientes)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Cliente.fromFirestore(doc))
        .toList());
  }

  // --- MÉTODOS DE ESCRITA DE CLIENTES (OPERAÇÕES CRUD) ---
  Future<void> adicionarCliente(Cliente cliente) async {
    final dados = cliente.toFirestore();
    dados['criadoPorId'] = _currentUserId;
    dados['criadoPorNome'] = _currentUserName;
    dados['atualizadoPorId'] = _currentUserId;
    dados['atualizadoPorNome'] = _currentUserName;
    dados['dataCadastro'] = FieldValue.serverTimestamp();
    dados['dataAtualizacao'] = FieldValue.serverTimestamp();
    await _db.collection(_colecaoClientes).add(dados);
  }

  Future<void> atualizarFaseCliente(String id, FaseCliente novaFase, {String? motivo}) async {
    await _db.collection(_colecaoClientes).doc(id).update({
      'fase': novaFase.toString().split('.').last,
      'motivoNaoVenda': motivo,
      'dataAtualizacao': FieldValue.serverTimestamp(),
      'atualizadoPorId': _currentUserId,
      'atualizadoPorNome': _currentUserName,
    });
    await adicionarInteracaoAutomatica(id, "Fase alterada para: ${novaFase.nomeDisplay}");
  }

  Future<void> atualizarClienteDetalhes(String id, Map<String, dynamic> dadosNovos) async {
    dadosNovos['dataAtualizacao'] = FieldValue.serverTimestamp();
    dadosNovos['atualizadoPorId'] = _currentUserId;
    dadosNovos['atualizadoPorNome'] = _currentUserName;
    await _db.collection(_colecaoClientes).doc(id).update(dadosNovos);
  }

  Future<void> deletarCliente(String id) async {
    await _db.collection(_colecaoClientes).doc(id).delete();
  }

  // ===== INÍCIO DOS NOVOS MÉTODOS PARA INTERAÇÕES =====

  // --- MÉTODOS DE INTERAÇÕES (SUB-COLEÇÃO) ---

  /// Busca o stream de interações de um cliente específico.
  Stream<List<Interacao>> getInteracoesStream(String clienteId) {
    return _db
        .collection(_colecaoClientes)
        .doc(clienteId)
        .collection('interacoes')
        .orderBy('dataInteracao', descending: true) // Ordena da mais nova para a mais antiga
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Interacao.fromFirestore(doc)).toList());
  }

  /// Adiciona uma nova interação manual a um cliente.
  Future<void> adicionarInteracao(String clienteId, Interacao interacao) async {
    final dados = interacao.toFirestore();
    // Injeta campos de auditoria e data do servidor
    dados['autorId'] = _currentUserId;
    dados['autorNome'] = _currentUserName;
    dados['dataInteracao'] = FieldValue.serverTimestamp();

    await _db
        .collection(_colecaoClientes)
        .doc(clienteId)
        .collection('interacoes')
        .add(dados);
  }

  /// Atualiza uma interação existente.
  Future<void> atualizarInteracao(String clienteId, Interacao interacao) async {
    await _db
        .collection(_colecaoClientes)
        .doc(clienteId)
        .collection('interacoes')
        .doc(interacao.id)
        .update(interacao.toFirestore());
  }

  /// Exclui uma interação de um cliente.
  Future<void> excluirInteracao(String clienteId, String interacaoId) async {
    await _db
        .collection(_colecaoClientes)
        .doc(clienteId)
        .collection('interacoes')
        .doc(interacaoId)
        .delete();
  }

  // --- FIM DOS NOVOS MÉTODOS PARA INTERAÇÕES ---

  // --- MÉTODOS AUXILIARES E DE USUÁRIOS ---

  Future<void> adicionarInteracaoAutomatica(String clienteId, String texto) async {
    await _db.collection(_colecaoClientes).doc(clienteId).collection('interacoes').add({
      'titulo': 'Evento do Sistema',
      'nota': texto,
      'dataInteracao': FieldValue.serverTimestamp(),
      'tipo': 'sistema',
      'autorNome': 'Sistema',
    });
  }

  Future<List<Usuario>> getTodosUsuarios() async {
    try {
      final snapshot = await _db.collection('usuarios').get();
      if (snapshot.docs.isEmpty) return [];
      return snapshot.docs.map((doc) => Usuario.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      print("Erro ao buscar usuários: $e");
      return [];
    }
  }
}
