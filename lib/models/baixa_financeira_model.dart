// lib/models/baixa_financeira_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class BaixaFinanceira {
  final String? id;

  /// Nome do cliente (ex: "VILLAMOR TAMBABA").
  final String cliente;

  /// Forma de pagamento (ex: "018 - PIX", "017 - BOLETO SICRED").
  final String tipo;

  /// Identificador do CAR / contrato (ex: "LXP-61-334/Cota-01").
  final String documentoCar;

  final DateTime vencimento;
  final double valorPago;
  final DateTime dataBaixa;
  final DateTime dataCredito;

  /// Sempre "Baixado" na importação inicial.
  final String status;

  /// Chave de agrupamento mensal derivada de [dataCredito] (ex: "2026-03").
  /// Usada em queries de filtro e agregação sem exigir índice de range em Timestamp.
  final String mesCreditoKey;

  /// Momento em que o registro foi importado para o Firestore.
  final DateTime importadoEm;

  /// UID do usuário que realizou a importação.
  final String importadoPorId;

  /// Nome legível do usuário que realizou a importação.
  final String importadoPorNome;

  const BaixaFinanceira({
    this.id,
    required this.cliente,
    required this.tipo,
    required this.documentoCar,
    required this.vencimento,
    required this.valorPago,
    required this.dataBaixa,
    required this.dataCredito,
    required this.status,
    required this.mesCreditoKey,
    required this.importadoEm,
    required this.importadoPorId,
    required this.importadoPorNome,
  });

  // ── Serialização ────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'cliente': cliente,
      'tipo': tipo,
      'documentoCar': documentoCar,
      'vencimento': Timestamp.fromDate(vencimento),
      'valorPago': valorPago,
      'dataBaixa': Timestamp.fromDate(dataBaixa),
      'dataCredito': Timestamp.fromDate(dataCredito),
      'status': status,
      'mesCreditoKey': mesCreditoKey,
      'importadoEm': Timestamp.fromDate(importadoEm),
      'importadoPorId': importadoPorId,
      'importadoPorNome': importadoPorNome,
    };
  }

  factory BaixaFinanceira.fromMap(Map<String, dynamic> data, {String? id}) {
    return BaixaFinanceira(
      id: id,
      cliente: data['cliente'] as String? ?? '',
      tipo: data['tipo'] as String? ?? '',
      documentoCar: data['documentoCar'] as String? ?? '',
      vencimento: _parseTimestamp(data['vencimento']),
      valorPago: (data['valorPago'] as num?)?.toDouble() ?? 0.0,
      dataBaixa: _parseTimestamp(data['dataBaixa']),
      dataCredito: _parseTimestamp(data['dataCredito']),
      status: data['status'] as String? ?? 'Baixado',
      mesCreditoKey: data['mesCreditoKey'] as String? ?? '',
      importadoEm: _parseTimestamp(data['importadoEm']),
      importadoPorId: data['importadoPorId'] as String? ?? '',
      importadoPorNome: data['importadoPorNome'] as String? ?? '',
    );
  }

  factory BaixaFinanceira.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BaixaFinanceira.fromMap(data, id: doc.id);
  }

  // ── copyWith ────────────────────────────────────────────────────────────────

  BaixaFinanceira copyWith({
    String? id,
    String? cliente,
    String? tipo,
    String? documentoCar,
    DateTime? vencimento,
    double? valorPago,
    DateTime? dataBaixa,
    DateTime? dataCredito,
    String? status,
    String? mesCreditoKey,
    DateTime? importadoEm,
    String? importadoPorId,
    String? importadoPorNome,
  }) {
    return BaixaFinanceira(
      id: id ?? this.id,
      cliente: cliente ?? this.cliente,
      tipo: tipo ?? this.tipo,
      documentoCar: documentoCar ?? this.documentoCar,
      vencimento: vencimento ?? this.vencimento,
      valorPago: valorPago ?? this.valorPago,
      dataBaixa: dataBaixa ?? this.dataBaixa,
      dataCredito: dataCredito ?? this.dataCredito,
      status: status ?? this.status,
      mesCreditoKey: mesCreditoKey ?? this.mesCreditoKey,
      importadoEm: importadoEm ?? this.importadoEm,
      importadoPorId: importadoPorId ?? this.importadoPorId,
      importadoPorNome: importadoPorNome ?? this.importadoPorNome,
    );
  }

  // ── Utilitários ─────────────────────────────────────────────────────────────

  /// Converte [dataCredito] no formato "yyyy-MM" para uso como chave de mês.
  static String buildMesKey(DateTime dataCredito) {
    final m = dataCredito.month.toString().padLeft(2, '0');
    return '${dataCredito.year}-$m';
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    debugPrint('⚠️ BaixaFinanceira: campo de data inesperado — $value');
    return DateTime(2000);
  }

  @override
  String toString() =>
      'BaixaFinanceira(id: $id, cliente: $cliente, mes: $mesCreditoKey, '
      'valor: $valorPago, doc: $documentoCar)';
}
