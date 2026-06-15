import 'interacao_model.dart' show Canal;

/// Registro enxuto de uma interação de lead, usado nos relatórios do dashboard.
///
/// Vem de uma query *collection-group* sobre `clientes/{id}/interacoes` — por
/// isso carrega o `clienteId` (extraído do caminho do documento) para permitir
/// contar clientes distintos contatados num período.
class AtividadeInteracao {
  final String clienteId;
  final DateTime dataInteracao;
  final Canal canal;
  final bool houveResposta;
  final String? autorId;

  const AtividadeInteracao({
    required this.clienteId,
    required this.dataInteracao,
    required this.canal,
    required this.houveResposta,
    this.autorId,
  });
}
