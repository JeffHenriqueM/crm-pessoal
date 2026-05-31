import 'package:cloud_firestore/cloud_firestore.dart';

class Produto {
  final String? id;
  final String nome;
  final String categoria;
  final double valor;
  final double? limiteEspecial;
  final bool ativo;
  final int ordem;

  const Produto({
    this.id,
    required this.nome,
    required this.categoria,
    required this.valor,
    this.limiteEspecial,
    this.ativo = true,
    this.ordem = 0,
  });

  factory Produto.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Produto(
      id: doc.id,
      nome: data['nome'] as String? ?? '',
      categoria: data['categoria'] as String? ?? '',
      valor: (data['valor'] as num?)?.toDouble() ?? 0,
      limiteEspecial: (data['limiteEspecial'] as num?)?.toDouble(),
      ativo: data['ativo'] as bool? ?? true,
      ordem: (data['ordem'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'categoria': categoria,
        'valor': valor,
        'limiteEspecial': limiteEspecial,
        'ativo': ativo,
        'ordem': ordem,
      };

  Produto copyWith({
    String? id,
    String? nome,
    String? categoria,
    double? valor,
    double? limiteEspecial,
    bool? ativo,
    int? ordem,
    bool clearLimiteEspecial = false,
  }) =>
      Produto(
        id: id ?? this.id,
        nome: nome ?? this.nome,
        categoria: categoria ?? this.categoria,
        valor: valor ?? this.valor,
        limiteEspecial:
            clearLimiteEspecial ? null : (limiteEspecial ?? this.limiteEspecial),
        ativo: ativo ?? this.ativo,
        ordem: ordem ?? this.ordem,
      );
}
