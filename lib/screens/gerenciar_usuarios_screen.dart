// lib/screens/gerenciar_usuarios_screen.dart

import 'package:flutter/material.dart';
import '../models/usuario_model.dart';
// AuthService não é mais necessário aqui, pois a edição é feita pelo FirestoreService
import '../services/firestore_service.dart';

class GerenciarUsuariosScreen extends StatefulWidget {
  const GerenciarUsuariosScreen({super.key});

  @override
  State<GerenciarUsuariosScreen> createState() => _GerenciarUsuariosScreenState();
}

class _GerenciarUsuariosScreenState extends State<GerenciarUsuariosScreen> {
  final FirestoreService _firestoreService = FirestoreService();

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
                trailing: Row( // Usamos um Row para o Chip e o botão de editar
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
                    // ============ BOTÃO DE EDITAR ============
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Editar Usuário',
                      onPressed: () => _mostrarDialogoEditarUsuario(context, usuario),
                    ),
                    // =========================================
                  ],
                ),
              );
            },
          );
        },
      ),
      // O FloatingActionButton para criar usuários continua aqui
      // (Seu código do FAB e do diálogo de criação)
      // ...
    );
  }

  // DIÁLOGO DE CRIAÇÃO (SEU CÓDIGO EXISTENTE)
  // void _mostrarDialogoCriarUsuario(BuildContext context) { ... }

  // ============ NOVO DIÁLOGO PARA EDITAR USUÁRIO ============
  void _mostrarDialogoEditarUsuario(BuildContext context, Usuario usuario) {
    final formKey = GlobalKey<FormState>();
    final nomeController = TextEditingController(text: usuario.nome);
    // O e-mail não deve ser editável, pois é a chave de login no Firebase Auth
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
                    readOnly: true, // Torna o campo apenas para leitura
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
                    // Chama o novo método no FirestoreService
                    await _firestoreService.atualizarUsuario(
                      id: usuario.id,
                      nome: nomeController.text,
                      perfil: perfilSelecionado,
                    );
                    Navigator.of(context).pop(); // Fecha o loading
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário atualizado com sucesso!'), backgroundColor: Colors.green));
                    setState(() {}); // Atualiza a lista na tela
                  } catch (e) {
                    Navigator.of(context).pop(); // Fecha o loading
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
