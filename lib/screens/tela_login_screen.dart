// lib/screens/tela_login_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class TelaLoginScreen extends StatefulWidget {
  const TelaLoginScreen({super.key});

  @override
  State<TelaLoginScreen> createState() => _TelaLoginScreenState();
}

class _TelaLoginScreenState extends State<TelaLoginScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Função _submit simplificada, apenas para login
  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final error = await _authService.signIn(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    // O setState é chamado mesmo se houver erro, para remover o loading
    // A verificação `mounted` previne erros se o widget for removido da árvore
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
        ),
      );
    }
    // Se o login for bem-sucedido, o Stream no 'main.dart' cuidará da navegação.
  }

  // ============ NOVA FUNÇÃO PARA O DIÁLOGO DE REDEFINIÇÃO ============
  void _mostrarDialogoRedefinirSenha() {
    final emailRedefinicaoController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Redefinir Senha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Digite seu e-mail para receber o link de redefinição.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailRedefinicaoController,
              decoration: const InputDecoration(labelText: 'E-mail'),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailRedefinicaoController.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Por favor, digite um e-mail válido.'), backgroundColor: Colors.orange),
                );
                return;
              }

              Navigator.of(ctx).pop(); // Fecha o diálogo
              setState(() => _isLoading = true);

              final erro = await _authService.enviarEmailRedefinicaoSenha(email);

              setState(() => _isLoading = false);

              if (erro == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link de redefinição enviado para o seu e-mail!'), backgroundColor: Colors.green),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(erro), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Acesso ao CRM', // Título fixo e mais profissional
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 24),
                    // Campo de Nome removido
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) => (value == null || !value.contains('@')) ? 'Email inválido.' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Senha'),
                      obscureText: true,
                      validator: (value) => (value == null || value.length < 6) ? 'A senha deve ter no mínimo 6 caracteres.' : null,
                    ),
                    const SizedBox(height: 24),
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Entrar'),
                      ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _isLoading ? null : _mostrarDialogoRedefinirSenha,
                      child: const Text('Esqueceu a senha?'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}