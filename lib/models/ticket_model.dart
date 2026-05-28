// lib/models/ticket_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ── Enums ──────────────────────────────────────────────────────────────────────

enum StatusTicket { aberto, emAndamento, resolvido, fechado }

extension StatusTicketExt on StatusTicket {
  String get nome => name;

  String get nomeDisplay {
    switch (this) {
      case StatusTicket.aberto:       return 'Aberto';
      case StatusTicket.emAndamento:  return 'Em andamento';
      case StatusTicket.resolvido:    return 'Resolvido';
      case StatusTicket.fechado:      return 'Fechado';
    }
  }

  static StatusTicket fromString(String? v) {
    return StatusTicket.values.firstWhere(
      (e) => e.name == v,
      orElse: () => StatusTicket.aberto,
    );
  }
}

enum TipoTicket { bug, melhoria, funcionalidade }

extension TipoTicketExt on TipoTicket {
  String get nome => name;

  String get nomeDisplay {
    switch (this) {
      case TipoTicket.bug:          return 'Bug';
      case TipoTicket.melhoria:     return 'Melhoria';
      case TipoTicket.funcionalidade: return 'Funcionalidade';
    }
  }

  IconData get icone {
    switch (this) {
      case TipoTicket.bug:          return Icons.bug_report_outlined;
      case TipoTicket.melhoria:     return Icons.lightbulb_outlined;
      case TipoTicket.funcionalidade: return Icons.build_outlined;
    }
  }

  Color get cor {
    switch (this) {
      case TipoTicket.bug:          return const Color(0xFFEF4444);
      case TipoTicket.melhoria:     return const Color(0xFF10B981);
      case TipoTicket.funcionalidade: return const Color(0xFF8B5CF6);
    }
  }

  static TipoTicket fromString(String? v) {
    // compatibilidade com CategoriaTicket antigo
    if (v == 'melhoria') return TipoTicket.melhoria;
    if (v == 'suporte' || v == 'duvida') return TipoTicket.melhoria;
    if (v == 'outro') return TipoTicket.funcionalidade;
    return TipoTicket.values.firstWhere(
      (e) => e.name == v,
      orElse: () => TipoTicket.bug,
    );
  }
}

enum PrioridadeTicket { baixa, media, alta }

extension PrioridadeTicketExt on PrioridadeTicket {
  String get nome => name;

  String get nomeDisplay {
    switch (this) {
      case PrioridadeTicket.baixa: return 'Baixa';
      case PrioridadeTicket.media: return 'Média';
      case PrioridadeTicket.alta:  return 'Alta';
    }
  }

  Color get cor {
    switch (this) {
      case PrioridadeTicket.baixa: return const Color(0xFF78909C);
      case PrioridadeTicket.media: return const Color(0xFFF59E0B);
      case PrioridadeTicket.alta:  return const Color(0xFFE65100);
    }
  }

  static PrioridadeTicket fromString(String? v) {
    // migra valores antigos do enum anterior
    if (v == 'normal') return PrioridadeTicket.media;
    if (v == 'urgente') return PrioridadeTicket.alta;
    return PrioridadeTicket.values.firstWhere(
      (e) => e.name == v,
      orElse: () => PrioridadeTicket.media,
    );
  }
}

// ── Ticket ─────────────────────────────────────────────────────────────────────

class Ticket {
  final String? id;
  final int numero;
  final String titulo;
  final String descricao;
  final StatusTicket status;
  final PrioridadeTicket prioridade;
  final TipoTicket tipo;
  final String criadoPorId;
  final String criadoPorNome;
  final String criadoPorPerfil;
  final String? contexto;
  final String? atribuidoParaId;
  final String? atribuidoParaNome;
  final DateTime dataCriacao;
  final DateTime dataAtualizacao;
  final String? clienteId;
  final String? clienteNome;
  final int totalComentarios;

  const Ticket({
    this.id,
    this.numero = 0,
    required this.titulo,
    required this.descricao,
    required this.status,
    required this.prioridade,
    required this.tipo,
    required this.criadoPorId,
    required this.criadoPorNome,
    this.criadoPorPerfil = '',
    this.contexto,
    this.atribuidoParaId,
    this.atribuidoParaNome,
    required this.dataCriacao,
    required this.dataAtualizacao,
    this.clienteId,
    this.clienteNome,
    this.totalComentarios = 0,
  });

