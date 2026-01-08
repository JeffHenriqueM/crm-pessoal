// lib/models/usuario_model.dart

class Usuario {
  final String id;
  final String nome;
  final String email;

  Usuario({
    required this.id,
    required this.nome,
    required this.email,
  });

  // Factory para criar um usuário a partir de um mapa (útil para o Firestore)
  factory Usuario.fromMap(Map<String, dynamic> data, String documentId) {
    return Usuario(
      id: documentId,
      nome: data['nome'] ?? 'Nome não encontrado',
      email: data['email'] ?? 'Email não encontrado',
    );
  }
}
