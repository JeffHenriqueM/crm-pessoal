import 'package:cloud_firestore/cloud_firestore.dart';

import 'interacao_model.dart' show Canal, CanalExt;

/// Uma tentativa de contato feita pelo embaixador (WhatsApp ou Ligação).
/// `houveResposta` fica nulo até ser preenchido (em geral no dia seguinte).
class Tentativa {
  final DateTime data;
  final Canal canal; // apenas whatsapp/ligacao são usados
  final bool? houveResposta;
  final String? registradoPorId;
  final String? registradoPorNome;

  const Tentativa({
    required this.data,
    required this.canal,
    this.houveResposta,
    this.registradoPorId,
    this.registradoPorNome,
  });

  /// Canais oferecidos ao embaixador.
  static const List<Canal> canaisDisponiveis = [Canal.whatsapp, Canal.ligacao];

  Tentativa copyWith({bool? houveResposta}) => Tentativa(
        data: data,
        canal: canal,
        houveResposta: houveResposta ?? this.houveResposta,
        registradoPorId: registradoPorId,
        registradoPorNome: registradoPorNome,
      );

  Map<String, dynamic> toMap() => {
        'data': Timestamp.fromDate(data),
        'canal': canal.valor,
        'houveResposta': houveResposta,
        if (registradoPorId != null) 'registradoPorId': registradoPorId,
        if (registradoPorNome != null) 'registradoPorNome': registradoPorNome,
      };

  factory Tentativa.fromMap(Map<String, dynamic> m) => Tentativa(
        data: (m['data'] as Timestamp?)?.toDate() ?? DateTime(1970),
        canal: CanalExt.fromString(m['canal'] as String?),
        houveResposta: m['houveResposta'] as bool?,
        registradoPorId: m['registradoPorId'] as String?,
        registradoPorNome: m['registradoPorNome'] as String?,
      );

  /// True se a resposta ainda não foi preenchida e a tentativa é de um dia
  /// anterior a [hoje] (regra: preencher no dia seguinte ao contato).
  bool respostaPendente(DateTime hoje) {
    if (houveResposta != null) return false;
    final d = DateTime(data.year, data.month, data.day);
    final h = DateTime(hoje.year, hoje.month, hoje.day);
    return d.isBefore(h);
  }
}

/// Contato a ser trabalhado pelo embaixador na Recepção.
class ContatoEmbaixador {
  final String id;
  final String nome;
  final String? nomeEsposa;
  final String telefone;
  final String? observacao;

  /// Embaixador/pessoa responsável por fazer o próximo contato. Vem da coluna
  /// "embaixador" da planilha de importação. Apenas informativo (rótulo no card).
  final String? responsavel;

  final List<Tentativa> tentativas;
  final DateTime? criadoEm;
  final String? criadoPorId;
  final String? criadoPorNome;

  const ContatoEmbaixador({
    this.id = '',
    required this.nome,
    this.nomeEsposa,
    required this.telefone,
    this.observacao,
    this.responsavel,
    this.tentativas = const [],
    this.criadoEm,
    this.criadoPorId,
    this.criadoPorNome,
  });

  int get totalTentativas => tentativas.length;

  Tentativa? get ultimaTentativa {
    if (tentativas.isEmpty) return null;
    return tentativas
        .reduce((a, b) => b.data.isAfter(a.data) ? b : a);
  }

  /// Tentativas cuja resposta ainda precisa ser preenchida (dia seguinte).
  List<Tentativa> respostasPendentes(DateTime hoje) =>
      tentativas.where((t) => t.respostaPendente(hoje)).toList();

  bool temRespostaPendente(DateTime hoje) =>
      tentativas.any((t) => t.respostaPendente(hoje));

  ContatoEmbaixador copyWith({
    String? id,
    String? nome,
    String? nomeEsposa,
    String? telefone,
    String? observacao,
    String? responsavel,
    List<Tentativa>? tentativas,
  }) =>
      ContatoEmbaixador(
        id: id ?? this.id,
        nome: nome ?? this.nome,
        nomeEsposa: nomeEsposa ?? this.nomeEsposa,
        telefone: telefone ?? this.telefone,
        observacao: observacao ?? this.observacao,
        responsavel: responsavel ?? this.responsavel,
        tentativas: tentativas ?? this.tentativas,
        criadoEm: criadoEm,
        criadoPorId: criadoPorId,
        criadoPorNome: criadoPorNome,
      );

  Map<String, dynamic> toFirestore() => {
        'nome': nome,
        'nomeEsposa': nomeEsposa,
        'telefone': telefone,
        'observacao': observacao,
        'responsavel': responsavel,
        'tentativas': tentativas.map((t) => t.toMap()).toList(),
        if (criadoPorId != null) 'criadoPorId': criadoPorId,
        if (criadoPorNome != null) 'criadoPorNome': criadoPorNome,
        'criadoEm': criadoEm == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(criadoEm!),
      };

  factory ContatoEmbaixador.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ContatoEmbaixador(
      id: doc.id,
      nome: d['nome'] as String? ?? '',
      nomeEsposa: d['nomeEsposa'] as String?,
      telefone: d['telefone'] as String? ?? '',
      observacao: d['observacao'] as String?,
      responsavel: d['responsavel'] as String?,
      tentativas: ((d['tentativas'] as List<dynamic>?) ?? [])
          .map((e) => Tentativa.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      criadoEm: (d['criadoEm'] as Timestamp?)?.toDate(),
      criadoPorId: d['criadoPorId'] as String?,
      criadoPorNome: d['criadoPorNome'] as String?,
    );
  }
}
