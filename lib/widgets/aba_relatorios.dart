import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/atividade_interacao.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../models/interacao_model.dart' show Canal, CanalExt;
import '../models/usuario_model.dart';
import '../services/firestore_service.dart';
import '../screens/lista_clientes_screen.dart';
import 'filtro_periodo.dart';
import 'secao_recolhivel.dart';

/// Indicadores que o usuário pode ligar/desligar no relatório do período.
enum _Metrica {
  mensagens,
  atrasadas,
  contatados,
  atendimentos,
  vendas,
  valor,
  taxaResposta,
}

extension _MetricaInfo on _Metrica {
  String get rotulo {
    switch (this) {
      case _Metrica.mensagens:    return 'Mensagens enviadas';
      case _Metrica.atrasadas:    return 'Mensagens atrasadas';
      case _Metrica.contatados:   return 'Clientes contatados';
      case _Metrica.atendimentos: return 'Atendimentos';
      case _Metrica.vendas:       return 'Vendas';
      case _Metrica.valor:        return 'Valor vendido';
      case _Metrica.taxaResposta: return 'Taxa de resposta';
    }
  }

  IconData get icone {
    switch (this) {
      case _Metrica.mensagens:    return Icons.send_outlined;
      case _Metrica.atrasadas:    return Icons.schedule_outlined;
      case _Metrica.contatados:   return Icons.people_alt_outlined;
      case _Metrica.atendimentos: return Icons.meeting_room_outlined;
      case _Metrica.vendas:       return Icons.check_circle_outline;
      case _Metrica.valor:        return Icons.attach_money;
      case _Metrica.taxaResposta: return Icons.reply_all_outlined;
    }
  }
}

class AbaRelatorios extends StatefulWidget {
  final List<Cliente> clientes;

  /// Quando informado (perfil vendedor), o relatório conta apenas a atividade
  /// desse usuário (mensagens que ele registrou). Nulo = visão da equipe (admin).
  final String? vendedorId;

  /// Lista de vendedores para o filtro interno do admin. Vazia = sem filtro
  /// (perfil vendedor). Não-vazia = mostra o seletor "Geral / por vendedor".
  final List<Usuario> todosVendedores;

  const AbaRelatorios({
    super.key,
    required this.clientes,
    this.vendedorId,
    this.todosVendedores = const [],
  });

  @override
  State<AbaRelatorios> createState() => _AbaRelatoriosState();
}

class _AbaRelatoriosState extends State<AbaRelatorios> {
  final _service = FirestoreService();

  /// Definido no início de [build]. Usado por [_legivel] para clarear as cores
  /// de destaque quando usadas em TEXTO no tema escuro (senão ficam ilegíveis).
  bool _isDark = false;

  /// Garante contraste de leitura para uma cor de destaque usada em texto.
  /// No dark mode, clareia cores escuras preservando o tom; no light, devolve
  /// a cor original.
  Color _legivel(Color base) {
    if (!_isDark) return base;
    final hsl = HSLColor.fromColor(base);
    if (hsl.lightness >= 0.62) return base;
    return hsl.withLightness(0.72).toColor();
  }

  FiltroPeriodo _filtro = const FiltroPeriodo(periodo: Periodo.semana);

  /// Vendedor selecionado no filtro do admin. Nulo = visão geral (empresa).
  String? _filtroVendedorId;

  /// Escopo efetivo de UID: admin usa o filtro interno; vendedor usa o seu fixo.
  String? get _escopoId =>
      widget.todosVendedores.isNotEmpty ? _filtroVendedorId : widget.vendedorId;

  /// True se o lead "pertence" ao usuário [uid] em qualquer papel (vendedor,
  /// captador, liner ou criador) — base dos filtros de atendimentos/carteira.
  bool _pertenceAo(Cliente c, String uid) =>
      c.vendedorId == uid ||
      c.captadorId == uid ||
      c.linerId == uid ||
      c.criadoPorId == uid;

  // Todos os indicadores ligados por padrão.
  final Set<_Metrica> _ativas = {..._Metrica.values};

