// lib/models/cliente_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'fase_enum.dart';

class Cliente {
  final String? id;
  final String nome;
  final String tipo;
  final FaseCliente fase;
  final String? nomeEsposa;
  final String? origem;
  final String? telefoneContato;
  final DateTime dataCadastro;
  final DateTime dataAtualizacao;
  final DateTime? proximoContato;
  final DateTime? dataVisita;
  final String? captadorId;
  final String? captadorNome;
  final DateTime? dataEntradaSala;
  final String? motivoNaoVenda;
  final String? motivoNaoVendaDropdown;
  final String? vendedorId;
  final String? vendedorNome;
  final String? criadoPorId;
  final String? criadoPorNome;
  final String? atualizadoPorId;
  final String? atualizadoPorNome;

  Cliente({
    this.id,
    required this.nome,
    required this.tipo,
    required this.fase,
    required this.dataCadastro,
    required this.dataAtualizacao,
    this.nomeEsposa,
    this.telefoneContato,
    this.proximoContato,
    this.dataVisita,
    this.origem,
    this.motivoNaoVenda,
    this.motivoNaoVendaDropdown,
    this.vendedorId,
    this.vendedorNome,
    this.captadorId,
    this.captadorNome,
    this.dataEntradaSala,
    this.criadoPorId,
    this.criadoPorNome,
    this.atualizadoPorId,
    this.atualizadoPorNome,
  });

  // Converte o objeto Cliente para um Mapa para o Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'nome': nome,
      'tipo': tipo,
      'fase': fase.toString().split('.').last,
      'nomeEsposa': nomeEsposa,
      'origem' : origem,
      'telefoneContato': telefoneContato,
      'dataCadastro': Timestamp.fromDate(dataCadastro),
      'dataAtualizacao': Timestamp.fromDate(dataAtualizacao),
      'proximoContato': proximoContato != null ? Timestamp.fromDate(proximoContato!) : null,
      'dataVisita': dataVisita != null ? Timestamp.fromDate(dataVisita!) : null,
      'motivoNaoVenda': motivoNaoVenda,
      'motivoNaoVendaDropdown': motivoNaoVendaDropdown,
      'vendedorId': vendedorId,
      'vendedorNome': vendedorNome,
      'captadorNome': captadorNome,
      'captadorId': captadorId,
      'dataEntradaSala': dataEntradaSala != null ? Timestamp.fromDate(dataEntradaSala!): null,
      'criadoPorId': criadoPorId,
      'criadoPorNome': criadoPorNome,
      'atualizadoPorId': atualizadoPorId,
      'atualizadoPorNome': atualizadoPorNome,
    };
  }

  // Cria um objeto Cliente a partir de um Documento do Firestore
  factory Cliente.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final stringFase = data['fase'] as String?;
    FaseCliente faseRecuperada = FaseCliente.prospeccao;

    if (stringFase != null) {
      try {
        faseRecuperada = FaseCliente.values.firstWhere(
              (e) => e.toString().split('.').last == stringFase,
          orElse: () => FaseCliente.prospeccao,
        );
      } catch (_) {
        faseRecuperada = FaseCliente.prospeccao;
      }
    }

    return Cliente(
      id: doc.id,
      nome: data['nome'] ?? 'Sem Nome',
      tipo: data['tipo'] ?? 'Não Definido',
      fase: faseRecuperada,
      origem: data['origem'] ?? 'Antigo',
      dataCadastro: (data['dataCadastro'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dataAtualizacao: (data['dataAtualizacao'] as Timestamp?)?.toDate() ?? DateTime.now(),
      nomeEsposa: data['nomeEsposa'],
      telefoneContato: data['telefoneContato'],
      proximoContato: (data['proximoContato'] as Timestamp?)?.toDate(),
      dataVisita: (data['dataVisita'] as Timestamp?)?.toDate(),
      motivoNaoVenda: data['motivoNaoVenda'],
      motivoNaoVendaDropdown: data['motivoNaoVendaDropdown'],
      vendedorId: data['vendedorId'],
      vendedorNome: data['vendedorNome'],
      captadorId: data['captadorId'],
      captadorNome: data['captadorNome'],
      dataEntradaSala: (data['dataEntradaSala'] as Timestamp?)?.toDate(),
      criadoPorId: data['criadoPorId'],
      criadoPorNome: data['criadoPorNome'],
      atualizadoPorId: data['atualizadoPorId'],
      atualizadoPorNome: data['atualizadoPorNome'],
    );
  }
}