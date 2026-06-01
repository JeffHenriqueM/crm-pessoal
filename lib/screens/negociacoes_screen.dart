import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/negociacao_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/proposta_pdf.dart';
import '../widgets/aba_negociacoes.dart';

final _moeda =
    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);

// ── Widget de negociações (sem Scaffold — usado como aba em ApresentacaoScreen) ─
class NegociacoesBody extends StatefulWidget {
  final String userProfile;
  final String? currentUserId;
  final String? currentUserName;

  const NegociacoesBody({
    super.key,
    required this.userProfile,
    this.currentUserId,
    this.currentUserName,
  });

  @override
  State<NegociacoesBody> createState() => _NegociacoesBodyState();
}

class _NegociacoesBodyState extends State<NegociacoesBody>
    with SingleTickerProviderStateMixin {
  final _service = FirestoreService();
  final _authService = AuthService();

  late final TabController _tabController;

  bool get _isAdmin =>
      widget.userProfile == 'admin' ||
      widget.userProfile == 'super admin' ||
      widget.userProfile == 'pós-venda' ||
      widget.userProfile == 'financeiro';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _isAdmin ? 2 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Column(
          children: [
            if (_isAdmin)
              Material(
                color: cs.surface,
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Todas'),
                    Tab(
                      icon: Icon(Icons.pending_outlined),
                      child: _PendentesTabLabel(),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _isAdmin
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _ListaNegociacoes(
                          service: _service,
                          embaixadorId: null,
                          isAdmin: true,
                          currentUserId: widget.currentUserId,
                          currentUserName: widget.currentUserName,
                          onAprovar: _abrirPainelAprovacao,
                          userProfile: widget.userProfile,
                        ),
                        _ListaPendentes(
                          service: _service,
                          onAprovar: _abrirPainelAprovacao,
                        ),
                      ],
                    )
                  : _ListaNegociacoes(
                      service: _service,
                      embaixadorId: widget.currentUserId,
                      isAdmin: false,
                      currentUserId: widget.currentUserId,
                      currentUserName: widget.currentUserName,
                      onAprovar: null,
                      userProfile: widget.userProfile,
                    ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'negociacoes_fab',
            onPressed: _novaNegociacao,
            icon: const Icon(Icons.add),
            label: const Text('Nova Proposta'),
          ),
        ),
      ],
    );
  }

  void _novaNegociacao() {
    final user = _authService.getCurrentUser();
    abrirFormularioNegociacao(
      context,
      service: _service,
      proximoNumero: 1,
      currentUserId: user?.uid ?? widget.currentUserId,
      currentUserName: user?.displayName ?? widget.currentUserName,
      userProfile: widget.userProfile,
    );
  }

  void _abrirPainelAprovacao(Negociacao neg) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PainelAprovacao(
        negociacao: neg,
        service: _service,
        onDone: () => Navigator.of(ctx).pop(),
      ),
    );
  }
}

// ── Widget auxiliar: label da aba Pendentes ────────────────────────────────────
class _PendentesTabLabel extends StatelessWidget {
  const _PendentesTabLabel();

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    return StreamBuilder<List<Negociacao>>(
      stream: service.getNegociacoesPendentesStream(),
      builder: (context, snapshot) {
        final count = snapshot.data?.length ?? 0;
        if (count == 0) return const Text('Pendentes');
        return Badge.count(
          count: count,
          child: const Padding(
            padding: EdgeInsets.only(right: 14),
            child: Text('Pendentes'),
          ),
        );
      },
    );
  }
}

// ── Lista de negociações ──────────────────────────────────────────────────────
class _ListaNegociacoes extends StatefulWidget {
  final FirestoreService service;
  final String? embaixadorId;
  final bool isAdmin;
  final String? currentUserId;
  final String? currentUserName;
  final void Function(Negociacao)? onAprovar;
  final String userProfile;

  const _ListaNegociacoes({
    required this.service,
    required this.embaixadorId,
    required this.isAdmin,
    this.currentUserId,
    this.currentUserName,
    this.onAprovar,
    this.userProfile = 'vendedor',
  });

  @override
  State<_ListaNegociacoes> createState() => _ListaNegociacoesState();
}

class _ListaNegociacoesState extends State<_ListaNegociacoes> {
  String _filtroStatus = ''; // '' = todos
  String _filtroTipo = ''; // '' = todos

