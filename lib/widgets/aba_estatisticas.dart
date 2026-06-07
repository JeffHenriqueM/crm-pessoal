import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../screens/lista_clientes_screen.dart';
import '../widgets/filtro_periodo.dart';
import '../widgets/meta_mensal_card.dart';
import '../widgets/secao_recolhivel.dart';

class AbaEstatisticas extends StatefulWidget {
  final List<Cliente> clientes;

  /// Quando fornecido, exibe o MetaMensalCard no topo da aba (rola junto).
  final String? userId;

  /// Perfil do dono da aba — define os tipos de meta oferecidos no card.
  final String? perfil;

  const AbaEstatisticas(
      {super.key, required this.clientes, this.userId, this.perfil});

  @override
  State<AbaEstatisticas> createState() => _AbaEstatisticasState();
}

class _AbaEstatisticasState extends State<AbaEstatisticas> {
  FiltroPeriodo _filtro = const FiltroPeriodo(periodo: Periodo.tudo);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // O filtro de período aplica à data de cadastro — não afeta o card de meta.
    final clientes = widget.clientes
        .where((c) => _filtro.contem(c.dataCadastro))
        .toList();

    final total = clientes.length;
    final visitasAgendadas = clientes.where((c) => c.dataVisita != null).length;
    final fechados = clientes.where((c) => c.fase == FaseCliente.fechado).length;
    final perdidos = clientes.where((c) => c.fase == FaseCliente.perdido).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meta mensal do vendedor (só quando userId é fornecido) — sempre
          // sobre a lista completa, independente do filtro de período.
          if (widget.userId != null) ...[
            MetaMensalCard(
                userId: widget.userId!,
                clientes: widget.clientes,
                perfil: widget.perfil),
            const SizedBox(height: 20),
          ],

          // ── Filtro de período ────────────────────────────────────────────
          FiltroPeriodoBar(
            filtro: _filtro,
            onChanged: (f) => setState(() => _filtro = f),
            legenda: 'Filtro aplica à data de cadastro dos leads',
          ),
          const SizedBox(height: 20),

          SecaoRecolhivel(
            id: 'estat_resumo',
            titulo: 'Resumo Geral',
            icone: Icons.insights_outlined,
            child: Column(children: [
              Row(children: [
                _kpiCard('Total Leads', '$total', Icons.people_outline,
                    cs.primary, cs),
                _kpiCard('Visitas', '$visitasAgendadas',
                    Icons.location_on_outlined, Colors.orange.shade700, cs),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _kpiCard('Fechados', '$fechados', Icons.check_circle_outline,
                    Colors.green.shade700, cs),
                _kpiCard('Perdidos', '$perdidos', Icons.cancel_outlined,
                    cs.error, cs),
              ]),
            ]),
          ),
          const SizedBox(height: 24),
          SecaoRecolhivel(
            id: 'estat_origem',
            titulo: 'Origem dos Clientes',
            icone: Icons.pie_chart_outline,
            child: SizedBox(
              height: 220,
              child: PieChart(PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 48,
                sections: _gerarDadosPizza(clientes, cs),
              )),
            ),
          ),
          const SizedBox(height: 24),
          SecaoRecolhivel(
            id: 'estat_motivos',
            titulo: 'Motivos de Perda',
            icone: Icons.do_not_disturb_alt_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Apenas motivos classificados via dropdown',
                  style: TextStyle(fontSize: 12, color: cs.outline),
                ),
                const SizedBox(height: 16),
                _buildBarChartMotivos(clientes, cs),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SecaoRecolhivel(
            id: 'estat_funil',
            titulo: 'Funil de Vendas',
            icone: Icons.filter_alt_outlined,
            child: Column(
              children: FaseCliente.values
                  .where((f) => f != FaseCliente.atendimento)
                  .map(
                    (fase) => _itemFunil(context, fase,
                        clientes.where((c) => c.fase == fase).length, total, cs),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _kpiCard(
      String label, String valor, IconData icon, Color cor, ColorScheme cs) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: cor.withValues(alpha: 0.12),
                child: Icon(icon, color: cor, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    valor,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: cor,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(fontSize: 11, color: cs.outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemFunil(BuildContext context, FaseCliente fase, int qtd, int total,
      ColorScheme cs) {
    final cor = _corDeFase(fase, cs);
    final pct = total == 0 ? 0.0 : qtd / total;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ListaClientesScreen(faseInicial: fase)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(fase.nomeDisplay,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Row(
                    children: [
                      Text('$qtd',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: cor)),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 16, color: cs.outline),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: cor.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(cor),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _corDeFase(FaseCliente fase, ColorScheme cs) {
    switch (fase) {
      case FaseCliente.atendimento:
        return Colors.blueGrey.shade400;
      case FaseCliente.prospeccao:
        return Colors.blueGrey;
      case FaseCliente.contato:
        return Colors.blue.shade600;
      case FaseCliente.negociacao:
        return Colors.orange.shade700;
      case FaseCliente.visita:
        return cs.primary;
      case FaseCliente.fechado:
        return Colors.green.shade700;
      case FaseCliente.perdido:
        return cs.error;
    }
  }

  List<PieChartSectionData> _gerarDadosPizza(
      List<Cliente> clientes, ColorScheme cs) {
    final contagem = <String, int>{};
    for (final c in clientes) {
      final origem =
          (c.origem == null || c.origem!.isEmpty) ? 'Não informado' : c.origem!;
      contagem[origem] = (contagem[origem] ?? 0) + 1;
    }

    if (contagem.isEmpty) {
      return [
        PieChartSectionData(
          color: Colors.grey.shade300,
          value: 1,
          title: 'Sem dados',
          radius: 55,
          titleStyle: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        )
      ];
    }

    final cores = [
      Colors.blue.shade700,
      Colors.orange.shade600,
      Colors.green.shade600,
      Colors.indigo.shade500,
      Colors.teal.shade500,
      Colors.purple.shade500,
    ];
    int i = 0;

    return contagem.entries.map((e) {
      final cor = cores[i % cores.length];
      i++;
      return PieChartSectionData(
        color: cor,
        value: e.value.toDouble(),
        title: '${e.key}\n${e.value}',
        radius: 55,
        titleStyle: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      );
    }).toList();
  }

  Widget _buildBarChartMotivos(List<Cliente> clientes, ColorScheme cs) {
    final contagem = <String, int>{};
    for (final c in clientes.where((c) => c.fase == FaseCliente.perdido)) {
      final motivo = c.motivoNaoVendaDropdown;
      if (motivo != null && motivo.isNotEmpty) {
        contagem[motivo] = (contagem[motivo] ?? 0) + 1;
      }
    }

    if (contagem.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Nenhum motivo registrado via dropdown.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.outline, fontSize: 13),
          ),
        ),
      );
    }

    final labels = contagem.keys.toList();
    final maxY =
        (contagem.values.reduce((a, b) => a > b ? a : b).toDouble() + 1);

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barGroups: List.generate(labels.length, (i) {
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: contagem[labels[i]]!.toDouble(),
                color: cs.error,
                width: 22,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              )
            ]);
          }),
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
                  var label = labels[i];
                  if (label.length > 10) label = '${label.substring(0, 8)}..';
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(label, style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => cs.error,
              getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                '${labels[gi]}\n${rod.toY.toInt()}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
