import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../models/interacao_model.dart';

// Enum para os critérios de ordenação
enum ClienteOrder { dataCadastro, nome, dataAtualizacao, proximoContato } // ADICIONADO: Ordenar por próximo contato

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _colecaoClientes = 'clientes';

  // 1. MÉTODO: Adicionar Cliente (Create)
  // Este método já está correto, pois o `toFirestore()` do seu modelo `Cliente`
  // já foi ajustado para lidar com `proximoContato`.
  Future<void> adicionarCliente(Cliente cliente) async {
    try {
      await _db.collection(_colecaoClientes).add(cliente.toFirestore());
      print('Cliente ${cliente.nome} adicionado com sucesso!');
    } catch (e) {
      print('Erro ao adicionar cliente: $e');
      rethrow;
    }
  }

  // 2. MÉTODO: Ler Clientes em Tempo Real (Read/Filtered/Ordered)
  Stream<List<Cliente>> getClientesStream({
    FaseCliente? fase,
    ClienteOrder orderBy = ClienteOrder.dataAtualizacao, // Mudei o padrão para dataAtualizacao
    bool descending = true,
  }) {
    Query collectionRef = _db.collection(_colecaoClientes);

    if (fase != null) {
      String faseString = fase.toString().split('.').last;
      collectionRef = collectionRef.where('fase', isEqualTo: faseString);
    }

    String orderByField;
    switch (orderBy) {
      case ClienteOrder.nome:
        orderByField = 'nome';
        // A direção da ordenação para nome é geralmente ascendente (A-Z)
        collectionRef = collectionRef.orderBy(orderByField, descending: false);
        break;
      case ClienteOrder.dataAtualizacao:
        orderByField = 'dataAtualizacao';
        collectionRef = collectionRef.orderBy(orderByField, descending: descending);
        break;
    // ADICIONADO: Caso de ordenação por próximo contato
      case ClienteOrder.proximoContato:
        orderByField = 'proximoContato';
        // Ordena por data de próximo contato, mostrando os nulos por último
        // e os mais próximos primeiro.
        collectionRef = collectionRef
            .orderBy(orderByField, descending: false); // false para ascendente (mais próximo primeiro)
        break;
      case ClienteOrder.dataCadastro:
      default:
        orderByField = 'dataCadastro';
        collectionRef = collectionRef.orderBy(orderByField, descending: descending);
        break;
    }

    return collectionRef.snapshots().map((snapshot) {
      // O método fromFirestore já foi atualizado para lidar com 'proximoContato',
      // então não precisamos mudar nada aqui no mapeamento.
      return snapshot.docs.map((doc) => Cliente.fromFirestore(doc)).toList();
    });
  }

  // 3. MÉTODO: Atualizar Fase do Cliente
  Future<void> atualizarFaseCliente(String clienteId, FaseCliente novaFase) async {
    try {
      String faseString = novaFase.toString().split('.').last;

      await _db.collection(_colecaoClientes).doc(clienteId).update({
        'fase': faseString,
        'dataAtualizacao': Timestamp.now(),
      });
      print('Fase do cliente $clienteId atualizada para $faseString');
    } catch (e) {
      print('Erro ao atualizar fase do cliente $clienteId: $e');
      rethrow;
    }
  }

  // 4. MÉTODO: Atualizar Detalhes do Cliente (CORRIGIDO)
  Future<void> atualizarClienteDetalhes(
      String clienteId,
      String novoNome,
      String novoTipo,
      String? novoTelefoneContato, // Ordem corrigida
      String? novoNomeEsposa,       // Ordem corrigida
      DateTime? proximoContato,     // PARÂMETRO ADICIONADO
      ) async {
    try {
      await _db.collection(_colecaoClientes).doc(clienteId).update({
        'nome': novoNome,
        'tipo': novoTipo,
        'telefoneContato': novoTelefoneContato,
        'nomeEsposa': novoNomeEsposa,
        'dataAtualizacao': Timestamp.now(),
        // CAMPO ADICIONADO PARA ATUALIZAÇÃO
        'proximoContato': proximoContato != null ? Timestamp.fromDate(proximoContato) : null,
      });
      print('Detalhes do cliente $clienteId atualizados.');
    } catch (e) {
      print('Erro ao atualizar detalhes do cliente $clienteId: $e');
      rethrow;
    }
  }


  // 5. MÉTODO: Deletar Cliente (Delete)
  Future<void> deletarCliente(String clienteId) async {
    try {
      // Também é uma boa prática deletar as subcoleções, mas para isso
      // seria necessário uma função mais complexa ou uma Cloud Function.
      // Por agora, manteremos a exclusão apenas do documento principal.
      await _db.collection(_colecaoClientes).doc(clienteId).delete();
      print('Cliente $clienteId deletado com sucesso!');
    } catch (e) {
      print('Erro ao deletar cliente $clienteId: $e');
      rethrow;
    }
  }

  // --- MÉTODOS DE INTERAÇÃO (sem alterações necessárias) ---

  Future<void> adicionarInteracao(String clienteId, Interacao interacao) async {
    try {
      await _db
          .collection(_colecaoClientes)
          .doc(clienteId)
          .collection('interacoes')
          .add(interacao.toFirestore());

      await _db.collection(_colecaoClientes).doc(clienteId).update({
        'dataAtualizacao': Timestamp.now(),
      });
      print('Interação adicionada para o cliente $clienteId');
    } catch (e) {
      print('Erro ao adicionar interação: $e');
      rethrow;
    }
  }

  Stream<List<Interacao>> getInteracoesStream(String clienteId) {
    return _db
        .collection(_colecaoClientes)
        .doc(clienteId)
        .collection('interacoes')
        .orderBy('dataInteracao', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Interacao.fromFirestore(doc)).toList();
    });
  }

  Future<void> atualizarInteracao(String clienteId, Interacao interacao) async {
    if (interacao.id == null) {
      throw Exception('O ID da interação não pode ser nulo para atualização.');
    }
    try {
      await _db
          .collection(_colecaoClientes)
          .doc(clienteId)
          .collection('interacoes')
          .doc(interacao.id)
          .update(interacao.toFirestore());

      await _db.collection(_colecaoClientes).doc(clienteId).update({
        'dataAtualizacao': Timestamp.now(),
      });

      print('Interação ${interacao.id} atualizada para o cliente $clienteId');
    } catch (e) {
      print('Erro ao atualizar interação: $e');
      rethrow;
    }
  }

  Future<void> excluirInteracao(String clienteId, String interacaoId) async {
    try {
      await _db
          .collection(_colecaoClientes)
          .doc(clienteId)
          .collection('interacoes')
          .doc(interacaoId)
          .delete();

      await _db.collection(_colecaoClientes).doc(clienteId).update({
        'dataAtualizacao': Timestamp.now(),
      });

      print('Interação $interacaoId excluída para o cliente $clienteId');
    } catch (e) {
      print('Erro ao excluir interação: $e');
      rethrow;
    }
  }
}
