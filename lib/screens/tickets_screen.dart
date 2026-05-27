// lib/screens/tickets_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ticket_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'ficha_ticket_screen.dart';

// ── Helpers visuais ───────────────────────────────────────────────────────────

Color _corStatus(StatusTicket s) {
  switch (s) {
    case StatusTicket.aberto:      return const Color(0xFF1565C0);
    case StatusTicket.emAndamento: return const Color(0xFFE65100);
    case StatusTicket.resolvido:   return const Color(0xFF2E7D32);
    case StatusTicket.fechado:     return const Color(0xFF546E7A);
  }
}

Color _corPrioridade(PrioridadeTicket p) {
  switch (p) {
    case PrioridadeTicket.baixa:   return const Color(0xFF78909C);
    case PrioridadeTicket.normal:  return const Color(0xFF1565C0);
    case PrioridadeTicket.alta:    return const Color(0xFFE65100);
    case PrioridadeTicket.urgente: return const Color(0xFFC62828);
  }
}

IconData _iconeCategoria(CategoriaTicket c) {
  switch (c) {
    case CategoriaTicket.suporte:  return Icons.support_agent_outlined;
    case CategoriaTicket.bug:      return Icons.bug_report_outlined;
    case CategoriaTicket.melhoria: return Icons.lightbulb_outlined;
    case CategoriaTicket.duvida:   return Icons.help_outline;
    case CategoriaTicket.outro:    return Icons.label_outline;
  }
}

// ── Tela principal ────────────────────────────────────────────────────────────

class TicketsScreen extends StatefulWidget {
  final String userProfile;
  final String? currentUserId;
  final String? currentUserName;

