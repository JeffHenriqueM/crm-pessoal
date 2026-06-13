import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// ── Canal de contato ──────────────────────────────────────────────────────────
enum Canal { whatsapp, ligacao, email, visita, outro, sistema }

extension CanalExt on Canal {
  String get valor {
    switch (this) {
      case Canal.whatsapp: return 'whatsapp';
      case Canal.ligacao:  return 'ligacao';
      case Canal.email:    return 'email';
      case Canal.visita:   return 'visita';
      case Canal.outro:    return 'outro';
      case Canal.sistema:  return 'sistema';
    }
  }

  String get nome {
    switch (this) {
      case Canal.whatsapp: return 'WhatsApp';
      case Canal.ligacao:  return 'Ligação';
      case Canal.email:    return 'E-mail';
      case Canal.visita:   return 'Visita';
      case Canal.outro:    return 'Outro';
      case Canal.sistema:  return 'Sistema';
    }
  }

  IconData get icone {
    switch (this) {
      case Canal.whatsapp: return FontAwesomeIcons.whatsapp;
      case Canal.ligacao:  return Icons.phone_outlined;
      case Canal.email:    return Icons.email_outlined;
      case Canal.visita:   return Icons.location_on_outlined;
      case Canal.outro:    return Icons.chat_bubble_outline;
      case Canal.sistema:  return Icons.settings_outlined;
    }
  }

  Color get cor {
    switch (this) {
      case Canal.whatsapp: return const Color(0xFF25D366);
      case Canal.ligacao:  return const Color(0xFF1565C0);
      case Canal.email:    return const Color(0xFF6A1B9A);
      case Canal.visita:   return const Color(0xFF00695C);
      case Canal.outro:    return const Color(0xFF546E7A);
      case Canal.sistema:  return const Color(0xFF90A4AE);
    }
  }

  static Canal fromString(String? v) {
    switch (v) {
      case 'whatsapp': return Canal.whatsapp;
      case 'ligacao':  return Canal.ligacao;
      case 'email':    return Canal.email;
      case 'visita':   return Canal.visita;
      case 'sistema':  return Canal.sistema;
      default:         return Canal.outro;
    }
  }
}

// ── Modalidade ────────────────────────────────────────────────────────────────
enum Modalidade { online, presencial }

extension ModalidadeExt on Modalidade {
  String get valor => this == Modalidade.online ? 'online' : 'presencial';
  String get nome  => this == Modalidade.online ? 'Online' : 'Presencial';

  static Modalidade fromString(String? v) =>
      v == 'presencial' ? Modalidade.presencial : Modalidade.online;
}

// ── Modelo ────────────────────────────────────────────────────────────────────
class Interacao {
  final String? id;
  final String? titulo;
  final String nota;
  final DateTime dataInteracao;
  final Canal canal;
  final Modalidade modalidade;
  final bool houveResposta;
  final String? oQueCombinamos;
  // Resposta do cliente registrada DEPOIS da interação (quando ela foi criada
  // sem resposta). Preenchê-la marca houveResposta=true. respostaEm = quando
  // foi registrada.
  final String? respostaCliente;
  final DateTime? respostaEm;
  final String? autorId;
  final String? autorNome;

  const Interacao({
    this.id,
    this.titulo,
    required this.nota,
    required this.dataInteracao,
    this.canal = Canal.whatsapp,
    this.modalidade = Modalidade.online,
    this.houveResposta = false,
    this.oQueCombinamos,
    this.respostaCliente,
    this.respostaEm,
    this.autorId,
    this.autorNome,
  });

  bool get isSistema => canal == Canal.sistema;

  Interacao copyWith({
    String? titulo,
    String? nota,
    DateTime? dataInteracao,
    Canal? canal,
    Modalidade? modalidade,
    bool? houveResposta,
    String? oQueCombinamos,
    String? respostaCliente,
    DateTime? respostaEm,
  }) =>
      Interacao(
        id: id,
        titulo: titulo ?? this.titulo,
        nota: nota ?? this.nota,
        dataInteracao: dataInteracao ?? this.dataInteracao,
        canal: canal ?? this.canal,
        modalidade: modalidade ?? this.modalidade,
        houveResposta: houveResposta ?? this.houveResposta,
        oQueCombinamos: oQueCombinamos ?? this.oQueCombinamos,
        respostaCliente: respostaCliente ?? this.respostaCliente,
        respostaEm: respostaEm ?? this.respostaEm,
        autorId: autorId,
        autorNome: autorNome,
      );

  Map<String, dynamic> toFirestore() => {
    if (titulo != null && titulo!.isNotEmpty) 'titulo': titulo,
    'nota':          nota,
    // Data real da interação (pode ser retroativa: registrar conversa antiga).
    'dataInteracao': Timestamp.fromDate(dataInteracao),
    'canal':         canal.valor,
    'modalidade':    modalidade.valor,
    'houveResposta': houveResposta,
    if (oQueCombinamos != null && oQueCombinamos!.isNotEmpty)
      'oQueCombinamos': oQueCombinamos,
    if (respostaCliente != null && respostaCliente!.isNotEmpty)
      'respostaCliente': respostaCliente,
    if (respostaEm != null) 'respostaEm': Timestamp.fromDate(respostaEm!),
  };

  factory Interacao.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // 'canal' é o campo unificado; 'tipo' é legado do Villamor CRM
    final canalRaw = (data['canal'] as String?) ?? (data['tipo'] as String?);

    // 'nota' é o campo unificado; 'summary' é legado do NeuroCRM
    final nota = (data['nota'] as String?)?.isNotEmpty == true
        ? data['nota'] as String
        : (data['summary'] as String? ?? '');

    final rawData = data['dataInteracao'];
    final dataInteracao = rawData is Timestamp
        ? rawData.toDate()
        : rawData is String
            ? DateTime.tryParse(rawData) ?? DateTime.now()
            : DateTime.now();

    return Interacao(
      id: doc.id,
      titulo: data['titulo'] as String?,
      nota: nota,
      dataInteracao: dataInteracao,
      canal: CanalExt.fromString(canalRaw),
      modalidade: ModalidadeExt.fromString(data['modalidade'] as String?),
      // 'houveResposta' é o campo unificado; 'got_response' é legado do NeuroCRM
      houveResposta: data['houveResposta'] as bool?
          ?? data['got_response'] as bool?
          ?? canalRaw == 'sistema',
      // 'oQueCombinamos' é o campo unificado; 'proximoPasso' é legado
      oQueCombinamos: (data['oQueCombinamos'] as String?)?.isNotEmpty == true
          ? data['oQueCombinamos'] as String
          : data['proximoPasso'] as String?,
      respostaCliente: (data['respostaCliente'] as String?)?.isNotEmpty == true
          ? data['respostaCliente'] as String
          : null,
      respostaEm: data['respostaEm'] is Timestamp
          ? (data['respostaEm'] as Timestamp).toDate()
          : null,
      autorId: data['autorId'] as String?,
      autorNome: data['autorNome'] as String? ?? data['user_name'] as String?,
    );
  }
}
