import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/campanha_model.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../screens/ficha_cliente_screen.dart';
import '../services/firestore_service.dart';

// ── Modelos internos ──────────────────────────────────────────────────────────
class _NotifCategoria {
  final String titulo;
  final IconData icone;
  final Color cor;
  final List<_NotifItem> itens;
  const _NotifCategoria(
      {required this.titulo,
      required this.icone,
      required this.cor,
      required this.itens});
}

class _NotifItem {
  final Cliente cliente;
  final String subtitulo;
  const _NotifItem({required this.cliente, required this.subtitulo});
}

class _CampanhaNotifItem {
  final String nome;
  final String resumo;
  final String periodo;
  const _CampanhaNotifItem(
      {required this.nome, required this.resumo, required this.periodo});
}

// ── Widget: sino com badge ────────────────────────────────────────────────────
class NotificacaoBell extends StatelessWidget {
  final String? vendedorId;

  /// Quando true, renderiza como ListTile completo (ícone + texto "Notificações")
  /// com o badge como trailing. Toda a linha é clicável.
  /// Quando false (padrão), renderiza apenas o IconButton com badge sobreposto.
  final bool showAsListTile;

  const NotificacaoBell({
    super.key,
    required this.vendedorId,
    this.showAsListTile = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmtPeriodo = DateFormat('dd/MM');

    // Stream externo: campanhas vigentes (todas, sem filtro de vendedor)
    return StreamBuilder<List<Campanha>>(
      stream: FirestoreService().getCampanhasVigentesStream(),
      builder: (context, campanhasSnap) {
        final campanhas = campanhasSnap.data ?? [];
        final campNotifs = campanhas
            .map((c) => _CampanhaNotifItem(
                  nome: c.nome,
                  resumo: c.resumo,
                  periodo:
                      '${fmtPeriodo.format(c.dataInicio)} → ${fmtPeriodo.format(c.dataFim)}',
                ))
            .toList();

        // Stream interno: clientes (filtrado por vendedor, se aplicável)
        return StreamBuilder<List<Cliente>>(
          stream: FirestoreService()
              .getTodosClientesStream(vendedorId: vendedorId),
          builder: (context, snapshot) {
            final clientes = snapshot.data ?? [];
            final categorias = _calcularCategorias(clientes);
            final totalClientes =
                categorias.fold<int>(0, (s, c) => s + c.itens.length);
            final total = totalClientes + campNotifs.length;

            void abrirPainel() =>
                _mostrarPainel(context, categorias, campNotifs, total);

            // ── Modo ListTile (sidebar expandida) ─────────────────────────
            if (showAsListTile) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                child: ListTile(
                  leading: Icon(
                    total > 0
                        ? Icons.notifications_rounded
                        : Icons.notifications_outlined,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                  title: Text(
                    'Notificações',
                    style: TextStyle(fontSize: 14, color: cs.onSurface),
                  ),
                  trailing: total > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            total > 99 ? '99+' : '$total',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  horizontalTitleGap: 8,
                  dense: true,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  onTap: abrirPainel,
                ),
              );
            }

            // ── Modo ícone (sidebar compacta ou mobile) ───────────────────
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Icon(
                    total > 0
                        ? Icons.notifications_rounded
                        : Icons.notifications_outlined,
                    color: cs.onSurface,
                  ),
                  tooltip: total > 0
                      ? '$total notificaç${total == 1 ? 'ão' : 'ões'} pendente${total != 1 ? 's' : ''}'
                      : 'Sem notificações',
                  onPressed: abrirPainel,
                ),
                if (total > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: cs.surface, width: 1.5),
                        ),
                        constraints: const BoxConstraints(minWidth: 16),
                        child: Text(
                          total > 99 ? '99+' : '$total',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Cálculo das categorias de clientes ─────────────────────────────────────
  List<_NotifCategoria> _calcularCategorias(List<Cliente> todos) {
    final hoje = DateTime.now();
    final inicioDoDia = DateTime(hoje.year, hoje.month, hoje.day);
    final fimDoDia = inicioDoDia.add(const Duration(days: 1));

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
              subtitulo: vendedorId == null && c.vendedorNome != null
                  ? c.vendedorNome!
                  : 'Contato programado para hoje',
            ))
        .toList();

    // 2. Contatos atrasados (mais antigo primeiro)
    final atrasados = ativos
        .where((c) =>
            c.proximoContato != null &&
            c.proximoContato!.isBefore(inicioDoDia))
        .toList()
      ..sort((a, b) => a.proximoContato!.compareTo(b.proximoContato!));
    final itensAtrasados = atrasados.map((c) {
      final dias = inicioDoDia.difference(c.proximoContato!).inDays;
      final quem = vendedorId == null && c.vendedorNome != null
          ? ' · ${c.vendedorNome}'
          : '';
      return _NotifItem(
        cliente: c,
        subtitulo: '$dias dia${dias != 1 ? 's' : ''} em atraso$quem',
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
      final quem = vendedorId == null && c.vendedorNome != null
          ? ' · ${c.vendedorNome}'
          : '';
      return _NotifItem(
          cliente: c, subtitulo: 'Visita às $hora$quem');
    }).toList();

    // 4. Negociação parada +7 dias
    final semUpdate = ativos
        .where((c) =>
            c.fase == FaseCliente.negociacao &&
            hoje.difference(c.dataAtualizacao).inDays >= 7)
        .toList()
      ..sort((a, b) => a.dataAtualizacao.compareTo(b.dataAtualizacao));
    final itensSemUpdate = semUpdate.map((c) {
      final dias = hoje.difference(c.dataAtualizacao).inDays;
      final quem = vendedorId == null && c.vendedorNome != null
          ? ' · ${c.vendedorNome}'
          : '';
      return _NotifItem(
          cliente: c,
          subtitulo: 'Sem atualização há $dias dias$quem');
    }).toList();

    return [
      if (contatosHoje.isNotEmpty)
        _NotifCategoria(
          titulo: 'Ligar hoje',
          icone: Icons.phone_outlined,
          cor: Colors.blue.shade700,
          itens: contatosHoje,
        ),
      if (itensAtrasados.isNotEmpty)
        _NotifCategoria(
          titulo: 'Contatos em atraso',
          icone: Icons.access_time_outlined,
          cor: const Color(0xFFB45309),
          itens: itensAtrasados,
        ),
      if (visitasHoje.isNotEmpty)
        _NotifCategoria(
          titulo: 'Visitas hoje',
          icone: Icons.location_on_outlined,
          cor: Colors.teal.shade700,
          itens: visitasHoje,
        ),
      if (itensSemUpdate.isNotEmpty)
        _NotifCategoria(
          titulo: 'Negociação parada',
          icone: Icons.pause_circle_outline,
          cor: Colors.purple.shade600,
          itens: itensSemUpdate,
        ),
    ];
  }

  // ── Painel lateral deslizante ─────────────────────────────────────────────
  void _mostrarPainel(
    BuildContext context,
    List<_NotifCategoria> categorias,
    List<_CampanhaNotifItem> campanhas,
    int total,
  ) {
    final larguraTela = MediaQuery.of(context).size.width;
    final larguraPainel = min(380.0, larguraTela * 0.88);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar notificações',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, _, __) => Align(
        alignment: Alignment.centerRight,
        child: _PainelLateral(
          largura: larguraPainel,
          categorias: categorias,
          campanhas: campanhas,
          total: total,
        ),
      ),
      transitionBuilder: (ctx, anim, _, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }
}

// ── Painel lateral ────────────────────────────────────────────────────────────
class _PainelLateral extends StatelessWidget {
  final double largura;
  final List<_NotifCategoria> categorias;
  final List<_CampanhaNotifItem> campanhas;
  final int total;

  const _PainelLateral({
    required this.largura,
    required this.categorias,
    required this.campanhas,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Material(
      elevation: 16,
      color: isLight ? Colors.white : const Color(0xFF1F2937),
      shadowColor: Colors.black.withValues(alpha: 0.3),
      child: SafeArea(
        child: SizedBox(
          width: largura,
          height: double.infinity,
          child: Column(
            children: [
              // ── Cabeçalho fixo ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                        color: cs.outlineVariant, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notifications_outlined,
                        color: cs.primary, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Notificações',
                      style: TextStyle(
                        fontSize: 17,
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
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon:
                          Icon(Icons.close, color: cs.onSurfaceVariant),
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // ── Conteúdo scrollável ────────────────────────────────
              Expanded(
                child: total == 0
                    ? _buildVazia(cs)
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          if (campanhas.isNotEmpty)
                            _buildCategoriaCampanha(context, cs),
                          ...categorias
                              .map((cat) =>
                                  _buildCategoria(context, cat, cs)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVazia(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline,
              size: 52, color: Colors.green.shade600),
          const SizedBox(height: 16),
          Text('Tudo em dia!',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface)),
          const SizedBox(height: 4),
          Text('Nenhuma pendência no momento.',
              style:
                  TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  // ── Categoria de campanhas vigentes ────────────────────────────────────────
  Widget _buildCategoriaCampanha(BuildContext context, ColorScheme cs) {
    final cor = Colors.green.shade700;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(Icons.campaign_outlined, color: cor, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                'Condições Vigentes',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cor,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${campanhas.length}',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold, color: cor),
                ),
              ),
            ],
          ),
        ),
        ...campanhas
            .map((c) => _buildItemCampanha(c, cor, cs)),
        Divider(
            height: 1,
            indent: 20,
            endIndent: 20,
            color: cs.outlineVariant),
      ],
    );
  }

  Widget _buildItemCampanha(
      _CampanhaNotifItem item, Color cor, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.local_offer_outlined, size: 16, color: cor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nome,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  item.resumo,
                  style: TextStyle(
                      fontSize: 12,
                      color: cor,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.periodo,
                  style:
                      TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Categoria de clientes ──────────────────────────────────────────────────
  Widget _buildCategoria(
      BuildContext context, _NotifCategoria cat, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: cat.cor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(cat.icone, color: cat.cor, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                cat.titulo,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cat.cor,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: cat.cor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${cat.itens.length}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: cat.cor,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...cat.itens.map((item) => _buildItem(context, item, cat.cor, cs)),
        Divider(
            height: 1,
            indent: 20,
            endIndent: 20,
            color: cs.outlineVariant),
      ],
    );
  }

  Widget _buildItem(BuildContext context, _NotifItem item, Color cor,
      ColorScheme cs) {
    final inicial = item.cliente.nome.isNotEmpty
        ? item.cliente.nome[0].toUpperCase()
        : '?';
    final nomeCompleto = item.cliente.nomeEsposa?.isNotEmpty == true
        ? '${item.cliente.nome} e ${item.cliente.nomeEsposa}'
        : item.cliente.nome;

    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => FichaClienteScreen(cliente: item.cliente),
        ));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: cor.withValues(alpha: 0.12),
              child: Text(
                inicial,
                style: TextStyle(
                  color: cor,
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
                  Text(
                    nomeCompleto,
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
            Icon(Icons.chevron_right, size: 16, color: cs.outline),
          ],
        ),
      ),
    );
  }
}
