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
  final String? motivoNaoVenda;

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
    this.motivoNaoVenda
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
      // --- ALTERAÇÃO NECESSÁRIA AQUI ---
      // Adiciona o proximoContato ao mapa, convertendo para Timestamp se não for nulo.
      'proximoContato': proximoContato != null ? Timestamp.fromDate(proximoContato!) : null,
      'dataVisita': dataVisita != null ? Timestamp.fromDate(dataVisita!) : null,
      'motivoNaoVenda': motivoNaoVenda,
    };
  }

  factory Cliente.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // 2. Tratamento seguro da Fase (Onde geralmente ocorre o erro de null)
    final stringFase = data['fase'] as String?;

    FaseCliente faseRecuperada = FaseCliente.prospeccao; // Default

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
      // 3. Tratamento seguro de Timestamps
      dataCadastro: (data['dataCadastro'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dataAtualizacao: (data['dataAtualizacao'] as Timestamp?)?.toDate() ?? DateTime.now(),
      nomeEsposa: data['nomeEsposa'],
      telefoneContato: data['telefoneContato'],
      proximoContato: (data['proximoContato'] as Timestamp?)?.toDate(),
      dataVisita: (data['dataVisita'] as Timestamp?)?.toDate(),
      motivoNaoVenda: data['motivoNaoVenda'],
    );
  }
}
