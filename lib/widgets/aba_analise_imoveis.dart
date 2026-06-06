import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/contrato_model.dart';
import '../models/imovel_model.dart';
import '../services/analise_imoveis.dart';
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
            return _buildConteudo(context, resumo);
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

  Widget _buildConteudo(BuildContext context, ResumoAnalise r) {
    return Column(
      children: [
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
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: switch (_secao) {
            0 => _SecaoEspelho(resumo: r),
            1 => _SecaoCotas(resumo: r),
            2 => _SecaoVendas(resumo: r),
            _ => _SecaoSaude(resumo: r),
          },
        ),
        // Barra de ações (sincronizar)
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${r.totalUnidades} unidades · ${r.totalCotasVendidas} cotas vendidas',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _ocupado ? null : _sincronizar,
                  icon: _ocupado
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync, size: 18),
                  label: const Text('Sincronizar cotas'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chipSecao(int idx, String label, IconData icon, {bool alerta = false}) {
    final selecionado = _secao == idx;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(icon,
            size: 18,
            color: selecionado
                ? Theme.of(context).colorScheme.onSecondaryContainer
                : null),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (alerta) ...[
              const SizedBox(width: 4),
              const Icon(Icons.error, size: 14, color: Colors.red),
            ],
          ],
        ),
        selected: selecionado,
        onSelected: (_) => setState(() => _secao = idx),
      ),
    );
  }

  Future<void> _gerarInventario() async {
    setState(() => _ocupado = true);
    try {
      await _fs.semearInventario();
      final res = await _fs.sincronizarCotas();
      if (mounted) {
        _snack(
            'Inventário gerado · ${res.cotas} cotas sincronizadas (${res.avulsos} contratos avulsos)');
      }
    } catch (e) {
      if (mounted) _snack('Erro ao gerar inventário: $e', erro: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _sincronizar() async {
    setState(() => _ocupado = true);
    try {
      final res = await _fs.sincronizarCotas();
      if (mounted) {
        _snack(
            '${res.cotas} cotas em ${res.imoveisAfetados} imóveis · ${res.avulsos} avulsos');
      }
    } catch (e) {
      if (mounted) _snack('Erro ao sincronizar: $e', erro: true);
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
    default:
      return '$pº pavimento';
  }
}

int _numeroOrdenavel(String numero) => int.tryParse(numero) ?? 0;

// ════════════════════════════════════════════════════════════════════════════
// SEÇÃO 1 — ESPELHO DE VENDA
// ════════════════════════════════════════════════════════════════════════════

class _SecaoEspelho extends StatelessWidget {
  final ResumoAnalise resumo;
  const _SecaoEspelho({required this.resumo});

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
    final tt = Theme.of(context).textTheme;
    final nome = itens.first.imovel.blocoNome;
    final esgotados = itens.where((i) => i.situacao == SituacaoImovel.esgotado).length;

    final porPav = <String, List<AnaliseImovel>>{};
    for (final a in itens) {
      (porPav[a.imovel.pavimento] ??= []).add(a);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text('Bloco ${bloco == 'BANGALO' ? '' : '$bloco '}— $nome',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ),
        Text('${itens.length} unidades · $esgotados esgotadas',
            style: tt.bodySmall?.copyWith(color: Colors.grey)),
        const SizedBox(height: 8),
        for (final pav in _ordemPavimentos)
          if (porPav[pav] != null) _pavimentoView(context, pav, porPav[pav]!),
        const SizedBox(height: 12),
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
            children: [for (final a in itens) _UnidadeChip(analise: a)],
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
  const _UnidadeChip({required this.analise});

  @override
  Widget build(BuildContext context) {
    final cor = _corSituacao(analise.situacao);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) => _DetalheImovel(analise: analise),
      ),
      child: Container(
        width: 52,
        height: 40,
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.18),
          border: Border.all(color: cor, width: 1.4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                analise.imovel.numero,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            if (analise.temAlerta)
              const Positioned(
                top: 1,
                right: 1,
                child: Icon(Icons.error, size: 11, color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetalheImovel extends StatelessWidget {
  final AnaliseImovel analise;
  const _DetalheImovel({required this.analise});

  @override
  Widget build(BuildContext context) {
    final a = analise;
    final tt = Theme.of(context).textTheme;
    final im = a.imovel;
    final cotas = [...a.cotas]
      ..sort((x, y) => _numeroOrdenavel(x.numero).compareTo(_numeroOrdenavel(y.numero)));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(color: _corSituacao(a.situacao), shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(im.bloco == 'BANGALO' ? 'Bangalô ${im.numero}' : '${im.bloco}-${im.numero}',
                  style: tt.titleLarge),
              const Spacer(),
              Chip(label: Text(_labelSituacao(a.situacao)), visualDensity: VisualDensity.compact),
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
                      valueColor: AlwaysStoppedAnimation(_corSituacao(a.situacao)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${a.cotasVendidas}/${a.cotasTotal}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Text('${a.disponiveis} cota(s) disponível(is) · ${_moeda.format(a.receita)} em contratos',
                style: tt.bodySmall),
          ] else
            Text('Sem cota vendida — tier ainda não definido', style: tt.bodySmall),
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
                      if (a.conflitoTier) 'Tiers misturados no mesmo imóvel',
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
          if (cotas.isNotEmpty) ...[
            Text('Cotistas', style: tt.titleSmall),
            const SizedBox(height: 4),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: cotas.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final c = cotas[i];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 14,
                      child: Text(c.numero.replaceAll('Cota-', ''),
                          style: const TextStyle(fontSize: 10)),
                    ),
                    title: Text(c.clienteNome.isEmpty ? '(sem nome)' : c.clienteNome),
                    subtitle: Text('${c.produto} · ${c.statusFinanceiro}'),
                    trailing: Text(_moedaCompacta.format(c.valor),
                        style: const TextStyle(fontSize: 12)),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SEÇÃO 2 — COTAS (barras por tier)
// ════════════════════════════════════════════════════════════════════════════

class _SecaoCotas extends StatelessWidget {
  final ResumoAnalise resumo;
  const _SecaoCotas({required this.resumo});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        Text('Cotas por tier', style: tt.titleMedium),
        const SizedBox(height: 4),
        Text('Vendidas vs. disponíveis nos imóveis já definidos por tier.',
            style: tt.bodySmall?.copyWith(color: Colors.grey)),
        const SizedBox(height: 16),
        for (final tier in _ordemTiers)
          if (resumo.porTier[tier] != null) _BarraTier(rt: resumo.porTier[tier]!),
        if (resumo.porTier.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: Text('Nenhuma cota vendida ainda.')),
          ),
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

class _SecaoVendas extends StatelessWidget {
  final ResumoAnalise resumo;
  const _SecaoVendas({required this.resumo});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final r = resumo;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Kpi(titulo: 'Unidades', valor: '${r.totalUnidades}'),
            _Kpi(titulo: 'Com venda', valor: '${r.totalComVenda}'),
            _Kpi(titulo: 'Esgotadas', valor: '${r.totalEsgotados}'),
            _Kpi(titulo: 'Cotas vendidas', valor: '${r.totalCotasVendidas}'),
            _Kpi(titulo: 'Receita (contratos)', valor: _moedaCompacta.format(r.receitaTotal)),
          ],
        ),
        const SizedBox(height: 20),
        Text('Por bloco', style: tt.titleMedium),
        const SizedBox(height: 8),
        for (final bloco in _ordemBlocos)
          if (r.porBloco[bloco] != null) _LinhaBloco(rb: r.porBloco[bloco]!),
      ],
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
    final avulsosPorBloco = <String, int>{};
    for (final c in r.avulsos) {
      final k = c.bloco.isEmpty ? '(sem bloco)' : c.bloco;
      avulsosPorBloco[k] = (avulsosPorBloco[k] ?? 0) + 1;
    }

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
        for (final e in (avulsosPorBloco.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value))))
          ListTile(
            dense: true,
            leading: const Icon(Icons.label_off_outlined, size: 18),
            title: Text(e.key),
            trailing: Text('${e.value}'),
          ),
        const Divider(height: 24),
        _CardAlerta(
          icone: Icons.rule,
          cor: r.comAlerta.isEmpty ? Colors.green : Colors.red,
          titulo: '${r.comAlerta.length} imóveis com inconsistência',
          descricao:
              'Tiers misturados no mesmo imóvel ou cota vendida em duplicidade.',
        ),
        for (final a in r.comAlerta)
          ListTile(
            dense: true,
            leading: const Icon(Icons.error, color: Colors.red, size: 18),
            title: Text('${a.imovel.bloco}-${a.imovel.numero}'),
            subtitle: Text([
              if (a.conflitoTier) 'tiers misturados',
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
