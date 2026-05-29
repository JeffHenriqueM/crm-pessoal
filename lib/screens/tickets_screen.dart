// lib/screens/tickets_screen.dart

import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:web/web.dart' as web;
import '../models/ticket_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'ficha_ticket_screen.dart';

// ── Helpers visuais ───────────────────────────────────────────────────────────

Color _corStatus(StatusTicket s) {
  switch (s) {
    case StatusTicket.aberto:               return const Color(0xFF1565C0);
    case StatusTicket.emAndamento:          return const Color(0xFFE65100);
    case StatusTicket.aguardandoValidacao:  return const Color(0xFF7B1FA2);
    case StatusTicket.resolvido:            return const Color(0xFF2E7D32);
    case StatusTicket.fechado:              return const Color(0xFF546E7A);
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

  StatusTicket? _filtroStatus = StatusTicket.aberto;
  PrioridadeTicket? _filtroPrioridade;
  TipoTicket? _filtroTipo;

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

    _meusSub = _service.getMeusTicketsStream(uid).listen(
      (lista) {
        if (mounted) setState(() => _meus = lista);
      },
      onError: (e) => debugPrint('[Tickets] getMeusTicketsStream erro: $e'),
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _todosSub?.cancel();
    _meusSub?.cancel();
    super.dispose();
  }

  // ── Export CSV ────────────────────────────────────────────────────────────

  String _csvEscape(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  void _exportarCSV() {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final buffer = StringBuffer();
    buffer.writeln('Numero,Titulo,Tipo,Prioridade,Status,Criado Por,Perfil,Contexto,Data Criacao,Data Atualizacao');

    for (final t in _todos) {
      buffer.writeln([
        t.numero > 0 ? '#${t.numero}' : '',
        _csvEscape(t.titulo),
        t.tipo.nomeDisplay,
        t.prioridade.nomeDisplay,
        t.status.nomeDisplay,
        _csvEscape(t.criadoPorNome),
        _csvEscape(t.criadoPorPerfil),
        _csvEscape(t.contexto ?? ''),
        fmt.format(t.dataCriacao),
        fmt.format(t.dataAtualizacao),
      ].join(','));
    }

    // BOM UTF-8 garante que Excel/Numbers abra com encoding correto
    final csv = '﻿${buffer.toString()}';
    final blob = web.Blob(
      [csv.toJS].toJS,
      web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = 'tickets_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    web.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }

  // ── Filtros ────────────────────────────────────────────────────────────────

  List<Ticket> _aplicarFiltros(List<Ticket> lista) {
    return lista.where((t) {
      if (_filtroStatus != null && t.status != _filtroStatus) return false;
      if (_filtroPrioridade != null && t.prioridade != _filtroPrioridade) return false;
      if (_filtroTipo != null && t.tipo != _filtroTipo) return false;
      return true;
    }).toList();
  }

  // ── Abrir / criar ticket ───────────────────────────────────────────────────

  void _abrirNovoTicket() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FichaTicketScreen(
          userProfile: widget.userProfile,
          currentUserId: widget.currentUserId,
          currentUserName: widget.currentUserName,
          contexto: 'Central de Tickets',
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
    final temFiltro = _filtroStatus != null || _filtroPrioridade != null || _filtroTipo != null;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          // Tipo chips
          ...TipoTicket.values.map((t) {
            final sel = _filtroTipo == t;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                avatar: Icon(t.icone, size: 14,
                    color: sel ? t.cor : cs.onSurfaceVariant),
                label: Text(t.nomeDisplay, style: const TextStyle(fontSize: 12)),
                selected: sel,
                onSelected: (_) => setState(() => _filtroTipo = sel ? null : t),
                selectedColor: t.cor.withValues(alpha: 0.12),
                side: BorderSide(color: sel ? t.cor : cs.outlineVariant),
                labelStyle: TextStyle(color: sel ? t.cor : cs.onSurfaceVariant),
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
              ),
            );
          }),
          const SizedBox(width: 6),
          const VerticalDivider(width: 1, thickness: 1, indent: 4, endIndent: 4),
          const SizedBox(width: 6),

          // Status chips
          ...StatusTicket.values.map((s) {
            final sel = _filtroStatus == s;
            final cor = _corStatus(s);
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(s.nomeDisplay, style: const TextStyle(fontSize: 12)),
                selected: sel,
                onSelected: (_) => setState(() => _filtroStatus = sel ? null : s),
                selectedColor: cor.withValues(alpha: 0.15),
                side: BorderSide(color: sel ? cor : cs.outlineVariant),
                labelStyle: TextStyle(color: sel ? cor : cs.onSurfaceVariant),
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
                selectedColor: p.cor.withValues(alpha: 0.15),
                side: BorderSide(color: sel ? p.cor : cs.outlineVariant),
                labelStyle: TextStyle(color: sel ? p.cor : cs.onSurfaceVariant),
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
              ),
            );
          }),

          if (temFiltro) ...[
            const SizedBox(width: 6),
            ActionChip(
              label: const Text('Limpar', style: TextStyle(fontSize: 12)),
              onPressed: () => setState(() {
                _filtroStatus = null;
                _filtroPrioridade = null;
                _filtroTipo = null;
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
              // Linha superior: ícone tipo + #numero + título + badge prioridade
              Row(
                children: [
                  Icon(ticket.tipo.icone, size: 15, color: ticket.tipo.cor),
                  const SizedBox(width: 6),
                  if (ticket.numero > 0)
                    Text(
                      '#${ticket.numero} ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
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
                  // Badge de prioridade (somente Alta)
                  if (ticket.prioridade == PrioridadeTicket.alta)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: ticket.prioridade.cor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: ticket.prioridade.cor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        ticket.prioridade.nomeDisplay,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: ticket.prioridade.cor,
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

              // Linha inferior: status + tipo badge + data + comentários
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
                  const SizedBox(width: 6),

                  // Tipo badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: ticket.tipo.cor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: ticket.tipo.cor.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      ticket.tipo.nomeDisplay,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: ticket.tipo.cor,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Criador
                  if (ticket.criadoPorNome.isNotEmpty) ...[
                    Icon(Icons.person_outline,
                        size: 12, color: cs.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Text(
                      ticket.criadoPorNome,
                      style:
                          TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Comentários
                  if (ticket.totalComentarios > 0) ...[
                    Icon(Icons.chat_bubble_outline,
                        size: 12, color: cs.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Text(
                      '${ticket.totalComentarios}',
                      style:
                          TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Data
                  Text(
                    fmt.format(ticket.dataAtualizacao),
                    style:
                        TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
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
        actions: [
          if (_isAdmin && _todos.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Exportar CSV',
              onPressed: _exportarCSV,
            ),
        ],
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
