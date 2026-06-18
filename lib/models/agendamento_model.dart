import 'package:cloud_firestore/cloud_firestore.dart';

/// Agendamento de atendimento FUTURO, lançado pela recepção/captação.
///
/// AINDA NÃO é lead — vive em coleção própria `agendamentos`, separado de
/// `clientes`, para não poluir os streams/contadores/funil filtrados por fase.
/// Quando o cliente comparece, vira um `Cliente` (fase atendimento) e este
/// agendamento é marcado como `compareceu` (com `clienteVinculadoId`).
class Agendamento {
  final String id;

  // Titular
  final String nome;
  final String? idade;
  final String? profissao;
  final String? telefone;

  // Cônjuge
  final String? nomeConjuge;
  final String? idadeConjuge;
  final String? profissaoConjuge;
  final String? telefoneConjuge;

  // Geral (mesmos campos do atendimento)
  final String? observacao;
  final String? sala;
  final String? origem; // ponto de captação
  final String? brinde;
  final String? captadorId;
  final String? captadorNome;
  final String? linerId;
  final String? linerNome;
  final String? vendedorId;
  final String? vendedorNome;

  // Específico do agendamento
  final DateTime dataHoraAgendamento;

  /// Ciclo de vida: `agendado` | `compareceu` | `faltou` | `cancelado`.
  final String status;

  /// Preenchido na conversão: id do `Cliente` criado quando o cliente comparece.
  final String? clienteVinculadoId;

  /// Remarcação (ticket #63): quantas vezes já foi remarcado, e o teto
  /// permitido (default 2). Ao atingir o teto, bloqueia; admin "libera"
  /// aumentando o teto em 1.
  final int remarcacoes;
  final int limiteRemarcacoes;

  /// Histórico de remarcações: cada item {de, para, motivo, em, porNome}.
  final List<Map<String, dynamic>> historicoRemarcacoes;

  // Auditoria
  final String? criadoPorId;
  final String? criadoPorNome;
  final DateTime? criadoEm;
  final DateTime? dataAtualizacao;
  final bool deletado;

  const Agendamento({
    this.id = '',
    required this.nome,
    this.idade,
    this.profissao,
    this.telefone,
    this.nomeConjuge,
    this.idadeConjuge,
    this.profissaoConjuge,
    this.telefoneConjuge,
    this.observacao,
    this.sala,
    this.origem,
    this.brinde,
    this.captadorId,
    this.captadorNome,
    this.linerId,
    this.linerNome,
    this.vendedorId,
    this.vendedorNome,
    required this.dataHoraAgendamento,
    this.status = 'agendado',
    this.clienteVinculadoId,
    this.remarcacoes = 0,
    this.limiteRemarcacoes = 2,
    this.historicoRemarcacoes = const [],
    this.criadoPorId,
    this.criadoPorNome,
    this.criadoEm,
    this.dataAtualizacao,
    this.deletado = false,
  });

  /// Atalho para uso na Agenda (mesma semântica de `dataHoraAgendamento`).
  DateTime get dataHora => dataHoraAgendamento;

  bool get isAgendado => status == 'agendado';

  /// Ainda pode remarcar (não atingiu o teto).
  bool get podeRemarcar => remarcacoes < limiteRemarcacoes;

  /// Remarcações restantes antes do bloqueio.
  int get remarcacoesRestantes {
    final r = limiteRemarcacoes - remarcacoes;
    return r < 0 ? 0 : r;
  }

  Map<String, dynamic> toFirestore() => {
        'nome': nome,
        'idade': idade,
        'profissao': profissao,
        'telefone': telefone,
        'nomeConjuge': nomeConjuge,
        'idadeConjuge': idadeConjuge,
        'profissaoConjuge': profissaoConjuge,
        'telefoneConjuge': telefoneConjuge,
        'observacao': observacao,
        'sala': sala,
        'origem': origem,
        'brinde': brinde,
        'captadorId': captadorId,
        'captadorNome': captadorNome,
        'linerId': linerId,
        'linerNome': linerNome,
        'vendedorId': vendedorId,
        'vendedorNome': vendedorNome,
        'dataHoraAgendamento': Timestamp.fromDate(dataHoraAgendamento),
        'status': status,
        if (clienteVinculadoId != null) 'clienteVinculadoId': clienteVinculadoId,
        'remarcacoes': remarcacoes,
        'limiteRemarcacoes': limiteRemarcacoes,
        if (historicoRemarcacoes.isNotEmpty)
          'historicoRemarcacoes': historicoRemarcacoes,
        if (deletado) 'deletado': true,
      };

  factory Agendamento.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Agendamento(
      id: doc.id,
      nome: d['nome'] as String? ?? 'Sem Nome',
      idade: d['idade'] as String?,
      profissao: d['profissao'] as String?,
      telefone: d['telefone'] as String?,
      nomeConjuge: d['nomeConjuge'] as String?,
      idadeConjuge: d['idadeConjuge'] as String?,
      profissaoConjuge: d['profissaoConjuge'] as String?,
      telefoneConjuge: d['telefoneConjuge'] as String?,
      observacao: d['observacao'] as String?,
      sala: d['sala'] as String?,
      origem: d['origem'] as String?,
      brinde: d['brinde'] as String?,
      captadorId: d['captadorId'] as String?,
      captadorNome: d['captadorNome'] as String?,
      linerId: d['linerId'] as String?,
      linerNome: d['linerNome'] as String?,
      vendedorId: d['vendedorId'] as String?,
      vendedorNome: d['vendedorNome'] as String?,
      dataHoraAgendamento:
          (d['dataHoraAgendamento'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: d['status'] as String? ?? 'agendado',
      clienteVinculadoId: d['clienteVinculadoId'] as String?,
      remarcacoes: (d['remarcacoes'] as num?)?.toInt() ?? 0,
      limiteRemarcacoes: (d['limiteRemarcacoes'] as num?)?.toInt() ?? 2,
      historicoRemarcacoes: (d['historicoRemarcacoes'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const [],
      criadoPorId: d['criadoPorId'] as String?,
      criadoPorNome: d['criadoPorNome'] as String?,
      criadoEm: (d['criadoEm'] as Timestamp?)?.toDate(),
      dataAtualizacao: (d['dataAtualizacao'] as Timestamp?)?.toDate(),
      deletado: d['deletado'] == true,
    );
  }
}
