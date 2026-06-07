import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de mensagem de WhatsApp. Pode ser **padrão** (compartilhado por todos)
/// ou **individual** (criado por um usuário, visível só para ele).
///
/// O texto pode conter variáveis que são substituídas no momento do envio:
/// `{nome}`, `{primeiroNome}`, `{esposa}`, `{responsavel}`.
class ModeloMensagem {
  final String id;
  final String titulo;
  final String texto;

  /// true = modelo padrão (compartilhado por todos); false = individual.
  final bool padrao;

  final String? criadoPorId;
  final String? criadoPorNome;
  final DateTime? criadoEm;

  const ModeloMensagem({
    this.id = '',
    required this.titulo,
    required this.texto,
    this.padrao = false,
    this.criadoPorId,
    this.criadoPorNome,
    this.criadoEm,
  });

  ModeloMensagem copyWith({
    String? titulo,
    String? texto,
    bool? padrao,
  }) =>
      ModeloMensagem(
        id: id,
        titulo: titulo ?? this.titulo,
        texto: texto ?? this.texto,
        padrao: padrao ?? this.padrao,
        criadoPorId: criadoPorId,
        criadoPorNome: criadoPorNome,
        criadoEm: criadoEm,
      );

  Map<String, dynamic> toFirestore() => {
        'titulo': titulo,
        'texto': texto,
        'padrao': padrao,
        if (criadoPorId != null) 'criadoPorId': criadoPorId,
        if (criadoPorNome != null) 'criadoPorNome': criadoPorNome,
        'criadoEm': criadoEm == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(criadoEm!),
      };

  factory ModeloMensagem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ModeloMensagem(
      id: doc.id,
      titulo: d['titulo'] as String? ?? '',
      texto: d['texto'] as String? ?? '',
      padrao: d['padrao'] as bool? ?? false,
      criadoPorId: d['criadoPorId'] as String?,
      criadoPorNome: d['criadoPorNome'] as String?,
      criadoEm: (d['criadoEm'] as Timestamp?)?.toDate(),
    );
  }
}

/// Substitui as variáveis suportadas no [texto] do modelo. Variáveis sem valor
/// viram string vazia. Lógica pura para ser testável.
String aplicarVariaveisMensagem(
  String texto, {
  String? nome,
  String? esposa,
  String? responsavel,
}) {
  String primeiro(String? s) {
    final t = (s ?? '').trim();
    if (t.isEmpty) return '';
    return t.split(RegExp(r'\s+')).first;
  }

  return texto
      .replaceAll('{primeiroNome}', primeiro(nome))
      .replaceAll('{nome}', nome?.trim() ?? '')
      .replaceAll('{esposa}', esposa?.trim() ?? '')
      .replaceAll('{responsavel}', responsavel?.trim() ?? '');
}
