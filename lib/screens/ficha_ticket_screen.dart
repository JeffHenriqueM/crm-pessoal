// lib/screens/ficha_ticket_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ticket_model.dart';
import '../models/usuario_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

// ── Helpers visuais (replicados para evitar dependência circular) ─────────────

Color _corStatus(StatusTicket s) {
  switch (s) {
    case StatusTicket.aberto:               return const Color(0xFF1565C0);
    case StatusTicket.emAndamento:          return const Color(0xFFE65100);
    case StatusTicket.aguardandoValidacao:  return const Color(0xFF7B1FA2);
    case StatusTicket.resolvido:            return const Color(0xFF2E7D32);
    case StatusTicket.fechado:              return const Color(0xFF546E7A);
  }
}


// ── Tela de detalhe / formulário de ticket ────────────────────────────────────

class FichaTicketScreen extends StatefulWidget {
  final Ticket? ticket;
  final String userProfile;
  final String? currentUserId;
  final String? currentUserName;
  final String? contexto;

  const FichaTicketScreen({
    super.key,
    this.ticket,
    required this.userProfile,
    this.currentUserId,
    this.currentUserName,
    this.contexto,
  });

  @override
  State<FichaTicketScreen> createState() => _FichaTicketScreenState();
}

class _FichaTicketScreenState extends State<FichaTicketScreen> {
  final _service = FirestoreService();
  final _authService = AuthService();

  // Form
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _comentarioCtrl;

  StatusTicket _status = StatusTicket.aberto;
  PrioridadeTicket _prioridade = PrioridadeTicket.media;
  TipoTicket _tipo = TipoTicket.bug;
  Usuario? _atribuidoPara;

  List<Usuario> _usuarios = [];
  List<ComentarioTicket> _comentarios = [];
  StreamSubscription<List<ComentarioTicket>>? _comentariosSub;

  bool _salvando = false;
  bool _enviandoComentario = false;
  bool get _isNovo => widget.ticket == null;
  bool get _isAdmin =>
      widget.userProfile == 'admin' || widget.userProfile == 'super admin';

  // Pode editar se for admin, se for ticket novo, ou se for o criador
  bool get _podeEditar {
    if (_isAdmin) return true;
    if (_isNovo) return true; // qualquer perfil pode criar novo ticket
    final uid = widget.currentUserId ?? _authService.getCurrentUser()?.uid ?? '';
    return widget.ticket?.criadoPorId == uid;
  }

  @override
  void initState() {
    super.initState();
    final t = widget.ticket;
    _tituloCtrl = TextEditingController(text: t?.titulo ?? '');
    _descCtrl = TextEditingController(text: t?.descricao ?? '');
    _comentarioCtrl = TextEditingController();
    _status = t?.status ?? StatusTicket.aberto;
    _prioridade = t?.prioridade ?? PrioridadeTicket.media;
    _tipo = t?.tipo ?? TipoTicket.bug;

    if (_isAdmin) _carregarUsuarios();
    if (!_isNovo) _iniciarStreamComentarios();
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    _comentarioCtrl.dispose();
    _comentariosSub?.cancel();
    super.dispose();
  }

  Future<void> _carregarUsuarios() async {
    try {
      final lista = await _service.getTodosUsuarios();
      if (!mounted) return;
      setState(() {
        _usuarios = lista;
        if (widget.ticket?.atribuidoParaId != null) {
          try {
            _atribuidoPara = lista.firstWhere(
              (u) => u.id == widget.ticket!.atribuidoParaId,
            );
          } catch (_) {}
        }
      });
    } catch (_) {}
  }

  void _iniciarStreamComentarios() {
    _comentariosSub = _service
        .getComentariosStream(widget.ticket!.id!)
        .listen((lista) {
      if (mounted) setState(() => _comentarios = lista);
    });
  }

