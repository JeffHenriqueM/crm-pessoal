import 'package:cloud_firestore/cloud_firestore.dart';

/// Representa uma versão da tabela de preços de venda do Hotel Villamor
/// (preço por categoria × cota).
class VersaoPrecoHotel {
  final String id;
  final String nome;
  final String criadoPorId;
  final String criadoPorNome;
  final DateTime criadoEm;
  final DateTime atualizadoEm;
  final Map<String, double> precos;
  final bool isPadrao;

  const VersaoPrecoHotel({
    required this.id,
    required this.nome,
    required this.criadoPorId,
    required this.criadoPorNome,
    required this.criadoEm,
    required this.atualizadoEm,
    required this.precos,
    this.isPadrao = false,
  });

  VersaoPrecoHotel copyWith({
    String? id,
    String? nome,
    String? criadoPorId,
    String? criadoPorNome,
    DateTime? criadoEm,
    DateTime? atualizadoEm,
    Map<String, double>? precos,
    bool? isPadrao,
  }) {
    return VersaoPrecoHotel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      criadoPorId: criadoPorId ?? this.criadoPorId,
      criadoPorNome: criadoPorNome ?? this.criadoPorNome,
      criadoEm: criadoEm ?? this.criadoEm,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
      precos: precos ?? this.precos,
      isPadrao: isPadrao ?? this.isPadrao,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nome': nome,
      'criadoPorId': criadoPorId,
      'criadoPorNome': criadoPorNome,
      'criadoEm': Timestamp.fromDate(criadoEm),
      'atualizadoEm': Timestamp.fromDate(atualizadoEm),
      'precos': precos,
      'isPadrao': isPadrao,
    };
  }

  factory VersaoPrecoHotel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final rawPrecos = (data['precos'] as Map<String, dynamic>?) ?? {};
    final m = <String, double>{};
    rawPrecos.forEach((k, v) {
      if (v is num && v > 0) m[k] = v.toDouble();
    });

    DateTime parseData(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return VersaoPrecoHotel(
      id: doc.id,
      nome: (data['nome'] as String?)?.trim() ?? 'Sem nome',
      criadoPorId: (data['criadoPorId'] as String?) ?? '',
      criadoPorNome: (data['criadoPorNome'] as String?) ?? 'Desconhecido',
      criadoEm: parseData(data['criadoEm']),
      atualizadoEm: parseData(data['atualizadoEm']),
      precos: m,
      isPadrao: (data['isPadrao'] as bool?) ?? false,
    );
  }
}
