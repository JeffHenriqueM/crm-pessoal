import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../models/usuario_model.dart';
import '../services/tempo_sem_contato.dart';
import '../utils/acoes_lead.dart';

/// Aba "Tempo sem contato" (ticket #48) — lista os leads ativos por dias sem
/// contato nas faixas 15/20/30, priorizados do mais crítico para o menos.
///
/// A regra vive em `services/tempo_sem_contato.dart` (lógica pura, testada).
/// Aqui é só apresentação + filtro por vendedor. É um recorte mais simples e
/// por recência pura que a aba "Risco de Silêncio" (que pondera follow-up
/// vencido e sem-resposta com outros thresholds).
class AbaTempoSemContato extends StatefulWidget {
  final List<Cliente> clientes;
  final List<Usuario> todosVendedores;
  final String userProfile;

  const AbaTempoSemContato({
    super.key,
    required this.clientes,
    this.todosVendedores = const [],
    this.userProfile = 'admin',
  });

  @override
  State<AbaTempoSemContato> createState() => _AbaTempoSemContatoState();
}

class _ItemTempo {
  final Cliente cliente;
  final AvaliacaoTempoContato avaliacao;
  const _ItemTempo(this.cliente, this.avaliacao);
}

class _AbaTempoSemContatoState extends State<AbaTempoSemContato> {
  String? _vendedorIdFiltro; // null = todos
  AlertaTempoContato? _faixaFiltro; // null = todas as faixas

  IconData _iconeFaixa(AlertaTempoContato f) {
    switch (f) {
      case AlertaTempoContato.critico:
        return Icons.error_outline;
      case AlertaTempoContato.alerta:
        return Icons.warning_amber_rounded;
      case AlertaTempoContato.atencao:
        return Icons.schedule;
      case AlertaTempoContato.emDia:
        return Icons.check_circle_outline;
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

    final itens = base
        .map((c) => _ItemTempo(c, avaliarTempoSemContatoCliente(c, agora: agora)))
        .where((i) => i.avaliacao.temAlerta)
        .toList()
      ..sort((a, b) {
        final sev =
            b.avaliacao.faixa.severidade.compareTo(a.avaliacao.faixa.severidade);
        if (sev != 0) return sev;
        return b.avaliacao.diasSemContato.compareTo(a.avaliacao.diasSemContato);
      });

    int contar(AlertaTempoContato f) =>
        itens.where((i) => i.avaliacao.faixa == f).length;
    final criticos = contar(AlertaTempoContato.critico);
    final alertas = contar(AlertaTempoContato.alerta);
    final atencoes = contar(AlertaTempoContato.atencao);

    final visiveis = _faixaFiltro == null
        ? itens
        : itens.where((i) => i.avaliacao.faixa == _faixaFiltro).toList();

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
                    Text('Tempo sem contato',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface)),
                    const SizedBox(height: 2),
                    Text(
                      'Leads ativos sem mensagem há ≥ 15 dias — meta: ninguém passa de 30',
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
                  child: _kpi(cs, 'Crítico\n30+ dias', criticos,
                      AlertaTempoContato.critico)),
              const SizedBox(width: 8),
              Expanded(
                  child: _kpi(cs, 'Alerta\n20–29 dias', alertas,
                      AlertaTempoContato.alerta)),
              const SizedBox(width: 8),
              Expanded(
                  child: _kpi(cs, 'Atenção\n15–19 dias', atencoes,
                      AlertaTempoContato.atencao)),
            ],
          ),
          if (_faixaFiltro != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Mostrando: ${_faixaFiltro!.rotulo}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant)),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => setState(() => _faixaFiltro = null),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
            _semNaFaixa(cs)
          else
            ...visiveis.map((i) => _cardItem(context, cs, i)),

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

  Widget _kpi(
      ColorScheme cs, String titulo, int valor, AlertaTempoContato faixa) {
    final cor = faixa.cor ?? cs.outline;
    final selecionado = _faixaFiltro == faixa;

    return Card(
      margin: EdgeInsets.zero,
      color: selecionado ? cor.withValues(alpha: 0.12) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            selecionado ? BorderSide(color: cor, width: 1.6) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            setState(() => _faixaFiltro = selecionado ? null : faixa),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Column(
            children: [
              Icon(_iconeFaixa(faixa), color: cor, size: 22),
              const SizedBox(height: 6),
              Text('$valor',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, color: cor)),
              Text(titulo,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _semNaFaixa(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Center(
          child: Text(
            'Nenhum lead em "${_faixaFiltro?.rotulo}" no momento',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
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
              Icon(Icons.celebration_outlined,
                  size: 40, color: Colors.green.shade600),
              const SizedBox(height: 12),
              Text('Todo mundo contatado nos últimos 15 dias',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 4),
              Text('Nenhum lead ativo passou do limite — siga assim.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: cs.outline)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardItem(BuildContext context, ColorScheme cs, _ItemTempo item) {
    final c = item.cliente;
    final a = item.avaliacao;
    final cor = a.faixa.cor ?? cs.outline;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            mostrarAcoesLead(context, c, userProfile: widget.userProfile),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: cor.withValues(alpha: 0.14),
                child: Icon(_iconeFaixa(a.faixa), color: cor, size: 20),
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
                      style:
                          TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
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
                    child: Text(a.faixa.rotulo,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: cor)),
                  ),
                  const SizedBox(height: 2),
                  Text('${a.diasSemContato}d sem contato',
                      style: TextStyle(fontSize: 10, color: cs.outline)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