  // Stream cacheado para não ser recriado a cada rebuild (causava appear/disappear)
  late Stream<List<Negociacao>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = widget.service.getNegociacoesGlobaisStream(
      embaixadorId: widget.embaixadorId,
    );
  }

  @override
  void didUpdateWidget(_ListaNegociacoes old) {
    super.didUpdateWidget(old);
    if (old.embaixadorId != widget.embaixadorId) {
      _stream = widget.service.getNegociacoesGlobaisStream(
        embaixadorId: widget.embaixadorId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<Negociacao>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var negociacoes = snapshot.data ?? [];

        // Filtros locais
        if (_filtroStatus.isNotEmpty) {
          negociacoes = negociacoes
              .where((n) => n.status.nome == _filtroStatus)
              .toList();
        }
        if (_filtroTipo.isNotEmpty) {
          negociacoes = negociacoes
              .where((n) => n.tipo.nome == _filtroTipo)
              .toList();
        }

        return Column(
          children: [
            // ── Filtros rápidos ─────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(
                    bottom:
                        BorderSide(color: cs.outlineVariant, width: 1)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filtroChip(cs, 'Todos', '',
                        isStatus: false, isTipo: false),
                    const SizedBox(width: 6),
                    _filtroChip(cs, 'Tabela', 'tabela',
                        isStatus: false, isTipo: true),
                    const SizedBox(width: 6),
                    _filtroChip(cs, 'Especial', 'especial',
                        isStatus: false, isTipo: true),
                    const SizedBox(width: 12),
                    const VerticalDivider(width: 1),
                    const SizedBox(width: 12),
                    _filtroChip(cs, 'Ativas', 'ativa',
                        isStatus: true, isTipo: false),
                    const SizedBox(width: 6),
                    _filtroChip(cs, 'Aceitas', 'aceita',
                        isStatus: true, isTipo: false),
                    const SizedBox(width: 6),
                    _filtroChip(cs, 'Recusadas', 'recusada',
                        isStatus: true, isTipo: false),
                  ],
                ),
              ),
            ),

            // ── Lista ────────────────────────────────────────
            Expanded(
              child: negociacoes.isEmpty
                  ? _buildVazio(cs)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                      itemCount: negociacoes.length,
                      itemBuilder: (context, i) {
                        final neg = negociacoes[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _NegociacaoGlobalCard(
                            negociacao: neg,
                            isAdmin: widget.isAdmin,
                            onEdit: neg.status != StatusNegociacao.inativa
                                ? () => abrirFormularioNegociacao(
                                      context,
                                      service: widget.service,
                                      proximoNumero: i + 1,
                                      editando: neg,
                                      currentUserId: widget.currentUserId,
                                      currentUserName: widget.currentUserName,
                                      userProfile: widget.userProfile,
                                    )
                                : null,
                            onDelete: () =>
                                _confirmarExclusao(context, neg),
                            onAbrirCliente: neg.clienteId != null
                                ? () => _abrirCliente(neg)
                                : null,
                            onAprovar: widget.onAprovar != null &&
                                    neg.tipo == TipoNegociacao.especial
                                ? () => widget.onAprovar!(neg)
                                : null,
                            onExportarPdf: neg.status != StatusNegociacao.inativa
                                ? () => PropostaPdf.gerar(neg)
                                : null,
                            onInativar: neg.status != StatusNegociacao.inativa
                                ? () => _abrirDialogInativacao(context, neg)
                                : null,
                            onReativar: neg.status == StatusNegociacao.inativa
                                ? () => widget.service.reativarNegociacao(neg.id!)
                                : null,
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _filtroChip(
    ColorScheme cs,
    String label,
    String value, {
    required bool isStatus,
    required bool isTipo,
  }) {
    final bool selected;
    if (!isStatus && !isTipo) {
      // "Todos"
      selected = _filtroStatus.isEmpty && _filtroTipo.isEmpty;
    } else if (isStatus) {
      selected = _filtroStatus == value;
    } else {
      selected = _filtroTipo == value;
    }

    return FilterChip(
      label: Text(label,
          style: TextStyle(fontSize: 12, color: selected ? cs.onPrimary : cs.onSurface)),
      selected: selected,
      selectedColor: cs.primary,
      checkmarkColor: cs.onPrimary,
      visualDensity: VisualDensity.compact,
      onSelected: (_) {
        setState(() {
          if (!isStatus && !isTipo) {
            _filtroStatus = '';
            _filtroTipo = '';
          } else if (isStatus) {
            _filtroStatus = selected ? '' : value;
          } else {
            _filtroTipo = selected ? '' : value;
          }
        });
      },
    );
  }

  Widget _buildVazio(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.handshake_outlined,
                size: 56, color: cs.outline.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'Nenhuma negociação encontrada.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.outline, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarExclusao(BuildContext context, Negociacao neg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir proposta?'),
        content: Text('Deseja excluir "${neg.titulo}" permanentemente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await widget.service.deletarNegociacao(neg.id!);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  static const _motivosInativacao = [
    'Negada pelo cliente',
    'Não aprovado pela gerência',
    'Proposta com data expirada',
    'Campanha não está mais válida',
    'Produto descontinuado',
    'Outro',
  ];

  void _abrirDialogInativacao(BuildContext context, Negociacao neg) {
    String? motivoSelecionado;
    final outroCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Inativar proposta'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('"${neg.titulo}"',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'Selecione o motivo da inativação:',
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                RadioGroup<String>(
                  groupValue: motivoSelecionado,
                  onChanged: (v) => setLocal(() => motivoSelecionado = v),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _motivosInativacao
                        .map((m) => RadioListTile<String>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(m,
                                  style: const TextStyle(fontSize: 14)),
                              value: m,
                            ))
                        .toList(),
                  ),
                ),
                if (motivoSelecionado == 'Outro') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: outroCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descreva o motivo',
                      isDense: true,
                    ),
                    maxLines: 2,
                    autofocus: true,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: motivoSelecionado == null
                  ? null
                  : () async {
                      final motivo = motivoSelecionado == 'Outro'
                          ? (outroCtrl.text.trim().isEmpty
                              ? 'Outro'
                              : outroCtrl.text.trim())
                          : motivoSelecionado!;
                      Navigator.of(ctx).pop();
                      await widget.service.inativarNegociacao(neg.id!, motivo);
                    },
              child: const Text('Inativar'),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirCliente(Negociacao neg) {
    // Abre a ficha do cliente associado à negociação
    // Buscamos apenas pelo clienteId — a FichaClienteScreen recebe o cliente completo,
    // então por ora fazemos uma navegação sem cliente completo (push sem cliente)
    // Uma melhoria futura pode buscar o cliente antes de navegar.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cliente: ${neg.clienteNome ?? neg.clienteId}'),
        action: SnackBarAction(
          label: 'Ver',
          onPressed: () {
            // Navega para a ficha sem objeto completo — será aprimorado
          },
        ),
      ),
    );
  }
}

