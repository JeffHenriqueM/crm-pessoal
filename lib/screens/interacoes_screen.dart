import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../models/interacao_model.dart';
import '../services/firestore_service.dart';

class InteracoesScreen extends StatelessWidget {
  final Cliente cliente;
  const InteracoesScreen({super.key, required this.cliente});

  void _mostrarDialogoInteracao(
      BuildContext context, FirestoreService service, Interacao? interacao) {
    final isEditing = interacao != null;
    final tituloCtrl = TextEditingController(text: interacao?.titulo);
    final notaCtrl = TextEditingController(text: interacao?.nota);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Editar Interação' : 'Nova Interação'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: tituloCtrl,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  prefixIcon: Icon(Icons.title),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Insira um título.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nota',
                  prefixIcon: Icon(Icons.notes),
                  alignLabelWithHint: true,
                ),
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Insira uma nota.' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final nova = Interacao(
                id: interacao?.id,
                titulo: tituloCtrl.text.trim(),
                nota: notaCtrl.text.trim(),
                dataInteracao: interacao?.dataInteracao ?? DateTime.now(),
              );

              if (isEditing) {
                await service.atualizarInteracao(cliente.id!, nova);
              } else {
                await service.adicionarInteracao(cliente.id!, nova);
              }

              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Interação ${isEditing ? 'atualizada' : 'registrada'}!'),
                    backgroundColor: Colors.green.shade700,
                  ),
                );
              }
            },
            child: Text(isEditing ? 'Salvar' : 'Registrar'),
          ),
        ],
      ),
    );
  }

  void _mostrarOpcoesInteracao(
      BuildContext context, FirestoreService service, Interacao interacao) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.edit_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('Editar'),
            onTap: () {
              Navigator.of(ctx).pop();
              _mostrarDialogoInteracao(context, service, interacao);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline,
                color: Theme.of(ctx).colorScheme.error),
            title: const Text('Excluir'),
            onTap: () async {
              Navigator.of(ctx).pop();

              final confirm = await showDialog<bool>(
                context: context,
                builder: (dctx) => AlertDialog(
                  title: const Text('Confirmar Exclusão'),
                  content: const Text('Deseja excluir esta interação?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dctx).pop(false),
                      child: const Text('Não'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            Theme.of(dctx).colorScheme.error,
                        foregroundColor:
                            Theme.of(dctx).colorScheme.onError,
                      ),
                      onPressed: () => Navigator.of(dctx).pop(true),
                      child: const Text('Excluir'),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                await service.excluirInteracao(cliente.id!, interacao.id!);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Interação excluída.')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Histórico: ${cliente.nome}'),
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 56,
                        color: cs.outline.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhuma interação registrada.\nAdicione a primeira!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.outline, fontSize: 15),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80, top: 4),
            itemCount: interacoes.length,
            itemBuilder: (context, index) {
              final i = interacoes[index];
              return Card(
                child: ListTile(
                  onLongPress: () =>
                      _mostrarOpcoesInteracao(context, firestoreService, i),
                  onTap: () =>
                      _mostrarOpcoesInteracao(context, firestoreService, i),
                  leading: CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    child: Icon(
                      Icons.chat_bubble_outline,
                      size: 18,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  title: Text(
                    i.titulo,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(i.nota, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Text(
                    DateFormat('dd/MM\nHH:mm').format(i.dataInteracao),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: cs.outline),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _mostrarDialogoInteracao(context, firestoreService, null),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Nova Interação'),
      ),
    );
  }
}
