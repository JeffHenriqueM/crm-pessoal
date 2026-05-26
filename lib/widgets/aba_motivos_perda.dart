// lib/widgets/aba_motivos_perda.dart
//
// Aba "Perdas" do Dashboard admin.
// Mostra distribuição de motivos de perda com auto-classificação do texto livre,
// KPIs e lista dos clientes perdidos recentes.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/cliente_model.dart';
import '../models/fase_enum.dart';

class AbaMotivosPerda extends StatelessWidget {
  /// Todos os clientes (a aba filtra internamente por fase == perdido).
  final List<Cliente> clientes;

  const AbaMotivosPerda({super.key, required this.clientes});

  // ── Categorias ────────────────────────────────────────────────────────────
  static const _cores = {
    'Sem interesse':         Color(0xFF6A1B9A),
    'Sem retorno':           Color(0xFF1565C0),
    'Financeiro':            Color(0xFFC62828),
    'Brinde/voucher':        Color(0xFFE65100),
    'Não conhecem a Villamor': Color(0xFF00695C),
    'Perfil inadequado':     Color(0xFF283593),
    'Quer decidir depois':   Color(0xFF2E7D32),
    'Proposta não aprovada': Color(0xFF4E342E),
    'Outro':                 Color(0xFF546E7A),
    'Sem motivo informado':  Color(0xFF9E9E9E),
  };

