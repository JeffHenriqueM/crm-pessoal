import 'package:flutter/material.dart';

import '../models/modelo_mensagem_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Tela de gestão dos modelos de mensagem de WhatsApp (acessada via
/// Configurações). Mostra os modelos do usuário e os modelos padrão.
class ModelosMensagemScreen extends StatelessWidget {
  const ModelosMensagemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final uid = AuthService().getCurrentUser()?.uid;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Modelos de mensagem')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirForm(context, fs),
        icon: const Icon(Icons.add),
        label: const Text('Novo modelo'),
      ),
      body: StreamBuilder<List<ModeloMensagem>>(
        stream: fs.getModelosMensagemStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Erro: ${snap.error}'));
          }
          final todos = snap.data ?? [];
          final meus =
              todos.where((m) => !m.padrao && m.criadoPorId == uid).toList();
          final padrao = todos.where((m) => m.padrao).toList();

          if (todos.isEmpty) {
            return _vazio(context);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            children: [
              Card(
                color: cs.surfaceContainerHighest,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Use variáveis no texto: {nome}, {primeiroNome}, {esposa}, '
                    '{primeiroNomeEsposa}, {responsavel}. Elas são preenchidas '
                    'automaticamente ao enviar.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _secao(context, 'Meus modelos', meus, fs, uid),
              const SizedBox(height: 8),
              _secao(context, 'Modelos padrão (todos)', padrao, fs, uid),
            ],
          );
        },
      ),
    );
  }

  Widget _vazio(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.message_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text('Nenhum modelo ainda', style: tt.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Crie um modelo para ir ao WhatsApp com a mensagem pronta.',
              textAlign: TextAlign.center,
              style: tt.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _secao(BuildContext context, String titulo,
      List<ModeloMensagem> itens, FirestoreService fs, String? uid) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
          child: Text(titulo,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.primary)),
        ),
        if (itens.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Nenhum modelo aqui.',
                style: TextStyle(fontSize: 12, color: cs.outline)),
          )
        else
          for (final m in itens)
            Card(
              child: ListTile(
                leading: Icon(m.padrao ? Icons.public : Icons.person_outline,
                    color: cs.primary),
                title: Text(m.titulo,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(m.texto,
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Editar',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _abrirForm(context, fs, existente: m),
                    ),
                    IconButton(
                      tooltip: 'Excluir',
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmarExcluir(context, fs, m),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Future<void> _abrirForm(BuildContext context, FirestoreService fs,
      {ModeloMensagem? existente}) async {
    final salvo = await showDialog<bool>(
      context: context,
      builder: (_) => _FormModeloDialog(fs: fs, existente: existente),
    );
    if (salvo == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modelo salvo.')),
      );
    }
  }

  Future<void> _confirmarExcluir(
      BuildContext context, FirestoreService fs, ModeloMensagem m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir modelo'),
        content: Text('Excluir o modelo "${m.titulo}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok == true) await fs.deletarModeloMensagem(m.id);
  }
}

// ── Form de criar/editar modelo ──────────────────────────────────────────────
class _FormModeloDialog extends StatefulWidget {
  final FirestoreService fs;
  final ModeloMensagem? existente;
  const _FormModeloDialog({required this.fs, this.existente});

  @override
  State<_FormModeloDialog> createState() => _FormModeloDialogState();
}

class _FormModeloDialogState extends State<_FormModeloDialog> {
  late final _titulo =
      TextEditingController(text: widget.existente?.titulo ?? '');
  late final _texto = TextEditingController(text: widget.existente?.texto ?? '');
  late bool _padrao = widget.existente?.padrao ?? false;
  bool _salvando = false;

  static const _variaveis = [
    '{nome}',
    '{primeiroNome}',
    '{esposa}',
    '{primeiroNomeEsposa}',
    '{responsavel}'
  ];

  @override
  void dispose() {
    _titulo.dispose();
    _texto.dispose();
    super.dispose();
  }

  void _inserirVariavel(String v) {
    final sel = _texto.selection;
    final txt = _texto.text;
    if (sel.isValid) {
      final novo = txt.replaceRange(sel.start, sel.end, v);
      _texto.value = TextEditingValue(
        text: novo,
        selection: TextSelection.collapsed(offset: sel.start + v.length),
      );
    } else {
      _texto.text = txt + v;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existente == null ? 'Novo modelo' : 'Editar modelo'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titulo,
                decoration: const InputDecoration(labelText: 'Título *'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _texto,
                decoration: const InputDecoration(
                  labelText: 'Mensagem *',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                minLines: 3,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final v in _variaveis)
                    ActionChip(
                      label: Text(v,
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurface)),
                      onPressed: () => _inserirVariavel(v),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Modelo padrão (compartilhar com todos)'),
                subtitle: const Text(
                    'Desligado = só você vê este modelo',
                    style: TextStyle(fontSize: 12)),
                value: _padrao,
                onChanged: (v) => setState(() => _padrao = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: _salvando ? null : _salvar,
          child: _salvando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Salvar'),
        ),
      ],
    );
  }

  Future<void> _salvar() async {
    final titulo = _titulo.text.trim();
    final texto = _texto.text.trim();
    if (titulo.isEmpty || texto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Título e mensagem são obrigatórios.')),
      );
      return;
    }
    setState(() => _salvando = true);
    try {
      if (widget.existente == null) {
        await widget.fs.criarModeloMensagem(
            ModeloMensagem(titulo: titulo, texto: texto, padrao: _padrao));
      } else {
        await widget.fs.atualizarModeloMensagem(widget.existente!
            .copyWith(titulo: titulo, texto: texto, padrao: _padrao));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }
}
