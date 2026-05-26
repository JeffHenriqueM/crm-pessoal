// lib/models/interacao_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// ── Tipo de interação ─────────────────────────────────────────────────────────
enum TipoInteracao { ligacao, whatsapp, visita, email, reuniao }

extension TipoInteracaoExt on TipoInteracao {
  String get nome {
    switch (this) {
      case TipoInteracao.ligacao:   return 'Ligação';
      case TipoInteracao.whatsapp:  return 'WhatsApp';
      case TipoInteracao.visita:    return 'Visita';
      case TipoInteracao.email:     return 'E-mail';
      case TipoInteracao.reuniao:   return 'Reunião';
    }
  }

  String get firestoreValue {
    switch (this) {
      case TipoInteracao.ligacao:   return 'ligacao';
      case TipoInteracao.whatsapp:  return 'whatsapp';
      case TipoInteracao.visita:    return 'visita';
      case TipoInteracao.email:     return 'email';
      case TipoInteracao.reuniao:   return 'reuniao';
    }
  }

  IconData get icone {
    switch (this) {
      case TipoInteracao.ligacao:   return Icons.phone_outlined;
      case TipoInteracao.whatsapp:  return FontAwesomeIcons.whatsapp;
      case TipoInteracao.visita:    return Icons.location_on_outlined;
      case TipoInteracao.email:     return Icons.email_outlined;
      case TipoInteracao.reuniao:   return Icons.groups_outlined;
    }
  }

  Color get cor {
    switch (this) {
      case TipoInteracao.ligacao:   return const Color(0xFF1565C0);
      case TipoInteracao.whatsapp:  return const Color(0xFF25D366);
      case TipoInteracao.visita:    return const Color(0xFF00695C);
      case TipoInteracao.email:     return const Color(0xFF6A1B9A);
      case TipoInteracao.reuniao:   return const Color(0xFFE65100);
    }
  }

  static TipoInteracao fromString(String? value) {
    switch (value) {
      case 'ligacao':   return TipoInteracao.ligacao;
      case 'whatsapp':  return TipoInteracao.whatsapp;
      case 'visita':    return TipoInteracao.visita;
      case 'email':     return TipoInteracao.email;
      case 'reuniao':   return TipoInteracao.reuniao;
      default:          return TipoInteracao.ligacao;
    }
  }
}

// ── Modelo ────────────────────────────────────────────────────────────────────
class Interacao {
  final String? id;
  final String titulo;
  final String nota;
  final DateTime dataInteracao;
  final TipoInteracao tipo;

  /// "O que combinamos?" — próximo passo combinado na interação.
  final String? proximoPasso;

  Interacao({
    this.id,
    required this.titulo,
    required this.nota,
    required this.dataInteracao,
    this.tipo = TipoInteracao.ligacao,
    this.proximoPasso,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'titulo': titulo,
      'nota': nota,
      'dataInteracao': Timestamp.fromDate(dataInteracao),
      'tipo': tipo.firestoreValue,
      'proximoPasso': proximoPasso,
    };
  }

  factory Interacao.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Interacao(
      id: doc.id,
      titulo: data['titulo'] ?? '',
      nota: data['nota'] ?? '',
      dataInteracao: (data['dataInteracao'] as Timestamp).toDate(),
      tipo: TipoInteracaoExt.fromString(data['tipo'] as String?),
      proximoPasso: data['proximoPasso'] as String?,
    );
  }
}
