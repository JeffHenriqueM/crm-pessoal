import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/contrato_model.dart';
import '../models/cota_model.dart';
import '../models/imovel_model.dart';
import '../screens/ficha_contrato_screen.dart';
import '../services/analise_imoveis.dart';
import '../services/analise_vendas.dart';
import '../services/firestore_service.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _moedaCompacta = NumberFormat.compactCurrency(
  locale: 'pt_BR',
  symbol: 'R\$',
  decimalDigits: 1,
);

const _ordemBlocos = ['B', 'C', 'BANGALO'];
const _ordemPavimentos = ['terreo', '1', '2', '3', '4', '5', 'unico'];
const _ordemTiers = [
  TierCota.bronze,
  TierCota.prata,
  TierCota.ouro,
  TierCota.diamante,
  TierCota.integral,
];

/// Aba "Análise" da Pós-Venda: espelho de venda (disponibilidade), cotas,
/// vendas e saúde dos dados. Calcula tudo a partir do inventário (`imoveis`)
/// cruzado com os `contratos`, via lógica pura em `analise_imoveis.dart`.
class AbaAnaliseImoveis extends StatefulWidget {
  final String userProfile;
  const AbaAnaliseImoveis({super.key, required this.userProfile});

  @override
  State<AbaAnaliseImoveis> createState() => _AbaAnaliseImoveisState();
}

class _AbaAnaliseImoveisState extends State<AbaAnaliseImoveis> {
  final _fs = FirestoreService();
  int _secao = 0;
  bool _ocupado = false;

  bool get _podeAdmin =>
      widget.userProfile == 'admin' || widget.userProfile == 'super admin';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Imovel>>(
      stream: _fs.getImoveisStream(),
      builder: (context, snapImoveis) {
        if (snapImoveis.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final imoveis = snapImoveis.data ?? [];
        if (imoveis.isEmpty) return _buildVazio(context);

        return StreamBuilder<List<Contrato>>(
          stream: _fs.getContratosStream(),
          builder: (context, snapContratos) {
            final contratos = snapContratos.data ?? [];
            final resumo = analisarEmpreendimento(imoveis, contratos);
            final contratosPorId = {
              for (final c in contratos) c.localizador: c,
            };
            return _buildConteudo(context, resumo, contratos, contratosPorId);
          },
        );
      },
    );
  }

  // ── Estado vazio: inventário ainda não semeado ──────────────────────────
  Widget _buildVazio(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.apartment_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text('Inventário ainda não gerado', style: tt.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Crie as 228 unidades da 1ª etapa (Bloco B, Bloco C e 12 bangalôs).',
              textAlign: TextAlign.center,
              style: tt.bodySmall,
            ),
            const SizedBox(height: 16),
            if (_podeAdmin)
              FilledButton.icon(
                onPressed: _ocupado ? null : _gerarInventario,
                icon: const Icon(Icons.add_business_outlined),
                label: const Text('Gerar inventário'),
              )
            else
              Text('Peça a um administrador para gerar o inventário.',
                  style: tt.bodySmall?.copyWith(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildConteudo(
    BuildContext context,
    ResumoAnalise r,
    List<Contrato> contratos,
    Map<String, Contrato> contratosPorId,
  ) {
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        // Total de unidades no topo.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              Text('${r.totalUnidades} unidades',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        // Seletor de seção
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              _chipSecao(0, 'Espelho de venda', Icons.grid_view_outlined),
              _chipSecao(1, 'Cotas', Icons.pie_chart_outline),
              _chipSecao(2, 'Vendas', Icons.attach_money_outlined),
              _chipSecao(3, 'Saúde dos dados', Icons.health_and_safety_outlined,
                  alerta: r.avulsos.isNotEmpty || r.comAlerta.isNotEmpty),
              _chipSecao(4, 'Dados', Icons.query_stats_outlined),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: switch (_secao) {
            0 => _SecaoEspelho(resumo: r, contratosPorId: contratosPorId),
            1 => _SecaoCotas(resumo: r),
            2 => _SecaoVendas(resumo: r, contratos: contratos),
            3 => _SecaoSaude(resumo: r),
            _ => _SecaoDados(resumo: r, contratos: contratos),
          },
        ),
      ],
    );
  }

