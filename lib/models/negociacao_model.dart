import 'package:cloud_firestore/cloud_firestore.dart';

// ── Enums originais ───────────────────────────────────────────────────────────
enum TipoDesconto { fixo, percentual }

enum StatusNegociacao { ativa, aceita, recusada, contratoEfetivado }

extension StatusNegociacaoExt on StatusNegociacao {
  String get nomeDisplay {
    switch (this) {
      case StatusNegociacao.ativa:
        return 'Ativa';
      case StatusNegociacao.aceita:
        return 'Aceita';
      case StatusNegociacao.recusada:
        return 'Recusada';
      case StatusNegociacao.contratoEfetivado:
        return 'Contrato Efetivado';
    }
  }

  String get nome => name;
}

// ── Novos enums ───────────────────────────────────────────────────────────────
enum TipoNegociacao { tabela, especial }

extension TipoNegociacaoExt on TipoNegociacao {
  String get nomeDisplay {
    switch (this) {
      case TipoNegociacao.tabela:
        return 'Valor de Tabela';
      case TipoNegociacao.especial:
        return 'Negociação Especial';
    }
  }

  String get nome => name;
}

enum StatusAprovacao {
  semSolicitacao,
  pendente,
  aprovada,
  negada,
  aguardandoAtualizacao,
}

extension StatusAprovacaoExt on StatusAprovacao {
  String get nomeDisplay {
    switch (this) {
      case StatusAprovacao.semSolicitacao:
        return 'Sem solicitação';
      case StatusAprovacao.pendente:
        return 'Aguardando aprovação';
      case StatusAprovacao.aprovada:
        return 'Aprovada';
      case StatusAprovacao.negada:
        return 'Negada';
      case StatusAprovacao.aguardandoAtualizacao:
        return 'Aguardando atualização';
    }
  }

  String get nome => name;
}

// ── Modelo principal ──────────────────────────────────────────────────────────
class Negociacao {
  final String? id;

  // Vínculo com lead (opcional — pode existir sem cliente)
  final String? clienteId;
  final String? clienteNome;

  // Tipo e fluxo de aprovação
  final TipoNegociacao tipo;
  final String? condicaoEspecial;
  final DateTime? prazoResposta;
  final StatusAprovacao statusAprovacao;
  final DateTime? dataSolicitacaoAprovacao;
  final DateTime? dataAprovacao;
  final String? aprovadoPorId;
  final String? aprovadoPorNome;
  final String? comentarioAprovacao;

  // Embaixador (quem conduz a negociação)
  final String? embaixadorId;
  final String? embaixadorNome;

  // Auditoria
  final String? criadoPorId;
  final String? criadoPorNome;
  final String? editadoPorId;
  final String? editadoPorNome;

  // Campos financeiros
  final String titulo;
  final double valorOriginal;
  final TipoDesconto tipoDesconto;
  final double desconto;
  final double? valorEntrada;
  final int? quantidadeParcelas;
  final double? valorParcelaOverride;
  final StatusNegociacao status;
  final DateTime dataCriacao;
  final String? observacoes;

