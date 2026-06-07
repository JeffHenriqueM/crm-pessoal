import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../screens/lista_clientes_screen.dart';
import 'secao_recolhivel.dart';

class AbaRelatorios extends StatelessWidget {
  final List<Cliente> clientes;
  const AbaRelatorios({super.key, required this.clientes});

  static const _fasesAtivas = {
    FaseCliente.prospeccao,
    FaseCliente.contato,
    FaseCliente.negociacao,
    FaseCliente.visita,
  };

  List<Cliente> get _base =>
      clientes.where((c) => c.fase != FaseCliente.atendimento).toList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final todos = _base;
    final hoje = DateTime.now();
    final inicioDia = DateTime(hoje.year, hoje.month, hoje.day);

    // ── Funil ────────────────────────────────────────────────────────────
    const fasesFunil = [
      FaseCliente.prospeccao,
      FaseCliente.contato,
      FaseCliente.negociacao,
      FaseCliente.visita,
      FaseCliente.fechado,
    ];
    final contagem = {
      for (final f in fasesFunil) f: todos.where((c) => c.fase == f).length,
    };
    final totalFunil =
        fasesFunil.fold<int>(0, (s, f) => s + contagem[f]!);

    // ── Saúde da carteira ─────────────────────────────────────────────────
    final leadsAtivos =
        todos.where((c) => _fasesAtivas.contains(c.fase)).toList();

    final semContato = leadsAtivos.where((c) => c.proximoContato == null).length;
    final contatoVencido = leadsAtivos
        .where((c) =>
            c.proximoContato != null &&
            c.proximoContato!.isBefore(inicioDia))
        .length;
    final emRisco = leadsAtivos
        .where((c) =>
            c.dataAtualizacao
                .isBefore(hoje.subtract(const Duration(days: 7))))
        .length;

    // ── Taxa de avanço além de prospecção ─────────────────────────────────
    final avancaram =
        todos.where((c) => c.fase != FaseCliente.prospeccao).length;
    final totalPipeline = todos.length;
    final taxaAvanco =
        totalPipeline == 0 ? 0.0 : avancaram / totalPipeline * 100;

