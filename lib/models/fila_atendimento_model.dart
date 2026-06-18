import 'package:cloud_firestore/cloud_firestore.dart';

/// Posição de um vendedor na Linha de atendimento da sala de vendas
/// (ticket "Linha de atendimento"). Vive na coleção `fila_atendimento`, um
/// doc por vendedor (id = vendedorId).
///
/// Ordenação HÍBRIDA: a ordem natural é por `posicaoEm` ascendente (quem ficou
/// disponível há mais tempo vai na frente); a recepção pode reordenar
/// manualmente trocando o `posicaoEm` entre vizinhos. Marcar disponível,
/// "atendeu" (automático no cadastro) e "atrasado" (botão) re-timestampam
/// `posicaoEm` para AGORA, jogando o vendedor para o fim da fila.
class FilaAtendimento {
  /// Id do doc = vendedorId.
  final String vendedorId;
  final String vendedorNome;

  /// Se está na fila de atendimento agora.
  final bool disponivel;

  /// Base da ordenação (ascendente). Atualizado a cada entrada/rodízio.
  final DateTime? posicaoEm;

  final DateTime? atualizadoEm;

  const FilaAtendimento({
    required this.vendedorId,
    required this.vendedorNome,
    this.disponivel = false,
    this.posicaoEm,
    this.atualizadoEm,
  });

  Map<String, dynamic> toFirestore() => {
        'vendedorNome': vendedorNome,
        'disponivel': disponivel,
        'posicaoEm': posicaoEm != null ? Timestamp.fromDate(posicaoEm!) : null,
      };

  factory FilaAtendimento.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FilaAtendimento(
      vendedorId: doc.id,
      vendedorNome: d['vendedorNome'] as String? ?? '',
      disponivel: d['disponivel'] == true,
      posicaoEm: (d['posicaoEm'] as Timestamp?)?.toDate(),
      atualizadoEm: (d['atualizadoEm'] as Timestamp?)?.toDate(),
    );
  }
}
