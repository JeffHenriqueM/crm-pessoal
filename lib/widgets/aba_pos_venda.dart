import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/contrato_model.dart';
import '../services/analise_imoveis.dart';
import '../services/aniversariantes_pos_venda.dart';
import '../services/firestore_service.dart';
import '../utils/whatsapp_interacao.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _moedaCompacta = NumberFormat.compactCurrency(
  locale: 'pt_BR',
  symbol: 'R\$',
  decimalDigits: 1,
);

class AbaPosVenda extends StatelessWidget {
  const AbaPosVenda({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Contrato>>(
      stream: FirestoreService().getContratosStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Erro: ${snap.error}'));
        }
        // Visão geral considera apenas contratos vigentes (Ativo).
        return _buildConteudo(context, contratosEfetivos(snap.data ?? []));
      },
    );
  }

  Widget _buildConteudo(BuildContext context, List<Contrato> contratos) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final total = contratos.length;
    final quitados = contratos.where((c) => c.estaQuitado).length;
    final emAndamento = total - quitados;
    final comAtraso = contratos.where((c) => c.temAtrasos).length;

    final valorFinanciadoTotal =
        contratos.fold<double>(0, (s, c) => s + c.valorFinanciado);
    final valorAtrasadoTotal =
        contratos.fold<double>(0, (s, c) => s + c.valorAtrasado);
    final percMedioIntegralizado = total > 0
        ? contratos.fold<double>(0, (s, c) => s + c.percentualEfetivo) /
            total
        : 0.0;

    final formalizados = contratos
        .where((c) => c.statusAssinatura.grupo == GrupoFormalizacao.formalizado)
        .length;
    final formalizacaoEmAndamento = contratos
        .where((c) => c.statusAssinatura.grupo == GrupoFormalizacao.emAndamento)
        .length;
    final pendentes = contratos
        .where((c) => c.statusAssinatura.grupo == GrupoFormalizacao.pendente)
        .length;

    final aniversariantes = aniversariantesEm(contratos, DateTime.now());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pós-Venda', style: tt.headlineSmall),
          const SizedBox(height: 4),
          Text(
            '$total contrato${total != 1 ? 's' : ''} ativos',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          // ── Botão aniversariantes ─────────────────────────────────────
          _BotaoAniversariantes(aniversariantes: aniversariantes),

          const SizedBox(height: 20),

          // ── Formalização ──────────────────────────────────────────────
          _buildSecaoTitulo(context, 'Status de formalização'),
          const SizedBox(height: 8),
          _AssinaturaCard(
            formalizados: formalizados,
            emAndamento: formalizacaoEmAndamento,
            pendentes: pendentes,
            total: total,
          ),

          const SizedBox(height: 20),

          // ── Financeiro ────────────────────────────────────────────────
          _buildSecaoTitulo(context, 'Financeiro'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  titulo: 'Valor financiado',
                  valor: _moedaCompacta.format(valorFinanciadoTotal),
                  subtitulo: _moeda.format(valorFinanciadoTotal),
                  icone: Icons.attach_money_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KpiCard(
                  titulo: 'Em atraso',
                  valor: _moedaCompacta.format(valorAtrasadoTotal),
                  subtitulo: '$comAtraso contrato${comAtraso != 1 ? 's' : ''}',
                  icone: Icons.warning_amber_rounded,
                  corDestaque: valorAtrasadoTotal > 0 ? cs.error : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  titulo: 'Quitados',
                  valor: '$quitados',
                  subtitulo: total > 0
                      ? '${(quitados / total * 100).toStringAsFixed(1)}% do total'
                      : '–',
                  icone: Icons.check_circle_outline_rounded,
                  corDestaque: cs.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KpiCard(
                  titulo: 'Em andamento',
                  valor: '$emAndamento',
                  subtitulo: total > 0
                      ? '${(emAndamento / total * 100).toStringAsFixed(1)}% do total'
                      : '–',
                  icone: Icons.pending_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _IntegralizacaoCard(percentual: percMedioIntegralizado),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSecaoTitulo(BuildContext context, String titulo) {
    return Text(
      titulo,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

// ── Botão de aniversariantes — abre bottom sheet com a lista ─────────────────
class _BotaoAniversariantes extends StatelessWidget {
  final List<Aniversariante> aniversariantes;

  const _BotaoAniversariantes({required this.aniversariantes});

  void _abrirBottomSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cake_rounded, color: cs.primary, size: 22),
                const SizedBox(width: 10),
                Text('Aniversariantes de hoje', style: tt.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            if (aniversariantes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Nenhum aniversariante hoje.',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              )
            else
              for (final a in aniversariantes) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.cake_outlined, size: 16, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.nome, style: tt.bodyMedium),
                            Text(
                              'Loc. ${a.localizador}',
                              style: tt.labelSmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      if (a.telefone.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.chat_rounded),
                          color: const Color(0xFF25D366),
                          tooltip: 'Abrir no WhatsApp e registrar interação',
                          onPressed: () => abrirWhatsAppERegistrarInteracao(
                            context,
                            contratoId: a.localizador,
                            telefone: a.telefone,
                            nomeContato: a.nome,
                          ),
                        ),
                    ],
                  ),
                ),
                if (a != aniversariantes.last) const Divider(height: 1),
              ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final temAniversariantes = aniversariantes.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _abrirBottomSheet(context),
        icon: Badge(
          isLabelVisible: temAniversariantes,
          label: Text('${aniversariantes.length}'),
          child: const Icon(Icons.cake_outlined),
        ),
        label: const Text('Ver aniversariantes de hoje'),
        style: OutlinedButton.styleFrom(
          foregroundColor:
              temAniversariantes ? cs.primary : cs.onSurfaceVariant,
          side: BorderSide(
            color: temAniversariantes
                ? cs.primary
                : cs.outlineVariant,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

// ── KPI card genérico ─────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final String? subtitulo;
  final IconData icone;
  final Color? corDestaque;

  const _KpiCard({
    required this.titulo,
    required this.valor,
    this.subtitulo,
    required this.icone,
    this.corDestaque,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cor = corDestaque ?? cs.primary;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    titulo,
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              valor,
              style: tt.titleLarge?.copyWith(
                color: cor,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitulo != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitulo!,
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Barra de integralização média ─────────────────────────────────────────────
class _IntegralizacaoCard extends StatelessWidget {
  final double percentual;

  const _IntegralizacaoCard({required this.percentual});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final perc = (percentual / 100).clamp(0.0, 1.0);

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up_rounded,
                    size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  'Integralização média',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const Spacer(),
                Text(
                  '${percentual.toStringAsFixed(1)}%',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: perc,
                minHeight: 8,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Barra tripartida de assinatura ────────────────────────────────────────────
class _AssinaturaCard extends StatelessWidget {
  final int formalizados;
  final int emAndamento;
  final int pendentes;
  final int total;

  const _AssinaturaCard({
    required this.formalizados,
    required this.emAndamento,
    required this.pendentes,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final t = total == 0 ? 1 : total;

    final fracAssinado = formalizados / t;
    final fracAndamento = emAndamento / t;
    final fracNao = pendentes / t;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    if (fracAssinado > 0)
                      Expanded(
                        flex: (fracAssinado * 1000).round(),
                        child: Container(color: Colors.green.shade600),
                      ),
                    if (fracAndamento > 0)
                      Expanded(
                        flex: (fracAndamento * 1000).round(),
                        child: Container(color: Colors.orange.shade400),
                      ),
                    if (fracNao > 0)
                      Expanded(
                        flex: (fracNao * 1000).round(),
                        child: Container(color: cs.surfaceContainerHighest),
                      ),
                    if (total == 0)
                      Expanded(child: Container(color: cs.surfaceContainerHighest)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _LegendaItem(
                  cor: Colors.green.shade600,
                  label: 'Formalizados',
                  count: formalizados,
                  percentual: fracAssinado * 100,
                  tt: tt,
                ),
                const SizedBox(width: 12),
                _LegendaItem(
                  cor: Colors.orange.shade400,
                  label: 'Em andamento',
                  count: emAndamento,
                  percentual: fracAndamento * 100,
                  tt: tt,
                ),
                const SizedBox(width: 12),
                _LegendaItem(
                  cor: cs.surfaceContainerHighest,
                  label: 'Pendentes',
                  count: pendentes,
                  percentual: fracNao * 100,
                  tt: tt,
                  corTexto: cs.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendaItem extends StatelessWidget {
  final Color cor;
  final String label;
  final int count;
  final double percentual;
  final TextTheme tt;
  final Color? corTexto;

  const _LegendaItem({
    required this.cor,
    required this.label,
    required this.count,
    required this.percentual,
    required this.tt,
    this.corTexto,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 2, right: 4),
            decoration: BoxDecoration(
              color: cor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: tt.labelSmall?.copyWith(
                    color: corTexto ?? cs.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$count (${percentual.toStringAsFixed(0)}%)',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