    // ── Leads esquecidos (sem interação há 14+ dias em fase ativa) ────────
    final esquecidos = leadsAtivos
        .where((c) => c.dataAtualizacao
            .isBefore(hoje.subtract(const Duration(days: 14))))
        .toList()
      ..sort((a, b) => a.dataAtualizacao.compareTo(b.dataAtualizacao));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Funil de conversão ────────────────────────────────────────
          SecaoRecolhivel(
            id: 'rel_funil',
            titulo: 'Funil de Conversão',
            icone: Icons.filter_alt_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Distribuição atual dos leads — toque para ver a lista',
                  style: TextStyle(fontSize: 12, color: cs.outline),
                ),
                const SizedBox(height: 16),
                _buildFunil(context, cs, fasesFunil, contagem, totalFunil),
                const SizedBox(height: 16),
                _buildTaxaAvanco(cs, taxaAvanco, avancaram, totalPipeline),
              ],
            ),
          ),

          // ── Saúde da carteira ─────────────────────────────────────────
          const SizedBox(height: 24),
          SecaoRecolhivel(
            id: 'rel_saude',
            titulo: 'Saúde da Carteira',
            icone: Icons.health_and_safety_outlined,
            child: Column(
              children: [
                _saudeCard(
                  cs,
                  icon: Icons.calendar_today_outlined,
                  cor: Colors.orange.shade700,
                  titulo: 'Sem próximo contato agendado',
                  valor: semContato,
                  descricao: 'leads ativos sem data de follow-up',
                ),
                _saudeCard(
                  cs,
                  icon: Icons.alarm_outlined,
                  cor: cs.error,
                  titulo: 'Contato vencido',
                  valor: contatoVencido,
                  descricao: 'leads com follow-up em atraso',
                ),
                _saudeCard(
                  cs,
                  icon: Icons.warning_amber_rounded,
                  cor: Colors.amber.shade700,
                  titulo: 'Em risco de esfriar',
                  valor: emRisco,
                  descricao: 'sem atualização há 7 dias ou mais',
                ),
              ],
            ),
          ),

          // ── Leads esquecidos ──────────────────────────────────────────
          if (esquecidos.isNotEmpty) ...[
            const SizedBox(height: 24),
            SecaoRecolhivel(
              id: 'rel_esquecidos',
              titulo: 'Leads Esquecidos',
              icone: Icons.hourglass_empty_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Leads ativos sem interação há 14 dias ou mais',
                    style: TextStyle(fontSize: 12, color: cs.outline),
                  ),
                  const SizedBox(height: 12),
                  ...esquecidos
                      .take(10)
                      .map((c) => _esquecidoCard(context, cs, c, hoje)),
                  if (esquecidos.length > 10)
                    Center(
                      child: TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ListaClientesScreen()),
                        ),
                        icon: const Icon(Icons.open_in_new, size: 14),
                        label: Text(
                            'Ver todos os ${esquecidos.length} esquecidos'),
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Funil com barras e taxa de conversão ──────────────────────────────────
  Widget _buildFunil(
    BuildContext context,
    ColorScheme cs,
    List<FaseCliente> fases,
    Map<FaseCliente, int> contagem,
    int total,
  ) {
    final cores = {
      FaseCliente.prospeccao: Colors.blueGrey,
      FaseCliente.contato: Colors.blue.shade600,
      FaseCliente.negociacao: Colors.orange.shade700,
      FaseCliente.visita: cs.primary,
      FaseCliente.fechado: Colors.green.shade700,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          children: fases.asMap().entries.map((e) {
            final fase = e.value;
            final qtd = contagem[fase]!;
            final pct = total == 0 ? 0.0 : qtd / total;
            final cor = cores[fase] ?? cs.primary;

            // Taxa de conversão para a próxima etapa
            String? taxaProxima;
            if (e.key < fases.length - 1) {
              final proxima = fases[e.key + 1];
              final qtdProxima = contagem[proxima]!;
              if (qtd > 0) {
                final t = (qtdProxima / qtd * 100).toStringAsFixed(0);
                taxaProxima = '→ $t% converteram para ${proxima.nomeDisplay}';
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ListaClientesScreen(faseInicial: fase)),
                ),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: cor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              fase.nomeDisplay,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                          Text(
                            '$qtd lead${qtd != 1 ? 's' : ''}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: cor,
                                fontSize: 13),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 36,
                            child: Text(
                              '${(pct * 100).toStringAsFixed(0)}%',
                              textAlign: TextAlign.right,
                              style:
                                  TextStyle(fontSize: 11, color: cs.outline),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right,
                              size: 14, color: cs.outline),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: cor.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(cor),
                          minHeight: 8,
                        ),
                      ),
                      if (taxaProxima != null) ...[
                        const SizedBox(height: 3),
                        Text(taxaProxima,
                            style: TextStyle(
                                fontSize: 10, color: cs.outline)),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Taxa de avanço ────────────────────────────────────────────────────────
  Widget _buildTaxaAvanco(
      ColorScheme cs, double taxa, int avancaram, int total) {
    final cor = taxa >= 50
        ? Colors.green.shade700
        : taxa >= 25
            ? Colors.orange.shade700
            : cs.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: cor.withValues(alpha: 0.12),
              child: Icon(Icons.trending_up, color: cor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Taxa de Avanço no Funil',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(
                    '${taxa.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: cor),
                  ),
                  Text(
                    '$avancaram de $total leads avançaram além de Prospecção',
                    style: TextStyle(fontSize: 11, color: cs.outline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card de saúde ─────────────────────────────────────────────────────────
  Widget _saudeCard(
    ColorScheme cs, {
    required IconData icon,
    required Color cor,
    required String titulo,
    required int valor,
    required String descricao,
  }) {
    final corValor = valor > 0 ? cor : Colors.green.shade700;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: (valor > 0 ? cor : Colors.green.shade700)
                  .withValues(alpha: 0.12),
              child: Icon(icon, color: valor > 0 ? cor : Colors.green.shade700,
                  size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(descricao,
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            Text(
              '$valor',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: corValor),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card de lead esquecido ────────────────────────────────────────────────
  Widget _esquecidoCard(
      BuildContext context, ColorScheme cs, Cliente c, DateTime hoje) {
    final dias = hoje.difference(c.dataAtualizacao).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ListaClientesScreen(faseInicial: c.fase)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: cs.errorContainer,
                child: Text(
                  c.nome.isNotEmpty ? c.nome[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: cs.onErrorContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.nome,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(
                      '${c.fase.nomeDisplay}'
                      '${c.vendedorNome?.isNotEmpty == true ? ' · ${c.vendedorNome}' : ''}',
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$dias dias',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: cs.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
