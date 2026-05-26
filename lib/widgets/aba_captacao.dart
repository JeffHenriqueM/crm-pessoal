import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';

enum _PeriodoCaptacao { semana, mes, tudo }

class AbaCaptacao extends StatefulWidget {
  final List<Cliente> clientes;
  const AbaCaptacao({super.key, required this.clientes});

  @override
  State<AbaCaptacao> createState() => _AbaCaptacaoState();
}

class _AbaCaptacaoState extends State<AbaCaptacao> {
  _PeriodoCaptacao _periodo = _PeriodoCaptacao.mes;

  static const _diasSemana = [
    'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'
  ];

  List<Cliente> get _base =>
      widget.clientes.where((c) => c.fase != FaseCliente.atendimento).toList();

  List<Cliente> get _filtrados {
    final agora = DateTime.now();
    final inicioDia = DateTime(agora.year, agora.month, agora.day);
    switch (_periodo) {
      case _PeriodoCaptacao.semana:
        final ini = inicioDia.subtract(Duration(days: agora.weekday - 1));
        return _base.where((c) => !c.dataCadastro.isBefore(ini)).toList();
      case _PeriodoCaptacao.mes:
        final ini = DateTime(agora.year, agora.month, 1);
        return _base.where((c) => !c.dataCadastro.isBefore(ini)).toList();
      case _PeriodoCaptacao.tudo:
        return _base;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final clientes = _filtrados;

    // Ranking de captadores
    final rankingMap = <String, int>{};
    for (final c in clientes) {
      final nome = c.captadorNome?.isNotEmpty == true
          ? c.captadorNome!
          : 'Não informado';
      rankingMap[nome] = (rankingMap[nome] ?? 0) + 1;
    }
    final ranking = rankingMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Dados por dia da semana (weekday 1=Seg … 7=Dom)
    final porDia = List.filled(7, 0);
    for (final c in clientes) {
      porDia[c.dataCadastro.weekday - 1]++;
    }
    final maxDia = porDia.reduce((a, b) => a > b ? a : b);
    final maxY = (maxDia + 1).toDouble().clamp(3.0, double.maxFinite);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Filtro de período ────────────────────────────────────────
          SegmentedButton<_PeriodoCaptacao>(
            segments: const [
              ButtonSegment(
                  value: _PeriodoCaptacao.semana, label: Text('Semana')),
              ButtonSegment(
                  value: _PeriodoCaptacao.mes, label: Text('Mês')),
              ButtonSegment(
                  value: _PeriodoCaptacao.tudo, label: Text('Tudo')),
            ],
            selected: {_periodo},
            onSelectionChanged: (s) => setState(() => _periodo = s.first),
          ),
          const SizedBox(height: 24),

          // ── KPI cards ────────────────────────────────────────────────
          Row(children: [
            _kpiCard('Leads Captados', clientes.length,
                Icons.people_outline, cs.primary, cs),
            _kpiCard('Captadores', ranking.length,
                Icons.record_voice_over_outlined,
                Colors.teal.shade600, cs),
          ]),
          const SizedBox(height: 28),

          // ── Gráfico por dia da semana ────────────────────────────────
          _sectionTitle(context, 'Captações por Dia da Semana'),
          const SizedBox(height: 16),
          _buildGraficoDias(cs, porDia, maxY),
          const SizedBox(height: 28),

          // ── Ranking de captadores ────────────────────────────────────
          _sectionTitle(context, 'Ranking de Captadores'),
          const SizedBox(height: 12),
          if (ranking.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nenhum dado de captação neste período.',
                  style: TextStyle(color: cs.outline),
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: ranking.asMap().entries.map((e) {
                    final pos = e.key + 1;
                    final nome = e.value.key;
                    final qtd = e.value.value;
                    final maxQtd = ranking.first.value;
                    final pct = maxQtd == 0 ? 0.0 : qtd / maxQtd;

                    Color corMedalha = cs.outline;
                    if (pos == 1) corMedalha = Colors.amber.shade600;
                    if (pos == 2) corMedalha = Colors.blueGrey.shade400;
                    if (pos == 3) corMedalha = Colors.brown.shade400;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              '$pos°',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: corMedalha),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        nome,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '$qtd lead${qtd != 1 ? 's' : ''}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: cs.primary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    backgroundColor:
                                        cs.primary.withValues(alpha: 0.12),
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(cs.primary),
                                    minHeight: 6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Gráfico de barras por dia da semana ───────────────────────────────────
  Widget _buildGraficoDias(ColorScheme cs, List<int> porDia, double maxY) {
    if (porDia.every((v) => v == 0)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text('Nenhuma captação neste período.',
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
          7,
          (i) => BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: porDia[i].toDouble(),
              color: cs.primary,
              width: 22,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6)),
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
                if (i < 0 || i >= 7) return const Text('');
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child:
                      Text(_diasSemana[i], style: const TextStyle(fontSize: 11)),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => cs.primary,
            getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
              '${_diasSemana[gi]}\n${rod.toY.toInt()} lead${rod.toY.toInt() != 1 ? 's' : ''}',
              const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      )),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  Widget _kpiCard(String label, int valor, IconData icon, Color cor,
      ColorScheme cs) {
    return Expanded(
      child: Card(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: cor.withValues(alpha: 0.12),
                child: Icon(icon, color: cor, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
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
