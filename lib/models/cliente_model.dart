// lib/models/cliente_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'fase_enum.dart';

class Cliente {
  final String? id;
  final String nome;
  final String tipo;
  final FaseCliente fase;
  final String? nomeEsposa;
  final String? origem;
  final String? telefoneContato;
  final String? telefone2;
  final DateTime dataCadastro;
  final DateTime dataAtualizacao;
  final DateTime? proximoContato;
  final DateTime? dataVisita;
  final String? captadorId;
  final String? captadorNome;
  final DateTime? dataEntradaSala;
  final String? motivoNaoVenda;
  final String? motivoNaoVendaDropdown;
  final String? vendedorId;
  final String? vendedorNome;
  final String? criadoPorId;
  final String? criadoPorNome;
  final String? atualizadoPorId;
  final String? atualizadoPorNome;
  // ── Campos de recepção ────────────────────────────────────────────────────
  final String? brinde;
  final String? sala;
  final int? numeroAtendimento;
  final String? idade;
  final String? profissao;
  final String? idadeConjuge;
  final String? profissaoConjuge;
  // Liner (apresenta) — quando há dois vendedores; vendedorId/Nome = closer (fecha)
  final String? linerId;
  final String? linerNome;

  // ── Rastreamento de mensagens (#16) ───────────────────────────────────────
  // Valores: null | 'nao_enviada' | 'enviada_sem_resposta' | 'enviada_com_resposta'
  final String? statusMensagem;

  // ── Fechamento ────────────────────────────────────────────────────────────
  final DateTime? dataFechamento;
  final double? valorVendido;

  // ── Soft-delete (#19) ─────────────────────────────────────────────────────
  final bool deletado;
  final String? excluidoPorId;
  final String? excluidoPorNome;
  final DateTime? dataExclusao;

  Cliente({
    this.id,
    required this.nome,
    required this.tipo,
    required this.fase,
    required this.dataCadastro,
    required this.dataAtualizacao,
    this.nomeEsposa,
    this.telefoneContato,
    this.telefone2,
    this.proximoContato,
    this.dataVisita,
    this.origem,
    this.motivoNaoVenda,
    this.motivoNaoVendaDropdown,
    this.vendedorId,
    this.vendedorNome,
    this.captadorId,
    this.captadorNome,
    this.dataEntradaSala,
    this.criadoPorId,
    this.criadoPorNome,
    this.atualizadoPorId,
    this.atualizadoPorNome,
    this.brinde,
    this.sala,
    this.numeroAtendimento,
    this.idade,
    this.profissao,
    this.idadeConjuge,
    this.profissaoConjuge,
    this.linerId,
    this.linerNome,
    this.statusMensagem,
    this.dataFechamento,
    this.valorVendido,
    this.deletado = false,
    this.excluidoPorId,
    this.excluidoPorNome,
    this.dataExclusao,
  });

