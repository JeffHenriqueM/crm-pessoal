import 'package:flutter/material.dart';

import '../models/interacao_model.dart';

/// Pede o texto da resposta do cliente (registrada depois da interação).
/// Retorna o texto digitado, ou `null` se o usuário cancelar.
Future<String?> pedirRespostaCliente(BuildContext context,
    {String? inicial}) async {
  final ctrl = TextEditingController(text: inicial ?? '');
  return showDialog<String>(
    context: context,
    builder: (dctx) => AlertDialog(
      title: const Text('Resposta do cliente'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'O que o cliente respondeu?',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final t = ctrl.text.trim();
            if (t.isEmpty) return;
            Navigator.pop(dctx, t);
          },
          child: const Text('Salvar resposta'),
        ),
      ],
    ),
  );
}

/// Dialog reutilizável de "Nova Interação".
///
/// Usado na ficha do contrato (FAB) e no fluxo de WhatsApp (aniversariantes /
/// botão de contato). O canal padrão é WhatsApp, mas pode ser sobrescrito.
class InteracaoFormDialog extends StatefulWidget {
  final Future<void> Function(Interacao) onSalvar;
  final Canal canalInicial;
  final String? titulo;

  const InteracaoFormDialog({
    super.key,
    required this.onSalvar,
    this.canalInicial = Canal.whatsapp,
    this.titulo,
  });

  static void show(
    BuildContext context, {
    required Future<void> Function(Interacao) onSalvar,
    Canal canalInicial = Canal.whatsapp,
    String? titulo,
  }) {
    showDialog(
      context: context,
      builder: (_) => InteracaoFormDialog(
        onSalvar: onSalvar,
        canalInicial: canalInicial,
        titulo: titulo,
      ),
    );
  }

  @override
  State<InteracaoFormDialog> createState() => _InteracaoFormDialogState();
}

class _InteracaoFormDialogState extends State<InteracaoFormDialog> {
  late Canal _canal = widget.canalInicial;
  Modalidade _modalidade = Modalidade.online;
  bool _houveResposta = false;
  final _tituloCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  final _combinamosCtrl = TextEditingController();
  bool _salvando = false;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _notaCtrl.dispose();
    _combinamosCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo ?? 'Nova Interação'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Canal
            DropdownButtonFormField<Canal>(
              value: _canal,
              decoration: const InputDecoration(labelText: 'Canal'),
              items: Canal.values
                  .where((c) => c != Canal.sistema)
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Icon(c.icone, size: 16, color: c.cor),
                            const SizedBox(width: 8),
                            Text(c.nome),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _canal = v!),
            ),
            const SizedBox(height: 12),
            // Modalidade
            DropdownButtonFormField<Modalidade>(
              value: _modalidade,
              decoration: const InputDecoration(labelText: 'Modalidade'),
              items: Modalidade.values
                  .map((m) =>
                      DropdownMenuItem(value: m, child: Text(m.nome)))
                  .toList(),
              onChanged: (v) => setState(() => _modalidade = v!),
            ),
            const SizedBox(height: 12),
            // Houve resposta
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Houve resposta?',
                  style: TextStyle(fontSize: 14)),
              value: _houveResposta,
              onChanged: (v) => setState(() => _houveResposta = v),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _tituloCtrl,
              decoration:
                  const InputDecoration(labelText: 'Título (opcional)'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notaCtrl,
              decoration: const InputDecoration(labelText: 'Observações'),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _combinamosCtrl,
              decoration:
                  const InputDecoration(labelText: 'O que combinamos?'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _salvando ? null : _salvar,
          child: _salvando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }

  Future<void> _salvar() async {
    final titulo = _tituloCtrl.text.trim();
    final nota = _notaCtrl.text.trim();
    if (nota.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insira uma nota para a interação.')),
      );
      return;
    }

    setState(() => _salvando = true);
    final combinamos = _combinamosCtrl.text.trim();
    final interacao = Interacao(
      titulo: titulo.isEmpty ? null : titulo,
      nota: nota,
      dataInteracao: DateTime.now(),
      canal: _canal,
      modalidade: _modalidade,
      houveResposta: _houveResposta,
      oQueCombinamos: combinamos.isEmpty ? null : combinamos,
    );

    try {
      await widget.onSalvar(interacao);
      if (mounted) Navigator.pop(context);
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
