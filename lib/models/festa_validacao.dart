// lib/models/festa_validacao.dart
//
// Decisão humana sobre a troca de categoria sugerida na Festa dos Sócios.
// A sugestão é estática (festa_ocupacao_gerado.dart); aqui fica a validação
// que o gestor registra (e que persiste no Firestore).
import 'package:cloud_firestore/cloud_firestore.dart';

/// Status da validação de um quarto. Ausência de doc = pendente.
class FestaValidacao {
  /// 'aprovada' (troca confirmada) | 'recusada' (manter no quarto)
  final String status;
  final String? validadoPorNome;
  final DateTime? validadoEm;

  const FestaValidacao({
    required this.status,
    this.validadoPorNome,
    this.validadoEm,
  });

  bool get aprovada => status == 'aprovada';
  bool get recusada => status == 'recusada';

  factory FestaValidacao.fromMap(Map<String, dynamic> d) => FestaValidacao(
        status: d['status'] as String? ?? 'pendente',
        validadoPorNome: d['validadoPorNome'] as String?,
        validadoEm: (d['validadoEm'] as Timestamp?)?.toDate(),
      );
}
