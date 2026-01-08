// lib/screens/gerenciar_usuarios_screen.dart

import 'package:flutter/material.dart';
import '../models/usuario_model.dart';
import '../services/firestore_service.dart';
// O AuthService é necessário para criar o usuário na autenticação do Firebase
import '../services/auth_service.dart';

class GerenciarUsuariosScreen extends StatefulWidget {
  const GerenciarUsuariosScreen({super.key});

  @override
  State<GerenciarUsuariosScreen> createState() => _GerenciarUsuariosScreenState();
}

class _GerenciarUsuariosScreenState extends State<GerenciarUsuariosScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  // Precisamos do AuthService para criar o login do novo usuário
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Usuários'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Usuario>>(
        future: _firestoreService.getTodosUsuarios(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum usuário encontrado ou erro ao buscar.'));
          }
          final usuarios = snapshot.data!;
          return ListView.builder(
            itemCount: usuarios.length,
            itemBuilder: (context, index) {
              final usuario = usuarios[index];
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(usuario.nome),
                subtitle: Text(usuario.email),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
                      label: Text(
                        usuario.perfil,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Colors.blueGrey,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Editar Usuário',
                      onPressed: () => _mostrarDialogoEditarUsuario(context, usuario),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      // ============ PASSO 1: ADICIONAR O FAB DE VOLTA ============
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarDialogoCriarUsuario(context),
        tooltip: 'Adicionar Novo Usuário',
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      // ========================================================
    );
  }

  // ============ PASSO 2: REINSERIR O DIÁLOGO DE CRIAÇÃO ============
  void _mostrarDialogoCriarUsuario(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nomeController = TextEditingController();
    final emailController = TextEditingController();
    final senhaController = TextEditingController();
    String perfilSelecionado = 'vendedor';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Criar Novo Usuário'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nomeController,
                    decoration: const InputDecoration(labelText: 'Nome Completo'),
                    validator: (v) => v!.trim().isEmpty ? 'Nome é obrigatório' : null,
                  ),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'E-mail (para login)'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v!.trim().isEmpty || !v.contains('@') ? 'E-mail inválido' : null,
                  ),
                  TextFormField(
                    controller: senhaController,
                    decoration: const InputDecoration(labelText: 'Senha (mínimo 6 caracteres)'),
                    obscureText: true,
                    validator: (v) => v!.trim().length < 6 ? 'Senha muito curta' : null,
                  ),
                  DropdownButtonFormField<String>(
                    value: perfilSelecionado,
                    decoration: const InputDecoration(labelText: 'Perfil'),
                    items: ['admin', 'pós-venda', 'financeiro', 'vendedor']
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) perfilSelecionado = value;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(); // Fecha o dialogo
                  showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()));

                  try {
                    // Chama o método no AuthService para criar o usuário na autenticação
                    await _authService.criarNovoUsuario(
                      email: emailController.text.trim(),
                      senha: senhaController.text.trim(),
                      nome: nomeController.text.trim(),
                      perfil: perfilSelecionado,
                    );

                    Navigator.of(context).pop(); // Fecha o loading
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário criado com sucesso!'), backgroundColor: Colors.green));
                    setState(() {}); // Atualiza a lista na tela
                  } catch (e) {
                    Navigator.of(context).pop(); // Fecha o loading
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao criar usuário: ${e.toString()}'), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text('Criar'),
            ),
          ],
        );
      },
    );
  }
  // =================================================================

  // DIÁLOGO DE EDIÇÃO (seu código existente, sem alterações)
  void _mostrarDialogoEditarUsuario(BuildContext context, Usuario usuario) {
    final formKey = GlobalKey<FormState>();
    final nomeController = TextEditingController(text: usuario.nome);
    final emailController = TextEditingController(text: usuario.email);
    String perfilSelecionado = usuario.perfil;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Editar Usuário'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nomeController,
                    decoration: const InputDecoration(labelText: 'Nome Completo'),
                    validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                  ),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'E-mail (não editável)'),
                    readOnly: true,
                  ),
                  DropdownButtonFormField<String>(
                    value: perfilSelecionado,
                    decoration: const InputDecoration(labelText: 'Perfil'),
                    items: ['admin', 'pós-venda', 'financeiro', 'vendedor']
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) perfilSelecionado = value;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop();
                  showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()));

                  try {
                    await _firestoreService.atualizarUsuario(
                      id: usuario.id,
                      nome: nomeController.text,
                      perfil: perfilSelecionado,
                    );
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário atualizado com sucesso!'), backgroundColor: Colors.green));
                    setState(() {});
                  } catch (e) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao atualizar usuário: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }
}
