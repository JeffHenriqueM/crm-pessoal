// lib/models/usuario_model.dart

class Usuario {
  final String id;
  final String nome;
  final String email;
  final String perfil;
  final bool ativo;

  /// Meta mensal de fechamentos definida pelo próprio vendedor.
  final int? metaMensal;

  Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.perfil,
    this.ativo = true,
    this.metaMensal,
  });

  factory Usuario.fromMap(Map<String, dynamic> data, String documentId) {
    return Usuario(
      id: documentId,
      nome: data['nome'] ?? 'Nome não encontrado',
      email: data['email'] ?? 'Email não encontrado',
      perfil: data['perfil'] ?? 'vendedor',
      ativo: data['ativo'] ?? true,
      metaMensal: data['metaMensal'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'email': email,
      'perfil': perfil,
      'ativo': ativo,
      if (metaMensal != null) 'metaMensal': metaMensal,
    };
  }

  @override
  bool operator ==(Object other) => other is Usuario && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