  Widget _chipSecao(int idx, String label, IconData icon, {bool alerta = false}) {
    final cs = Theme.of(context).colorScheme;
    final sel = _secao == idx;
    final corConteudo = sel ? cs.onPrimary : cs.onSurface;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        showCheckmark: false,
        avatar: Icon(icon, size: 18, color: corConteudo),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: corConteudo, fontWeight: FontWeight.w600)),
            if (alerta) ...[
              const SizedBox(width: 4),
              Icon(Icons.error, size: 14, color: sel ? cs.onPrimary : Colors.red),
            ],
          ],
        ),
        selected: sel,
        backgroundColor: cs.surfaceContainerHighest,
        selectedColor: cs.primary,
        side: BorderSide(color: sel ? Colors.transparent : cs.outlineVariant),
        onSelected: (_) => setState(() => _secao = idx),
      ),
    );
  }

  Future<void> _gerarInventario() async {
    setState(() => _ocupado = true);
    try {
      await _fs.semearInventario();
      if (mounted) _snack('Inventário gerado (228 imóveis)');
    } catch (e) {
      if (mounted) _snack('Erro ao gerar inventário: $e', erro: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _snack(String msg, {bool erro = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: erro ? Colors.red : Colors.green,
    ));
  }
}

// ── Cores e rótulos de situação ─────────────────────────────────────────────

Color _corSituacao(SituacaoImovel s) {
  switch (s) {
    case SituacaoImovel.esgotado:
      return Colors.red.shade400;
    case SituacaoImovel.parcial:
      return Colors.amber.shade600;
    case SituacaoImovel.indefinido:
      return Colors.green.shade400;
  }
}

String _labelSituacao(SituacaoImovel s) {
  switch (s) {
    case SituacaoImovel.esgotado:
      return 'Esgotado';
    case SituacaoImovel.parcial:
      return 'Parcial';
    case SituacaoImovel.indefinido:
      return 'Disponível';
  }
}

String _pavimentoLabel(String p) {
  switch (p) {
    case 'terreo':
      return 'Térreo';
    case 'unico':
      return 'Bangalôs';
    case '1':
      return 'Primeiro andar';
    case '2':
      return 'Segundo andar';
    case '3':
      return 'Terceiro andar';
    case '4':
      return 'Quarto andar';
    case '5':
      return 'Quinto andar';
    default:
      return '$pº andar';
  }
}

int _numeroOrdenavel(String numero) => int.tryParse(numero) ?? 0;

/// Extrai o número da cota ('Cota-06' → 6). 'Integral' → null.
int? _numeroDaCota(String label) {
  final m = RegExp(r'(\d+)').firstMatch(label);
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// Rótulo padronizado de uma cota: 'Cota-06'.
String _rotuloCota(int n) => 'Cota-${n.toString().padLeft(2, '0')}';

/// Seção recolhível reutilizável (mantém o estado aberto/fechado ao rolar).
class _Expansivel extends StatelessWidget {
  final String chaveId;
  final String titulo;
  final String? resumo;
  final bool inicial;
  final EdgeInsetsGeometry childrenPadding;
  final List<Widget> children;
  const _Expansivel({
    required this.chaveId,
    required this.titulo,
    this.resumo,
    this.inicial = false,
    this.childrenPadding = const EdgeInsets.fromLTRB(14, 0, 14, 12),
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        key: PageStorageKey(chaveId),
        initiallyExpanded: inicial,
        title: Row(
          children: [
            Expanded(
              child: Text(titulo,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            if (resumo != null)
              Text(resumo!,
                  style: tt.bodySmall?.copyWith(color: Colors.grey)),
          ],
        ),
        childrenPadding: childrenPadding,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SEÇÃO 1 — ESPELHO DE VENDA
// ════════════════════════════════════════════════════════════════════════════

class _SecaoEspelho extends StatelessWidget {
  final ResumoAnalise resumo;
  final Map<String, Contrato> contratosPorId;
  const _SecaoEspelho({required this.resumo, required this.contratosPorId});

  @override
  Widget build(BuildContext context) {
    final porBloco = <String, List<AnaliseImovel>>{};
    for (final a in resumo.imoveis) {
      (porBloco[a.imovel.bloco] ??= []).add(a);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      children: [
        _LegendaEspelho(),
        const SizedBox(height: 12),
        for (final bloco in _ordemBlocos)
          if (porBloco[bloco] != null) _blocoView(context, bloco, porBloco[bloco]!),
      ],
    );
  }

  Widget _blocoView(BuildContext context, String bloco, List<AnaliseImovel> itens) {
    final nome = itens.first.imovel.blocoNome;
    final esgotados = itens.where((i) => i.situacao == SituacaoImovel.esgotado).length;

    final porPav = <String, List<AnaliseImovel>>{};
    for (final a in itens) {
      (porPav[a.imovel.pavimento] ??= []).add(a);
    }

    return _Expansivel(
      chaveId: 'espelho-$bloco',
      titulo: bloco == 'BANGALO' ? 'Bangalôs — $nome' : 'Bloco $bloco — $nome',
      resumo: '${itens.length} un · $esgotados esg.',
      inicial: bloco == 'B',
      children: [
        for (final pav in _ordemPavimentos)
          if (porPav[pav] != null) _pavimentoView(context, pav, porPav[pav]!),
      ],
    );
  }

  Widget _pavimentoView(BuildContext context, String pav, List<AnaliseImovel> itens) {
    itens.sort((a, b) =>
        _numeroOrdenavel(a.imovel.numero).compareTo(_numeroOrdenavel(b.imovel.numero)));
    final ehBangalo = pav == 'unico';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!ehBangalo)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(_pavimentoLabel(pav),
                  style: Theme.of(context).textTheme.labelMedium),
            ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final a in itens)
                _UnidadeChip(analise: a, contratosPorId: contratosPorId)
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendaEspelho extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 4),
            Text(t, style: Theme.of(context).textTheme.bodySmall),
          ],
        );
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        item(Colors.green.shade400, 'Disponível'),
        item(Colors.amber.shade600, 'Parcial'),
        item(Colors.red.shade400, 'Esgotado'),
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error, size: 13, color: Colors.red),
          const SizedBox(width: 4),
          Text('Alerta de dados', style: Theme.of(context).textTheme.bodySmall),
        ]),
      ],
    );
  }
}