  const Negociacao({
    this.id,
    this.clienteId,
    this.clienteNome,
    this.tipo = TipoNegociacao.tabela,
    this.condicaoEspecial,
    this.prazoResposta,
    this.statusAprovacao = StatusAprovacao.semSolicitacao,
    this.dataSolicitacaoAprovacao,
    this.dataAprovacao,
    this.aprovadoPorId,
    this.aprovadoPorNome,
    this.comentarioAprovacao,
    this.embaixadorId,
    this.embaixadorNome,
    this.criadoPorId,
    this.criadoPorNome,
    this.editadoPorId,
    this.editadoPorNome,
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

  // ── copyWith ──────────────────────────────────────────────────────────────
  Negociacao copyWith({
    String? id,
    Object? clienteId = _sentinel,
    Object? clienteNome = _sentinel,
    TipoNegociacao? tipo,
    Object? condicaoEspecial = _sentinel,
    Object? prazoResposta = _sentinel,
    StatusAprovacao? statusAprovacao,
    Object? dataSolicitacaoAprovacao = _sentinel,
    Object? dataAprovacao = _sentinel,
    Object? aprovadoPorId = _sentinel,
    Object? aprovadoPorNome = _sentinel,
    Object? comentarioAprovacao = _sentinel,
    Object? embaixadorId = _sentinel,
    Object? embaixadorNome = _sentinel,
    Object? criadoPorId = _sentinel,
    Object? criadoPorNome = _sentinel,
    Object? editadoPorId = _sentinel,
    Object? editadoPorNome = _sentinel,
    String? titulo,
    double? valorOriginal,
    TipoDesconto? tipoDesconto,
    double? desconto,
    Object? valorEntrada = _sentinel,
    Object? quantidadeParcelas = _sentinel,
    Object? valorParcelaOverride = _sentinel,
    StatusNegociacao? status,
    DateTime? dataCriacao,
    Object? observacoes = _sentinel,
  }) {
    return Negociacao(
      id: id ?? this.id,
      clienteId: clienteId == _sentinel ? this.clienteId : clienteId as String?,
      clienteNome: clienteNome == _sentinel ? this.clienteNome : clienteNome as String?,
      tipo: tipo ?? this.tipo,
      condicaoEspecial: condicaoEspecial == _sentinel ? this.condicaoEspecial : condicaoEspecial as String?,
      prazoResposta: prazoResposta == _sentinel ? this.prazoResposta : prazoResposta as DateTime?,
      statusAprovacao: statusAprovacao ?? this.statusAprovacao,
      dataSolicitacaoAprovacao: dataSolicitacaoAprovacao == _sentinel ? this.dataSolicitacaoAprovacao : dataSolicitacaoAprovacao as DateTime?,
      dataAprovacao: dataAprovacao == _sentinel ? this.dataAprovacao : dataAprovacao as DateTime?,
      aprovadoPorId: aprovadoPorId == _sentinel ? this.aprovadoPorId : aprovadoPorId as String?,
      aprovadoPorNome: aprovadoPorNome == _sentinel ? this.aprovadoPorNome : aprovadoPorNome as String?,
      comentarioAprovacao: comentarioAprovacao == _sentinel ? this.comentarioAprovacao : comentarioAprovacao as String?,
      embaixadorId: embaixadorId == _sentinel ? this.embaixadorId : embaixadorId as String?,
      embaixadorNome: embaixadorNome == _sentinel ? this.embaixadorNome : embaixadorNome as String?,
      criadoPorId: criadoPorId == _sentinel ? this.criadoPorId : criadoPorId as String?,
      criadoPorNome: criadoPorNome == _sentinel ? this.criadoPorNome : criadoPorNome as String?,
      editadoPorId: editadoPorId == _sentinel ? this.editadoPorId : editadoPorId as String?,
      editadoPorNome: editadoPorNome == _sentinel ? this.editadoPorNome : editadoPorNome as String?,
      titulo: titulo ?? this.titulo,
      valorOriginal: valorOriginal ?? this.valorOriginal,
      tipoDesconto: tipoDesconto ?? this.tipoDesconto,
      desconto: desconto ?? this.desconto,
      valorEntrada: valorEntrada == _sentinel ? this.valorEntrada : valorEntrada as double?,
      quantidadeParcelas: quantidadeParcelas == _sentinel ? this.quantidadeParcelas : quantidadeParcelas as int?,
      valorParcelaOverride: valorParcelaOverride == _sentinel ? this.valorParcelaOverride : valorParcelaOverride as double?,
      status: status ?? this.status,
      dataCriacao: dataCriacao ?? this.dataCriacao,
      observacoes: observacoes == _sentinel ? this.observacoes : observacoes as String?,
    );
  }

  // ── Firestore ─────────────────────────────────────────────────────────────
  factory Negociacao.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Negociacao(
      id: doc.id,
      clienteId: d['clienteId'],
      clienteNome: d['clienteNome'],
      tipo: _tipoFromString(d['tipo']),
      condicaoEspecial: d['condicaoEspecial'],
      prazoResposta: (d['prazoResposta'] as Timestamp?)?.toDate(),
      statusAprovacao: _statusAprovacaoFromString(d['statusAprovacao']),
      dataSolicitacaoAprovacao:
          (d['dataSolicitacaoAprovacao'] as Timestamp?)?.toDate(),
      dataAprovacao: (d['dataAprovacao'] as Timestamp?)?.toDate(),
      aprovadoPorId: d['aprovadoPorId'],
      aprovadoPorNome: d['aprovadoPorNome'],
      comentarioAprovacao: d['comentarioAprovacao'],
      embaixadorId: d['embaixadorId'],
      embaixadorNome: d['embaixadorNome'],
      criadoPorId: d['criadoPorId'],
      criadoPorNome: d['criadoPorNome'],
      editadoPorId: d['editadoPorId'],
      editadoPorNome: d['editadoPorNome'],
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

  static TipoNegociacao _tipoFromString(String? s) {
    switch (s) {
      case 'especial':
        return TipoNegociacao.especial;
      default:
        return TipoNegociacao.tabela;
    }
  }

  static StatusAprovacao _statusAprovacaoFromString(String? s) {
    switch (s) {
      case 'pendente':
        return StatusAprovacao.pendente;
      case 'aprovada':
        return StatusAprovacao.aprovada;
      case 'negada':
        return StatusAprovacao.negada;
      case 'aguardandoAtualizacao':
        return StatusAprovacao.aguardandoAtualizacao;
      default:
        return StatusAprovacao.semSolicitacao;
    }
  }

  static StatusNegociacao _statusFromString(String? s) {
    switch (s) {
      case 'aceita':
        return StatusNegociacao.aceita;
      case 'recusada':
        return StatusNegociacao.recusada;
      case 'contratoEfetivado':
        return StatusNegociacao.contratoEfetivado;
      default:
        return StatusNegociacao.ativa;
    }
  }

  Map<String, dynamic> toFirestore() => {
        'clienteId': clienteId,
        'clienteNome': clienteNome,
        'tipo': tipo.nome,
        'condicaoEspecial': condicaoEspecial,
        'prazoResposta':
            prazoResposta != null ? Timestamp.fromDate(prazoResposta!) : null,
        'statusAprovacao': statusAprovacao.nome,
        'dataSolicitacaoAprovacao': dataSolicitacaoAprovacao != null
            ? Timestamp.fromDate(dataSolicitacaoAprovacao!)
            : null,
        'dataAprovacao':
            dataAprovacao != null ? Timestamp.fromDate(dataAprovacao!) : null,
        'aprovadoPorId': aprovadoPorId,
        'aprovadoPorNome': aprovadoPorNome,
        'comentarioAprovacao': comentarioAprovacao,
        'embaixadorId': embaixadorId,
        'embaixadorNome': embaixadorNome,
        'criadoPorId': criadoPorId,
        'criadoPorNome': criadoPorNome,
        'editadoPorId': editadoPorId,
        'editadoPorNome': editadoPorNome,
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

// Sentinel para distinguir null intencional de "não fornecido" no copyWith
const _sentinel = Object();
