// lib/models/ticket_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

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

enum PrioridadeTicket { baixa, normal, alta, urgente }

extension PrioridadeTicketExt on PrioridadeTicket {
  String get nome => name;

  String get nomeDisplay {
    switch (this) {
      case PrioridadeTicket.baixa:   return 'Baixa';
      case PrioridadeTicket.normal:  return 'Normal';
      case PrioridadeTicket.alta:    return 'Alta';
      case PrioridadeTicket.urgente: return 'Urgente';
    }
  }

  static PrioridadeTicket fromString(String? v) {
    return PrioridadeTicket.values.firstWhere(
      (e) => e.name == v,
      orElse: () => PrioridadeTicket.normal,
    );
  }
}

enum CategoriaTicket { suporte, bug, melhoria, duvida, outro }

extension CategoriaTicketExt on CategoriaTicket {
  String get nome => name;

  String get nomeDisplay {
    switch (this) {
      case CategoriaTicket.suporte:   return 'Suporte';
      case CategoriaTicket.bug:       return 'Bug';
      case CategoriaTicket.melhoria:  return 'Melhoria';
      case CategoriaTicket.duvida:    return 'Dúvida';
      case CategoriaTicket.outro:     return 'Outro';
    }
  }

  static CategoriaTicket fromString(String? v) {
    return CategoriaTicket.values.firstWhere(
      (e) => e.name == v,
      orElse: () => CategoriaTicket.outro,
    );
  }
}

// ── Ticket ─────────────────────────────────────────────────────────────────────

class Ticket {
  final String? id;
  final String titulo;
  final String descricao;
  final StatusTicket status;
  final PrioridadeTicket prioridade;
  final CategoriaTicket categoria;
  final String criadoPorId;
  final String criadoPorNome;
  final String? atribuidoParaId;
  final String? atribuidoParaNome;
  final DateTime dataCriacao;
  final DateTime dataAtualizacao;
  final String? clienteId;
  final String? clienteNome;
  final int totalComentarios;

  const Ticket({
    this.id,
    required this.titulo,
    required this.descricao,
    required this.status,
    required this.prioridade,
    required this.categoria,
    required this.criadoPorId,
    required this.criadoPorNome,
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
    return Ticket(
      id:                 doc.id,
      titulo:             d['titulo']           as String? ?? '',
      descricao:          d['descricao']         as String? ?? '',
      status:             StatusTicketExt.fromString(d['status'] as String?),
      prioridade:         PrioridadeTicketExt.fromString(d['prioridade'] as String?),
      categoria:          CategoriaTicketExt.fromString(d['categoria'] as String?),
      criadoPorId:        d['criadoPorId']       as String? ?? '',
      criadoPorNome:      d['criadoPorNome']     as String? ?? '',
      atribuidoParaId:    d['atribuidoParaId']   as String?,
      atribuidoParaNome:  d['atribuidoParaNome'] as String?,
      dataCriacao:        (d['dataCriacao']       as Timestamp?)?.toDate() ?? DateTime.now(),
      dataAtualizacao:    (d['dataAtualizacao']   as Timestamp?)?.toDate() ?? DateTime.now(),
      clienteId:          d['clienteId']         as String?,
      clienteNome:        d['clienteNome']       as String?,
      totalComentarios:   d['totalComentarios']  as int? ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'titulo':             titulo,
    'descricao':          descricao,
    'status':             status.nome,
    'prioridade':         prioridade.nome,
    'categoria':          categoria.nome,
    'criadoPorId':        criadoPorId,
    'criadoPorNome':      criadoPorNome,
    'atribuidoParaId':    atribuidoParaId,
    'atribuidoParaNome':  atribuidoParaNome,
    'dataCriacao':        Timestamp.fromDate(dataCriacao),
    'dataAtualizacao':    Timestamp.fromDate(dataAtualizacao),
    'clienteId':          clienteId,
    'clienteNome':        clienteNome,
    'totalComentarios':   totalComentarios,
  };

  Ticket copyWith({
    String? id,
    String? titulo,
    String? descricao,
    StatusTicket? status,
    PrioridadeTicket? prioridade,
    CategoriaTicket? categoria,
    String? criadoPorId,
    String? criadoPorNome,
    String? atribuidoParaId,
    String? atribuidoParaNome,
    DateTime? dataCriacao,
    DateTime? dataAtualizacao,
    String? clienteId,
    String? clienteNome,
    int? totalComentarios,
  }) => Ticket(
    id:                 id ?? this.id,
    titulo:             titulo ?? this.titulo,
    descricao:          descricao ?? this.descricao,
    status:             status ?? this.status,
    prioridade:         prioridade ?? this.prioridade,
    categoria:          categoria ?? this.categoria,
    criadoPorId:        criadoPorId ?? this.criadoPorId,
    criadoPorNome:      criadoPorNome ?? this.criadoPorNome,
    atribuidoParaId:    atribuidoParaId ?? this.atribuidoParaId,
    atribuidoParaNome:  atribuidoParaNome ?? this.atribuidoParaNome,
    dataCriacao:        dataCriacao ?? this.dataCriacao,
    dataAtualizacao:    dataAtualizacao ?? this.dataAtualizacao,
    clienteId:          clienteId ?? this.clienteId,
    clienteNome:        clienteNome ?? this.clienteNome,
    totalComentarios:   totalComentarios ?? this.totalComentarios,
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
