import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../models/usuario_model.dart';
import '../screens/lista_clientes_screen.dart';

// ── Modelo interno de stats por vendedor ────────────────────────────────────
class _VendedorStats {
  final String vendedorId;
  final String vendedorNome;
  final List<Cliente> clientes;

  _VendedorStats({
    required this.vendedorId,
    required this.vendedorNome,
    required this.clientes,
  });

  int get total => clientes.length;

  int get atrasados => clientes.where((c) {
        if (c.fase == FaseCliente.fechado || c.fase == FaseCliente.perdido) {
          return false;
        }
        return c.proximoContato != null &&
            c.proximoContato!.isBefore(DateTime.now());
      }).length;

  int get emNegociacao =>
      clientes.where((c) => c.fase == FaseCliente.negociacao).length;

  int get emVisita =>
      clientes.where((c) => c.fase == FaseCliente.visita).length;

  int get fechados =>
      clientes.where((c) => c.fase == FaseCliente.fechado).length;

  int get perdidos =>
      clientes.where((c) => c.fase == FaseCliente.perdido).length;

  int get ativos => clientes
      .where((c) =>
          c.fase != FaseCliente.fechado && c.fase != FaseCliente.perdido)
      .length;

  double get taxaConversao {
    final denom = fechados + perdidos;
    return denom == 0 ? 0 : (fechados / denom) * 100;
  }

  List<Cliente> get clientesAtrasados => clientes.where((c) {
        if (c.fase == FaseCliente.fechado || c.fase == FaseCliente.perdido) {
          return false;
        }
        return c.proximoContato != null &&
            c.proximoContato!.isBefore(DateTime.now());
      }).toList()
        ..sort((a, b) => a.proximoContato!.compareTo(b.proximoContato!));
}

// ── Widget principal ─────────────────────────────────────────────────────────
class AbaAdminOverview extends StatelessWidget {
  final List<Cliente> todosClientes;
  final List<Usuario> todosVendedores;

  const AbaAdminOverview({
    super.key,
    required this.todosClientes,
    required this.todosVendedores,
  });

