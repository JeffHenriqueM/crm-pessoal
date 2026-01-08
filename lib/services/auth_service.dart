// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream para verificar o estado da autenticação (logado ou deslogado)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Método de Login
  Future<String?> signInWithEmailAndPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // Sucesso
    } on FirebaseAuthException catch (e) {
      return e.message; // Retorna a mensagem de erro
    }
  }

  // Método de Registro (Criar conta)
  Future<String?> signUpWithEmailAndPassword(String email, String password, String nome) async {
    try {
      // 1. Cria o usuário no Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = userCredential.user;

      if (user != null) {
        // 2. Atualiza o nome do usuário no perfil do Firebase Auth
        await user.updateDisplayName(nome);

        // 3. Salva os dados do usuário na coleção 'usuarios' para a seleção de vendedores
        await _db.collection('usuarios').doc(user.uid).set({
          'nome': nome,
          'email': email,
          'uid': user.uid,
        });
      }
      return null; // Sucesso
    } on FirebaseAuthException catch (e) {
      return e.message; // Retorna a mensagem de erro
    }
  }

  // Método de Logout
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
