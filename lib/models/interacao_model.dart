// lib/models/interacao_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Interacao {
  final String? id;
  final String titulo;
  final String nota;
  final DateTime dataInteracao;

  Interacao({
    this.id,
    required this.titulo,
    required this.nota,
    required this.dataInteracao,
  });

  // Converte o objeto Interacao para um Mapa (para salvar no Firestore)
  Map<String, dynamic> toFirestore() {
    return {
      'titulo': titulo,
      'nota': nota,
      'dataInteracao': Timestamp.fromDate(dataInteracao),
    };
  }

  // Construtor nomeado para criar Interacao a partir de um documento do Firestore
  factory Interacao.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Interacao(
      id: doc.id,
      titulo: data['titulo'] ?? '',
      nota: data['nota'] ?? '',
      dataInteracao: (data['dataInteracao'] as Timestamp).toDate(),
    );
  }
}