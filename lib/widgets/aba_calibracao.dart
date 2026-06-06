import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../services/calibracao.dart';

/// Aba "Calibração" (admin) — confronta os sinais que o Lead Score usa com os
/// desfechos reais (fechado vs perdido) e mostra o poder preditivo (lift) de
/// cada um. É aqui que se decide se os pesos do score estão certos.
///
/// A regra vive em `services/calibracao.dart` (lógica pura, testada).
class AbaCalibracao extends StatelessWidget {
  final List<Cliente> todosClientes;

  const AbaCalibracao({super.key, required this.todosClientes});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = calibrarSinais(todosClientes);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Calibração dos Sinais',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface)),
          const SizedBox(height: 2),
          Text(
            'O que os leads já decididos provam sobre cada sinal de fechamento',
            style: TextStyle(fontSize: 12, color: cs.outline),
          ),
          const SizedBox(height: 16),

          _amostraCard(cs, r),
          const SizedBox(height: 16),

          if (r.amostra == 0)
            _vazio(cs)
          else ...[
            if (!r.amostraSuficiente) _avisoAmostra(cs, r),
            Text('Poder preditivo por sinal',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface)),
            const SizedBox(height: 4),
            Text(
              'Lift = quanto o sinal aumenta a chance de fechar (em pontos %)',
              style: TextStyle(fontSize: 11, color: cs.outline),
            ),
            const SizedBox(height: 10),
            ...r.sinais.map((s) => _sinalCard(cs, s)),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _amostraCard(ColorScheme cs, RelatorioCalibracao r) {
    return Card(
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _stat(cs, '${r.amostra}', 'decididos'),
            _div(cs),
            _stat(cs, '${r.fechados}', 'fechados'),
            _div(cs),
            _stat(cs, '${r.perdidos}', 'perdidos'),
            _div(cs),
            _stat(cs, '${r.taxaBase.toStringAsFixed(0)}%', 'taxa-base'),
          ],
        ),
      ),
    );
  }

  Widget _stat(ColorScheme cs, String valor, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(valor,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface)),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: cs.outline)),
        ],
      ),
    );
  }

  Widget _div(ColorScheme cs) =>
      Container(width: 1, height: 32, color: cs.outlineVariant);

  Widget _avisoAmostra(ColorScheme cs, RelatorioCalibracao r) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 16, color: Colors.amber.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Amostra ainda pequena (${r.amostra} de $kMinAmostraCalibracao). '
              'Os números são uma prévia — tendem a estabilizar com mais desfechos.',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sinalCard(ColorScheme cs, SinalCalibrado s) {
    final lift = s.lift;
    final cor = lift >= 10
        ? Colors.green.shade600
        : lift <= -10
            ? Colors.red.shade600
            : cs.outline;
    final sinalLift = lift > 0 ? '+' : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(s.rotulo,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                if (!s.confiavel)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Tooltip(
                      message:
                          'Poucos exemplos de um dos lados — lift ainda instável',
                      child: Icon(Icons.help_outline,
                          size: 15, color: cs.outline),
                    ),
                  ),
                Text('$sinalLift${lift.toStringAsFixed(0)} pts',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: cor)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ladoBarra(
                      cs,
                      'Com o sinal',
                      s.fechamentoComSinal,
                      s.comSinal,
                      Colors.green.shade600),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ladoBarra(
                      cs,
                      'Sem o sinal',
                      s.fechamentoSemSinal,
                      s.semSinal,
                      cs.outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _ladoBarra(
      ColorScheme cs, String label, double pct, int n, Color cor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(fontSize: 10, color: cs.outline)),
            Text('${pct.toStringAsFixed(0)}% · n=$n',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (pct / 100).clamp(0.0, 1.0),
            backgroundColor: cor.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(cor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _vazio(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.science_outlined, size: 40, color: cs.outline),
              const SizedBox(height: 12),
              Text('Ainda não há leads decididos para calibrar',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 4),
              Text('Conforme leads forem fechados ou perdidos, os sinais\n'
                  'serão validados aqui.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: cs.outline)),
            ],
          ),
        ),
      ),
    );
  }
}
