import 'package:cloud_firestore/cloud_firestore.dart';

/// Tier de cota de um imóvel. O total de cotas por apartamento depende do tier:
/// bronze 52 · prata 26 · ouro 13 · diamante 1 · integral 1 (apto inteiro).
enum TierCota {
  bronze,
  prata,
  ouro,
  diamante,
  integral;

  /// Quantidade de cotas que o tier comporta por imóvel.
  int get cotasTotal {
    switch (this) {
      case TierCota.bronze:
        return 52;
      case TierCota.prata:
        return 26;
      case TierCota.ouro:
        return 13;
      case TierCota.diamante:
        return 1;
      case TierCota.integral:
        return 1;
    }
  }

  String get label {
    switch (this) {
      case TierCota.bronze:
        return 'Bronze';
      case TierCota.prata:
        return 'Prata';
      case TierCota.ouro:
        return 'Ouro';
      case TierCota.diamante:
        return 'Diamante';
      case TierCota.integral:
        return 'Integral';
    }
  }

  String get value => name;

  static TierCota? fromString(String? v) {
    if (v == null) return null;
    for (final t in TierCota.values) {
      if (t.name == v) return t;
    }
    return null;
  }
}

/// Unidade do empreendimento (apartamento ou bangalô). É o inventário
/// estático da 1ª etapa: Bloco B (HERA, 98 aptos), Bloco C (AFRODITE, 118 aptos)
/// e 12 bangalôs — total de 228 unidades.
///
/// As vendas/cotas NÃO ficam aqui: vivem na subcoleção `imoveis/{id}/cotas`,
/// projetadas a partir da coleção raiz `contratos`. O tier do imóvel é derivado
/// das cotas (todos os contratos de um imóvel compartilham o mesmo tier).
class Imovel {
  /// Id legível e estável: `B-101`, `C-313`, `BANG-F`.
  final String id;

  /// 'B' | 'C' | 'BANGALO'.
  final String bloco;

  /// 'HERA' | 'AFRODITE' | 'Bangalôs'.
  final String blocoNome;

  /// 'terreo' | '1' | '2' | '3' | '4' | '5' | 'unico' (bangalô).
  final String pavimento;

  /// Número do apartamento ('1'..'20', '101'..'520') ou letra do bangalô ('F').
  final String numero;

  /// Tipo da planta: 'LUXO', 'LUXO PREMIUM', 'LUXO MASTER', 'VILLAMOR',
  /// 'VILLAMOR PREMIUM', 'VILLAMOR SUPER MASTER', 'BANGALO'.
  final String tipo;

  /// Área interna em m². Null nos bangalôs (definida depois).
  final double? metragem;

  /// Área externa em m² (térreos do Bloco C). Null quando não há.
  final double? metragemExterna;

  /// Etapa de entrega. Esta primeira leva é a etapa 1.
  final int etapa;

  const Imovel({
    required this.id,
    required this.bloco,
    required this.blocoNome,
    required this.pavimento,
    required this.numero,
    required this.tipo,
    this.metragem,
    this.metragemExterna,
    this.etapa = 1,
  });

  bool get ehBangalo => bloco == 'BANGALO';

  factory Imovel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Imovel(
      id: doc.id,
      bloco: d['bloco'] as String? ?? '',
      blocoNome: d['blocoNome'] as String? ?? '',
      pavimento: d['pavimento'] as String? ?? '',
      numero: d['numero'] as String? ?? '',
      tipo: d['tipo'] as String? ?? '',
      metragem: _toDoubleOrNull(d['metragem']),
      metragemExterna: _toDoubleOrNull(d['metragemExterna']),
      etapa: (d['etapa'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'bloco': bloco,
      'blocoNome': blocoNome,
      'pavimento': pavimento,
      'numero': numero,
      'tipo': tipo,
      'metragem': metragem,
      'metragemExterna': metragemExterna,
      'etapa': etapa,
    };
  }

  static double? _toDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.'));
    return null;
  }
}
