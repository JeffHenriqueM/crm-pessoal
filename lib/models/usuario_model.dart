// lib/models/usuario_model.dart

class Usuario {
  final String id;
  final String nome;
  final String email;
  final String perfil; // <--- 1. NOVO CAMPO 'PERFIL'

  Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.perfil, // <--- 2. ADICIONAR AO CONSTRUTOR
  });

  factory Usuario.fromMap(Map<String, dynamic> data, String documentId) {
    return Usuario(
      id: documentId,
      nome: data['nome'] ?? 'Nome não encontrado',
      email: data['email'] ?? 'Email não encontrado',
      perfil: data['perfil'] ?? 'vendedor', // <--- 3. LEITURA DO BANCO
      // Se o perfil não existir, assume 'vendedor' como padrão.
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'email': email,
      'perfil': perfil, // <--- 4. ADICIONAR AO MAPA PARA SALVAR NO BANCO
    };
  }
}
