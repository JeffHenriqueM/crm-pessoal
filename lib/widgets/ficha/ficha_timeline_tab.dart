import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/interacao_model.dart';

/// Aba de interações com visual de timeline.
class FichaTimelineTab extends StatelessWidget {
  final List<Interacao> interacoes;
  final bool isNovo;

  /// Chamado ao tocar em um item manual — o parent exibe o bottom sheet de opções.
  final void Function(Interacao interacao) onItemTap;

  /// Chamado ao tocar em "Registrar resposta do cliente" num item que ainda
  /// não teve resposta. Opcional — quando null, o atalho não aparece (ex.: na
  /// criação de um cliente novo, antes de salvar).
  final void Function(Interacao interacao)? onRegistrarResposta;

  const FichaTimelineTab({
    super.key,
    required this.interacoes,
    required this.isNovo,
    required this.onItemTap,
    this.onRegistrarResposta,
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

  Widget _buildTimelineItem(
    BuildContext context,
    Interacao item, {
    required bool isFirst,
    required bool isLast,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isSistema = item.isSistema;
    final dotColor = isSistema ? cs.outlineVariant : item.canal.cor;
    final lineColor = cs.outlineVariant.withValues(alpha: 0.6);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Rail esquerdo ───────────────────────────────────────────────────
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

          // ── Conteúdo ────────────────────────────────────────────────────────
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

  // ── Item de sistema (compacto, muted) ────────────────────────────────────────
  Widget _buildSistemaItem(Interacao item, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: cs.outline.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Sistema',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: cs.outline)),
              ),
              const SizedBox(width: 6),
              Text(
                DateFormat('dd/MM/yy · HH:mm').format(item.dataInteracao),
                style: TextStyle(fontSize: 10, color: cs.outline),
              ),
            ],
          ),
          const SizedBox(height: 3),
          if (item.titulo != null && item.titulo!.isNotEmpty)
            Text(
              item.titulo!,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant),
            ),
          if (item.nota.isNotEmpty &&
              item.nota != item.titulo)
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

  // ── Item manual (card completo, clicável) ────────────────────────────────────
  Widget _buildManualItem(Interacao item, ColorScheme cs) {
    final temCombinamos =
        item.oQueCombinamos != null && item.oQueCombinamos!.isNotEmpty;

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
              // ── Cabeçalho: canal + badges + data ──────────────────────────
              Row(
                children: [
                  // Canal
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: item.canal.cor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.canal.icone,
                            size: 11, color: item.canal.cor),
                        const SizedBox(width: 4),
                        Text(item.canal.nome,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: item.canal.cor)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  // Modalidade
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: item.modalidade == Modalidade.presencial
                          ? Colors.teal.withValues(alpha: 0.10)
                          : Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.modalidade.nome,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: item.modalidade == Modalidade.presencial
                              ? Colors.teal.shade700
                              : Colors.blue.shade700),
                    ),
                  ),
                  const SizedBox(width: 5),
                  // Houve resposta
                  Icon(
                    item.houveResposta
                        ? Icons.check_circle
                        : Icons.cancel_outlined,
                    size: 13,
                    color: item.houveResposta
                        ? Colors.green.shade600
                        : cs.outlineVariant,
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

              // ── Título (opcional) ──────────────────────────────────────────
              if (item.titulo != null && item.titulo!.isNotEmpty) ...[
                Text(
                  item.titulo!,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 3),
              ],

              // ── Nota ──────────────────────────────────────────────────────
              Text(
                item.nota,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, color: cs.onSurfaceVariant, height: 1.4),
              ),

              // ── O que combinamos ──────────────────────────────────────────
              if (temCombinamos) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color:
                            Colors.green.shade700.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 13, color: Colors.green.shade700),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          item.oQueCombinamos!,
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

              // ── Resposta do cliente (registrada depois) ───────────────────
              if (item.respostaCliente != null &&
                  item.respostaCliente!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: item.canal.cor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: item.canal.cor.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.reply, size: 13, color: item.canal.cor),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Resposta do cliente',
                                style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: item.canal.cor)),
                            const SizedBox(height: 2),
                            Text(
                              item.respostaCliente!,
                              style: TextStyle(
                                  fontSize: 12, color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ]
              // Atalho: registrar a resposta que chegou depois (só quando ainda
              // não houve resposta e o item já está salvo).
              else if (onRegistrarResposta != null &&
                  !item.houveResposta &&
                  item.id != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => onRegistrarResposta!(item),
                    icon: const Icon(Icons.reply, size: 15),
                    label: const Text('Registrar resposta do cliente'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],

              // ── Autor ──────────────────────────────────────────────────────
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