  static final _moeda =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);

  static const _fasesAtivas = {
    FaseCliente.prospeccao,
    FaseCliente.contato,
    FaseCliente.negociacao,
    FaseCliente.visita,
  };

  List<Cliente> get _base {
    final esc = _escopoId;
    return widget.clientes
        .where((c) =>
            c.fase != FaseCliente.atendimento &&
            (esc == null || _pertenceAo(c, esc)))
        .toList();
  }

  /// Data em que o cliente passou pela recepção (base do indicador
  /// "Atendimentos"). `dataEntradaSala` é o ideal; cai para `dataCadastro`
  /// quando o lead ainda está em "atendimento" mas não tem a entrada gravada.
  DateTime? _dataAtendimento(Cliente c) =>
      c.dataEntradaSala ??
      (c.fase == FaseCliente.atendimento ? c.dataCadastro : null);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    _isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Relatório do período ──────────────────────────────────────
          Row(
            children: [
              Icon(Icons.analytics_outlined, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              const Text('Relatório do Período',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          // Filtro por vendedor (somente admin) — "Geral" + cada vendedor.
          if (widget.todosVendedores.isNotEmpty) _buildFiltroVendedor(cs),
          FiltroPeriodoBar(
            filtro: _filtro,
            onChanged: (f) => setState(() => _filtro = f),
            legenda: 'Conta pela data de cada evento no período',
          ),
          const SizedBox(height: 16),

          // Seletor de indicadores
          Text('Indicadores — toque para mostrar/ocultar',
              style: TextStyle(fontSize: 12, color: cs.outline)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _Metrica.values.map((m) {
              final ativo = _ativas.contains(m);
              return FilterChip(
                label: Text(m.rotulo),
                selected: ativo,
                avatar: Icon(m.icone,
                    size: 16,
                    color: ativo ? cs.onSecondaryContainer : cs.outline),
                onSelected: (_) => setState(() {
                  ativo ? _ativas.remove(m) : _ativas.add(m);
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Cards do período (depende do stream de atividades de interação)
          StreamBuilder<List<AtividadeInteracao>>(
            stream:
                _service.getAtividadeInteracoesStream(autorId: _escopoId),
            builder: (context, snap) {
              final carregando =
                  snap.connectionState == ConnectionState.waiting &&
                      !snap.hasData;
              final atividades = snap.data ?? const <AtividadeInteracao>[];
              return _buildPainelPeriodo(context, cs, atividades, carregando);
            },
          ),

          // ── Visão atual da carteira (não depende do período) ──────────
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 12),
          Text('Visão atual da carteira',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('Retrato de agora — não muda com o filtro acima',
              style: TextStyle(fontSize: 11, color: cs.outline)),
          const SizedBox(height: 16),
          _buildVisaoAtual(context, cs),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Filtro por vendedor (admin) ───────────────────────────────────────────
  Widget _buildFiltroVendedor(ColorScheme cs) {
    final selecionado = _filtroVendedorId == null
        ? null
        : widget.todosVendedores
            .where((v) => v.id == _filtroVendedorId)
            .firstOrNull;
    final ativo = _filtroVendedorId != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text('Visão:',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          const SizedBox(width: 8),
          PopupMenuButton<String?>(
            tooltip: 'Filtrar por vendedor',
            offset: const Offset(0, 36),
            onSelected: (v) => setState(() => _filtroVendedorId = v),
            itemBuilder: (_) => [
              PopupMenuItem<String?>(
                value: null,
                child: Row(children: [
                  Icon(Icons.business_outlined,
                      size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Geral (empresa)')),
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
                          style: TextStyle(
                              fontSize: 10, color: cs.onPrimaryContainer),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child:
                              Text(v.nome, overflow: TextOverflow.ellipsis)),
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
                color:
                    ativo ? cs.primaryContainer : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(ativo ? Icons.person_outlined : Icons.business_outlined,
                      size: 15,
                      color: ativo
                          ? cs.onPrimaryContainer
                          : cs.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Text(
                    selecionado != null
                        ? selecionado.nome.split(' ').first
                        : 'Geral',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: ativo
                          ? cs.onPrimaryContainer
                          : cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.arrow_drop_down_rounded,
                      size: 18,
                      color: ativo
                          ? cs.onPrimaryContainer
                          : cs.onSurfaceVariant),
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

  // ── Painel do período (cards + canais) ────────────────────────────────────
  Widget _buildPainelPeriodo(
    BuildContext context,
    ColorScheme cs,
    List<AtividadeInteracao> atividades,
    bool carregando,
  ) {
    // Interações dentro do período selecionado.
    final noPeriodo =
        atividades.where((a) => _filtro.contem(a.dataInteracao)).toList();
    final mensagens = noPeriodo.length;
    final contatados = noPeriodo.map((a) => a.clienteId).toSet().length;
    final comResposta = noPeriodo.where((a) => a.houveResposta).length;
    final taxaResposta =
        mensagens == 0 ? 0.0 : comResposta / mensagens * 100;

    // Métricas derivadas dos leads (não dependem do stream).
    final esc = _escopoId;
    // Atendimentos: leads que a pessoa conduziu/captou (ou todos, no geral).
    final atendimentos = widget.clientes.where((c) {
      if (esc != null && !_pertenceAo(c, esc)) return false;
      final d = _dataAtendimento(c);
      return d != null && _filtro.contem(d);
    }).length;

    // Mensagens atrasadas: follow-up (proximoContato) vencido e AINDA em aberto
    // — mesma regra do badge "atrasado" do kanban. "Desse mês" sai do filtro:
    // conta as que venceram dentro do período selecionado e seguem no passado.
    final hojeInicio = DateTime(DateTime.now().year, DateTime.now().month,
        DateTime.now().day);
    final atrasadas = widget.clientes.where((c) {
      if (esc != null && !_pertenceAo(c, esc)) return false;
      final p = c.proximoContato;
      return p != null && p.isBefore(hojeInicio) && _filtro.contem(p);
    }).length;

    // Vendas: contam para o vendedor que FECHOU (vendedorId).
    final vendasList = widget.clientes
        .where((c) =>
            (esc == null || c.vendedorId == esc) &&
            c.fase == FaseCliente.fechado &&
            _filtro.contem(c.dataFechamento))
        .toList();
    final vendas = vendasList.length;
    final valorVendido =
        vendasList.fold<double>(0, (s, c) => s + (c.valorVendido ?? 0));

    final cards = <Widget>[
      if (_ativas.contains(_Metrica.mensagens))
        _statCard(cs,
            metrica: _Metrica.mensagens,
            cor: const Color(0xFF25D366),
            valor: '$mensagens',
            sub: 'interações registradas',
            carregando: carregando),
      if (_ativas.contains(_Metrica.atrasadas))
        _statCard(cs,
            metrica: _Metrica.atrasadas,
            cor: Colors.red.shade600,
            valor: '$atrasadas',
            sub: 'follow-up vencido e em aberto'),
      if (_ativas.contains(_Metrica.contatados))
        _statCard(cs,
            metrica: _Metrica.contatados,
            cor: Colors.blue.shade600,
            valor: '$contatados',
            sub: 'clientes distintos',
            carregando: carregando),
      if (_ativas.contains(_Metrica.atendimentos))
        _statCard(cs,
            metrica: _Metrica.atendimentos,
            cor: Colors.teal.shade600,
            valor: '$atendimentos',
            sub: 'passaram pela recepção'),
      if (_ativas.contains(_Metrica.vendas))
        _statCard(cs,
            metrica: _Metrica.vendas,
            cor: Colors.green.shade700,
            valor: '$vendas',
            sub: 'leads fechados'),
      if (_ativas.contains(_Metrica.valor))
        _statCard(cs,
            metrica: _Metrica.valor,
            cor: Colors.green.shade800,
            valor: _moeda.format(valorVendido),
            sub: 'somado nas vendas'),
      if (_ativas.contains(_Metrica.taxaResposta))
        _statCard(cs,
            metrica: _Metrica.taxaResposta,
            cor: Colors.deepPurple.shade400,
            valor: '${taxaResposta.toStringAsFixed(0)}%',
            sub: '$comResposta de $mensagens com resposta',
            carregando: carregando),
    ];

    if (cards.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text('Selecione ao menos um indicador acima.',
                style: TextStyle(color: cs.outline)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            // 2 colunas em telas estreitas, 3 em telas largas.
            final colunas = c.maxWidth >= 560 ? 3 : 2;
            const gap = 8.0;
            final largura = (c.maxWidth - gap * (colunas - 1)) / colunas;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: cards
                  .map((w) => SizedBox(width: largura, child: w))
                  .toList(),
            );
          },
        ),
        if (_ativas.contains(_Metrica.mensagens) && mensagens > 0) ...[
          const SizedBox(height: 16),
          _buildCanais(cs, noPeriodo, mensagens),
        ],
      ],
    );
  }

  Widget _statCard(
    ColorScheme cs, {
    required _Metrica metrica,
    required Color cor,
    required String valor,
    required String sub,
    bool carregando = false,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(metrica.icone, size: 16, color: _legivel(cor)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(metrica.rotulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            carregando
                ? const SizedBox(
                    height: 26,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  )
                : Text(valor,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _legivel(cor))),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(fontSize: 10, color: cs.outline)),
          ],
        ),
      ),
    );
  }

  // ── Quebra por canal ──────────────────────────────────────────────────────
  Widget _buildCanais(
      ColorScheme cs, List<AtividadeInteracao> noPeriodo, int total) {
    final contagem = <Canal, int>{};
    for (final a in noPeriodo) {
      contagem[a.canal] = (contagem[a.canal] ?? 0) + 1;
    }
    final ordenado = contagem.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mensagens por canal',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            ...ordenado.map((e) {
              final pct = total == 0 ? 0.0 : e.value / total;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(e.key.icone, size: 14, color: _legivel(e.key.cor)),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(e.key.nome,
                                style: const TextStyle(fontSize: 12))),
                        Text('${e.value}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _legivel(e.key.cor))),
                        const SizedBox(width: 6),
                        Text('${(pct * 100).toStringAsFixed(0)}%',
                            style:
                                TextStyle(fontSize: 11, color: cs.outline)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: e.key.cor.withValues(alpha: 0.12),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(e.key.cor),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Visão atual da carteira (funil + saúde + esquecidos) ──────────────────
  Widget _buildVisaoAtual(BuildContext context, ColorScheme cs) {
    final todos = _base;
    final hoje = DateTime.now();
    final inicioDia = DateTime(hoje.year, hoje.month, hoje.day);

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
    final totalFunil = fasesFunil.fold<int>(0, (s, f) => s + contagem[f]!);

    final leadsAtivos =
        todos.where((c) => _fasesAtivas.contains(c.fase)).toList();
    final semContato =
        leadsAtivos.where((c) => c.proximoContato == null).length;
    final contatoVencido = leadsAtivos
        .where((c) =>
            c.proximoContato != null &&
            c.proximoContato!.isBefore(inicioDia))
        .length;
    final emRisco = leadsAtivos
        .where((c) =>
            c.dataAtualizacao.isBefore(hoje.subtract(const Duration(days: 7))))
        .length;

    final avancaram =
        todos.where((c) => c.fase != FaseCliente.prospeccao).length;
    final totalPipeline = todos.length;
    final taxaAvanco =
        totalPipeline == 0 ? 0.0 : avancaram / totalPipeline * 100;

    final esquecidos = leadsAtivos
        .where((c) => c.dataAtualizacao
            .isBefore(hoje.subtract(const Duration(days: 14))))
        .toList()
      ..sort((a, b) => a.dataAtualizacao.compareTo(b.dataAtualizacao));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
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
                                color: _legivel(cor),
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
                          fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(
                    '${taxa.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _legivel(cor)),
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
              child: Icon(icon,
                  color: valor > 0 ? cor : Colors.green.shade700, size: 20),
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
                  color: _legivel(corValor)),
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
