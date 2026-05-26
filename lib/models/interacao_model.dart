// lib/models/interacao_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Interacao {
  final String? id;
  final String titulo;
  final String nota;
  final DateTime dataInteracao;

  /// Campo "O que combinamos?" — próximo passo combinado na interação.
  final String? proximoPasso;

  Interacao({
    this.id,
    required this.titulo,
    required this.nota,
    required this.dataInteracao,
    this.proximoPasso,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'titulo': titulo,
      'nota': nota,
      'dataInteracao': Timestamp.fromDate(dataInteracao),
      'proximoPasso': proximoPasso,
    };
  }

  factory Interacao.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Interacao(
      id: doc.id,
      titulo: data['titulo'] ?? '',
      nota: data['nota'] ?? '',
      dataInteracao: (data['dataInteracao'] as Timestamp).toDate(),
      proximoPasso: data['proximoPasso'] as String?,
    );
  }
}
