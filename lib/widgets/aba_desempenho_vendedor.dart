import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../models/usuario_model.dart';
import '../services/desempenho_vendedor.dart';

/// Aba "Desempenho" (admin) — diagnostica cada vendedor contra a média da
/// equipe nas 4 dimensões e aponta o gargalo (onde cada um vaza).
///
/// A regra vive em `services/desempenho_vendedor.dart` (lógica pura, testada).
class AbaDesempenhoVendedor extends StatelessWidget {
  final List<Cliente> todosClientes;
  final List<Usuario> todosVendedores;

  const AbaDesempenhoVendedor({
    super.key,
    required this.todosClientes,
    required this.todosVendedores,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final agora = DateTime.now();

    // Agrupa leads por vendedor (closer ou liner contam para o dono).
    final porVendedor = <String, List<Cliente>>{};
    for (final c in todosClientes) {
      final vid = c.vendedorId;
      if (vid == null || vid.isEmpty) continue;
      porVendedor.putIfAbsent(vid, () => []).add(c);
    }

    final entradas = todosVendedores
        .where((u) => u.perfil == 'vendedor' || u.perfil == 'captador')
        .where((u) => (porVendedor[u.id] ?? const []).isNotEmpty)
        .map((u) => (
              id: u.id,
              nome: u.nome,
              clientes: porVendedor[u.id] ?? <Cliente>[]
            ))
        .toList();

    final diags = avaliarEquipe(entradas, agora: agora);
    final bench = BenchmarkEquipe.de(
        diags.map((d) => d.metricas).toList());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Desempenho da Equipe',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface)),
          const SizedBox(height: 2),
          Text(
            'Cada vendedor comparado à média do time — e onde ele vaza',
            style: TextStyle(fontSize: 12, color: cs.outline),
          ),
          const SizedBox(height: 16),

          if (diags.isEmpty)
            _vazio(cs)
          else ...[
            _benchmarkCard(cs, bench),
            const SizedBox(height: 16),
            ...diags.map((d) => _vendedorCard(context, cs, d)),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _benchmarkCard(ColorScheme cs, BenchmarkEquipe b) {
    String pct(double? v) => v == null ? '—' : '${v.toStringAsFixed(0)}%';
    String dias(double? v) =>
        v == null ? '—' : '${v.toStringAsFixed(0)}d';

    return Card(
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed_outlined, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('Média do time',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface)),
                const Spacer(),
                Text('${b.vendedoresConsiderados} no benchmark',
                    style: TextStyle(fontSize: 11, color: cs.outline)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _benchItem(cs, 'Conversão', pct(b.taxaConversao)),
                _benchItem(cs, 'Velocidade', dias(b.cicloMedioDias)),
                _benchItem(cs, 'Resposta', pct(b.taxaResposta)),
                _benchItem(cs, 'Comparecimento', pct(b.taxaComparecimento)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _benchItem(ColorScheme cs, String label, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(valor,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cs.onSurface)),
        Text(label, style: TextStyle(fontSize: 10, color: cs.outline)),
      ],
    );
  }

  Widget _vendedorCard(
      BuildContext context, ColorScheme cs, DiagnosticoVendedor d) {
    final m = d.metricas;
    final gargalo = d.gargalo;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho
            Row(
              children: [
                _avatar(m.vendedorNome),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.vendedorNome,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(
                        '${m.fechados} fechado${m.fechados != 1 ? 's' : ''} · '
                        '${m.ativos} ativo${m.ativos != 1 ? 's' : ''}',
                        style:
                            TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${m.taxaConversao.toStringAsFixed(0)}% conv.',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: cs.primary)),
                ),
              ],
            ),

            if (!d.amostraSuficiente) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: cs.outline),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Amostra pequena ($kMinAmostraDecididos+ decididos para diagnóstico confiável)',
                      style: TextStyle(fontSize: 11, color: cs.outline),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            ...d.dimensoes.map((dim) => _dimensaoRow(cs, dim)),

            // Gargalo
            if (d.amostraSuficiente && gargalo != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.priority_high_rounded,
                        size: 16, color: Colors.red.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Maior gargalo: ${gargalo.rotulo.toLowerCase()}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dimensaoRow(ColorScheme cs, DimensaoDesempenho dim) {
    final (cor, icone) = switch (dim.posicao) {
      Posicao.acima => (Colors.green.shade600, Icons.arrow_upward_rounded),
      Posicao.abaixo => (Colors.red.shade600, Icons.arrow_downward_rounded),
      Posicao.naMedia => (cs.outline, Icons.remove_rounded),
      Posicao.semDados => (cs.outline, Icons.horizontal_rule_rounded),
    };

    String fmt(double? v) {
      if (v == null) return '—';
      return dim.unidade == 'dias'
          ? '${v.toStringAsFixed(0)}d'
          : '${v.toStringAsFixed(0)}%';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(dim.rotulo,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ),
          Icon(icone, size: 14, color: cor),
          const SizedBox(width: 4),
          Text(fmt(dim.valor),
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: cor)),
          const SizedBox(width: 6),
          Text('(média ${fmt(dim.media)})',
              style: TextStyle(fontSize: 11, color: cs.outline)),
        ],
      ),
    );
  }

  Widget _avatar(String nome) {
    final inicial = nome.isNotEmpty ? nome[0].toUpperCase() : '?';
    final cores = [
      Colors.blue.shade700,
      Colors.teal.shade600,
      Colors.indigo.shade600,
      Colors.orange.shade700,
      Colors.green.shade700,
      Colors.cyan.shade700,
    ];
    final cor = cores[
        (nome.isEmpty ? 0 : nome.codeUnits.first) % cores.length];
    return CircleAvatar(
      radius: 18,
      backgroundColor: cor.withValues(alpha: 0.15),
      child: Text(inicial,
          style: TextStyle(
              color: cor, fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _vazio(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.groups_outlined, size: 40, color: cs.outline),
              const SizedBox(height: 12),
              Text('Sem dados de vendedores para analisar',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: cs.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}
