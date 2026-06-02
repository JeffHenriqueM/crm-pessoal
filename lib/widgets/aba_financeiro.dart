import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import 'filtro_periodo.dart';

class AbaFinanceiro extends StatefulWidget {
  final List<Cliente> clientes;
  const AbaFinanceiro({super.key, required this.clientes});

  @override
  State<AbaFinanceiro> createState() => _AbaFinanceiroState();
}

class _AbaFinanceiroState extends State<AbaFinanceiro> {
  FiltroPeriodo _filtro = const FiltroPeriodo(periodo: Periodo.mes);

  static const _meses = [
    'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
    'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
  ];

  List<Cliente> get _base =>
      widget.clientes.where((c) => c.fase != FaseCliente.atendimento).toList();

  List<Cliente> get _filtrados =>
      _base.where((c) => _filtro.contem(c.dataCadastro)).toList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final clientes = _filtrados;

    final emNegociacao =
        clientes.where((c) => c.fase == FaseCliente.negociacao).length;
    final emVisita =
        clientes.where((c) => c.fase == FaseCliente.visita).length;
    final fechados =
        clientes.where((c) => c.fase == FaseCliente.fechado).length;
    final perdidos =
        clientes.where((c) => c.fase == FaseCliente.perdido).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Filtro de período ────────────────────────────────────────
          FiltroPeriodoBar(
            filtro: _filtro,
            onChanged: (f) => setState(() => _filtro = f),
            legenda: 'Filtro aplica à data de cadastro dos leads',
          ),
          const SizedBox(height: 24),

          // ── KPI cards ────────────────────────────────────────────────
          _sectionTitle(context, 'Visão do Pipeline'),
          const SizedBox(height: 12),
          Row(children: [
            _kpiCard(context, 'Negociação', emNegociacao,
                Icons.handshake_outlined, Colors.orange.shade700, cs),
            _kpiCard(context, 'Visita', emVisita,
                Icons.location_on_outlined, cs.primary, cs),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _kpiCard(context, 'Fechados', fechados,
                Icons.check_circle_outline, Colors.green.shade700, cs),
            _kpiCard(context, 'Perdidos', perdidos,
                Icons.cancel_outlined, cs.error, cs),
          ]),

          // ── Taxa de fechamento ────────────────────────────────────────
          const SizedBox(height: 20),
          _buildTaxaCard(fechados, perdidos, emNegociacao + emVisita, cs),

          // ── Gráfico: fechamentos por mês ──────────────────────────────
          const SizedBox(height: 28),
          _sectionTitle(context, 'Fechamentos — Últimos 12 Meses'),
          const SizedBox(height: 4),
          Text(
            'Baseado na data de atualização dos leads fechados',
            style: TextStyle(fontSize: 11, color: cs.outline),
          ),
          const SizedBox(height: 16),
          _buildFechamentosPorMes(cs),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Taxa de fechamento card ───────────────────────────────────────────────
  Widget _buildTaxaCard(
      int fechados, int perdidos, int pipeline, ColorScheme cs) {
    final total = fechados + perdidos;
    final taxa = total == 0 ? 0.0 : fechados / total * 100;
    final corTaxa = taxa >= 30
        ? Colors.green.shade700
        : taxa >= 15
            ? Colors.orange.shade700
            : cs.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Taxa de Fechamento',
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text('${taxa.toStringAsFixed(1)}%',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: corTaxa)),
                  Text('dos finalizados foram fechados',
                      style: TextStyle(fontSize: 11, color: cs.outline)),
                ],
              ),
            ),
            if (pipeline > 0) ...[
              Container(
                  height: 48,
                  width: 1,
                  color: cs.outlineVariant,
                  margin: const EdgeInsets.symmetric(horizontal: 16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Em Andamento',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text('$pipeline',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: cs.primary)),
                    Text('leads em negociação ou visita',
                        style: TextStyle(fontSize: 11, color: cs.outline)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Gráfico de fechamentos por mês (12 meses) ────────────────────────────
  Widget _buildFechamentosPorMes(ColorScheme cs) {
    final agora = DateTime.now();
    final mesesRef = List.generate(12, (i) {
      final m = agora.month - 11 + i;
      final y = agora.year + (m <= 0 ? -1 : 0);
      final mes = m <= 0 ? m + 12 : m;
      return DateTime(y, mes, 1);
    });

    final contagem = {for (final m in mesesRef) '${m.year}-${m.month}': 0};
    for (final c in _base.where((c) => c.fase == FaseCliente.fechado)) {
      final key = '${c.dataAtualizacao.year}-${c.dataAtualizacao.month}';
      if (contagem.containsKey(key)) contagem[key] = contagem[key]! + 1;
    }

    final valores = mesesRef
        .map((m) => contagem['${m.year}-${m.month}']!.toDouble())
        .toList();
    final maxVal = valores.reduce((a, b) => a > b ? a : b);
    final maxY = (maxVal + 1).clamp(3.0, double.maxFinite);
    final labels = mesesRef.map((m) => _meses[m.month - 1]).toList();

    if (maxVal == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text('Nenhum fechamento registrado.',
              style: TextStyle(color: cs.outline)),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: BarChart(BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barGroups: List.generate(
          12,
          (i) => BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: valores[i],
              color: Colors.green.shade600,
              width: 18,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ]),
        ),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= labels.length) return const Text('');
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(labels[i],
                      style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.green.shade700,
            getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
              '${labels[gi]}\n${rod.toY.toInt()} fechado${rod.toY.toInt() != 1 ? 's' : ''}',
              const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      )),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  Widget _kpiCard(
    BuildContext context,
    String label,
    int valor,
    IconData icon,
    Color cor,
    ColorScheme cs,
  ) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: cor.withValues(alpha: 0.12),
                child: Icon(icon, color: cor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$valor',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: cor)),
                    Text(label,
                        style: TextStyle(fontSize: 10, color: cs.outline)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
}
