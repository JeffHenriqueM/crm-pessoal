// lib/screens/interacoes_screen.dart

import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../models/interacao_model.dart';
import '../services/firestore_service.dart';

class InteracoesScreen extends StatelessWidget {
  final Cliente cliente;
  const InteracoesScreen({super.key, required this.cliente});

  // MÉTODOS DE DIÁLOGO E OPÇÕES

  // Diálogo genérico para Adicionar/Editar
  void _mostrarDialogoInteracao(
      BuildContext context, FirestoreService service, Interacao? interacao) {

    // Se for edição, pré-preenche com os dados existentes
    final isEditing = interacao != null;
    final _tituloController = TextEditingController(text: interacao?.titulo);
    final _notaController = TextEditingController(text: interacao?.nota);
    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Editar Interação' : 'Nova Interação'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (v) => v!.isEmpty ? 'Insira um título.' : null,
              ),
              TextFormField(
                controller: _notaController,
                decoration: const InputDecoration(labelText: 'Nota'),
                keyboardType: TextInputType.multiline,
                maxLines: 3,
                validator: (v) => v!.isEmpty ? 'Insira uma nota.' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final interacaoAtualizada = Interacao(
                  id: interacao?.id, // Mantém o ID se for edição
                  titulo: _tituloController.text,
                  nota: _notaController.text,
                  // Mantém a data original se for edição, ou usa a data atual se for novo.
                  dataInteracao: interacao?.dataInteracao ?? DateTime.now(),
                );

                if (isEditing) {
                  await service.atualizarInteracao(cliente.id!, interacaoAtualizada);
                } else {
                  await service.adicionarInteracao(cliente.id!, interacaoAtualizada);
                }

                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Interação ${isEditing ? 'editada' : 'salva'}!')),
                  );
                }
              }
            },
            child: Text(isEditing ? 'SALVAR EDIÇÃO' : 'SALVAR'),
          ),
        ],
      ),
    );
  }

  // BottomSheet para Editar/Excluir
  void _mostrarOpcoesInteracao(
      BuildContext context, FirestoreService service, Interacao interacao) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Editar Interação'),
              onTap: () {
                Navigator.of(context).pop();
                _mostrarDialogoInteracao(context, service, interacao);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Excluir Interação'),
              onTap: () async {
                Navigator.of(context).pop(); // Fecha o sheet

                // Pede confirmação antes de excluir
                final bool? confirm = await showDialog(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    title: const Text('Confirmar Exclusão'),
                    content: const Text('Tem certeza que deseja excluir esta interação?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Não')),
                      TextButton(onPressed: () => Navigator.of(dialogCtx).pop(true), child: const Text('Sim, Excluir')),
                    ],
                  ),
                );

                if (confirm == true) {
                  await service.excluirInteracao(cliente.id!, interacao.id!);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Interação excluída!')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: Text('Histórico: ${cliente.nome}'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Interacao>>(
        stream: firestoreService.getInteracoesStream(cliente.id!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }

          final interacoes = snapshot.data ?? [];

          if (interacoes.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'Nenhuma interação registrada. Adicione a primeira!',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: interacoes.length,
            itemBuilder: (context, index) {
              final interacao = interacoes[index];
              return Card(
                elevation: 1,
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: ListTile(
                  // NOVIDADE: Ao pressionar e segurar, abre as opções
                  onLongPress: () => _mostrarOpcoesInteracao(context, firestoreService, interacao),

                  title: Text(
                    interacao.titulo,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(interacao.nota),
                  trailing: Text(
                    '${interacao.dataInteracao.day}/${interacao.dataInteracao.month} - ${interacao.dataInteracao.hour}h${interacao.dataInteracao.minute}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarDialogoInteracao(context, firestoreService, null), // Passa null para criar
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_comment),
      ),
    );
  }
}