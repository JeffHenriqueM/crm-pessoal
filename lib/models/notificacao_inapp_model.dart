import 'package:cloud_firestore/cloud_firestore.dart';

class NotificacaoInApp {
  final String id;
  final String tipo;
  final String titulo;
  final String corpo;
  final bool lida;
  final DateTime? criadoEm;
  final String? ticketId;
  final int ticketNumero;
  final String ticketTitulo;
  final String? clienteId;

  const NotificacaoInApp({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.corpo,
    required this.lida,
    this.criadoEm,
    this.ticketId,
    this.ticketNumero = 0,
    this.ticketTitulo = '',
    this.clienteId,
  });

  factory NotificacaoInApp.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return NotificacaoInApp(
      id:            doc.id,
      tipo:          d['tipo']         as String? ?? '',
      titulo:        d['titulo']       as String? ?? '',
      corpo:         d['corpo']        as String? ?? '',
      lida:          d['lida']         == true,
      criadoEm:      (d['criadoEm']   as Timestamp?)?.toDate(),
      ticketId:      d['ticketId']     as String?,
      ticketNumero:  d['ticketNumero'] as int? ?? 0,
      ticketTitulo:  d['ticketTitulo'] as String? ?? '',
      clienteId:     d['clienteId']    as String?,
    );
  }
}
