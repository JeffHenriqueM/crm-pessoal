import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de mensagem de WhatsApp. Pode ser **padrão** (compartilhado por todos)
/// ou **individual** (criado por um usuário, visível só para ele).
///
/// O texto pode conter variáveis que são substituídas no momento do envio:
/// `{nome}`, `{primeiroNome}`, `{esposa}`, `{primeiroNomeEsposa}`, `{responsavel}`.
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

/// Conectivos de nomes próprios que ficam em minúsculo (exceto se 1ª palavra).
const _conectivosNome = {'da', 'de', 'do', 'das', 'dos', 'e', 'di', 'du'};

/// Normaliza um nome para Title Case: 1ª letra de cada palavra em maiúscula e o
/// restante em minúscula (os dados dos contratos vêm em CAIXA ALTA). Conectivos
/// (`da`, `de`, `do`, …) ficam minúsculos, salvo na 1ª palavra.
String capitalizarNome(String? s) {
  final t = (s ?? '').trim();
  if (t.isEmpty) return '';
  final palavras = t.toLowerCase().split(RegExp(r'\s+'));
  return [
    for (var i = 0; i < palavras.length; i++)
      if (palavras[i].isEmpty)
        palavras[i]
      else if (i != 0 && _conectivosNome.contains(palavras[i]))
        palavras[i]
      else
        palavras[i][0].toUpperCase() + palavras[i].substring(1),
  ].join(' ');
}

/// Substitui as variáveis suportadas no [texto] do modelo. Variáveis sem valor
/// viram string vazia. Nomes são normalizados para Title Case. Lógica pura para
/// ser testável.
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
      .replaceAll('{primeiroNomeEsposa}', capitalizarNome(primeiro(esposa)))
      .replaceAll('{primeiroNome}', capitalizarNome(primeiro(nome)))
      .replaceAll('{nome}', capitalizarNome(nome))
      .replaceAll('{esposa}', capitalizarNome(esposa))
      .replaceAll('{responsavel}', capitalizarNome(responsavel));
}