class _UnidadeChip extends StatelessWidget {
  final AnaliseImovel analise;
  final Map<String, Contrato> contratosPorId;
  const _UnidadeChip({required this.analise, required this.contratosPorId});

  @override
  Widget build(BuildContext context) {
    final a = analise;
    final cor = _corSituacao(a.situacao);
    final temVenda = a.cotasVendidas > 0;

    final tooltip = a.cotasTotal == null
        ? 'Apto ${a.imovel.numero} · disponível (sem cota definida)'
        : 'Apto ${a.imovel.numero} · ${a.cotasVendidas} cota(s) vendida(s)';

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showModalBottomSheet(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) => _DetalheImovel(
            analise: a,
            contratosPorId: contratosPorId,
          ),
        ),
        child: Container(
          width: 56,
          height: 48,
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.18),
            border: Border.all(color: cor, width: 1.4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              // Número do apartamento — um pouco abaixo do centro.
              Align(
                alignment: const Alignment(0, 0.55),
                child: Text(
                  a.imovel.numero,
                  style: const TextStyle(
                      fontSize: 14, height: 1, fontWeight: FontWeight.w700),
                ),
              ),
              // Cotas vendidas no topo (um pouco maior).
              if (temVenda)
                Positioned(
                  top: 3,
                  left: 0,
                  right: 0,
                  child: Text(
                    '${a.cotasVendidas}▲',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        height: 1,
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              if (a.temAlerta)
                const Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(Icons.error, size: 11, color: Colors.red),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetalheImovel extends StatelessWidget {
  final AnaliseImovel analise;
  final Map<String, Contrato> contratosPorId;
  const _DetalheImovel({required this.analise, required this.contratosPorId});

  @override
  Widget build(BuildContext context) {
    final a = analise;
    final tt = Theme.of(context).textTheme;
    final im = a.imovel;

    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                      color: _corSituacao(a.situacao), shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                    im.bloco == 'BANGALO'
                        ? 'Bangalô ${im.numero}'
                        : '${im.bloco}-${im.numero}',
                    style: tt.titleLarge),
                const Spacer(),
                Chip(
                    label: Text(_labelSituacao(a.situacao)),
                    visualDensity: VisualDensity.compact),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                im.tipo,
                if (im.metragem != null) '${im.metragem!.toStringAsFixed(2)} m²',
                if (a.tier != null) 'Cota ${a.tier!.label}',
              ].join(' · '),
              style: tt.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            if (a.cotasTotal != null) ...[
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (a.ocupacaoPct / 100).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor:
                            AlwaysStoppedAnimation(_corSituacao(a.situacao)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${a.cotasVendidas}/${a.cotasTotal}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                  '${a.disponiveis} disponível(is) · ${_moeda.format(a.receita)} em contratos',
                  style: tt.bodySmall),
            ] else
              Text('Sem cota vendida — cota definida na primeira venda',
                  style: tt.bodySmall),
            if (a.temAlerta) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.error, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        if (a.conflitoTier) 'Cotas misturadas no mesmo imóvel',
                        if (a.cotasDuplicadas.isNotEmpty)
                          'Cota duplicada: ${a.cotasDuplicadas.join(', ')}',
                      ].join(' · '),
                      style: tt.bodySmall?.copyWith(color: Colors.red.shade900),
                    ),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Cotas', style: tt.titleSmall),
                const Spacer(),
                if (a.cotasTotal != null)
                  Text('${a.cotasVendidas} vendida(s) · ${a.disponiveis} livre(s)',
                      style: tt.bodySmall?.copyWith(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 4),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: _linhasCotas(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _linhasCotas(BuildContext context) {
    final a = analise;
    final vendidas = <int, Cota>{};
    Cota? cotaUnica; // cota sem número (Integral)
    for (final c in a.cotas) {
      final n = _numeroDaCota(c.numero);
      if (n == null) {
        cotaUnica = c;
      } else {
        vendidas[n] = c;
      }
    }

    final tier = a.tier;
    final linhas = <Widget>[];

    if (tier == null) {
      if (a.cotas.isEmpty) {
        return [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
                'Nenhuma cota vendida ainda. A cota (bronze/prata/ouro/diamante) '
                'será definida na primeira venda.'),
          ),
        ];
      }
      for (final c in a.cotas) {
        linhas.add(_linhaVendida(context, c.numero, c));
      }
      return linhas;
    }

    if (tier == TierCota.integral || tier == TierCota.diamante) {
      final c = cotaUnica ?? vendidas[1] ?? (a.cotas.isNotEmpty ? a.cotas.first : null);
      final label = tier == TierCota.integral ? 'Integral' : 'Cota única';
      linhas.add(c == null ? _linhaLivre(label) : _linhaVendida(context, label, c));
      return linhas;
    }

    for (var i = 1; i <= tier.cotasTotal; i++) {
      final c = vendidas[i];
      final label = _rotuloCota(i);
      linhas.add(c == null ? _linhaLivre(label) : _linhaVendida(context, label, c));
    }
    return linhas;
  }

  Widget _linhaVendida(BuildContext context, String label, Cota c) {
    final contrato = contratosPorId[c.contratoId];
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: Colors.green.shade100,
        child: Text(label.replaceAll('Cota-', ''),
            style: TextStyle(fontSize: 10, color: Colors.green.shade900)),
      ),
      title: Text(c.clienteNome.isEmpty ? '(sem nome)' : c.clienteNome),
      subtitle: Text('$label · ${c.produto} · ${c.statusFinanceiro}',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_moedaCompacta.format(c.valor),
              style: const TextStyle(fontSize: 12)),
          if (contrato != null) const Icon(Icons.chevron_right, size: 18),
        ],
      ),
      onTap: contrato == null
          ? null
          : () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => FichaContratoScreen(contrato: contrato),
              ));
            },
    );
  }

  Widget _linhaLivre(String label) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: Colors.grey.shade200,
        child: Text(label.replaceAll('Cota-', ''),
            style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
      ),
      title: Text(label, style: TextStyle(color: Colors.grey.shade700)),
      trailing: Text('Disponível',
          style: TextStyle(
              fontSize: 12,
              color: Colors.green.shade700,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SEÇÃO 2 — COTAS (barras por tier)
// ════════════════════════════════════════════════════════════════════════════

const _ordemCategorias = [
  'LUXO',
  'LUXO PREMIUM',
  'LUXO MASTER',
  'VILLAMOR',
  'VILLAMOR PREMIUM',
  'VILLAMOR SUPER MASTER',
  'BANGALO',
];

String _tituloCategoria(String tipo) {
  if (tipo == 'BANGALO') return 'Bangalô';
  return tipo
      .split(' ')
      .map((p) => p.isEmpty ? p : '${p[0]}${p.substring(1).toLowerCase()}')
      .join(' ');
}

class _SecaoCotas extends StatelessWidget {
  final ResumoAnalise resumo;
  const _SecaoCotas({required this.resumo});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    // Agrega cotas por categoria de apartamento e, dentro dela, por cota.
    final porCategoria = <String, Map<TierCota, ResumoTier>>{};
    for (final a in resumo.imoveis) {
      if (a.tier == null || a.cotasTotal == null) continue;
      final cat = porCategoria.putIfAbsent(a.imovel.tipo, () => {});
      final rt = cat.putIfAbsent(a.tier!, () => ResumoTier(a.tier!));
      rt.imoveis++;
      rt.cotasVendidas += a.cotasVendidas;
      rt.cotasTotal += a.cotasTotal!;
    }

    final categorias = [
      ..._ordemCategorias.where(porCategoria.containsKey),
      ...porCategoria.keys.where((c) => !_ordemCategorias.contains(c)),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        Text('Cotas por categoria de apartamento', style: tt.titleMedium),
        const SizedBox(height: 4),
        Text('Vendidas vs. disponíveis nos imóveis já definidos.',
            style: tt.bodySmall?.copyWith(color: Colors.grey)),
        const SizedBox(height: 16),
        if (porCategoria.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: Text('Nenhuma cota vendida ainda.')),
          ),
        for (final cat in categorias)
          _CategoriaCotas(titulo: _tituloCategoria(cat), porTier: porCategoria[cat]!),
      ],
    );
  }
}

