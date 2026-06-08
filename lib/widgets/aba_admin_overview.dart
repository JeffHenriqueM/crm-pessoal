import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../models/usuario_model.dart';
import '../screens/lista_clientes_screen.dart';
import 'secao_recolhivel.dart';

// ── Modelo interno de stats por vendedor ────────────────────────────────────
class _VendedorStats {
  final String vendedorId;
  final String vendedorNome;
  final List<Cliente> clientes;
  final int? metaMensal;

  _VendedorStats({
    required this.vendedorId,
    required this.vendedorNome,
    required this.clientes,
    this.metaMensal,
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

  int get fechadosMes {
    final agora = DateTime.now();
    final inicioMes = DateTime(agora.year, agora.month, 1);
    return clientes
        .where((c) =>
            c.fase == FaseCliente.fechado &&
            !c.dataAtualizacao.isBefore(inicioMes))
        .length;
  }

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
class AbaAdminOverview extends StatefulWidget {
  final List<Cliente> todosClientes;
  final List<Usuario> todosVendedores;

  const AbaAdminOverview({
    super.key,
    required this.todosClientes,
    required this.todosVendedores,
  });

  @override
  State<AbaAdminOverview> createState() => _AbaAdminOverviewState();
}

class _AbaAdminOverviewState extends State<AbaAdminOverview> {
  String? _filtroVendedorId;

  List<_VendedorStats> _calcularStats() {
    final map = <String, List<Cliente>>{};

    for (final c in widget.todosClientes) {
      final vid = c.vendedorId ?? '__sem_vendedor__';
      map.putIfAbsent(vid, () => []).add(c);
    }

    final stats = <_VendedorStats>[];

    for (final v in widget.todosVendedores) {
      final clientes = map[v.id] ?? [];
      stats.add(_VendedorStats(
        vendedorId: v.id,
        vendedorNome: v.nome,
        clientes: clientes,
        // Mostra a meta de fechamentos (novo mapa) com fallback ao campo legado.
        metaMensal: v.metas['fechamentos']?.toInt() ?? v.metaMensal,
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
    final todoStats = _calcularStats();

    // Aplica filtro de vendedor
    final stats = _filtroVendedorId == null
        ? todoStats
        : todoStats.where((s) => s.vendedorId == _filtroVendedorId).toList();

    final totalLeads = stats.fold<int>(0, (s, v) => s + v.total);
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
          // ── Filtro de vendedor ─────────────────────────────────────────
          if (widget.todosVendedores.isNotEmpty)
            _buildFiltroVendedor(cs),

          // ── KPIs Gerais ────────────────────────────────────────────────
          SecaoRecolhivel(
            id: 'equipe_resumo',
            titulo: 'Resumo da Equipe',
            icone: Icons.groups_outlined,
            child: _kpiRow(context, cs, totalLeads, totalAtrasados,
                totalNegociacao, totalFechados),
          ),

          // ── Alerta: Contatos Atrasados ─────────────────────────────────
          if (statsComAtrasados.isNotEmpty) ...[
            const SizedBox(height: 20),
            _alertaAtrasados(context, cs, statsComAtrasados),
          ],

          // ── Ranking de Fechamentos ────────────────────────────────────
          const SizedBox(height: 20),
          SecaoRecolhivel(
            id: 'equipe_ranking',
            titulo: 'Ranking de Fechamentos',
            icone: Icons.emoji_events_outlined,
            child: _rankingFechamentos(context, cs, rankingFechados),
          ),

          // ── Cards por Vendedor ─────────────────────────────────────────
          const SizedBox(height: 20),
          SecaoRecolhivel(
            id: 'equipe_vendedores',
            titulo: 'Situação por Vendedor',
            icone: Icons.badge_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: stats.map((s) => _vendedorCard(context, cs, s)).toList(),
            ),
          ),

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

          // ── Meta mensal (se definida) ─────────────────────────────────
          if (s.metaMensal != null) ...[
            _metaProgressRow(cs, s),
            const SizedBox(height: 10),
          ],

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

  Widget _metaProgressRow(ColorScheme cs, _VendedorStats s) {
    final meta = s.metaMensal!;
    final fechados = s.fechadosMes;
    final pct = (meta == 0 ? 0.0 : fechados / meta).clamp(0.0, 1.0);
    final atingiu = fechados >= meta;
    final corMeta = atingiu
        ? Colors.green.shade600
        : pct >= 0.7
            ? Colors.orange.shade600
            : cs.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flag_outlined, size: 13, color: cs.outline),
            const SizedBox(width: 4),
            Text(
              'Meta do mês: $fechados/$meta fechamento${meta != 1 ? 's' : ''}',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            if (atingiu) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_circle, size: 13, color: Colors.green.shade600),
            ],
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: corMeta.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(corMeta),
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  // ── Filtro de vendedor (inline na aba) ───────────────────────────────────
  Widget _buildFiltroVendedor(ColorScheme cs) {
    final selecionado = _filtroVendedorId == null
        ? null
        : widget.todosVendedores
            .where((v) => v.id == _filtroVendedorId)
            .firstOrNull;
    final ativo = _filtroVendedorId != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Text(
            'Filtrar:',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String?>(
            tooltip: 'Filtrar por vendedor',
            offset: const Offset(0, 36),
            onSelected: (v) => setState(() => _filtroVendedorId = v),
            itemBuilder: (_) => [
              PopupMenuItem<String?>(
                value: null,
                child: Row(children: [
                  Icon(Icons.people_outlined, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Todos')),
                  if (!ativo) Icon(Icons.check, size: 16, color: cs.primary),
                ]),
              ),
              const PopupMenuDivider(),
              ...widget.todosVendedores.map((v) => PopupMenuItem<String?>(
                    value: v.id,
                    child: Row(children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: cs.primaryContainer,
                        child: Text(
                          v.nome.isNotEmpty ? v.nome[0].toUpperCase() : '?',
                          style: TextStyle(fontSize: 10, color: cs.onPrimaryContainer),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(v.nome, overflow: TextOverflow.ellipsis)),
                      if (_filtroVendedorId == v.id) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.check, size: 16, color: cs.primary),
                      ],
                    ]),
                  )),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ativo ? cs.primaryContainer : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_outlined,
                      size: 15,
                      color: ativo ? cs.onPrimaryContainer : cs.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Text(
                    selecionado != null
                        ? selecionado.nome.split(' ').first
                        : 'Todos',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: ativo ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.arrow_drop_down_rounded,
                      size: 18,
                      color: ativo ? cs.onPrimaryContainer : cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
          if (ativo) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _filtroVendedorId = null),
              child: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

}
