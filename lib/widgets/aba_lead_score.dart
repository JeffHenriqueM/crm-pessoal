import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../models/usuario_model.dart';
import '../services/lead_score.dart';
import '../utils/acoes_lead.dart';

/// Aba "Potencial" — Lead Score: lista os leads ativos por propensão de
/// fechamento (Quente / Morno / Frio), priorizando os mais quentes.
///
/// A regra vive em `services/lead_score.dart` (lógica pura, testada).
class AbaLeadScore extends StatefulWidget {
  final List<Cliente> clientes;
  final List<Usuario> todosVendedores;
  final String userProfile;

  const AbaLeadScore({
    super.key,
    required this.clientes,
    this.todosVendedores = const [],
    this.userProfile = 'admin',
  });

  @override
  State<AbaLeadScore> createState() => _AbaLeadScoreState();
}

class _ScoreItem {
  final Cliente cliente;
  final ScoreLead score;
  const _ScoreItem(this.cliente, this.score);
}

class _AbaLeadScoreState extends State<AbaLeadScore> {
  String? _vendedorIdFiltro; // null = todos
  TemperaturaLead? _tempFiltro; // null = todas

  Color _corTemp(TemperaturaLead t, ColorScheme cs) {
    switch (t) {
      case TemperaturaLead.quente:
        return Colors.deepOrange.shade700;
      case TemperaturaLead.morno:
        return Colors.amber.shade800;
      case TemperaturaLead.frio:
        return Colors.blueGrey;
    }
  }

  IconData _iconeTemp(TemperaturaLead t) {
    switch (t) {
      case TemperaturaLead.quente:
        return Icons.local_fire_department_rounded;
      case TemperaturaLead.morno:
        return Icons.wb_sunny_outlined;
      case TemperaturaLead.frio:
        return Icons.ac_unit_rounded;
    }
  }

  bool _temPerfilAdmin() =>
      widget.userProfile == 'admin' || widget.userProfile == 'super admin';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final agora = DateTime.now();
    final mostrarFiltro =
        widget.todosVendedores.isNotEmpty && _temPerfilAdmin();

    final base = _vendedorIdFiltro == null
        ? widget.clientes
        : widget.clientes
            .where((c) =>
                c.vendedorId == _vendedorIdFiltro ||
                c.linerId == _vendedorIdFiltro)
            .toList();

    // Avalia, mantém só leads ativos, ordena por pontuação desc.
    final itens = base
        .map((c) => _ScoreItem(c, avaliarLeadScoreCliente(c, agora: agora)))
        .where((i) => i.score.ativo)
        .toList()
      ..sort((a, b) => b.score.pontuacao.compareTo(a.score.pontuacao));

    final quentes = itens
        .where((i) => i.score.temperatura == TemperaturaLead.quente)
        .length;
    final mornos = itens
        .where((i) => i.score.temperatura == TemperaturaLead.morno)
        .length;
    final frios = itens
        .where((i) => i.score.temperatura == TemperaturaLead.frio)
        .length;

    final visiveis = _tempFiltro == null
        ? itens
        : itens.where((i) => i.score.temperatura == _tempFiltro).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Potencial de Fechamento',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface)),
                    const SizedBox(height: 2),
                    Text(
                      'Leads ativos por propensão — ataque os quentes primeiro',
                      style: TextStyle(fontSize: 12, color: cs.outline),
                    ),
                  ],
                ),
              ),
              if (mostrarFiltro) _filtroVendedor(cs),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                  child: _kpi(cs, 'Quente', quentes, TemperaturaLead.quente)),
              const SizedBox(width: 8),
              Expanded(
                  child: _kpi(cs, 'Morno', mornos, TemperaturaLead.morno)),
              const SizedBox(width: 8),
              Expanded(child: _kpi(cs, 'Frio', frios, TemperaturaLead.frio)),
            ],
          ),
          if (_tempFiltro != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Mostrando: ${_tempFiltro!.rotulo}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant)),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => setState(() => _tempFiltro = null),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close, size: 14, color: cs.primary),
                        const SizedBox(width: 2),
                        Text('limpar',
                            style:
                                TextStyle(fontSize: 12, color: cs.primary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),

          if (itens.isEmpty)
            _estadoVazio(cs)
          else if (visiveis.isEmpty)
            _semNaTemp(cs)
          else
            ...visiveis.map((i) => _cardScore(context, cs, i)),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _filtroVendedor(ColorScheme cs) {
    final selecionado = _vendedorIdFiltro == null
        ? 'Todos'
        : widget.todosVendedores
            .firstWhere((u) => u.id == _vendedorIdFiltro,
                orElse: () =>
                    Usuario(id: '', nome: 'Todos', email: '', perfil: ''))
            .nome;

    return PopupMenuButton<String?>(
      tooltip: 'Filtrar por vendedor',
      onSelected: (v) => setState(() => _vendedorIdFiltro = v),
      itemBuilder: (_) => [
        const PopupMenuItem<String?>(value: null, child: Text('Todos')),
        ...widget.todosVendedores
            .where((u) => u.perfil == 'vendedor' || u.perfil == 'captador')
            .map((u) =>
                PopupMenuItem<String?>(value: u.id, child: Text(u.nome))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(selecionado,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: cs.onSurface)),
            ),
            Icon(Icons.arrow_drop_down, size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _kpi(ColorScheme cs, String titulo, int valor, TemperaturaLead temp) {
    final cor = _corTemp(temp, cs);
    final icone = _iconeTemp(temp);
    final selecionado = _tempFiltro == temp;

    return Card(
      margin: EdgeInsets.zero,
      color: selecionado ? cor.withValues(alpha: 0.12) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selecionado
            ? BorderSide(color: cor, width: 1.6)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            setState(() => _tempFiltro = selecionado ? null : temp),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            children: [
              Icon(icone, color: cor, size: 22),
              const SizedBox(height: 6),
              Text('$valor',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, color: cor)),
              Text(titulo,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _estadoVazio(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 40, color: cs.outline),
              const SizedBox(height: 12),
              Text('Nenhum lead ativo para pontuar',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: cs.onSurface)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _semNaTemp(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Center(
          child: Text('Nenhum lead "${_tempFiltro?.rotulo}" no momento',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        ),
      ),
    );
  }

  Widget _cardScore(BuildContext context, ColorScheme cs, _ScoreItem item) {
    final c = item.cliente;
    final s = item.score;
    final cor = _corTemp(s.temperatura, cs);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            mostrarAcoesLead(context, c, userProfile: widget.userProfile),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: cor.withValues(alpha: 0.14),
                    child: Icon(_iconeTemp(s.temperatura), color: cor,
                        size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.nome,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        Text(
                          '${c.fase.nomeDisplay}'
                          '${c.vendedorNome?.isNotEmpty == true ? ' · ${c.vendedorNome}' : ''}',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: cor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(s.temperatura.rotulo,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: cor)),
                      ),
                      const SizedBox(height: 2),
                      Text('${s.pontuacao}/100',
                          style: TextStyle(fontSize: 10, color: cs.outline)),
                    ],
                  ),
                ],
              ),
              if (s.sinais.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: s.sinais
                      .map((m) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(m,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant)),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
