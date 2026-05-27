import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/interacao_model.dart';

/// Aba de interações com visual de timeline.
/// Recebe a lista de interações e um callback para quando o usuário
/// toca em um item manual (editar / excluir).
class FichaTimelineTab extends StatelessWidget {
  final List<Interacao> interacoes;
  final bool isNovo;

  /// Chamado ao tocar em um item manual — o parent exibe o bottom sheet de opções.
  final void Function(Interacao interacao) onItemTap;

  const FichaTimelineTab({
    super.key,
    required this.interacoes,
    required this.isNovo,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (interacoes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timeline_outlined,
                  size: 56, color: cs.outline.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text(
                isNovo
                    ? 'Adicione interações antes de salvar\no cliente — serão enviadas junto.'
                    : 'Nenhuma interação registrada ainda.\nToque no botão abaixo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.outline, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: interacoes.length,
      itemBuilder: (context, index) {
        final item = interacoes[index];
        return _buildTimelineItem(
          context,
          item,
          isFirst: index == 0,
          isLast: index == interacoes.length - 1,
        );
      },
    );
  }

  // ── Item de timeline ──────────────────────────────────────────────────────────
  Widget _buildTimelineItem(
    BuildContext context,
    Interacao item, {
    required bool isFirst,
    required bool isLast,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isSistema = item.isSistema;
    final dotColor = isSistema
        ? (item.isMensagem ? Colors.deepPurple.shade400 : cs.outlineVariant)
        : item.tipo.cor;
    final lineColor = cs.outlineVariant.withValues(alpha: 0.6);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Rail esquerdo ─────────────────────────────────────────────────────
          SizedBox(
            width: 32,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    flex: 1,
                    child: Center(child: Container(width: 2, color: lineColor)),
                  )
                else
                  const SizedBox(height: 8),

                // Dot
                Container(
                  width: isSistema ? 10 : 14,
                  height: isSistema ? 10 : 14,
                  decoration: BoxDecoration(
                    color: isSistema ? null : dotColor,
                    border: isSistema
                        ? Border.all(color: dotColor, width: 1.5)
                        : null,
                    shape: BoxShape.circle,
                  ),
                  child: isSistema && item.isMensagem
                      ? Center(
                          child: Icon(Icons.message_outlined,
                              size: 6, color: dotColor))
                      : null,
                ),

                if (!isLast)
                  Expanded(
                    flex: 3,
                    child: Center(child: Container(width: 2, color: lineColor)),
                  )
                else
                  const SizedBox(height: 12),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // ── Conteúdo ──────────────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: isSistema
                  ? _buildSistemaItem(item, cs)
                  : _buildManualItem(item, cs),
            ),
          ),
        ],
      ),
    );
  }

  // ── Item de sistema (compacto, muted) ─────────────────────────────────────────
  Widget _buildSistemaItem(Interacao item, ColorScheme cs) {
    final isMsg = item.isMensagem;
    final cor = isMsg ? Colors.deepPurple.shade400 : cs.outline;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isMsg ? 'Mensagem' : 'Sistema',
                  style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w600, color: cor),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                DateFormat('dd/MM/yy · HH:mm').format(item.dataInteracao),
                style: TextStyle(fontSize: 10, color: cs.outline),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            item.titulo,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant),
          ),
          if (item.nota.isNotEmpty && item.nota != item.titulo)
            Text(
              item.nota,
              style: TextStyle(fontSize: 11, color: cs.outline),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  // ── Item manual (card completo, clicável) ─────────────────────────────────────
  Widget _buildManualItem(Interacao item, ColorScheme cs) {
    final temProximoPasso =
        item.proximoPasso != null && item.proximoPasso!.isNotEmpty;

    return GestureDetector(
      onTap: () => onItemTap(item),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cabeçalho: chip de tipo + data ────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: item.tipo.cor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.tipo.icone, size: 11, color: item.tipo.cor),
                        const SizedBox(width: 4),
                        Text(
                          item.tipo.nome,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: item.tipo.cor),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('dd/MM/yy · HH:mm').format(item.dataInteracao),
                    style: TextStyle(fontSize: 10, color: cs.outline),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.more_horiz, size: 14, color: cs.outline),
                ],
              ),
              const SizedBox(height: 7),

              // ── Título ────────────────────────────────────────────────────────
              Text(
                item.titulo,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 3),

              // ── Nota ─────────────────────────────────────────────────────────
              Text(
                item.nota,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, color: cs.onSurfaceVariant, height: 1.4),
              ),

              // ── Próximo passo ─────────────────────────────────────────────────
              if (temProximoPasso) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        Colors.green.shade700.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.green.shade700
                            .withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 13, color: Colors.green.shade700),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          item.proximoPasso!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Autor ─────────────────────────────────────────────────────────
              if (item.autorNome != null && item.autorNome!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.autorNome!,
                  style: TextStyle(fontSize: 10, color: cs.outline),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