  // ── Auto-classificação ────────────────────────────────────────────────────
  static String _categorizar(String? dropdown, String? texto) {
    // 1. Dropdown preenchido — normalizar
    if (dropdown != null && dropdown.isNotEmpty) {
      final d = dropdown.toLowerCase();
      if (d.contains('brinde') || d.contains('voucher')) return 'Brinde/voucher';
      if (d.contains('retorno')) return 'Sem retorno';
      if (d.contains('financeiro')) return 'Financeiro';
      if (d.contains('não conhecem') || d.contains('nao conhecem')) return 'Não conhecem a Villamor';
      if (d.contains('interesse')) return 'Sem interesse';
      if (d.contains('perfil')) return 'Perfil inadequado';
      if (d.contains('decidir') || d.contains('depois')) return 'Quer decidir depois';
      if (d.contains('proposta') || d.contains('aprovad')) return 'Proposta não aprovada';
      if (d == 'outro') return 'Outro';
      return dropdown; // retorna o valor original se não mapeado
    }

    // 2. Auto-classificar pelo texto livre
    if (texto == null || texto.trim().isEmpty) return 'Sem motivo informado';
    final t = texto.toLowerCase();

    if (t.contains('brinde') || t.contains('voucher') || t.contains('day use')) {
      return 'Brinde/voucher';
    }
    if (t.contains('sem retorno') || t.contains('sem resposta') ||
        t.contains('não retorn') || t.contains('nao retorn') ||
        t.contains('não responde') || t.contains('nao responde') ||
        t.contains('nunca mais respondeu')) {
      return 'Sem retorno';
    }
    if (t.contains('financeiro') || t.contains('altos valores') ||
        t.contains('não tem condições') || t.contains('nao tem condi') ||
        t.contains('fora da realidade') || t.contains('construindo casa') ||
        t.contains('compraram um carro')) {
      return 'Financeiro';
    }
    if (t.contains('não conhece') || t.contains('nao conhece') ||
        t.contains('nunca veio') || t.contains('conhecer o hotel') ||
        t.contains('conhecer a villamor') || t.contains('conhecer prime')) {
      return 'Não conhecem a Villamor';
    }
    if (t.contains('sem interesse') || t.contains('não quis') ||
        t.contains('nao quis') || t.contains('não quer') ||
        t.contains('nao quer') || t.contains('não quiseram') ||
        t.contains('não deseja') || t.contains('sem motivo') ||
        t.contains('não quer comprar')) {
      return 'Sem interesse';
    }
    if (t.contains('decidir quando') || t.contains('retornar proposta') ||
        t.contains('não é o momento') || t.contains('nao é o momento') ||
        t.contains('fevereiro') || t.contains('abril') || t.contains('março')) {
      return 'Quer decidir depois';
    }
    if (t.contains('não autorizou') || t.contains('nao autorizou') ||
        t.contains('cancelamento') || t.contains('proposta')) {
      return 'Proposta não aprovada';
    }
    if (t.contains('solteiro') || t.contains('prestação de serviço') ||
        t.contains('não acredita no retorno') || t.contains('upgrade')) {
      return 'Perfil inadequado';
    }
    return 'Outro';
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final perdidos = clientes
        .where((c) => c.fase == FaseCliente.perdido)
        .toList()
      ..sort((a, b) => b.dataAtualizacao.compareTo(a.dataAtualizacao));

    // Agrupar por categoria
    final contagem = <String, int>{};
    final porCategoria = <String, List<Cliente>>{};
    for (final c in perdidos) {
      final cat = _categorizar(c.motivoNaoVendaDropdown, c.motivoNaoVenda);
      contagem[cat] = (contagem[cat] ?? 0) + 1;
      porCategoria.putIfAbsent(cat, () => []).add(c);
    }

    final ordenado = contagem.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = perdidos.length;
    final comMotivo =
        perdidos.where((c) => (c.motivoNaoVendaDropdown?.isNotEmpty == true) ||
            (c.motivoNaoVenda?.isNotEmpty == true)).length;
    final semMotivo = total - comMotivo;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── KPIs ──────────────────────────────────────────────────────────
          Row(children: [
            _kpi(cs, '$total', 'Perdidos\ntotal', Icons.person_off_outlined, cs.error),
            const SizedBox(width: 8),
            _kpi(cs, '$comMotivo',
                'Com\nregistro',
                Icons.check_circle_outline,
                Colors.green.shade700),
            const SizedBox(width: 8),
            _kpi(cs, '$semMotivo',
                'Sem\nmotivo',
                Icons.help_outline,
                Colors.orange.shade700),
          ]),
          const SizedBox(height: 24),

          // ── Gráfico de barras horizontais ──────────────────────────────
          _secTitle(context, 'Distribuição por motivo'),
          const SizedBox(height: 4),
          Text(
            'Inclui classificação automática a partir das observações',
            style: TextStyle(fontSize: 12, color: cs.outline),
          ),
          const SizedBox(height: 12),

          if (total == 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Nenhum cliente perdido registrado.',
                    style: TextStyle(color: cs.outline)),
              ),
            )
          else
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: ordenado.map((e) {
                    return _barraMotivo(
                      context,
                      e.key,
                      e.value,
                      total,
                      _cores[e.key] ?? Colors.grey,
                    );
                  }).toList(),
                ),
              ),
            ),

          const SizedBox(height: 24),

          // ── Detalhes por categoria ─────────────────────────────────────
          _secTitle(context, 'Detalhamento por categoria'),
          const SizedBox(height: 12),
          ...ordenado.map((e) => _categoriaExpandida(
                context,
                e.key,
                porCategoria[e.key] ?? [],
                _cores[e.key] ?? Colors.grey,
                cs,
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Widgets auxiliares ────────────────────────────────────────────────────
  Widget _secTitle(BuildContext context, String title) => Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );

  Widget _kpi(ColorScheme cs, String valor, String label, IconData icon, Color cor) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: cor.withValues(alpha: 0.12),
                child: Icon(icon, color: cor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(valor,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: cor,
                        )),
                    Text(label,
                        style: TextStyle(fontSize: 10, color: cs.outline),
                        maxLines: 2),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barraMotivo(BuildContext context, String label, int count,
      int total, Color cor) {
    final pct = total == 0 ? 0.0 : count / total;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 18,
                backgroundColor: cor.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(cor),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: Text(
              '$count (${(pct * 100).round()}%)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoriaExpandida(BuildContext context, String categoria,
      List<Cliente> clientes, Color cor, ColorScheme cs) {
    if (clientes.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cor.withValues(alpha: 0.3)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: cor.withValues(alpha: 0.15),
            child: Text(
              '${clientes.length}',
              style: TextStyle(
                color: cor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          title: Text(
            categoria,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          initiallyExpanded: false,
          children: clientes.map((c) => _clienteTile(c, cs)).toList(),
        ),
      ),
    );
  }

  Widget _clienteTile(Cliente c, ColorScheme cs) {
    final obs = c.motivoNaoVenda?.trim() ?? '';
    final fmt = DateFormat('dd/MM/yy');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: cs.primaryContainer,
            child: Text(
              c.nome.isNotEmpty ? c.nome[0].toUpperCase() : '?',
              style: TextStyle(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        c.nome,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      fmt.format(c.dataAtualizacao),
                      style: TextStyle(fontSize: 11, color: cs.outline),
                    ),
                  ],
                ),
                if (c.vendedorNome != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    c.vendedorNome!,
                    style: TextStyle(fontSize: 11, color: cs.primary),
                  ),
                ],
                if (obs.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    obs.length > 120 ? '${obs.substring(0, 117)}...' : obs,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
