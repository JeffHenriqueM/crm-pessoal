// lib/services/auth_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fornece um Stream para ouvir as mudanças de estado de autenticação.
  /// (usuário logou, deslogou, etc.)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(      email: email,
        password: password,
      );
      // Em caso de sucesso, não retorna nada (ou null),
      // indicando que não houve erro.
      return null;
    } on FirebaseAuthException catch (e) {
      // Em caso de erro, retorna uma mensagem amigável.
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return 'E-mail ou senha inválidos.';
      }
      return 'Ocorreu um erro no login. Tente novamente.';
    } catch (e) {
      return 'Um erro inesperado ocorreu.';
    }
  }

  Future<String?> enviarEmailRedefinicaoSenha(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      // Retorna null em caso de sucesso
      return null;
    } on FirebaseAuthException catch (e) {
      // Retorna uma mensagem de erro amigável
      if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        return 'Nenhum usuário encontrado para este e-mail.';
      }
      return 'Ocorreu um erro. Tente novamente.';
    } catch (e) {
      return 'Ocorreu um erro inesperado.';
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // --- NOVOS MÉTODOS (AQUI ESTÁ A CORREÇÃO) ---

  /// **Busca o perfil do usuário logado.**
  /// Usado para mostrar/esconder botões de admin.
  Future<String> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return 'vendedor'; // Retorna perfil restrito se não houver usuário

    try {
      final doc = await _db.collection('usuarios').doc(user.uid).get();
      return doc.exists ? (doc.data()?['perfil'] ?? 'vendedor') : 'vendedor';
    } catch (e) {
      // Em caso de erro, assume o perfil mais restrito por segurança.
      return 'vendedor';
    }
  }

  /// **Cria um novo usuário no Firebase Auth e salva seus dados no Firestore.**
  /// Este método é chamado pela tela de gerenciamento de usuários do admin.
  Future<void> criarNovoUsuario({
    required String email,
    required String senha,
    required String nome,
    required String perfil,
  }) async {
    try {
      // 1. Cria o usuário no Firebase Authentication
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: senha,
      );

      final User? novoUsuario = userCredential.user;

      if (novoUsuario != null) {
        // 2. Atualiza o nome de exibição no perfil do Firebase Auth (opcional, mas bom)
        await novoUsuario.updateDisplayName(nome);

        // 3. Salva os dados adicionais (incluindo o perfil) no Firestore
        await _db.collection('usuarios').doc(novoUsuario.uid).set({
          'nome': nome,
          'email': email,
          'perfil': perfil,
        });
      } else {
        throw Exception('Não foi possível obter o novo usuário após a criação.');
      }
    } on FirebaseAuthException catch (e) {
      // Retorna uma mensagem de erro mais amigável para a UI
      if (e.code == 'email-already-in-use') {
        throw 'Este e-mail já está em uso por outra conta.';
      } else if (e.code == 'weak-password') {
        throw 'A senha fornecida é muito fraca.';
      }
      throw 'Ocorreu um erro de autenticação. Verifique os dados. (${e.code})';
    } catch (e) {
      throw 'Ocorreu um erro inesperado ao criar o usuário.';
    }
  }
}