class _CategoriaCotas extends StatelessWidget {
  final String titulo;
  final Map<TierCota, ResumoTier> porTier;
  const _CategoriaCotas({required this.titulo, required this.porTier});

  @override
  Widget build(BuildContext context) {
    final vendidas = porTier.values.fold(0, (s, r) => s + r.cotasVendidas);
    final total = porTier.values.fold(0, (s, r) => s + r.cotasTotal);
    return _Expansivel(
      chaveId: 'cotas-$titulo',
      titulo: titulo,
      resumo: '$vendidas/$total cotas',
      children: [
        for (final tier in _ordemTiers)
          if (porTier[tier] != null) _BarraTier(rt: porTier[tier]!),
      ],
    );
  }
}

class _BarraTier extends StatelessWidget {
  final ResumoTier rt;
  const _BarraTier({required this.rt});

  Color get _cor {
    switch (rt.tier) {
      case TierCota.bronze:
        return const Color(0xFFCD7F32);
      case TierCota.prata:
        return const Color(0xFF9E9E9E);
      case TierCota.ouro:
        return const Color(0xFFD4AF37);
      case TierCota.diamante:
        return const Color(0xFF4FC3F7);
      case TierCota.integral:
        return const Color(0xFF7E57C2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final frac = rt.cotasTotal > 0 ? rt.cotasVendidas / rt.cotasTotal : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: _cor, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 6),
              Text(rt.tier.label, style: tt.titleSmall),
              const Spacer(),
              Text('${rt.cotasVendidas}/${rt.cotasTotal}  ·  ${rt.imoveis} imóvel(is)',
                  style: tt.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: frac.clamp(0.0, 1.0),
              minHeight: 14,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(_cor),
            ),
          ),
          const SizedBox(height: 4),
          Text('${rt.disponiveis} disponível(is)  ·  ${(frac * 100).toStringAsFixed(0)}% ocupado',
              style: tt.bodySmall?.copyWith(color: Colors.grey)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SEÇÃO 3 — VENDAS
// ════════════════════════════════════════════════════════════════════════════

const _meses = [
  '', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
];

class _SecaoVendas extends StatelessWidget {
  final ResumoAnalise resumo;
  final List<Contrato> contratos;
  const _SecaoVendas({required this.resumo, required this.contratos});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final r = resumo;

    final aReceber = valorAReceber(contratos);
    final atualizado = dataAtualizacaoDados(contratos);
    final porAno = vendasPorAno(contratos);
    final anos = porAno.keys.toList()..sort((a, b) => b.compareTo(a));
    final semPagamento =
        contratosSemPagamento(contratos, agora: DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Data de atualização dos dados (último Excel importado).
        Row(
          children: [
            const Icon(Icons.update, size: 15, color: Colors.grey),
            const SizedBox(width: 6),
            Text(
              atualizado == null
                  ? 'Sem data de atualização'
                  : 'Dados atualizados em ${DateFormat('dd/MM/yyyy').format(atualizado)}',
              style: tt.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // KPIs
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Kpi(titulo: 'Unidades', valor: '${r.totalUnidades}'),
            _Kpi(titulo: 'Com venda', valor: '${r.totalComVenda}'),
            _Kpi(titulo: 'Esgotadas', valor: '${r.totalEsgotados}'),
            _Kpi(titulo: 'Cotas vendidas', valor: '${r.totalCotasVendidas}'),
            _Kpi(titulo: 'Receita (contratos)', valor: _moedaCompacta.format(r.receitaTotal)),
            _Kpi(titulo: 'A receber', valor: _moedaCompacta.format(aReceber)),
          ],
        ),
        const SizedBox(height: 20),

        // Por bloco (recolhível)
        _Expansivel(
          chaveId: 'vendas-porbloco',
          titulo: 'Por bloco',
          inicial: true,
          children: [
            for (final bloco in _ordemBlocos)
              if (r.porBloco[bloco] != null) _LinhaBloco(rb: r.porBloco[bloco]!),
          ],
        ),

        const SizedBox(height: 12),
        Text('Vendas por mês', style: tt.titleMedium),
        const SizedBox(height: 4),
        Builder(builder: (context) {
          final todosMeses = porAno.values.expand((l) => l);
          final totCotas = todosMeses.fold<int>(0, (s, m) => s + m.cotas);
          final totInt = todosMeses.fold<int>(0, (s, m) => s + m.inteiros);
          return Text(
            'Total: ${_contagemCotas(totCotas, totInt)}. Toque num mês para ver os contratos.',
            style: tt.bodySmall?.copyWith(color: Colors.grey),
          );
        }),
        const SizedBox(height: 8),
        if (anos.isEmpty)
          Text('Sem contratos com data.', style: tt.bodySmall),
        for (final ano in anos)
          _Expansivel(
            chaveId: 'vendas-ano-$ano',
            titulo: '$ano',
            resumo: _moedaCompacta
                .format(porAno[ano]!.fold<double>(0, (s, m) => s + m.valor)),
            inicial: ano == anos.first,
            childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            children: [_LinhaMeses(meses: porAno[ano]!)],
          ),

        const SizedBox(height: 12),
        _Expansivel(
          chaveId: 'vendas-sempagamento',
          titulo: 'Sem pagamento há tempo',
          resumo: '${semPagamento.length}',
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Em atraso ou vencidos há 60+ dias.',
                  style: tt.bodySmall?.copyWith(color: Colors.grey)),
            ),
            if (semPagamento.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Nenhum contrato em atraso. 🎉', style: tt.bodySmall),
              ),
            for (final c in semPagamento.take(25)) _LinhaAtraso(contrato: c),
            if (semPagamento.length > 25)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('… e mais ${semPagamento.length - 25} contrato(s).',
                    style: tt.bodySmall?.copyWith(color: Colors.grey)),
              ),
          ],
        ),
      ],
    );
  }
}