// ── Lista de pendentes para aprovação ────────────────────────────────────────
class _ListaPendentes extends StatelessWidget {
  final FirestoreService service;
  final void Function(Negociacao) onAprovar;

  const _ListaPendentes({required this.service, required this.onAprovar});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<Negociacao>>(
      stream: service.getNegociacoesPendentesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final pendentes = snapshot.data ?? [];

        if (pendentes.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 52, color: Colors.green.shade600),
                const SizedBox(height: 16),
                Text(
                  'Nenhuma aprovação pendente.',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
          itemCount: pendentes.length,
          itemBuilder: (context, i) {
            final neg = pendentes[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _NegociacaoGlobalCard(
                negociacao: neg,
                isAdmin: true,
                onEdit: null,
                onDelete: null,
                onAbrirCliente: null,
                onAprovar: () => onAprovar(neg),
                onExportarPdf: () => PropostaPdf.gerar(neg),
                highlightAprovacao: true,
              ),
            );
          },
        );
      },
    );
  }
}

// ── Card de negociação global ─────────────────────────────────────────────────
class _NegociacaoGlobalCard extends StatelessWidget {
  final Negociacao negociacao;
  final bool isAdmin;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAbrirCliente;
  final VoidCallback? onAprovar;
  final VoidCallback? onExportarPdf;
  final VoidCallback? onInativar;
  final VoidCallback? onReativar;
  final bool highlightAprovacao;

  const _NegociacaoGlobalCard({
    required this.negociacao,
    required this.isAdmin,
    this.onEdit,
    this.onDelete,
    this.onAbrirCliente,
    this.onAprovar,
    this.onExportarPdf,
    this.onInativar,
    this.onReativar,
    this.highlightAprovacao = false,
  });

