import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../screens/interacoes_screen.dart';
import '../services/firestore_service.dart';

// ── Modelo de categoria de notificação ───────────────────────────────────────
class _NotifCategoria {
  final String titulo;
  final IconData icone;
  final Color cor;
  final List<_NotifItem> itens;

  const _NotifCategoria({
    required this.titulo,
    required this.icone,
    required this.cor,
    required this.itens,
  });
}

class _NotifItem {
  final Cliente cliente;
  final String subtitulo;

  const _NotifItem({required this.cliente, required this.subtitulo});
}

// ── Widget principal ──────────────────────────────────────────────────────────
class NotificacaoBell extends StatelessWidget {
  /// null = admin vê todos; uid = vendedor vê só os seus
  final String? vendedorId;

  const NotificacaoBell({super.key, required this.vendedorId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Cliente>>(
      stream:
          FirestoreService().getTodosClientesStream(vendedorId: vendedorId),
      builder: (context, snapshot) {
        final clientes = snapshot.data ?? [];
        final categorias = _calcularCategorias(clientes);
        final total =
            categorias.fold<int>(0, (s, c) => s + c.itens.length);

        return Badge(
          isLabelVisible: total > 0,
          label: Text(
            total > 99 ? '99+' : '$total',
            style: const TextStyle(fontSize: 10),
          ),
          alignment: const AlignmentDirectional(10, -8),
          child: IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: total > 0
                ? '$total notificação${total != 1 ? 'ões' : ''}'
                : 'Sem notificações',
            onPressed: () => _mostrarPainel(context, categorias, total),
          ),
        );
      },
    );
  }

  // ── Cálculo das categorias ─────────────────────────────────────────────────
  List<_NotifCategoria> _calcularCategorias(List<Cliente> todos) {
    final hoje = DateTime.now();
    final inicioDoDia = DateTime(hoje.year, hoje.month, hoje.day);
    final fimDoDia = inicioDoDia.add(const Duration(days: 1));

    // Exclui fechados e perdidos de todos os alertas
    final ativos = todos.where((c) =>
        c.fase != FaseCliente.fechado && c.fase != FaseCliente.perdido);

    // 1. Contatos para hoje
    final contatosHoje = ativos
        .where((c) =>
            c.proximoContato != null &&
            !c.proximoContato!.isBefore(inicioDoDia) &&
            c.proximoContato!.isBefore(fimDoDia))
        .map((c) => _NotifItem(
              cliente: c,
              subtitulo: c.vendedorNome != null && vendedorId == null
                  ? 'Vendedor: ${c.vendedorNome}'
                  : 'Contato programado para hoje',
            ))
        .toList();

    // 2. Contatos atrasados (mais urgentes primeiro)
    final atrasados = ativos
        .where((c) =>
            c.proximoContato != null &&
            c.proximoContato!.isBefore(inicioDoDia))
        .toList()
      ..sort((a, b) => a.proximoContato!.compareTo(b.proximoContato!));
    final itensAtrasados = atrasados.map((c) {
      final dias = inicioDoDia.difference(c.proximoContato!).inDays;
      final sufixo = vendedorId == null && c.vendedorNome != null
          ? ' · ${c.vendedorNome}'
          : '';
      return _NotifItem(
        cliente: c,
        subtitulo: '$dias dia${dias != 1 ? 's' : ''} em atraso$sufixo',
      );
    }).toList();

    // 3. Visitas hoje
    final visitasHoje = todos
        .where((c) =>
            c.dataVisita != null &&
            !c.dataVisita!.isBefore(inicioDoDia) &&
            c.dataVisita!.isBefore(fimDoDia))
        .map((c) {
      final hora = DateFormat('HH:mm').format(c.dataVisita!);
      final sufixo = vendedorId == null && c.vendedorNome != null
          ? ' · ${c.vendedorNome}'
          : '';
      return _NotifItem(
        cliente: c,
        subtitulo: 'Visita às $hora$sufixo',
      );
    }).toList();

    // 4. Em negociação sem atualização há mais de 7 dias
    final semUpdate = ativos
        .where((c) =>
            c.fase == FaseCliente.negociacao &&
            hoje.difference(c.dataAtualizacao).inDays >= 7)
        .toList()
      ..sort((a, b) => a.dataAtualizacao.compareTo(b.dataAtualizacao));
    final itensSemUpdate = semUpdate.map((c) {
      final dias = hoje.difference(c.dataAtualizacao).inDays;
      final sufixo = vendedorId == null && c.vendedorNome != null
          ? ' · ${c.vendedorNome}'
          : '';
      return _NotifItem(
        cliente: c,
        subtitulo: 'Sem atualização há $dias dias$sufixo',
      );
    }).toList();

    final categorias = <_NotifCategoria>[];

    if (contatosHoje.isNotEmpty) {
      categorias.add(_NotifCategoria(
        titulo: 'Ligar hoje',
        icone: Icons.phone_outlined,
        cor: Colors.blue.shade700,
        itens: contatosHoje,
      ));
    }
    if (itensAtrasados.isNotEmpty) {
      categorias.add(_NotifCategoria(
        titulo: 'Contatos em atraso',
        icone: Icons.access_time_outlined,
        cor: const Color(0xFFB45309), // amber corporativo
        itens: itensAtrasados,
      ));
    }
    if (visitasHoje.isNotEmpty) {
      categorias.add(_NotifCategoria(
        titulo: 'Visitas hoje',
        icone: Icons.location_on_outlined,
        cor: Colors.teal.shade700,
        itens: visitasHoje,
      ));
    }
    if (itensSemUpdate.isNotEmpty) {
      categorias.add(_NotifCategoria(
        titulo: 'Negociação parada',
        icone: Icons.pause_circle_outline,
        cor: Colors.purple.shade600,
        itens: itensSemUpdate,
      ));
    }

    return categorias;
  }