const _mesesCurto = [
  '', 'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
  'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
];

/// "7 cotas · 1 integral" (omite a parte com zero, exceto cotas).
String _contagemCotas(int cotas, int integrais) {
  final partes = <String>['$cotas cota${cotas == 1 ? '' : 's'}'];
  if (integrais > 0) {
    partes.add('$integrais integral${integrais == 1 ? '' : 'is'}');
  }
  return partes.join(' · ');
}

/// Linha horizontal de cards de mês (rolável), do mais recente ao mais antigo.
class _LinhaMeses extends StatelessWidget {
  final List<VendaMes> meses;
  const _LinhaMeses({required this.meses});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [for (final vm in meses) _CardMesPequeno(vm: vm)],
      ),
    );
  }
}

class _CardMesPequeno extends StatelessWidget {
  final VendaMes vm;
  const _CardMesPequeno({required this.vm});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(right: 8, bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showModalBottomSheet(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) => _DetalheMes(vm: vm),
        ),
        child: Container(
          width: 136,
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_mesesCurto[vm.mes],
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(_moedaCompacta.format(vm.valor),
                  style: tt.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                _contagemCotas(vm.cotas, vm.inteiros),
                maxLines: 2,
                style: tt.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetalheMes extends StatelessWidget {
  final VendaMes vm;
  const _DetalheMes({required this.vm});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final contratos = [...vm.contratos]
      ..sort((a, b) => b.valorTotalReajustado.compareTo(a.valorTotalReajustado));
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_meses[vm.mes]} de ${vm.ano}', style: tt.titleLarge),
            Text(
                '${_contagemCotas(vm.cotas, vm.inteiros)} · ${_moeda.format(vm.valor)}',
                style: tt.bodySmall?.copyWith(color: Colors.grey)),
            const Divider(),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: contratos.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final c = contratos[i];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                        c.nomeComprador.isEmpty ? '(sem nome)' : c.nomeComprador,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        '${c.cota.isEmpty ? '—' : c.cota} · ${c.bloco} ${c.imovel} · ${c.produto}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    trailing: Text(_moedaCompacta.format(c.valorTotalReajustado),
                        style: const TextStyle(fontSize: 12)),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => FichaContratoScreen(contrato: c),
                      ));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinhaAtraso extends StatelessWidget {
  final Contrato contrato;
  const _LinhaAtraso({required this.contrato});

  @override
  Widget build(BuildContext context) {
    final c = contrato;
    final venc = c.dataProximoVencimento;
    final sub = <String>[
      if (venc != null) 'venc. ${DateFormat('dd/MM/yyyy').format(venc)}',
      if (c.valorAtrasado > 0) 'atraso ${_moedaCompacta.format(c.valorAtrasado)}',
      if (c.bloco.isNotEmpty) c.bloco,
    ];
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.schedule, color: Colors.deepOrange, size: 18),
      title: Text(c.nomeComprador, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(sub.join(' · '),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text('saldo ${_moedaCompacta.format(c.saldoRestante)}',
          style: const TextStyle(fontSize: 12)),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FichaContratoScreen(contrato: c),
      )),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String titulo;
  final String valor;
  const _Kpi({required this.titulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(valor, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 2),
          Text(titulo, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _LinhaBloco extends StatelessWidget {
  final ResumoBloco rb;
  const _LinhaBloco({required this.rb});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final nome = rb.bloco == 'BANGALO' ? 'Bangalôs' : 'Bloco ${rb.bloco}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(nome, style: tt.titleSmall),
                const Spacer(),
                Text(_moeda.format(rb.receita), style: tt.titleSmall),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${rb.unidades} unidades · ${rb.comVenda} com venda · ${rb.esgotados} esgotadas · ${rb.indefinidos} sem cota · ${rb.cotasVendidas} cotas vendidas',
              style: tt.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SEÇÃO 4 — SAÚDE DOS DADOS
// ════════════════════════════════════════════════════════════════════════════

class _SecaoSaude extends StatelessWidget {
  final ResumoAnalise resumo;
  const _SecaoSaude({required this.resumo});

  @override
  Widget build(BuildContext context) {
    final r = resumo;
    final avulsos = [...r.avulsos]
      ..sort((a, b) => a.nomeComprador.compareTo(b.nomeComprador));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        _CardAlerta(
          icone: Icons.link_off,
          cor: r.avulsos.isEmpty ? Colors.green : Colors.orange,
          titulo: '${r.avulsos.length} contratos avulsos',
          descricao:
              'Não casam com Bloco B/C/Bangalô (projeto antigo). Ficam em contratos, sem virar cota.',
        ),
        const SizedBox(height: 4),
        for (final c in avulsos)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_off_outlined, size: 18),
            title: Text(
              c.nomeComprador.isEmpty ? '(sem nome)' : c.nomeComprador,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${c.cota.isEmpty ? 'sem cota' : c.cota} · ${motivoAvulso(c)}',
              maxLines: 2,
            ),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => FichaContratoScreen(contrato: c),
            )),
          ),
        const Divider(height: 24),
        _CardAlerta(
          icone: Icons.rule,
          cor: r.comAlerta.isEmpty ? Colors.green : Colors.red,
          titulo: '${r.comAlerta.length} imóveis com inconsistência',
          descricao:
              'Cotas misturadas no mesmo imóvel ou cota vendida em duplicidade.',
        ),
        for (final a in r.comAlerta)
          ListTile(
            dense: true,
            leading: const Icon(Icons.error, color: Colors.red, size: 18),
            title: Text('${a.imovel.bloco}-${a.imovel.numero}'),
            subtitle: Text([
              if (a.conflitoTier) 'cotas misturadas',
              if (a.cotasDuplicadas.isNotEmpty)
                'cota duplicada (${a.cotasDuplicadas.join(', ')})',
            ].join(' · ')),
          ),
      ],
    );
  }
}