  const TicketsScreen({
    super.key,
    required this.userProfile,
    this.currentUserId,
    this.currentUserName,
  });

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen>
    with SingleTickerProviderStateMixin {
  final _service = FirestoreService();
  final _authService = AuthService();

  late final TabController _tabCtrl;
  List<Ticket> _todos = [];
  List<Ticket> _meus = [];
  StreamSubscription<List<Ticket>>? _todosSub;
  StreamSubscription<List<Ticket>>? _meusSub;

  StatusTicket? _filtroStatus;
  PrioridadeTicket? _filtroPrioridade;

  bool get _isAdmin =>
      widget.userProfile == 'admin' || widget.userProfile == 'super admin';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _isAdmin ? 2 : 1, vsync: this);
    _iniciarStreams();
  }

  void _iniciarStreams() {
    final uid = widget.currentUserId ?? _authService.getCurrentUser()?.uid ?? '';

    if (_isAdmin) {
      _todosSub = _service.getTicketsStream().listen((lista) {
        if (mounted) setState(() => _todos = lista);
      });
    }

    _meusSub = _service.getMeusTicketsStream(uid).listen((lista) {
      if (mounted) setState(() => _meus = lista);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _todosSub?.cancel();
    _meusSub?.cancel();
    super.dispose();
  }

  // ── Filtros ────────────────────────────────────────────────────────────────

  List<Ticket> _aplicarFiltros(List<Ticket> lista) {
    return lista.where((t) {
      if (_filtroStatus != null && t.status != _filtroStatus) return false;
      if (_filtroPrioridade != null && t.prioridade != _filtroPrioridade) return false;
      return true;
    }).toList();
  }

  // ── Criar ticket ───────────────────────────────────────────────────────────

  void _abrirNovoTicket() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FichaTicketScreen(
          userProfile: widget.userProfile,
          currentUserId: widget.currentUserId,
          currentUserName: widget.currentUserName,
        ),
      ),
    );
  }

  void _abrirTicket(Ticket ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FichaTicketScreen(
          ticket: ticket,
          userProfile: widget.userProfile,
          currentUserId: widget.currentUserId,
          currentUserName: widget.currentUserName,
        ),
      ),
    );
  }

  // ── Filtros chip row ───────────────────────────────────────────────────────

  Widget _buildFiltros() {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          // Status chips
          ...StatusTicket.values.map((s) {
            final sel = _filtroStatus == s;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(s.nomeDisplay, style: const TextStyle(fontSize: 12)),
                selected: sel,
                onSelected: (_) => setState(() => _filtroStatus = sel ? null : s),
                selectedColor: _corStatus(s).withValues(alpha: 0.15),
                side: BorderSide(
                  color: sel ? _corStatus(s) : cs.outlineVariant,
                ),
                labelStyle: TextStyle(
                  color: sel ? _corStatus(s) : cs.onSurfaceVariant,
                ),
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
              ),
            );
          }),
          const SizedBox(width: 6),
          const VerticalDivider(width: 1, thickness: 1, indent: 4, endIndent: 4),
          const SizedBox(width: 6),
          // Prioridade chips
          ...PrioridadeTicket.values.map((p) {
            final sel = _filtroPrioridade == p;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(p.nomeDisplay, style: const TextStyle(fontSize: 12)),
                selected: sel,
                onSelected: (_) => setState(() => _filtroPrioridade = sel ? null : p),
                selectedColor: _corPrioridade(p).withValues(alpha: 0.15),
                side: BorderSide(
                  color: sel ? _corPrioridade(p) : cs.outlineVariant,
                ),
                labelStyle: TextStyle(
                  color: sel ? _corPrioridade(p) : cs.onSurfaceVariant,
                ),
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
              ),
            );
          }),
          if (_filtroStatus != null || _filtroPrioridade != null) ...[
            const SizedBox(width: 6),
            ActionChip(
              label: const Text('Limpar', style: TextStyle(fontSize: 12)),
              onPressed: () => setState(() {
                _filtroStatus = null;
                _filtroPrioridade = null;
              }),
              avatar: Icon(Icons.clear, size: 14, color: cs.error),
              side: BorderSide(color: cs.outlineVariant),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }

  // ── Card de ticket ─────────────────────────────────────────────────────────

  Widget _buildCard(Ticket ticket) {
    final cs = Theme.of(context).colorScheme;
    final corS = _corStatus(ticket.status);
    final corP = _corPrioridade(ticket.prioridade);
    final fmt = DateFormat('dd/MM', 'pt_BR');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _abrirTicket(ticket),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Linha superior: categoria ícone + título + prioridade badge
              Row(
                children: [
                  Icon(
                    _iconeCategoria(ticket.categoria),
                    size: 15,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ticket.titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Badge de prioridade (apenas alta/urgente são visíveis)
                  if (ticket.prioridade == PrioridadeTicket.alta ||
                      ticket.prioridade == PrioridadeTicket.urgente)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: corP.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: corP.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        ticket.prioridade.nomeDisplay,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: corP,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              // Descrição preview
              Text(
                ticket.descricao,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Linha inferior: status + data + autor + comentários
              Row(
                children: [
                  // Status chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: corS.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: corS.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      ticket.status.nomeDisplay,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: corS,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Categoria
                  Text(
                    ticket.categoria.nomeDisplay,
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                  const Spacer(),
                  // Comentários
                  if (ticket.totalComentarios > 0) ...[
                    Icon(Icons.chat_bubble_outline, size: 12, color: cs.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Text(
                      '${ticket.totalComentarios}',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Data
                  Text(
                    fmt.format(ticket.dataAtualizacao),
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Lista vazia ────────────────────────────────────────────────────────────

  Widget _buildVazio(String msg) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.confirmation_number_outlined,
              size: 56, color: cs.outline.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(msg, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _abrirNovoTicket,
            icon: const Icon(Icons.add),
            label: const Text('Abrir Ticket'),
          ),
        ],
      ),
    );
  }

  // ── Aba de lista ───────────────────────────────────────────────────────────

  Widget _buildLista(List<Ticket> lista, String emptyMsg) {
    final filtrada = _aplicarFiltros(lista);
    if (filtrada.isEmpty) return _buildVazio(emptyMsg);
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 80),
      itemCount: filtrada.length,
      itemBuilder: (_, i) => _buildCard(filtrada[i]),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tickets'),
        automaticallyImplyLeading: false,
        bottom: _isAdmin
            ? TabBar(
                controller: _tabCtrl,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Todos'),
                        if (_todos.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Badge.count(count: _todos.length),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Meus tickets'),
                        if (_meus.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Badge.count(count: _meus.length),
                        ],
                      ],
                    ),
                  ),
                ],
              )
            : null,
      ),
      body: Column(
        children: [
          _buildFiltros(),
          const SizedBox(height: 4),
          Expanded(
            child: _isAdmin
                ? TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildLista(_todos, 'Nenhum ticket encontrado'),
                      _buildLista(_meus, 'Você ainda não abriu nenhum ticket'),
                    ],
                  )
                : _buildLista(_meus, 'Você ainda não abriu nenhum ticket'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirNovoTicket,
        icon: const Icon(Icons.add),
        label: const Text('Novo Ticket'),
      ),
    );
  }
}
