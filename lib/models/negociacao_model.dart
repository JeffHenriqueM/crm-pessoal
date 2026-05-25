import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoDesconto { fixo, percentual }

enum StatusNegociacao { ativa, aceita, recusada }

extension StatusNegociacaoExt on StatusNegociacao {
  String get nomeDisplay {
    switch (this) {
      case StatusNegociacao.ativa:
        return 'Ativa';
      case StatusNegociacao.aceita:
        return 'Aceita';
      case StatusNegociacao.recusada:
        return 'Recusada';
    }
  }

  String get nome => name;
}

class Negociacao {
  final String? id;
  final String titulo;
  final double valorOriginal;
  final TipoDesconto tipoDesconto;
  final double desconto;
  final double? valorEntrada;
  final int? quantidadeParcelas;
  final double? valorParcelaOverride; // null = usa o calculado
  final StatusNegociacao status;
  final DateTime dataCriacao;
  final String? observacoes;

  const Negociacao({
    this.id,
    required this.titulo,
    required this.valorOriginal,
    this.tipoDesconto = TipoDesconto.fixo,
    this.desconto = 0,
    this.valorEntrada,
    this.quantidadeParcelas,
    this.valorParcelaOverride,
    this.status = StatusNegociacao.ativa,
    required this.dataCriacao,
    this.observacoes,
  });

  // ── Valores calculados ────────────────────────────────────────────────────
  double get valorFinal {
    final v = tipoDesconto == TipoDesconto.percentual
        ? valorOriginal * (1 - desconto / 100)
        : valorOriginal - desconto;
    return v.clamp(0, double.infinity);
  }

  double? get valorParcelaCalculado {
    if (quantidadeParcelas == null || quantidadeParcelas! <= 0) return null;
    final saldo = valorFinal - (valorEntrada ?? 0);
    return saldo <= 0 ? 0 : saldo / quantidadeParcelas!;
  }

  double? get valorParcela => valorParcelaOverride ?? valorParcelaCalculado;

  // ── Firestore ─────────────────────────────────────────────────────────────
  factory Negociacao.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Negociacao(
      id: doc.id,
      titulo: d['titulo'] ?? 'Proposta',
      valorOriginal: (d['valorOriginal'] as num?)?.toDouble() ?? 0,
      tipoDesconto: d['tipoDesconto'] == 'percentual'
          ? TipoDesconto.percentual
          : TipoDesconto.fixo,
      desconto: (d['desconto'] as num?)?.toDouble() ?? 0,
      valorEntrada: (d['valorEntrada'] as num?)?.toDouble(),
      quantidadeParcelas: (d['quantidadeParcelas'] as num?)?.toInt(),
      valorParcelaOverride:
          (d['valorParcelaOverride'] as num?)?.toDouble(),
      status: _statusFromString(d['status']),
      dataCriacao:
          (d['dataCriacao'] as Timestamp?)?.toDate() ?? DateTime.now(),
      observacoes: d['observacoes'],
    );
  }

  static StatusNegociacao _statusFromString(String? s) {
    switch (s) {
      case 'aceita':
        return StatusNegociacao.aceita;
      case 'recusada':
        return StatusNegociacao.recusada;
      default:
        return StatusNegociacao.ativa;
    }
  }

  Map<String, dynamic> toFirestore() => {
        'titulo': titulo,
        'valorOriginal': valorOriginal,
        'tipoDesconto':
            tipoDesconto == TipoDesconto.percentual ? 'percentual' : 'fixo',
        'desconto': desconto,
        'valorEntrada': valorEntrada,
        'quantidadeParcelas': quantidadeParcelas,
        'valorParcelaOverride': valorParcelaOverride,
        'status': status.nome,
        'dataCriacao': Timestamp.fromDate(dataCriacao),
        'observacoes': observacoes,
      };
}