  factory Ticket.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    // docs antigos tinham 'categoria' em vez de 'tipo'
    final tipoStr = (d['tipo'] ?? d['categoria']) as String?;
    return Ticket(
      id:               doc.id,
      numero:           d['numero']           as int? ?? 0,
      titulo:           d['titulo']           as String? ?? '',
      descricao:        d['descricao']        as String? ?? '',
      status:           StatusTicketExt.fromString(d['status']     as String?),
      prioridade:       PrioridadeTicketExt.fromString(d['prioridade'] as String?),
      tipo:             TipoTicketExt.fromString(tipoStr),
      criadoPorId:      d['criadoPorId']      as String? ?? '',
      criadoPorNome:    d['criadoPorNome']    as String? ?? '',
      criadoPorPerfil:  d['criadoPorPerfil']  as String? ?? '',
      contexto:         d['contexto']         as String?,
      atribuidoParaId:  d['atribuidoParaId']  as String?,
      atribuidoParaNome: d['atribuidoParaNome'] as String?,
      dataCriacao:      (d['dataCriacao']     as Timestamp?)?.toDate() ?? DateTime.now(),
      dataAtualizacao:  (d['dataAtualizacao'] as Timestamp?)?.toDate() ?? DateTime.now(),
      clienteId:        d['clienteId']        as String?,
      clienteNome:      d['clienteNome']      as String?,
      totalComentarios: d['totalComentarios'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'numero':           numero,
    'titulo':           titulo,
    'descricao':        descricao,
    'status':           status.nome,
    'prioridade':       prioridade.nome,
    'tipo':             tipo.nome,
    'criadoPorId':      criadoPorId,
    'criadoPorNome':    criadoPorNome,
    'criadoPorPerfil':  criadoPorPerfil,
    'contexto':         contexto,
    'atribuidoParaId':  atribuidoParaId,
    'atribuidoParaNome': atribuidoParaNome,
    'dataCriacao':      Timestamp.fromDate(dataCriacao),
    'dataAtualizacao':  Timestamp.fromDate(dataAtualizacao),
    'clienteId':        clienteId,
    'clienteNome':      clienteNome,
    'totalComentarios': totalComentarios,
  };

  Ticket copyWith({
    String? id,
    int? numero,
    String? titulo,
    String? descricao,
    StatusTicket? status,
    PrioridadeTicket? prioridade,
    TipoTicket? tipo,
    String? criadoPorId,
    String? criadoPorNome,
    String? criadoPorPerfil,
    String? contexto,
    String? atribuidoParaId,
    String? atribuidoParaNome,
    DateTime? dataCriacao,
    DateTime? dataAtualizacao,
    String? clienteId,
    String? clienteNome,
    int? totalComentarios,
  }) => Ticket(
    id:               id ?? this.id,
    numero:           numero ?? this.numero,
    titulo:           titulo ?? this.titulo,
    descricao:        descricao ?? this.descricao,
    status:           status ?? this.status,
    prioridade:       prioridade ?? this.prioridade,
    tipo:             tipo ?? this.tipo,
    criadoPorId:      criadoPorId ?? this.criadoPorId,
    criadoPorNome:    criadoPorNome ?? this.criadoPorNome,
    criadoPorPerfil:  criadoPorPerfil ?? this.criadoPorPerfil,
    contexto:         contexto ?? this.contexto,
    atribuidoParaId:  atribuidoParaId ?? this.atribuidoParaId,
    atribuidoParaNome: atribuidoParaNome ?? this.atribuidoParaNome,
    dataCriacao:      dataCriacao ?? this.dataCriacao,
    dataAtualizacao:  dataAtualizacao ?? this.dataAtualizacao,
    clienteId:        clienteId ?? this.clienteId,
    clienteNome:      clienteNome ?? this.clienteNome,
    totalComentarios: totalComentarios ?? this.totalComentarios,
  );
}

// ── Comentário de ticket ───────────────────────────────────────────────────────

class ComentarioTicket {
  final String? id;
  final String texto;
  final String autorId;
  final String autorNome;
  final DateTime data;

  const ComentarioTicket({
    this.id,
    required this.texto,
    required this.autorId,
    required this.autorNome,
    required this.data,
  });

  factory ComentarioTicket.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ComentarioTicket(
      id:        doc.id,
      texto:     d['texto']     as String? ?? '',
      autorId:   d['autorId']   as String? ?? '',
      autorNome: d['autorNome'] as String? ?? '',
      data:      (d['data']     as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'texto':     texto,
    'autorId':   autorId,
    'autorNome': autorNome,
    'data':      Timestamp.fromDate(data),
  };
}