  List<_VendedorStats> _calcularStats() {
    final map = <String, List<Cliente>>{};

    for (final c in todosClientes) {
      final vid = c.vendedorId ?? '__sem_vendedor__';
      map.putIfAbsent(vid, () => []).add(c);
    }

    final stats = <_VendedorStats>[];

    for (final v in todosVendedores) {
      final clientes = map[v.id] ?? [];
      stats.add(_VendedorStats(
        vendedorId: v.id,
        vendedorNome: v.nome,
        clientes: clientes,
      ));
    }

    // Clientes sem vendedor atribuído
    if (map.containsKey('__sem_vendedor__')) {
      stats.add(_VendedorStats(
        vendedorId: '__sem_vendedor__',
        vendedorNome: 'Sem vendedor',
        clientes: map['__sem_vendedor__']!,
      ));
    }

    // Ordena por número de leads ativos (desc)
    stats.sort((a, b) => b.ativos.compareTo(a.ativos));
    return stats;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stats = _calcularStats();

    final totalLeads = todosClientes.length;
    final totalAtrasados = stats.fold<int>(0, (s, v) => s + v.atrasados);
    final totalNegociacao = stats.fold<int>(0, (s, v) => s + v.emNegociacao);
    final totalFechados = stats.fold<int>(0, (s, v) => s + v.fechados);

    final statsComAtrasados = stats
        .where((s) => s.atrasados > 0)
        .toList()
      ..sort((a, b) => b.atrasados.compareTo(a.atrasados));

    final rankingFechados = [...stats]
      ..sort((a, b) => b.fechados.compareTo(a.fechados));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── KPIs Gerais ────────────────────────────────────────────────
          _sectionTitle(context, 'Resumo da Equipe'),
          const SizedBox(height: 12),
          _kpiRow(context, cs, totalLeads, totalAtrasados, totalNegociacao,
              totalFechados),

          // ── Alerta: Contatos Atrasados ─────────────────────────────────
          if (statsComAtrasados.isNotEmpty) ...[
            const SizedBox(height: 28),
            _alertaAtrasados(context, cs, statsComAtrasados),
          ],

          // ── Ranking de Fechamentos ────────────────────────────────────
          const SizedBox(height: 28),
          _sectionTitle(context, 'Ranking de Fechamentos'),
          const SizedBox(height: 12),
          _rankingFechamentos(context, cs, rankingFechados),

          // ── Cards por Vendedor ─────────────────────────────────────────
          const SizedBox(height: 28),
          _sectionTitle(context, 'Situação por Vendedor'),
          const SizedBox(height: 12),
          ...stats.map((s) => _vendedorCard(context, cs, s)),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Seção: KPIs gerais ────────────────────────────────────────────────────
  Widget _kpiRow(BuildContext context, ColorScheme cs, int totalLeads,
      int totalAtrasados, int totalNegociacao, int totalFechados) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 500) {
        // Linha com 4 cards
        return Row(
          children: [
            _kpiCard('Total Leads', '$totalLeads', Icons.people_outline,
                cs.primary, cs),
            _kpiCard(
                'Atrasados',
                '$totalAtrasados',
                Icons.warning_amber_rounded,
                totalAtrasados > 0 ? Colors.red.shade600 : Colors.green.shade600,
                cs),
            _kpiCard('Negociação', '$totalNegociacao',
                Icons.handshake_outlined, Colors.orange.shade700, cs),
            _kpiCard('Fechados', '$totalFechados', Icons.check_circle_outline,
                Colors.green.shade700, cs),
          ],
        );
      } else {
        return Column(
          children: [
            Row(children: [
              _kpiCard('Total Leads', '$totalLeads', Icons.people_outline,
                  cs.primary, cs),
              _kpiCard(
                  'Atrasados',
                  '$totalAtrasados',
                  Icons.warning_amber_rounded,
                  totalAtrasados > 0
                      ? Colors.red.shade600
                      : Colors.green.shade600,
                  cs),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _kpiCard('Negociação', '$totalNegociacao',
                  Icons.handshake_outlined, Colors.orange.shade700, cs),
              _kpiCard('Fechados', '$totalFechados',
                  Icons.check_circle_outline, Colors.green.shade700, cs),
            ]),
          ],
        );
      }
    });
  }

  Widget _kpiCard(
      String label, String valor, IconData icon, Color cor, ColorScheme cs) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: cor.withValues(alpha: 0.12),
                child: Icon(icon, color: cor, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    valor,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: cor,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(fontSize: 10, color: cs.outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Seção: Alerta de atrasados ────────────────────────────────────────────
  Widget _alertaAtrasados(
      BuildContext context, ColorScheme cs, List<_VendedorStats> stats) {
    const accentColor = Color(0xFFB45309); // amber-700 — profissional
    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Borda lateral de acento — sem fundo colorido
            Container(width: 4, color: accentColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time_outlined,
                            color: accentColor, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Contatos em atraso',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...stats.map((s) => _alertaVendedorRow(context, cs, s)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _alertaVendedorRow(
      BuildContext context, ColorScheme cs, _VendedorStats stats) {
    final primeiroAtrasado = stats.clientesAtrasados.isNotEmpty
        ? stats.clientesAtrasados.first
        : null;

    final diasAtraso = primeiroAtrasado?.proximoContato != null
        ? DateTime.now()
            .difference(primeiroAtrasado!.proximoContato!)
            .inDays
        : 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          _avatarVendedor(stats.vendedorNome, 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stats.vendedorNome,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                if (primeiroAtrasado != null)
                  Text(
                    'Mais antigo: ${primeiroAtrasado.nome} ($diasAtraso dias)',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${stats.atrasados} atrasado${stats.atrasados != 1 ? 's' : ''}',
              style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ── Seção: Ranking de fechamentos ─────────────────────────────────────────
  Widget _rankingFechamentos(
      BuildContext context, ColorScheme cs, List<_VendedorStats> ranking) {
    final maxFechados = ranking.isEmpty
        ? 1
        : ranking.first.fechados == 0
            ? 1
            : ranking.first.fechados;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: ranking.map((s) {
            final pct = s.fechados / maxFechados;
            final posicao = ranking.indexOf(s) + 1;
            Color medalha = cs.outline;
            if (posicao == 1) medalha = Colors.amber.shade600;
            if (posicao == 2) medalha = Colors.blueGrey.shade400;
            if (posicao == 3) medalha = Colors.brown.shade400;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '$posicao°',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: medalha,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _avatarVendedor(s.vendedorNome, 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                s.vendedorNome,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${s.fechados} fechado${s.fechados != 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor:
                                Colors.green.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.green.shade600),
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
    );
  }

  // ── Card por vendedor ─────────────────────────────────────────────────────
  Widget _vendedorCard(
      BuildContext context, ColorScheme cs, _VendedorStats s) {
    final temAlerta = s.atrasados > 0;
    const alertaColor = Color(0xFFB45309);

    final innerContent = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabeçalho do card ────────────────────────────────────────
          Row(
            children: [
              _avatarVendedor(s.vendedorNome, 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.vendedorNome,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      '${s.total} lead${s.total != 1 ? 's' : ''} no total',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (temAlerta)
                _tagAtrasados(
                    '${s.atrasados} atrasado${s.atrasados != 1 ? 's' : ''}',
                    cs),
              if (!temAlerta && s.total > 0) _tagEmDia(cs),
            ],
          ),

          const SizedBox(height: 16),

          // ── Métricas em grid ─────────────────────────────────────────
          LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth >= 450) {
              return Row(
                children: [
                  _metricaItem(
                      context,
                      'Prospecção',
                      s.clientes
                          .where((c) => c.fase == FaseCliente.prospeccao)
                          .length,
                      Colors.blueGrey,
                      cs),
                  _metricaItem(
                      context,
                      '1° Contato',
                      s.clientes
                          .where((c) => c.fase == FaseCliente.contato)
                          .length,
                      Colors.blue.shade600,
                      cs),
                  _metricaItem(context, 'Negociação', s.emNegociacao,
                      Colors.orange.shade700, cs),
                  _metricaItem(context, 'Visita', s.emVisita, cs.primary, cs),
                  _metricaItem(context, 'Fechados', s.fechados,
                      Colors.green.shade700, cs),
                  _metricaItem(context, 'Perdidos', s.perdidos, cs.error, cs),
                ],
              );
            } else {
              return Column(
                children: [
                  Row(children: [
                    _metricaItem(
                        context,
                        'Prospecção',
                        s.clientes
                            .where((c) => c.fase == FaseCliente.prospeccao)
                            .length,
                        Colors.blueGrey,
                        cs),
                    _metricaItem(
                        context,
                        '1° Contato',
                        s.clientes
                            .where((c) => c.fase == FaseCliente.contato)
                            .length,
                        Colors.blue.shade600,
                        cs),
                    _metricaItem(context, 'Negociação', s.emNegociacao,
                        Colors.orange.shade700, cs),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    _metricaItem(
                        context, 'Visita', s.emVisita, cs.primary, cs),
                    _metricaItem(context, 'Fechados', s.fechados,
                        Colors.green.shade700, cs),
                    _metricaItem(
                        context, 'Perdidos', s.perdidos, cs.error, cs),
                  ]),
                ],
              );
            }
          }),

          const SizedBox(height: 14),

          // ── Rodapé: conversão + link ─────────────────────────────────
          Row(
            children: [
              Icon(Icons.trending_up, size: 14, color: cs.outline),
              const SizedBox(width: 4),
              Text(
                'Taxa de conversão: ${s.taxaConversao.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const Spacer(),
              if (s.vendedorId != '__sem_vendedor__')
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ListaClientesScreen(
                          vendedorIdInicial: s.vendedorId),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label:
                      const Text('Ver leads', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    // Card com borda lateral de acento quando há atrasos
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: temAlerta
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: alertaColor),
                  Expanded(child: innerContent),
                ],
              ),
            )
          : innerContent,
    );
  }

  Widget _metricaItem(BuildContext context, String label, int valor, Color cor,
      ColorScheme cs) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$valor',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: cor,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9, color: cs.outline),
          ),
        ],
      ),
    );
  }

  // Tag discreta para "atrasados" — fundo neutro escuro, sem cor viva
  Widget _tagAtrasados(String text, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_outlined,
              size: 12, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // Tag "Em dia" — discreta e positiva
  Widget _tagEmDia(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline,
              size: 12, color: Colors.green.shade700),
          const SizedBox(width: 4),
          Text(
            'Em dia',
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarVendedor(String nome, double radius) {
    final inicial =
        nome.isNotEmpty ? nome[0].toUpperCase() : '?';
    final cores = [
      Colors.blue.shade700,
      Colors.teal.shade600,
      Colors.indigo.shade600,
      Colors.orange.shade700,
      Colors.green.shade700,
      Colors.cyan.shade700,
    ];
    final cor = cores[nome.codeUnits.first % cores.length];

    return CircleAvatar(
      radius: radius,
      backgroundColor: cor.withValues(alpha: 0.15),
      child: Text(
        inicial,
        style: TextStyle(
          color: cor,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.9,
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}
