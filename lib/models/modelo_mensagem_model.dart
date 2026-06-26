import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de mensagem para WhatsApp **ou** e-mail. Pode ser **padrão**
/// (compartilhado por todos) ou **individual** (criado por um usuário, visível
/// só para ele).
///
/// O texto (e o [assunto], no e-mail) pode conter variáveis substituídas no
/// momento do envio: `{nome}`, `{primeiroNome}`, `{esposa}`,
/// `{primeiroNomeEsposa}`, `{responsavel}`.
class ModeloMensagem {
  final String id;
  final String titulo;
  final String texto;

  /// Canal do modelo: `'whatsapp'` (padrão) ou `'email'`. Docs antigos sem o
  /// campo são tratados como WhatsApp (retrocompatibilidade).
  final String canal;

  /// Assunto do e-mail. Usado apenas quando [canal] == `'email'`.
  final String? assunto;

  /// true = modelo padrão (compartilhado por todos); false = individual.
  final bool padrao;

  final String? criadoPorId;
  final String? criadoPorNome;
  final DateTime? criadoEm;

  const ModeloMensagem({
    this.id = '',
    required this.titulo,
    required this.texto,
    this.canal = 'whatsapp',
    this.assunto,
    this.padrao = false,
    this.criadoPorId,
    this.criadoPorNome,
    this.criadoEm,
  });

  /// True quando o modelo é de e-mail.
  bool get isEmail => canal == 'email';

  ModeloMensagem copyWith({
    String? titulo,
    String? texto,
    String? canal,
    String? assunto,
    bool? padrao,
  }) =>
      ModeloMensagem(
        id: id,
        titulo: titulo ?? this.titulo,
        texto: texto ?? this.texto,
        canal: canal ?? this.canal,
        assunto: assunto ?? this.assunto,
        padrao: padrao ?? this.padrao,
        criadoPorId: criadoPorId,
        criadoPorNome: criadoPorNome,
        criadoEm: criadoEm,
      );

  Map<String, dynamic> toFirestore() => {
        'titulo': titulo,
        'texto': texto,
        'canal': canal,
        if (assunto != null) 'assunto': assunto,
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
      canal: d['canal'] as String? ?? 'whatsapp',
      assunto: d['assunto'] as String?,
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
///
/// Variáveis de nome: `{nome}`, `{primeiroNome}`, `{esposa}`,
/// `{primeiroNomeEsposa}`, `{responsavel}`.
/// Variáveis de contrato (preenchidas só onde há contrato, ex.: aba Distratar):
/// `{contrato}`, `{cota}`, `{valorAtrasado}`, `{saldo}`, `{dataLimite}`. Estas
/// chegam já formatadas pelo chamador (moeda/data) e não são capitalizadas.
String aplicarVariaveisMensagem(
  String texto, {
  String? nome,
  String? esposa,
  String? responsavel,
  String? contrato,
  String? cota,
  String? valorAtrasado,
  String? saldo,
  String? dataLimite,
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
      .replaceAll('{responsavel}', capitalizarNome(responsavel))
      .replaceAll('{contrato}', contrato ?? '')
      .replaceAll('{cota}', cota ?? '')
      .replaceAll('{valorAtrasado}', valorAtrasado ?? '')
      .replaceAll('{saldo}', saldo ?? '')
      .replaceAll('{dataLimite}', dataLimite ?? '');
}