  static const _statusCores = {
    StatusNegociacao.ativa:             Color(0xFF1565C0),
    StatusNegociacao.aceita:            Color(0xFF2E7D32),
    StatusNegociacao.recusada:          Color(0xFFC62828),
    StatusNegociacao.contratoEfetivado: Color(0xFF6A1B9A),
    StatusNegociacao.inativa:           Color(0xFF78909C),
  };

  static const _aprovacaoCores = {
    StatusAprovacao.semSolicitacao: Color(0xFF757575),
    StatusAprovacao.pendente: Color(0xFFF57F17),
    StatusAprovacao.aprovada: Color(0xFF2E7D32),
    StatusAprovacao.negada: Color(0xFFC62828),
    StatusAprovacao.aguardandoAtualizacao: Color(0xFF6A1B9A),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cor = _statusCores[negociacao.status] ?? const Color(0xFF1565C0);
    final isEspecial = negociacao.tipo == TipoNegociacao.especial;
    final corAprov = _aprovacaoCores[negociacao.statusAprovacao]!;

    return Card(
      elevation: highlightAprovacao ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: highlightAprovacao
            ? BorderSide(color: Colors.amber.shade700, width: 1.5)
            : BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabeçalho ──────────────────────────────────────
            Row(
              children: [
                if (isEspecial) ...[
                  Icon(Icons.star_rounded,
                      size: 16, color: Colors.amber.shade700),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    negociacao.titulo,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: cor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    negociacao.status.nomeDisplay,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cor),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // ── Meta‑dados ─────────────────────────────────────
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (negociacao.clienteNome != null)
                  _meta(context, Icons.person_outlined,
                      negociacao.clienteNome!),
                if (negociacao.embaixadorNome != null)
                  _meta(context, Icons.badge_outlined,
                      negociacao.embaixadorNome!),
                _meta(context, Icons.calendar_today_outlined,
                    DateFormat('dd/MM/yyyy')
                        .format(negociacao.dataCriacao)),
              ],
            ),

            // Condição especial
            if (isEspecial &&
                negociacao.condicaoEspecial?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.amber.shade700
                          .withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star_outlined,
                        size: 14, color: Colors.amber.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        negociacao.condicaoEspecial!,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurface),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Prazo de resposta
            if (isEspecial && negociacao.prazoResposta != null) ...[
              const SizedBox(height: 4),
              _meta(
                context,
                Icons.timer_outlined,
                'Prazo: ${DateFormat('dd/MM/yyyy').format(negociacao.prazoResposta!)}',
              ),
            ],

            // Comentário de aprovação
            if (negociacao.comentarioAprovacao?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.comment_outlined,
                        size: 13, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        negociacao.comentarioAprovacao!,
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            // ── Valor + ações ──────────────────────────────────
            Row(
              children: [
                Text(
                  _moeda.format(negociacao.valorFinal),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  ),
                ),
                const Spacer(),
                // Badge aprovação
                if (isEspecial &&
                    negociacao.statusAprovacao !=
                        StatusAprovacao.semSolicitacao) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: corAprov.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: corAprov.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      negociacao.statusAprovacao.nomeDisplay,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: corAprov),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                // Botão aprovação (admin)
                if (onAprovar != null)
                  OutlinedButton.icon(
                    onPressed: onAprovar,
                    icon: const Icon(Icons.admin_panel_settings_outlined,
                        size: 16),
                    label: const Text('Avaliar',
                        style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: Colors.amber.shade700),
                      foregroundColor: Colors.amber.shade700,
                    ),
                  ),
                if (negociacao.status == StatusNegociacao.inativa) ...[
                  if (onReativar != null)
                    IconButton(
                      icon: Icon(Icons.restart_alt_outlined,
                          size: 18, color: cs.primary),
                      tooltip: 'Reativar',
                      onPressed: onReativar,
                      visualDensity: VisualDensity.compact,
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 18, color: cs.error),
                      tooltip: 'Excluir',
                      onPressed: onDelete,
                      visualDensity: VisualDensity.compact,
                    ),
                ] else ...[
                  if (onExportarPdf != null)
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf_outlined,
                          size: 18, color: Color(0xFFC62828)),
                      tooltip: 'Exportar PDF',
                      onPressed: onExportarPdf,
                      visualDensity: VisualDensity.compact,
                    ),
                  if (onAbrirCliente != null)
                    IconButton(
                      icon: const Icon(Icons.person_outlined, size: 18),
                      tooltip: 'Ver cliente',
                      onPressed: onAbrirCliente,
                      visualDensity: VisualDensity.compact,
                    ),
                  if (onEdit != null)
                    IconButton(
                      icon: Icon(Icons.edit_outlined,
                          size: 18, color: cs.primary),
                      tooltip: 'Editar',
                      onPressed: onEdit,
                      visualDensity: VisualDensity.compact,
                    ),
                  if (onInativar != null)
                    IconButton(
                      icon: const Icon(Icons.block_outlined,
                          size: 18, color: Color(0xFF78909C)),
                      tooltip: 'Inativar',
                      onPressed: onInativar,
                      visualDensity: VisualDensity.compact,
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 18, color: cs.error),
                      tooltip: 'Excluir',
                      onPressed: onDelete,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ],
            ),

            // Banner de motivo de inativação
            if (negociacao.status == StatusNegociacao.inativa &&
                negociacao.motivoInativacao != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF78909C).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF78909C).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.block_outlined,
                        size: 13, color: Color(0xFF78909C)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        negociacao.motivoInativacao!,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF78909C)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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

  Widget _meta(BuildContext context, IconData icon, String texto) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(texto,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ],
    );
  }
}