  // ── Painel de notificações ─────────────────────────────────────────────────
  void _mostrarPainel(BuildContext context, List<_NotifCategoria> categorias,
      int total) {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.92,
          builder: (_, scrollController) => Column(
            children: [
              // Handle + cabeçalho
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.notifications_outlined,
                            color: cs.primary, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          'Notificações',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                        const Spacer(),
                        if (total > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$total pendente${total != 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Divider(color: cs.outlineVariant),
                  ],
                ),
              ),

              // Conteúdo scrollável
              Expanded(
                child: total == 0
                    ? _buildVazia(cs)
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
                        children: categorias
                            .map((cat) =>
                                _buildCategoria(ctx, cat, cs))
                            .toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVazia(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline,
              size: 56, color: Colors.green.shade600),
          const SizedBox(height: 16),
          Text(
            'Tudo em dia!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Nenhuma pendência no momento.',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoria(
      BuildContext context, _NotifCategoria cat, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header da categoria
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: cat.cor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(cat.icone, color: cat.cor, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                cat.titulo,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cat.cor,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: cat.cor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${cat.itens.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: cat.cor,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Itens
        ...cat.itens.map((item) => _buildItem(context, item, cat.cor, cs)),

        const Divider(height: 1, indent: 20, endIndent: 20),
      ],
    );
  }

  Widget _buildItem(BuildContext context, _NotifItem item, Color cor,
      ColorScheme cs) {
    final inicial = item.cliente.nome.isNotEmpty
        ? item.cliente.nome[0].toUpperCase()
        : '?';

    return InkWell(
      onTap: () {
        Navigator.of(context).pop(); // fecha o painel
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => InteracoesScreen(cliente: item.cliente),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: cor.withValues(alpha: 0.12),
              child: Text(
                inicial,
                style: TextStyle(
                  color: cor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.cliente.nomeEsposa?.isNotEmpty == true
                        ? '${item.cliente.nome} e ${item.cliente.nomeEsposa}'
                        : item.cliente.nome,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitulo,
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: cs.outline),
          ],
        ),
      ),
    );
  }
}
