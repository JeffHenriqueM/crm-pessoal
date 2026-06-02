// lib/models/usuario_model.dart

class Usuario {
  final String id;
  final String nome;
  final String email;
  final String perfil;
  final bool ativo;

  /// Meta mensal legada (fechamentos). Mantida para retrocompatibilidade.
  final int? metaMensal;

  /// Tipo da meta: 'fechamentos' | 'valorVendido' | 'novosLeads'
  final String? tipoMeta;

  /// Valor alvo da meta (substitui metaMensal para dados novos).
  final double? valorMeta;

  /// Metas mensais, no formato {tipoMeta: valorAlvo} — permite várias metas
  /// simultâneas por usuário (ex.: valorVendido + mensagensEnviadas).
  final Map<String, double> metas;

  /// Contador de interações por mês, no formato {'AAAA-M': quantidade}.
  /// Usado para o progresso da meta "mensagens enviadas".
  final Map<String, int> interacoesPorMes;

  Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.perfil,
    this.ativo = true,
    this.metaMensal,
    this.tipoMeta,
    this.valorMeta,
    this.metas = const {},
    this.interacoesPorMes = const {},
  });

  factory Usuario.fromMap(Map<String, dynamic> data, String documentId) {
    return Usuario(
      id: documentId,
      nome: data['nome'] ?? 'Nome não encontrado',
      email: data['email'] ?? 'Email não encontrado',
      perfil: data['perfil'] ?? 'vendedor',
      ativo: data['ativo'] ?? true,
      metaMensal: data['metaMensal'] as int?,
      tipoMeta: data['tipoMeta'] as String?,
      valorMeta: (data['valorMeta'] as num?)?.toDouble(),
      metas: _lerMetas(data),
      interacoesPorMes: (data['interacoesPorMes'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0)) ??
          const {},
    );
  }

  /// Lê o mapa de metas com retrocompatibilidade: usa `metas` quando existir;
  /// senão converte a meta única antiga (tipoMeta/valorMeta) ou a legada
  /// (metaMensal → fechamentos) em um mapa de uma entrada.
  static Map<String, double> _lerMetas(Map<String, dynamic> data) {
    final raw = data['metas'];
    if (raw is Map && raw.isNotEmpty) {
      return raw.map((k, v) => MapEntry(k as String, (v as num).toDouble()));
    }
    final tipo = data['tipoMeta'] as String?;
    final valor = (data['valorMeta'] as num?)?.toDouble();
    if (tipo != null && valor != null) return {tipo: valor};
    final legado = (data['metaMensal'] as num?)?.toDouble();
    if (legado != null) return {'fechamentos': legado};
    return {};
  }

  /// Quantidade de interações registradas pelo usuário no mês corrente.
  int get interacoesMesAtual {
    final agora = DateTime.now();
    return interacoesPorMes['${agora.year}-${agora.month}'] ?? 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'email': email,
      'perfil': perfil,
      'ativo': ativo,
      if (metas.isNotEmpty) 'metas': metas,
      if (metaMensal != null) 'metaMensal': metaMensal,
      if (tipoMeta != null) 'tipoMeta': tipoMeta,
      if (valorMeta != null) 'valorMeta': valorMeta,
    };
  }

  @override
  bool operator ==(Object other) => other is Usuario && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