// ── Painel de aprovação ───────────────────────────────────────────────────────
class _PainelAprovacao extends StatefulWidget {
  final Negociacao negociacao;
  final FirestoreService service;
  final VoidCallback onDone;

  const _PainelAprovacao({
    required this.negociacao,
    required this.service,
    required this.onDone,
  });

  @override
  State<_PainelAprovacao> createState() => _PainelAprovacaoState();
}

class _PainelAprovacaoState extends State<_PainelAprovacao> {
  final _comentarioCtrl = TextEditingController();
  bool _salvando = false;

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    super.dispose();
  }

  Future<void> _acao(Future<void> Function() fn) async {
    setState(() => _salvando = true);
    try {
      await fn();
      widget.onDone();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final neg = widget.negociacao;
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho
            Row(
              children: [
                Icon(Icons.admin_panel_settings_outlined,
                    color: Colors.amber.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Avaliar: ${neg.titulo}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onDone,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Detalhes
            if (neg.embaixadorNome != null)
              Text('Embaixador: ${neg.embaixadorNome}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            if (neg.clienteNome != null)
              Text('Cliente: ${neg.clienteNome}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            Text('Valor final: ${moeda.format(neg.valorFinal)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
            if (neg.condicaoEspecial?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.amber.shade700.withValues(alpha: 0.3)),
                ),
                child: Text(neg.condicaoEspecial!,
                    style: const TextStyle(fontSize: 13)),
              ),
            ],
            if (neg.prazoResposta != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Prazo: ${DateFormat('dd/MM/yyyy').format(neg.prazoResposta!)}',
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.error,
                      fontWeight: FontWeight.w600),
                ),
              ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 10),

            // Comentário
            TextField(
              controller: _comentarioCtrl,
              decoration: InputDecoration(
                labelText: 'Comentário (opcional)',
                prefixIcon: const Icon(Icons.comment_outlined),
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // Ações
            if (_salvando)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  // Solicitar atualização
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Pedir\natualização',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12)),
                      onPressed: () => _acao(() =>
                          widget.service.solicitarAtualizacaoNegociacao(
                            neg.id!,
                            comentario: _comentarioCtrl.text.trim().isEmpty
                                ? null
                                : _comentarioCtrl.text.trim(),
                          )),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Negar
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.error,
                        foregroundColor: cs.onError,
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Negar',
                          style: TextStyle(fontSize: 12)),
                      onPressed: () => _acao(() =>
                          widget.service.negarNegociacao(
                            neg.id!,
                            comentario: _comentarioCtrl.text.trim().isEmpty
                                ? null
                                : _comentarioCtrl.text.trim(),
                          )),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Aprovar
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.check_circle_outlined,
                          size: 16),
                      label: const Text('Aprovar',
                          style: TextStyle(fontSize: 12)),
                      onPressed: () => _acao(() =>
                          widget.service.aprovarNegociacao(
                            neg.id!,
                            comentario: _comentarioCtrl.text.trim().isEmpty
                                ? null
                                : _comentarioCtrl.text.trim(),
                          )),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
