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
      interacoesPorMes: (data['interacoesPorMes'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0)) ??
          const {},
    );
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
