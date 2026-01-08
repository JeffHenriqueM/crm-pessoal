import 'package:crm_pessoal/screens/lista_clientes_screen.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/firestore_service.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import 'adicionar_cliente_screen.dart';

class DashboardScreen extends StatelessWidget {
  final FirestoreService _firestoreService = FirestoreService();

  DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CRM Villamor - Dashboard'),
        centerTitle: true,
        backgroundColor: const Color(0xFF673AB7),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdicionarClienteScreen()),
              );
            },
            tooltip: 'Novo Cliente',
          ),
          // Botão para Ver Lista/Kanban (Ícone alterado para "group")
          IconButton(
            icon: const Icon(Icons.group),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ListaClientesScreen()),
              );
            },
            tooltip: 'Ver Clientes',
          ),
        ],
      ),
      body: StreamBuilder<List<Cliente>>(
        stream: _firestoreService.getTodosClientesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum dado cadastrado.'));
          }

          final clientes = snapshot.data!;

          // Métricas principais
          int totalLeads = clientes.length;
          int visitasAgendadas = clientes.where((c) => c.dataVisita != null).length;
          int fechados = clientes.where((c) => c.fase == FaseCliente.fechado).length;
          int perdidos = clientes.where((c) => c.fase == FaseCliente.perdido).length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Resumo de Performance",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                Row(
                  children: [
                    _cardResumo("Total Leads", "$totalLeads", Colors.blue),
                    _cardResumo("Visitas", "$visitasAgendadas", Colors.orange),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    _cardResumo("Fechados", "$fechados", Colors.green),
                    _cardResumo("Perdidos", "$perdidos", Colors.red),
                  ],
                ),

                const SizedBox(height: 32),
                const Text("Origem dos Clientes",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: _gerarDadosPizza(clientes),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                const Text("Motivos de Perda (Estatísticas)",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("Somente motivos classificados via Dropdown",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 20),

                // GRÁFICO DE BARRAS ATUALIZADO (APENAS DADOS NOVOS)
                _buildBarChartMotivos(clientes),

                const SizedBox(height: 32),
                const Text("Funil de Vendas",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                ...FaseCliente.values.map((fase) {
                  int qtd = clientes.where((c) => c.fase == fase).length;
                  return _itemFunil(context, fase, qtd);
                }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _cardResumo(String label, String valor, Color cor) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(label, style: const TextStyle(color: Colors.grey)),
              Text(valor,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: cor)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemFunil(BuildContext context, FaseCliente fase, int qtd) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ListaClientesScreen(faseInicial: fase),
            ),
          );
        },
        title: Text(
          fase.nomeDisplay,
          style: const TextStyle(fontSize: 13),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("$qtd", style: const TextStyle(fontWeight: FontWeight.bold)),
            const Icon(Icons.chevron_right, size: 16),
          ],
        ),
        leading: Icon(Icons.align_horizontal_left,
            size: 16, color: Colors.deepPurple[200]),
      ),
    );
  }

  List<PieChartSectionData> _gerarDadosPizza(List<Cliente> clientes) {
    Map<String, int> contagem = {};
    for (var c in clientes) {
      String origem =
      (c.origem == null || c.origem!.isEmpty) ? "Não Informado" : c.origem!;
      contagem[origem] = (contagem[origem] ?? 0) + 1;
    }

    List<Color> cores = [
      Colors.deepPurple, Colors.blue, Colors.teal, Colors.amber, Colors.pink
    ];
    int i = 0;

    return contagem.entries.map((e) {
      final cor = cores[i % cores.length];
      i++;
      return PieChartSectionData(
        color: cor,
        value: e.value.toDouble(),
        title: '${e.key}\n${e.value}',
        radius: 50,
        titleStyle: const TextStyle(
            fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
      );
    }).toList();
  }

  Widget _buildBarChartMotivos(List<Cliente> clientes) {
    Map<String, int> contagemPerda = {};
    var perdidos = clientes.where((c) => c.fase == FaseCliente.perdido);

    for (var c in perdidos) {
      if (c.motivoNaoVendaDropdown != null && c.motivoNaoVendaDropdown!.isNotEmpty) {
        String motivo = c.motivoNaoVendaDropdown!;
        contagemPerda[motivo] = (contagemPerda[motivo] ?? 0) + 1;
      }
    }

    if (contagemPerda.isEmpty) {
      return const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              "Nenhum motivo classificado via Dropdown.\nEdite os clientes perdidos para ver o gráfico.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ));
    }

    List<String> labels = contagemPerda.keys.toList();

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (contagemPerda.values.reduce((a, b) => a > b ? a : b).toDouble() + 1),
          barGroups: List.generate(labels.length, (index) {
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: contagemPerda[labels[index]]!.toDouble(),
                  color: Colors.redAccent,
                  width: 22,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                )
              ],
            );
          }),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int idx = value.toInt();
                  if (idx >= 0 && idx < labels.length) {
                    String label = labels[idx];
                    if (label.length > 11) label = "${label.substring(0, 9)}..";
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.redAccent,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${labels[groupIndex]}\n${rod.toY.toInt()}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