class _CardAlerta extends StatelessWidget {
  final IconData icone;
  final Color cor;
  final String titulo;
  final String descricao;
  const _CardAlerta({
    required this.icone,
    required this.cor,
    required this.titulo,
    required this.descricao,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icone, color: cor),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(descricao),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SEÇÃO 5 — DADOS (perguntas e respostas)
// ════════════════════════════════════════════════════════════════════════════

/// Painel de perguntas: cada item é uma métrica que, ao tocar, expande e mostra
/// a resposta com o detalhamento. As perguntas serão definidas pelo usuário —
/// começamos com algumas de exemplo (quantidade e valor vendido).
Widget _linhaDado(BuildContext context, String rotulo, String valor) {
  final tt = Theme.of(context).textTheme;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(rotulo, style: tt.bodyMedium)),
        Text(valor, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

Widget _notaPendente(BuildContext context, String texto) {
  return Align(
    alignment: Alignment.centerLeft,
    child: Text(texto,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Colors.grey, fontStyle: FontStyle.italic)),
  );
}

class _SecaoDados extends StatelessWidget {
  final ResumoAnalise resumo;
  final List<Contrato> contratos;
  const _SecaoDados({required this.resumo, required this.contratos});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final r = resumo;

    // (2) Apartamentos por andar e tipo.
    final aptosPorAndarTipo = <String, Map<String, int>>{};
    // (3) Por andar: vendidos x disponíveis.
    final vendidosPorAndar = <String, int>{};
    final dispPorAndar = <String, int>{};
    // (4) Cotas vendidas por andar e categoria.
    final cotasPorAndarCat = <String, Map<String, int>>{};
    for (final a in r.imoveis) {
      final pav = a.imovel.pavimento;
      (aptosPorAndarTipo[pav] ??= {});
      aptosPorAndarTipo[pav]![a.imovel.tipo] =
          (aptosPorAndarTipo[pav]![a.imovel.tipo] ?? 0) + 1;
      if (a.situacao == SituacaoImovel.indefinido) {
        dispPorAndar[pav] = (dispPorAndar[pav] ?? 0) + 1;
      } else {
        vendidosPorAndar[pav] = (vendidosPorAndar[pav] ?? 0) + 1;
      }
      if (a.cotasVendidas > 0) {
        (cotasPorAndarCat[pav] ??= {});
        cotasPorAndarCat[pav]![a.imovel.tipo] =
            (cotasPorAndarCat[pav]![a.imovel.tipo] ?? 0) + a.cotasVendidas;
      }
    }

    // (6) Valor vendido; (9) Inadimplência.
    final vendido = valorVendidoTotal(contratos);
    final inadValor = contratos.fold<double>(0, (s, c) => s + c.valorAtrasado);
    final inadCount = contratos.where((c) => c.valorAtrasado > 0).length;

    // (1) e (13) Permuta — por enquanto pelo comprador conhecido.
    final permutas = contratosPermuta(contratos);
    final imovelTipo = {for (final a in r.imoveis) a.imovel.id: a.imovel.tipo};
    final permutaPorTipo = <String, int>{};
    for (final c in permutas) {
      final id = imovelIdDoContrato(c);
      final tipo = id != null ? imovelTipo[id] : null;
      final cat = tipo != null ? _tituloCategoria(tipo) : 'Avulso';
      permutaPorTipo[cat] = (permutaPorTipo[cat] ?? 0) + 1;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('Toque numa pergunta para ver a resposta.',
            style: tt.bodySmall?.copyWith(color: Colors.grey)),
        const SizedBox(height: 8),

        // 1) Permuta (por comprador conhecido)
        _Expansivel(
          chaveId: 'dados-permuta',
          titulo: 'Quantos foram vendidos por permuta?',
          resumo: '${permutas.length}',
          children: [
            _notaPendente(context,
                'Provisório: identificado pelo comprador (Mateus Antônio Camilo). '
                'Quando houver marcação própria no Excel, troco por ela.'),
            const SizedBox(height: 4),
            if (permutas.isEmpty)
              _notaPendente(context, 'Nenhum contrato de permuta encontrado.'),
            for (final c in permutas)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.swap_horiz, size: 18),
                title: Text(c.nomeComprador,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${c.cota} · ${c.bloco} ${c.imovel} · ${c.produto}',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Text(_moedaCompacta.format(c.valorTotalReajustado),
                    style: const TextStyle(fontSize: 12)),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => FichaContratoScreen(contrato: c),
                )),
              ),
          ],
        ),

        // 2) Apartamentos por andar e tipo
        _Expansivel(
          chaveId: 'dados-aptos-andar-tipo',
          titulo: 'Quantos apartamentos por andar e tipo?',
          resumo: '${r.totalUnidades}',
          children: [
            for (final pav in _ordemPavimentos)
              if (aptosPorAndarTipo[pav] != null)
                for (final e in aptosPorAndarTipo[pav]!.entries)
                  _linhaDado(context,
                      '${_pavimentoLabel(pav)} · ${_tituloCategoria(e.key)}',
                      '${e.value}'),
          ],
        ),

        // 3) Por andar: vendidos x disponíveis
        _Expansivel(
          chaveId: 'dados-andar-vend-disp',
          titulo: 'Apartamentos por andar: vendidos e disponíveis',
          resumo: '${r.totalComVenda}/${r.totalUnidades}',
          children: [
            for (final pav in _ordemPavimentos)
              if (aptosPorAndarTipo[pav] != null)
                _linhaDado(
                    context,
                    _pavimentoLabel(pav),
                    '${vendidosPorAndar[pav] ?? 0} vend · ${dispPorAndar[pav] ?? 0} disp'),
          ],
        ),

        // 4) Cotas vendidas por andar e tipo
        _Expansivel(
          chaveId: 'dados-cotas-andar-tipo',
          titulo: 'Cotas vendidas por tipo e andar',
          resumo: '${r.totalCotasVendidas}',
          children: [
            if (r.totalCotasVendidas == 0)
              _notaPendente(context, 'Nenhuma cota vendida ainda.'),
            for (final pav in _ordemPavimentos)
              if (cotasPorAndarCat[pav] != null)
                for (final e in cotasPorAndarCat[pav]!.entries)
                  _linhaDado(context,
                      '${_pavimentoLabel(pav)} · ${_tituloCategoria(e.key)}',
                      '${e.value} cotas'),
          ],
        ),

        // 5) VGV total (sem dado)
        _Expansivel(
          chaveId: 'dados-vgv',
          titulo: 'VGV total da 1ª etapa',
          resumo: 'a definir',
          children: [
            _notaPendente(context,
                'Preciso do valor de tabela de cada unidade (ou o VGV total) '
                'para calcular. Me envie a tabela de preços que eu somo aqui.'),
          ],
        ),

        // 6) Valor vendido até o momento
        _Expansivel(
          chaveId: 'dados-valor-vendido',
          titulo: 'Valor vendido até o momento',
          resumo: _moedaCompacta.format(vendido),
          children: [
            _linhaDado(context, 'Total (todos os contratos)', _moeda.format(vendido)),
            _linhaDado(context, 'Nº de contratos', '${contratos.length}'),
          ],
        ),

        // 9) Inadimplência
        _Expansivel(
          chaveId: 'dados-inadimplencia',
          titulo: 'Inadimplência (valor e contratos)',
          resumo: _moedaCompacta.format(inadValor),
          children: [
            _linhaDado(context, 'Valor em atraso', _moeda.format(inadValor)),
            _linhaDado(context, 'Contratos em atraso', '$inadCount'),
          ],
        ),

        // 10) Distratos (sem dado)
        _Expansivel(
          chaveId: 'dados-distratos',
          titulo: 'Número de distratos até o momento',
          resumo: 'a definir',
          children: [
            _notaPendente(context,
                'Não há marcação de distrato nos dados atuais. Me diga como o '
                'distrato aparece no Excel (um status? uma data?) que eu conto.'),
          ],
        ),

        // 12) Cronograma de obra (sem dado)
        _Expansivel(
          chaveId: 'dados-cronograma',
          titulo: 'Cronograma de obra para finalizar',
          resumo: 'a definir',
          children: [
            _notaPendente(context,
                'Me envie o cronograma (marcos e datas) que eu exibo aqui.'),
          ],
        ),

        // 13) Permutas por tipo
        _Expansivel(
          chaveId: 'dados-permutas-tipo',
          titulo: 'Quantas permutas por tipo foram feitas',
          resumo: '${permutas.length}',
          children: [
            if (permutas.isEmpty)
              _notaPendente(context, 'Nenhuma permuta encontrada.'),
            for (final e in (permutaPorTipo.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value))))
              _linhaDado(context, e.key, '${e.value}'),
          ],
        ),

        // 14) Descrição detalhada da 1ª etapa (sem dado)
        _Expansivel(
          chaveId: 'dados-descricao',
          titulo: 'Descrição detalhada da 1ª etapa',
          resumo: 'a definir',
          children: [
            _notaPendente(context,
                'Blocos, área social e administrativo com fotos e projetos. '
                'Me envie os textos e as imagens que eu monto a apresentação.'),
          ],
        ),
      ],
    );
  }
}
