import 'package:flutter/material.dart';

import '../services/tempo_sem_contato.dart';

/// Chip colorido "Xd sem contato" (ticket #48), reutilizado nos cards do
/// pipeline (kanban/lista) e na ficha do cliente. Renderiza apenas quando há
/// alerta (≥ 15 dias); para `emDia` retorna um widget vazio.
class ChipTempoSemContato extends StatelessWidget {
  final AvaliacaoTempoContato avaliacao;

  /// Versão compacta (sem rótulo da faixa) — usada nos cards estreitos.
  final bool compacto;

  const ChipTempoSemContato(this.avaliacao, {super.key, this.compacto = false});

  @override
  Widget build(BuildContext context) {
    final cor = avaliacao.faixa.cor;
    if (cor == null) return const SizedBox.shrink();

    final dias = avaliacao.diasSemContato;
    final texto = compacto
        ? '${dias}d sem contato'
        : '${dias}d sem contato · ${avaliacao.faixa.rotulo}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: cor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 11, color: cor),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(
              fontSize: 10.5,
              color: cor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
