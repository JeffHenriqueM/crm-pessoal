import 'package:flutter/material.dart';

import '../models/fila_atendimento_model.dart';
import '../services/firestore_service.dart';

/// Aba "Linha de atendimento" (dentro da Recepção): mostra a fila da sala de
/// vendas em ordem (1º = Próximo), permite reordenar manualmente (híbrido) e
/// mandar alguém pro fim (atendeu/atrasado). A disponibilidade é marcada pelo
/// próprio vendedor na home dele; aqui a recepção só opera a fila.
class AbaLinhaAtendimento extends StatelessWidget {
  const AbaLinhaAtendimento({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<FilaAtendimento>>(
      stream: service.getFilaAtendimentoStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final todos = snap.data ?? [];
        final disponiveis = todos.where((f) => f.disponivel).toList();
        final indisponiveis = todos.where((f) => !f.disponivel).toList()
          ..sort((a, b) => a.vendedorNome.compareTo(b.vendedorNome));

        if (todos.isEmpty) {
          return _vazio(cs, 'Ninguém na linha de atendimento ainda.',
              'Os vendedores aparecem aqui quando marcam "disponível".');
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            Text('Disponíveis para atender (${disponiveis.length})',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface)),
            const SizedBox(height: 8),
            if (disponiveis.isEmpty)
              _vazio(cs, 'Nenhum vendedor disponível.',
                  'Aguardando alguém marcar disponibilidade.')
            else
              ...disponiveis.asMap().entries.map((e) => _cardDisponivel(
                    context,
                    service,
                    cs,
                    e.value,
                    posicao: e.key,
                    total: disponiveis.length,
                    anterior: e.key > 0 ? disponiveis[e.key - 1] : null,
                    proximo: e.key < disponiveis.length - 1
                        ? disponiveis[e.key + 1]
                        : null,
                  )),
            if (indisponiveis.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Indisponíveis (${indisponiveis.length})',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurfaceVariant)),
              const SizedBox(height: 8),
              ...indisponiveis.map((f) => _cardIndisponivel(cs, f)),
            ],
          ],
        );
      },
    );
  }

  Widget _vazio(ColorScheme cs, String titulo, String sub) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Column(
          children: [
            Icon(Icons.people_alt_outlined,
                size: 44, color: cs.outline.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(titulo,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: cs.onSurface)),
            const SizedBox(height: 4),
            Text(sub,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: cs.outline)),
          ],
        ),
      );

  Widget _cardDisponivel(
    BuildContext context,
    FirestoreService service,
    ColorScheme cs,
    FilaAtendimento f, {
    required int posicao,
    required int total,
    FilaAtendimento? anterior,
    FilaAtendimento? proximo,
  }) {
    final ehProximo = posicao == 0;
    final cor = ehProximo ? cs.primary : cs.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: ehProximo
            ? BorderSide(color: cs.primary, width: 1.5)
            : BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: cor.withValues(alpha: 0.14),
              child: Text('${posicao + 1}',
                  style: TextStyle(
                      color: cor, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.vendedorNome,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  if (ehProximo)
                    Text('Próximo a atender',
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.primary,
                            fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            // Reordenar (híbrido)
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up, size: 20),
              tooltip: 'Subir',
              visualDensity: VisualDensity.compact,
              onPressed: anterior == null
                  ? null
                  : () => service.trocarPosicaoFila(
                      f.vendedorId, anterior.vendedorId),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, size: 20),
              tooltip: 'Descer',
              visualDensity: VisualDensity.compact,
              onPressed: proximo == null
                  ? null
                  : () => service.trocarPosicaoFila(
                      f.vendedorId, proximo.vendedorId),
            ),
            PopupMenuButton<String>(
              tooltip: 'Mandar pro fim',
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (v) async {
                await service.mandarParaFimDaFila(f.vendedorId);
                if (context.mounted) {
                  final msg = v == 'atendeu'
                      ? '${f.vendedorNome} atendeu — foi pro fim da fila.'
                      : '${f.vendedorNome} marcado como atrasado — foi pro fim.';
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(msg)));
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'atendeu',
                  child: ListTile(
                    leading: Icon(Icons.check_circle_outline),
                    title: Text('Atendeu → fim'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                PopupMenuItem(
                  value: 'atrasado',
                  child: ListTile(
                    leading: Icon(Icons.timer_off_outlined),
                    title: Text('Atrasado → fim'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardIndisponivel(ColorScheme cs, FilaAtendimento f) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      elevation: 0,
      child: ListTile(
        dense: true,
        leading: Icon(Icons.do_not_disturb_on_outlined,
            color: cs.outline, size: 20),
        title: Text(f.vendedorNome,
            style: TextStyle(color: cs.onSurfaceVariant)),
        subtitle: Text('Indisponível',
            style: TextStyle(fontSize: 11, color: cs.outline)),
      ),
    );
  }
}