  // Converte o objeto Cliente para um Mapa para o Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'nome': nome,
      'tipo': tipo,
      'fase': fase.toString().split('.').last,
      'nomeEsposa': nomeEsposa,
      'origem' : origem,
      'telefoneContato': telefoneContato,
      'telefone2': telefone2,
      'dataCadastro': Timestamp.fromDate(dataCadastro),
      'dataAtualizacao': Timestamp.fromDate(dataAtualizacao),
      'proximoContato': proximoContato != null ? Timestamp.fromDate(proximoContato!) : null,
      'dataVisita': dataVisita != null ? Timestamp.fromDate(dataVisita!) : null,
      'motivoNaoVenda': motivoNaoVenda,
      'motivoNaoVendaDropdown': motivoNaoVendaDropdown,
      'vendedorId': vendedorId,
      'vendedorNome': vendedorNome,
      'captadorNome': captadorNome,
      'captadorId': captadorId,
      'dataEntradaSala': dataEntradaSala != null ? Timestamp.fromDate(dataEntradaSala!): null,
      'criadoPorId': criadoPorId,
      'criadoPorNome': criadoPorNome,
      'atualizadoPorId': atualizadoPorId,
      'atualizadoPorNome': atualizadoPorNome,
      'brinde': brinde,
      'sala': sala,
      'numeroAtendimento': numeroAtendimento,
      'idade': idade,
      'profissao': profissao,
      'idadeConjuge': idadeConjuge,
      'profissaoConjuge': profissaoConjuge,
      'linerId': linerId,
      'linerNome': linerNome,
      'statusMensagem': statusMensagem,
      'dataFechamento': dataFechamento != null ? Timestamp.fromDate(dataFechamento!) : null,
      'valorVendido': valorVendido,
      // soft-delete: só serializa se true para não poluir docs normais
      if (deletado) 'deletado': true,
      if (excluidoPorId != null) 'excluidoPorId': excluidoPorId,
      if (excluidoPorNome != null) 'excluidoPorNome': excluidoPorNome,
      if (dataExclusao != null)
        'dataExclusao': Timestamp.fromDate(dataExclusao!),
    };
  }

  // Cria um objeto Cliente a partir de um Documento do Firestore
  factory Cliente.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final stringFase = data['fase'] as String?;
    FaseCliente faseRecuperada = FaseCliente.prospeccao;

    if (stringFase != null) {
      try {
        faseRecuperada = FaseCliente.values.firstWhere(
              (e) => e.toString().split('.').last == stringFase,
          orElse: () => FaseCliente.prospeccao,
        );
      } catch (_) {
        faseRecuperada = FaseCliente.prospeccao;
      }
    }

    return Cliente(
      id: doc.id,
      nome: data['nome'] ?? 'Sem Nome',
      tipo: data['tipo'] ?? 'Não Definido',
      fase: faseRecuperada,
      origem: data['origem'] ?? 'Antigo',
      dataCadastro: (data['dataCadastro'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dataAtualizacao: (data['dataAtualizacao'] as Timestamp?)?.toDate() ?? DateTime.now(),
      nomeEsposa: data['nomeEsposa'],
      telefoneContato: data['telefoneContato'],
      telefone2: data['telefone2'],
      proximoContato: (data['proximoContato'] as Timestamp?)?.toDate(),
      dataVisita: (data['dataVisita'] as Timestamp?)?.toDate(),
      motivoNaoVenda: data['motivoNaoVenda'],
      motivoNaoVendaDropdown: data['motivoNaoVendaDropdown'],
      vendedorId: data['vendedorId'],
      vendedorNome: data['vendedorNome'],
      captadorId: data['captadorId'],
      captadorNome: data['captadorNome'],
      dataEntradaSala: (data['dataEntradaSala'] as Timestamp?)?.toDate(),
      criadoPorId: data['criadoPorId'],
      criadoPorNome: data['criadoPorNome'],
      atualizadoPorId: data['atualizadoPorId'],
      atualizadoPorNome: data['atualizadoPorNome'],
      brinde: data['brinde'],
      sala: data['sala'],
      numeroAtendimento: data['numeroAtendimento'] as int?,
      idade: data['idade'],
      profissao: data['profissao'],
      idadeConjuge: data['idadeConjuge'],
      profissaoConjuge: data['profissaoConjuge'],
      linerId: data['linerId'],
      linerNome: data['linerNome'],
      statusMensagem: data['statusMensagem'] as String?,
      dataFechamento: (data['dataFechamento'] as Timestamp?)?.toDate(),
      valorVendido: (data['valorVendido'] as num?)?.toDouble(),
      deletado: data['deletado'] == true,
      excluidoPorId: data['excluidoPorId'] as String?,
      excluidoPorNome: data['excluidoPorNome'] as String?,
      dataExclusao: (data['dataExclusao'] as Timestamp?)?.toDate(),
    );
  }
}