  // ── Salvar / criar ticket ──────────────────────────────────────────────────

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    try {
      final uid = widget.currentUserId ?? _authService.getCurrentUser()?.uid ?? '';
      final nome = widget.currentUserName ??
          _authService.getCurrentUser()?.displayName ??
          'Usuário';
      final agora = DateTime.now();

      if (_isNovo) {
        final ticket = Ticket(
          titulo:            _tituloCtrl.text.trim(),
          descricao:         _descCtrl.text.trim(),
          status:            _status,
          prioridade:        _prioridade,
          tipo:              _tipo,
          criadoPorId:       uid,
          criadoPorNome:     nome,
          criadoPorPerfil:   widget.userProfile,
          contexto:          widget.contexto,
          atribuidoParaId:   _atribuidoPara?.id,
          atribuidoParaNome: _atribuidoPara?.nome,
          dataCriacao:       agora,
          dataAtualizacao:   agora,
        );
        await _service.criarTicket(ticket);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ticket criado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        await _service.atualizarTicket(widget.ticket!.id!, {
          'titulo':            _tituloCtrl.text.trim(),
          'descricao':         _descCtrl.text.trim(),
          'status':            _status.nome,
          'prioridade':        _prioridade.nome,
          'tipo':              _tipo.nome,
          'atribuidoParaId':   _atribuidoPara?.id,
          'atribuidoParaNome': _atribuidoPara?.nome,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ticket atualizado!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  // ── Enviar comentário ──────────────────────────────────────────────────────

  Future<void> _enviarComentario() async {
    final texto = _comentarioCtrl.text.trim();
    if (texto.isEmpty || widget.ticket?.id == null) return;
    setState(() => _enviandoComentario = true);
    try {
      final uid = widget.currentUserId ?? _authService.getCurrentUser()?.uid ?? '';
      final nome = widget.currentUserName ??
          _authService.getCurrentUser()?.displayName ??
          'Usuário';
      final comentario = ComentarioTicket(
        texto:     texto,
        autorId:   uid,
        autorNome: nome,
        data:      DateTime.now(),
      );
      await _service.adicionarComentario(widget.ticket!.id!, comentario);
      _comentarioCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _enviandoComentario = false);
    }
  }

  // ── Alterar status rápido ──────────────────────────────────────────────────

  void _mostrarMenuStatus() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Alterar status',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
          ...StatusTicket.values.map((s) {
            final cor = _corStatus(s);
            return ListTile(
              leading: CircleAvatar(
                radius: 10,
                backgroundColor: cor.withValues(alpha: 0.2),
                child: CircleAvatar(radius: 5, backgroundColor: cor),
              ),
              title: Text(s.nomeDisplay),
              selected: _status == s,
              onTap: () async {
                Navigator.pop(ctx);
                setState(() => _status = s);
                if (!_isNovo) {
                  await _service.atualizarTicket(widget.ticket!.id!, {
                    'status': s.nome,
                  });
                }
              },
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Deletar ticket ─────────────────────────────────────────────────────────

  void _deletarDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir ticket?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.deletarTicket(widget.ticket!.id!);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  // ── Seção de form ──────────────────────────────────────────────────────────

  Widget _buildForm() {
    final cs = Theme.of(context).colorScheme;
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumb de contexto (somente ao criar novo ticket)
            if (_isNovo) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 13, color: cs.onSurfaceVariant),
                    const SizedBox(width: 5),
                    Text(
                      'Villamor CRM',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    if (widget.contexto != null) ...[
                      Icon(Icons.chevron_right,
                          size: 13, color: cs.onSurfaceVariant),
                      Text(
                        widget.contexto!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Título
            TextFormField(
              controller: _tituloCtrl,
              enabled: _podeEditar,
              decoration: const InputDecoration(
                labelText: 'Título *',
                prefixIcon: Icon(Icons.title),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe um título.' : null,
            ),
            const SizedBox(height: 12),

            // Descrição
            TextFormField(
              controller: _descCtrl,
              enabled: _podeEditar,
              decoration: const InputDecoration(
                labelText: 'Descrição *',
                hintText: 'Passos para reproduzir, o que esperava vs o que aconteceu...',
                prefixIcon: Icon(Icons.description_outlined),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe uma descrição.' : null,
            ),
            const SizedBox(height: 16),

            // Tipo: Bug / Funcionalidade
            Text('Tipo *',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 6),
            Row(
              children: TipoTicket.values.map((t) {
                final sel = _tipo == t;
                final idx = TipoTicket.values.indexOf(t);
                return Expanded(
                  child: GestureDetector(
                    onTap: _podeEditar ? () => setState(() => _tipo = t) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: EdgeInsets.only(
                          right: idx < TipoTicket.values.length - 1 ? 6 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: sel
                            ? t.cor.withValues(alpha: 0.12)
                            : cs.surfaceContainerHighest.withValues(alpha: 0.4),
                        border: Border.all(
                          color: sel ? t.cor : cs.outlineVariant,
                          width: sel ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(t.icone,
                              size: 18,
                              color: sel ? t.cor : cs.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(
                            t.nomeDisplay,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: sel ? t.cor : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Prioridade: Baixa / Média / Alta
            Text('Prioridade *',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 6),
            Row(
              children: PrioridadeTicket.values.map((p) {
                final sel = _prioridade == p;
                final idx = PrioridadeTicket.values.indexOf(p);
                return Expanded(
                  child: GestureDetector(
                    onTap:
                        _podeEditar ? () => setState(() => _prioridade = p) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: EdgeInsets.only(right: idx < 2 ? 6 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: sel
                            ? p.cor.withValues(alpha: 0.12)
                            : cs.surfaceContainerHighest.withValues(alpha: 0.4),
                        border: Border.all(
                          color: sel ? p.cor : cs.outlineVariant,
                          width: sel ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        p.nomeDisplay,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sel ? p.cor : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Status (editável inline + botão rápido no header)
            _buildDropdown<StatusTicket>(
              label: 'Status',
              value: _status,
              items: StatusTicket.values,
              displayText: (s) => s.nomeDisplay,
              onChanged: _podeEditar
                  ? (v) => setState(() => _status = v!)
                  : null,
              itemColor: _corStatus,
            ),
            const SizedBox(height: 12),

            // Atribuir para (admin only)
            if (_isAdmin)
              DropdownButtonFormField<Usuario?>(
                value: _atribuidoPara,
                decoration: const InputDecoration(
                  labelText: 'Atribuído para',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Sem atribuição'),
                  ),
                  ..._usuarios.map((u) => DropdownMenuItem(
                    value: u,
                    child: Text(u.nome),
                  )),
                ],
                onChanged: (v) => setState(() => _atribuidoPara = v),
              ),

            if (!_isNovo) ...[
              const SizedBox(height: 16),
              Divider(color: cs.outlineVariant),
              const SizedBox(height: 8),
              // Metadata
              Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'Aberto por ${widget.ticket?.criadoPorNome ?? '?'}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Icon(Icons.schedule, size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd/MM/yyyy', 'pt_BR').format(widget.ticket!.dataCriacao),
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // Botão salvar (no form, além do AppBar)
            if (_podeEditar)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _salvando ? null : _salvar,
                  icon: _salvando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isNovo ? 'Criar Ticket' : 'Salvar Alterações'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Seção de comentários ───────────────────────────────────────────────────

  Widget _buildComentarios() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Lista de comentários
        if (_comentarios.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Nenhum comentário ainda.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            itemCount: _comentarios.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) => _buildBolhaComentario(_comentarios[i]),
          ),
        const SizedBox(height: 12),

        // Campo de novo comentário
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _comentarioCtrl,
                  decoration: InputDecoration(
                    hintText: 'Adicionar comentário...',
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              const SizedBox(width: 8),
              _enviandoComentario
                  ? const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton.filled(
                      onPressed: _enviarComentario,
                      icon: const Icon(Icons.send_rounded),
                      tooltip: 'Enviar',
                    ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildBolhaComentario(ComentarioTicket c) {
    final cs = Theme.of(context).colorScheme;
    final meu = c.autorId ==
        (widget.currentUserId ?? _authService.getCurrentUser()?.uid ?? '');
    final fmt = DateFormat('dd/MM HH:mm', 'pt_BR');

    return Align(
      alignment: meu ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: meu
                ? cs.primaryContainer.withValues(alpha: 0.7)
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: Radius.circular(meu ? 12 : 2),
              bottomRight: Radius.circular(meu ? 2 : 12),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                meu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!meu)
                Text(
                  c.autorNome,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              Text(c.texto, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                fmt.format(c.data),
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Dropdown helper ────────────────────────────────────────────────────────

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) displayText,
    required void Function(T?)? onChanged,
    Color Function(T)? itemColor,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((item) => DropdownMenuItem<T>(
                value: item,
                child: Text(
                  displayText(item),
                  style: itemColor != null
                      ? TextStyle(
                          color: itemColor(item),
                          fontWeight: FontWeight.w500,
                        )
                      : null,
                ),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final corS = _corStatus(_status);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNovo ? 'Novo Ticket' : 'Ticket'),
        actions: [
          // Chip de status rápido (só em modo edição)
          if (!_isNovo && _podeEditar)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _mostrarMenuStatus,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: corS.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: corS.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _status.nomeDisplay,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: corS,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, size: 16, color: corS),
                    ],
                  ),
                ),
              ),
            ),
          if (!_isNovo && _isAdmin)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) {
                if (v == 'delete') _deletarDialog();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: cs.error),
                    title: Text('Excluir ticket',
                        style: TextStyle(color: cs.error)),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isNovo
          ? _buildForm()
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildForm(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 16, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          'Comentários (${_comentarios.length})',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: cs.outlineVariant,
                  ),
                  const SizedBox(height: 8),
                  _buildComentarios(),
                ],
              ),
            ),
    );
  }
}
