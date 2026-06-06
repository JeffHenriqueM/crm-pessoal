import 'package:cloud_firestore/cloud_firestore.dart';

import 'imovel_model.dart';

/// Uma cota vendida de um imóvel. Vive na subcoleção `imoveis/{id}/cotas`,
/// projetada a partir de um contrato da coleção raiz `contratos`.
///
/// Regra de negócio: cada cota de um imóvel pode estar associada a **um**
/// contrato apenas. Por isso o id do documento é o próprio rótulo da cota
/// (`Cota-06`, `Integral`), garantindo unicidade dentro do imóvel.
class Cota {
  /// Id do documento = rótulo da cota: 'Cota-06' ou 'Integral'.
  final String numero;

  /// Tier derivado do produto do contrato.
  final TierCota? tier;

  /// Comprador (de quem é a cota).
  final String clienteNome;
  final String cpfComprador;

  /// Localizador do contrato de origem (liga à coleção `contratos`).
  final String contratoId;

  final String produto;
  final double valor;
  final String statusFinanceiro;
  final DateTime? dataContrato;

  const Cota({
    required this.numero,
    this.tier,
    this.clienteNome = '',
    this.cpfComprador = '',
    required this.contratoId,
    this.produto = '',
    this.valor = 0,
    this.statusFinanceiro = 'Em andamento',
    this.dataContrato,
  });

  bool get estaQuitada => statusFinanceiro.toLowerCase() == 'quitado';

  factory Cota.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Cota(
      numero: doc.id,
      tier: TierCota.fromString(d['tier'] as String?),
      clienteNome: d['clienteNome'] as String? ?? '',
      cpfComprador: d['cpfComprador'] as String? ?? '',
      contratoId: d['contratoId'] as String? ?? '',
      produto: d['produto'] as String? ?? '',
      valor: _toDouble(d['valor']),
      statusFinanceiro: d['statusFinanceiro'] as String? ?? 'Em andamento',
      dataContrato: (d['dataContrato'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'numero': numero,
      'tier': tier?.value,
      'clienteNome': clienteNome,
      'cpfComprador': cpfComprador,
      'contratoId': contratoId,
      'produto': produto,
      'valor': valor,
      'statusFinanceiro': statusFinanceiro,
      if (dataContrato != null) 'dataContrato': Timestamp.fromDate(dataContrato!),
      'atualizadoEm': FieldValue.serverTimestamp(),
    };
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
    return 0.0;
  }
}
