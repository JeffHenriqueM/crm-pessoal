import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../models/negociacao_model.dart';
import '../services/proposta_pdf.dart';
import '../models/usuario_model.dart';
import '../services/firestore_service.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _moedaCompacta = NumberFormat.currency(
    locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);

// ── Catálogo de produtos Villamor ─────────────────────────────────────────────
class _Produto {
  final String nome;
  final double valor;
  const _Produto(this.nome, this.valor);
}

const _produtos = [
  // Categoria Luxo (Cota)
  _Produto('Luxo Bronze',     45000),
  _Produto('Luxo Prata',      77000),
  _Produto('Luxo Ouro',      145000),
  _Produto('Luxo Diamante', 1750000),
  // Categoria Villamor
  _Produto('Villamor Bronze',    61000),
  _Produto('Villamor Prata',     98000),
  _Produto('Villamor Ouro',     192000),
  _Produto('Villamor Diamante', 2465000),
];

// ── Aba principal (usada dentro da FichaClienteScreen) ────────────────────────
class AbaNegociacoes extends StatelessWidget {
  final String clienteId;
  final int proximoNumero;
  final String? currentUserId;
  final String? currentUserName;
  final String userProfile;

  const AbaNegociacoes({
    super.key,
    required this.clienteId,
    required this.proximoNumero,
    this.currentUserId,
    this.currentUserName,
    this.userProfile = 'vendedor',
  });

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return StreamBuilder<List<Negociacao>>(
      stream: service.getNegociacoesStream(clienteId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final negociacoes = snapshot.data ?? [];
        final proximo = negociacoes.length + 1;

        if (negociacoes.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.handshake_outlined,
                      size: 56,
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma proposta ainda.\nAdicione a primeira!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
          itemCount: negociacoes.length,
          itemBuilder: (context, i) {
            final neg = negociacoes[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _NegociacaoCard(
                negociacao: neg,
                onEdit: () => abrirFormularioNegociacao(
                  context,
                  clienteId: clienteId,
                  service: service,
                  proximoNumero: proximo,
                  editando: neg,
                  currentUserId: currentUserId,
                  currentUserName: currentUserName,
                  userProfile: userProfile,
                ),
                onDelete: () => _confirmarExclusao(context, service, neg),
                onExportPdf: () => PropostaPdf.gerar(neg),
                onStatusChange: (s) =>
                    _handleStatusMudanca(context, service, neg, s),
              ),
            );
          },
        );
      },
    );
  }

  /// Trata mudança de status. Se for [contratoEfetivado], exige lead vinculado
  /// e move o lead para [FaseCliente.fechado] automaticamente.
  Future<void> _handleStatusMudanca(
    BuildContext context,
    FirestoreService service,
    Negociacao neg,
    StatusNegociacao novoStatus,
  ) async {
    if (novoStatus != StatusNegociacao.contratoEfetivado) {
      await service.atualizarNegociacao(neg.copyWith(status: novoStatus));
      return;
    }

    // ── Contrato Efetivado ── exige lead vinculado ──────────────────────────
    String? leadId = neg.clienteId;
    String? leadNome = neg.clienteNome;

    if (leadId == null) {
      // Abre busca de lead para vinculação obrigatória
      final result = await showDialog<Cliente>(
        context: context,
        builder: (ctx) => _BuscaLeadDialog(service: service),
      );
      if (result == null || !context.mounted) return; // usuário cancelou
      leadId = result.id!;
      leadNome = result.nome;
    }

    // Move lead para Fechado
    await service.atualizarFaseCliente(leadId, FaseCliente.fechado);

    // Salva negociação com novo status + lead vinculado
    await service.atualizarNegociacao(
      neg.copyWith(
        status: StatusNegociacao.contratoEfetivado,
        clienteId: leadId,
        clienteNome: leadNome,
      ),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Contrato efetivado! Lead "$leadNome" movido para Fechado.',
          ),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    }
  }

  void _confirmarExclusao(
      BuildContext context, FirestoreService service, Negociacao neg) {
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
              await service.deletarNegociacao(neg.id!);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

// ── FAB público ───────────────────────────────────────────────────────────────
/// [onSaveLocal]: se fornecido, a proposta é salva localmente (cliente novo).
/// [currentUserId] / [currentUserName]: usados para pré-selecionar o embaixador.
void abrirFormularioNegociacao(
  BuildContext context, {
  String? clienteId,
  String? clienteNome,
  FirestoreService? service,
  required int proximoNumero,
  Negociacao? editando,
  void Function(Negociacao)? onSaveLocal,
  String? currentUserId,
  String? currentUserName,
  String userProfile = 'vendedor',
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _FormularioNegociacao(
      clienteId: clienteId,
      clienteNome: clienteNome,
      service: service,
      editando: editando,
      sugestaoTitulo: editando?.titulo ?? 'Proposta $proximoNumero',
      onSaveLocal: onSaveLocal,
      currentUserId: currentUserId,
      currentUserName: currentUserName,
      userProfile: userProfile,
    ),
  );
}

// ── Card de negociação ────────────────────────────────────────────────────────
class _NegociacaoCard extends StatelessWidget {
  final Negociacao negociacao;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onExportPdf;
  final Function(StatusNegociacao) onStatusChange;

  const _NegociacaoCard({
    required this.negociacao,
    required this.onEdit,
    required this.onDelete,
    required this.onExportPdf,
    required this.onStatusChange,
  });

  static const _statusCores = {
    StatusNegociacao.ativa: Color(0xFF1565C0),
    StatusNegociacao.aceita: Color(0xFF2E7D32),
    StatusNegociacao.recusada: Color(0xFFC62828),
    StatusNegociacao.contratoEfetivado: Color(0xFF6A1B9A),
  };

  static const _aprovacaoCores = {
    StatusAprovacao.semSolicitacao: Colors.transparent,
    StatusAprovacao.pendente: Color(0xFFF57F17),
    StatusAprovacao.aprovada: Color(0xFF2E7D32),
    StatusAprovacao.negada: Color(0xFFC62828),
    StatusAprovacao.aguardandoAtualizacao: Color(0xFF6A1B9A),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cor = _statusCores[negociacao.status] ?? const Color(0xFF1565C0);
    final temDesconto = negociacao.desconto > 0;
    final temParcelas =
        negociacao.quantidadeParcelas != null &&
            negociacao.quantidadeParcelas! > 0;
    final isEspecial = negociacao.tipo == TipoNegociacao.especial;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: negociacao.status == StatusNegociacao.aceita ||
                  negociacao.status == StatusNegociacao.contratoEfetivado
              ? cor.withValues(alpha: 0.4)
              : cs.outlineVariant.withValues(alpha: 0.5),
          width: negociacao.status == StatusNegociacao.aceita ||
                  negociacao.status == StatusNegociacao.contratoEfetivado
              ? 1.5
              : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cabeçalho ─────────────────────────────────────
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
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  // Badge aprovação (se especial e solicitada)
                  if (isEspecial &&
                      negociacao.statusAprovacao != StatusAprovacao.semSolicitacao) ...[
                    _aprovacaoChip(negociacao.statusAprovacao),
                    const SizedBox(width: 6),
                  ],
                  // Chip de status
                  PopupMenuButton<StatusNegociacao>(
                    tooltip: 'Alterar status',
                    onSelected: onStatusChange,
                    itemBuilder: (_) => StatusNegociacao.values
                        .map((s) => PopupMenuItem(
                              value: s,
                              child: Text(s.nomeDisplay),
                            ))
                        .toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: cor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            negociacao.status.nomeDisplay,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: cor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down,
                              size: 14, color: cor),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Embaixador
              if (negociacao.embaixadorNome != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person_outlined,
                        size: 12,
                        color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      negociacao.embaixadorNome!,
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ],

              Divider(
                  height: 16,
                  color: cs.outlineVariant.withValues(alpha: 0.5)),

              // ── Valores ───────────────────────────────────────
              _linha(cs, 'Valor original',
                  _moeda.format(negociacao.valorOriginal)),
              if (temDesconto) ...[
                const SizedBox(height: 4),
                _linhaDesconto(cs),
              ],
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: cs.onSurface,
                        )),
                    Text(
                      _moeda.format(negociacao.valorFinal),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),

              if (negociacao.valorEntrada != null || temParcelas) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (negociacao.valorEntrada != null)
                      Expanded(
                        child: _infoChip(
                          context,
                          Icons.payments_outlined,
                          'Entrada',
                          _moedaCompacta
                              .format(negociacao.valorEntrada!),
                        ),
                      ),
                    if (negociacao.valorEntrada != null &&
                        temParcelas)
                      const SizedBox(width: 8),
                    if (temParcelas)
                      Expanded(
                        child: _infoChip(
                          context,
                          Icons.calendar_month_outlined,
                          '${negociacao.quantidadeParcelas}x',
                          negociacao.valorParcela != null
                              ? _moedaCompacta
                                  .format(negociacao.valorParcela!)
                              : '—',
                        ),
                      ),
                  ],
                ),
              ],

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
                        color: Colors.amber.shade700.withValues(alpha: 0.3)),
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
                              fontSize: 12,
                              color: cs.onSurface),
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
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.timer_outlined,
                        size: 13, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      'Prazo: ${DateFormat('dd/MM/yyyy').format(negociacao.prazoResposta!)}',
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ],

              // Observações
              if (negociacao.observacoes?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  negociacao.observacoes!,
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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

              // ── Rodapé ────────────────────────────────────────
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('dd/MM/yyyy')
                        .format(negociacao.dataCriacao),
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf_outlined,
                            size: 16, color: Color(0xFFC62828)),
                        onPressed: onExportPdf,
                        tooltip: 'Exportar PDF',
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        icon: Icon(Icons.edit_outlined,
                            size: 16, color: cs.primary),
                        onPressed: onEdit,
                        tooltip: 'Editar',
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 16, color: cs.error),
                        onPressed: onDelete,
                        tooltip: 'Excluir',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aprovacaoChip(StatusAprovacao status) {
    final cor = _aprovacaoCores[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.nomeDisplay,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: cor,
        ),
      ),
    );
  }

  Widget _linha(ColorScheme cs, String label, String valor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        Text(valor,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _linhaDesconto(ColorScheme cs) {
    final label = negociacao.tipoDesconto == TipoDesconto.percentual
        ? 'Desconto (${negociacao.desconto.toStringAsFixed(1)}%)'
        : 'Desconto';
    final valor = negociacao.tipoDesconto == TipoDesconto.percentual
        ? '- ${_moeda.format(negociacao.valorOriginal * negociacao.desconto / 100)}'
        : '- ${_moeda.format(negociacao.desconto)}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: cs.error)),
        Text(valor,
            style: TextStyle(
                fontSize: 12,
                color: cs.error,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _infoChip(
      BuildContext context, IconData icon, String label, String valor) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10, color: cs.onSurfaceVariant)),
                Text(valor,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Formulário de negociação ──────────────────────────────────────────────────
class _FormularioNegociacao extends StatefulWidget {
  final String? clienteId;
  final String? clienteNome;
  final FirestoreService? service;
  final Negociacao? editando;
  final String sugestaoTitulo;
  final void Function(Negociacao)? onSaveLocal;
  final String? currentUserId;
  final String? currentUserName;
  final String userProfile;

  const _FormularioNegociacao({
    this.clienteId,
    this.clienteNome,
    this.service,
    required this.editando,
    required this.sugestaoTitulo,
    this.onSaveLocal,
    this.currentUserId,
    this.currentUserName,
    this.userProfile = 'vendedor',
  });

  @override
  State<_FormularioNegociacao> createState() =>
      _FormularioNegociacaoState();
}

class _FormularioNegociacaoState extends State<_FormularioNegociacao> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _valorOriginalCtrl;
  late final TextEditingController _descontoCtrl;
  late final TextEditingController _valorEntradaCtrl;
  late final TextEditingController _parcelasCtrl;
  late final TextEditingController _valorParcelaCtrl;
  late final TextEditingController _obsCtrl;
  late final TextEditingController _condicaoEspecialCtrl;
  late final TextEditingController _nomeClienteCtrl;

  TipoDesconto _tipoDesconto = TipoDesconto.fixo;
  TipoNegociacao _tipoNegociacao = TipoNegociacao.tabela;
  StatusNegociacao _status = StatusNegociacao.ativa;
  DateTime? _prazoResposta;
  bool _solicitarAprovacao = false;
  bool _parcelaManual = false;
  bool _salvando = false;
  bool _autoEspecial = false;         // forçado por valor abaixo do limite do produto
  bool _autoEspecialParcelas = false; // forçado por parcelas > 80
  double _entradaPercMemoria = 10.0;  // % de entrada — preservada ao recalcular valorFinal
  bool _atualizandoEntrada = false;   // evita loop ao atualizar entrada programaticamente

  // ── Rentabilidade ─────────────────────────────────────────────────────────
  late final TextEditingController _valorDiariaCtrl;
  double _taxaOcupacao = 0.63;
  bool _modoOcupacaoDias = false; // false = %, true = dias

  // Vínculo com lead (só usado quando não há clienteId pré-definido)
  String? _vinculoClienteId;
  String? _vinculoClienteNome;

  // Produto selecionado
  _Produto? _produtoSelecionado;

  // Embaixador
  List<Usuario> _usuarios = [];
  Usuario? _embaixador;
  bool _carregandoUsuarios = true;

  bool get _isAdmin =>
      widget.userProfile == 'admin' || widget.userProfile == 'super admin';

  // ── Limites de negociação especial por produto ────────────────────────────
  static const _limitesEspecial = {
    'Luxo Bronze':      37000.0,
    'Luxo Prata':       61000.0,
    'Luxo Ouro':       116000.0,
    'Luxo Diamante':  1224000.0,
    'Villamor Bronze':  51000.0,
    'Villamor Prata':   88000.0,
    'Villamor Ouro':   171000.0,
    'Villamor Diamante': 2190000.0,
  };

  bool get _deveSerEspecial {
    if (_produtoSelecionado == null) return false;
    final limite = _limitesEspecial[_produtoSelecionado!.nome];
    if (limite == null) return false;
    return _valorFinal > 0 && _valorFinal < limite;
  }

  // ── Rentabilidade — getters ───────────────────────────────────────────────
  int? get _diasPlanoProduto {
    if (_produtoSelecionado == null) return null;
    final nome = _produtoSelecionado!.nome;
    if (nome.contains('Bronze')) return 7;
    if (nome.contains('Prata')) return 14;
    if (nome.contains('Ouro')) return 28;
    return null; // Diamante: sem dias fixos por semana
  }

  double? get _qtdDiarias {
    final vf = _valorFinal;
    final vd = _parse(_valorDiariaCtrl.text);
    if (vf <= 0 || vd <= 0) return null;
    return vf / vd;
  }

  double? get _anosEquivalentes {
    final dias = _qtdDiarias;
    final diasPlano = _diasPlanoProduto;
    if (dias == null || diasPlano == null || diasPlano == 0 || _taxaOcupacao == 0) return null;
    return dias / (diasPlano * _taxaOcupacao);
  }

  @override
  void initState() {
    super.initState();
    final e = widget.editando;
    // Título: sempre gerado automaticamente (read-only no form)
    _tituloCtrl = TextEditingController(text: e?.titulo ?? '');
    _valorOriginalCtrl = TextEditingController(
        text: e != null ? _fmt(e.valorOriginal) : '');
    _descontoCtrl = TextEditingController(
        text: e != null && e.desconto > 0 ? _fmt(e.desconto) : '');
    _valorEntradaCtrl = TextEditingController(
        text: e?.valorEntrada != null ? _fmt(e!.valorEntrada!) : '');
    _parcelasCtrl = TextEditingController(
        text: e?.quantidadeParcelas?.toString() ?? '');
    _tipoDesconto = e?.tipoDesconto ?? TipoDesconto.fixo;
    _tipoNegociacao = e?.tipo ?? TipoNegociacao.tabela;
    _status = e?.status ?? StatusNegociacao.ativa;
    _prazoResposta = e?.prazoResposta;
    _condicaoEspecialCtrl =
        TextEditingController(text: e?.condicaoEspecial ?? '');
    _solicitarAprovacao = e?.statusAprovacao == StatusAprovacao.pendente;

    final parcelaInicial = e?.valorParcelaOverride != null
        ? _fmt(e!.valorParcelaOverride!)
        : '';
    _valorParcelaCtrl = TextEditingController(text: parcelaInicial);
    _parcelaManual = e?.valorParcelaOverride != null;
    _obsCtrl = TextEditingController(text: e?.observacoes ?? '');

    // Nome do cliente (campo livre antes de vincular lead)
    _nomeClienteCtrl = TextEditingController(
        text: (e?.clienteId == null && e?.clienteNome != null) ? e!.clienteNome! : '');

    // Vínculo de lead (preserva o do editando, se houver)
    _vinculoClienteId = e?.clienteId ?? widget.clienteId;
    _vinculoClienteNome = e?.clienteNome ?? widget.clienteNome;

    // Inicializa % de entrada para cálculo bidirecional
    final vfInit = _valorFinal;
    if (e?.valorEntrada != null && vfInit > 0) {
      _entradaPercMemoria = (e!.valorEntrada! / vfInit * 100).clamp(0, 100);
    }

    // Listeners para recalcular
    for (final ctrl in [
      _valorOriginalCtrl,
      _descontoCtrl,
      _parcelasCtrl,
    ]) {
      ctrl.addListener(_recalcular);
    }
    _valorEntradaCtrl.addListener(_onEntradaEditada); // listener separado para manter %
    _valorParcelaCtrl.addListener(_onParcelaEditada);
    _nomeClienteCtrl.addListener(_recalcular); // atualiza título ao digitar nome

    _valorDiariaCtrl = TextEditingController(text: '1600');
    _valorDiariaCtrl.addListener(() { if (mounted) setState(() {}); });

    _carregarUsuarios();
  }

  Future<void> _carregarUsuarios() async {
    try {
      final service = widget.service ?? FirestoreService();
      final lista = await service.getTodosUsuarios(apenasAtivos: true);
      if (!mounted) return;
      setState(() {
        _usuarios = lista;
        _carregandoUsuarios = false;
        // Pré-seleciona embaixador: quem está editando, ou usuário logado
        final editId = widget.editando?.embaixadorId;
        final fallbackId = widget.currentUserId;
        if (editId != null) {
          try { _embaixador = _usuarios.firstWhere((u) => u.id == editId); } catch (_) {}
        } else if (fallbackId != null) {
          try { _embaixador = _usuarios.firstWhere((u) => u.id == fallbackId); } catch (_) {}
        }
      });
    } catch (_) {
      if (mounted) setState(() => _carregandoUsuarios = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _tituloCtrl, _valorOriginalCtrl, _descontoCtrl,
      _valorEntradaCtrl, _parcelasCtrl, _valorParcelaCtrl,
      _obsCtrl, _condicaoEspecialCtrl, _nomeClienteCtrl,
      _valorDiariaCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  double _parse(String s) =>
      double.tryParse(s.replaceAll(',', '.')) ?? 0;

  double get _valorFinal {
    final orig = _parse(_valorOriginalCtrl.text);
    final desc = _parse(_descontoCtrl.text);
    if (_tipoDesconto == TipoDesconto.percentual) {
      return (orig * (1 - desc / 100)).clamp(0, double.infinity);
    }
    return (orig - desc).clamp(0, double.infinity);
  }

  double? get _parcelaCalculada {
    final parcelas = int.tryParse(_parcelasCtrl.text);
    if (parcelas == null || parcelas <= 0) return null;
    final entrada = _parse(_valorEntradaCtrl.text);
    final saldo = _valorFinal - entrada;
    return saldo <= 0 ? 0 : saldo / parcelas;
  }

  bool _atualizandoParcela = false;

  void _atualizarTitulo() {
    if (_produtoSelecionado == null) return;
    final data = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final vf = _moeda.format(_valorFinal);
    // Prefixo com nome do cliente (lead vinculado tem prioridade sobre campo livre)
    final nomeCliente =
        (_vinculoClienteNome ?? _nomeClienteCtrl.text.trim());
    _tituloCtrl.text = nomeCliente.isNotEmpty
        ? '$nomeCliente - ${_produtoSelecionado!.nome} - $data - $vf'
        : '${_produtoSelecionado!.nome} - $data - $vf';
  }

  void _recalcular() {
    // ① Recalcula entrada mantendo a % memorizada (quando valorOriginal ou desconto muda)
    final vf = _valorFinal;
    if (vf > 0) {
      _atualizandoEntrada = true;
      _valorEntradaCtrl.text = _fmt(vf * _entradaPercMemoria / 100);
      _atualizandoEntrada = false;
    }

    // ② Recalcula valor da parcela
    if (!_parcelaManual) {
      final calc = _parcelaCalculada;
      _atualizandoParcela = true;
      _valorParcelaCtrl.text = calc != null ? _fmt(calc) : '';
      _atualizandoParcela = false;
    }

    // ③ Auto-especial por valor abaixo do limite do produto
    if (_produtoSelecionado != null) {
      final deveEspecial = _deveSerEspecial;
      if (deveEspecial && _tipoNegociacao == TipoNegociacao.tabela) {
        _tipoNegociacao = TipoNegociacao.especial;
        _autoEspecial = true;
      } else if (!deveEspecial && _autoEspecial) {
        _autoEspecial = false;
        if (!_autoEspecialParcelas && _tipoNegociacao == TipoNegociacao.especial) {
          _tipoNegociacao = TipoNegociacao.tabela;
          _solicitarAprovacao = false;
        }
      }
    }

    // ④ Auto-especial por parcelas > 80
    final nParcelas = int.tryParse(_parcelasCtrl.text) ?? 0;
    if (nParcelas > 80 && _tipoNegociacao == TipoNegociacao.tabela) {
      _tipoNegociacao = TipoNegociacao.especial;
      _autoEspecialParcelas = true;
    } else if (nParcelas <= 80 && _autoEspecialParcelas) {
      _autoEspecialParcelas = false;
      if (!_autoEspecial && _tipoNegociacao == TipoNegociacao.especial) {
        _tipoNegociacao = TipoNegociacao.tabela;
      }
    }

    _atualizarTitulo();
    if (mounted) setState(() {});
  }

  /// Chamado quando o USUÁRIO edita o valor de entrada manualmente.
  /// Atualiza a % memorizada e recalcula só a parcela.
  void _onEntradaEditada() {
    if (_atualizandoEntrada) return;
    final vf = _valorFinal;
    final entrada = _parse(_valorEntradaCtrl.text);
    if (vf > 0) {
      _entradaPercMemoria = (entrada / vf * 100).clamp(0, 100);
    }
    if (!_parcelaManual) {
      final calc = _parcelaCalculada;
      _atualizandoParcela = true;
      _valorParcelaCtrl.text = calc != null ? _fmt(calc) : '';
      _atualizandoParcela = false;
    }
    _atualizarTitulo();
    if (mounted) setState(() {});
  }

  void _onParcelaEditada() {
    if (_atualizandoParcela) return;
    _parcelaManual = true;
  }

  void _resetarParcela() {
    setState(() {
      _parcelaManual = false;
      _recalcular();
    });
  }

  Future<void> _selecionarPrazo() async {
    final hoje = DateTime.now();
    final limite = hoje.add(const Duration(days: 7));
    final data = await showDatePicker(
      context: context,
      initialDate: _prazoResposta ?? limite,
      firstDate: hoje,
      lastDate: limite,
      helpText: 'Prazo máximo: 7 dias',
    );
    if (data != null && mounted) setState(() => _prazoResposta = data);
  }

  // ── Escolha de produto ────────────────────────────────────────────────────
  Future<void> _abrirEscolhaProduto() async {
    final cs = Theme.of(context).colorScheme;
    final resultado = await showModalBottomSheet<_Produto>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.villa_outlined, color: cs.primary, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Escolher Produto',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Categoria Luxo
                Text('Categoria Luxo — Cota',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                        letterSpacing: 0.4)),
                const SizedBox(height: 8),
                ..._produtos.where((p) => p.nome.startsWith('Luxo')).map((p) =>
                    _produtoTile(ctx, p, cs)),
                const SizedBox(height: 14),
                // Categoria Villamor
                Text('Categoria Villamor',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                        letterSpacing: 0.4)),
                const SizedBox(height: 8),
                ..._produtos.where((p) => p.nome.startsWith('Villamor')).map((p) =>
                    _produtoTile(ctx, p, cs)),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
    if (resultado != null && mounted) {
      setState(() {
        _produtoSelecionado = resultado;
        _autoEspecial = false;
        _autoEspecialParcelas = false;
        _entradaPercMemoria = 10.0; // reset: entrada volta a 10% do novo produto
        _valorOriginalCtrl.text = _fmt(resultado.valor);
        // Pré-preenche entrada com 10% (sem acionar _onEntradaEditada)
        _atualizandoEntrada = true;
        _valorEntradaCtrl.text = _fmt(resultado.valor * 0.10);
        _atualizandoEntrada = false;
        _parcelaManual = false;
        _recalcular(); // gera título + detecta especial
      });
    }
  }

  Widget _produtoTile(BuildContext ctx, _Produto p, ColorScheme cs) {
    final selecionado = _produtoSelecionado?.nome == p.nome;
    return InkWell(
      onTap: () => Navigator.of(ctx).pop(p),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selecionado
              ? cs.primaryContainer.withValues(alpha: 0.4)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selecionado ? cs.primary.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(p.nome,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: cs.onSurface)),
            Text(_moeda.format(p.valor),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cs.primary)),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirBuscaLead() async {
    final service = widget.service ?? FirestoreService();
    final result = await showDialog<Cliente>(
      context: context,
      builder: (ctx) => _BuscaLeadDialog(service: service),
    );
    if (result != null && mounted) {
      setState(() {
        _vinculoClienteId = result.id;
        _vinculoClienteNome = result.nome;
        _atualizarTitulo();
      });
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    // clienteNome: lead vinculado tem prioridade; caso contrário usa o campo livre
    final nomeCliente = _vinculoClienteNome ??
        (_nomeClienteCtrl.text.trim().isNotEmpty
            ? _nomeClienteCtrl.text.trim()
            : null);

    final neg = Negociacao(
      id: widget.editando?.id,
      clienteId: _vinculoClienteId,
      clienteNome: nomeCliente,
      tipo: _tipoNegociacao,
      condicaoEspecial: _tipoNegociacao == TipoNegociacao.especial &&
              _condicaoEspecialCtrl.text.trim().isNotEmpty
          ? _condicaoEspecialCtrl.text.trim()
          : null,
      prazoResposta:
          _tipoNegociacao == TipoNegociacao.especial ? _prazoResposta : null,
      statusAprovacao: _tipoNegociacao == TipoNegociacao.especial &&
              _solicitarAprovacao
          ? StatusAprovacao.pendente
          : (widget.editando?.statusAprovacao ?? StatusAprovacao.semSolicitacao),
      dataSolicitacaoAprovacao: _tipoNegociacao == TipoNegociacao.especial &&
              _solicitarAprovacao &&
              widget.editando?.dataSolicitacaoAprovacao == null
          ? DateTime.now()
          : widget.editando?.dataSolicitacaoAprovacao,
      dataAprovacao: widget.editando?.dataAprovacao,
      aprovadoPorId: widget.editando?.aprovadoPorId,
      aprovadoPorNome: widget.editando?.aprovadoPorNome,
      comentarioAprovacao: widget.editando?.comentarioAprovacao,
      embaixadorId: _embaixador?.id,
      embaixadorNome: _embaixador?.nome,
      criadoPorId: widget.editando?.criadoPorId,
      criadoPorNome: widget.editando?.criadoPorNome,
      titulo: _tituloCtrl.text.trim(),
      valorOriginal: _parse(_valorOriginalCtrl.text),
      tipoDesconto: _tipoDesconto,
      desconto: _parse(_descontoCtrl.text),
      valorEntrada: _valorEntradaCtrl.text.trim().isEmpty
          ? null
          : _parse(_valorEntradaCtrl.text),
      quantidadeParcelas: int.tryParse(_parcelasCtrl.text),
      valorParcelaOverride: _parcelaManual &&
              _valorParcelaCtrl.text.trim().isNotEmpty
          ? _parse(_valorParcelaCtrl.text)
          : null,
      status: _status,
      dataCriacao: widget.editando?.dataCriacao ?? DateTime.now(),
      observacoes: _obsCtrl.text.trim().isEmpty
          ? null
          : _obsCtrl.text.trim(),
    );

    try {
      if (widget.onSaveLocal != null) {
        widget.onSaveLocal!(neg);
        if (mounted) Navigator.of(context).pop();
      } else if (widget.editando != null) {
        await widget.service!.atualizarNegociacao(neg);
        if (mounted) Navigator.of(context).pop();
      } else {
        await widget.service!.adicionarNegociacao(neg);
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro: $e'),
              backgroundColor:
                  Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEditing = widget.editando != null;
    final isEspecial = _tipoNegociacao == TipoNegociacao.especial;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Cabeçalho ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
              child: Row(
                children: [
                  Icon(Icons.handshake_outlined, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEditing ? 'Editar Proposta' : 'Nova Proposta',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                    onPressed: _salvando ? null : () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),

            // ── Conteúdo ─────────────────────────────────────────────────
            Flexible(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Tipo + Banner (full width) ──────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _sectionLabel(cs, 'Tipo de Negociação'),
                          const SizedBox(width: 12),
                          SegmentedButton<TipoNegociacao>(
                            segments: const [
                              ButtonSegment(
                                value: TipoNegociacao.tabela,
                                icon: Icon(Icons.table_chart_outlined, size: 16),
                                label: Text('Valor de Tabela'),
                              ),
                              ButtonSegment(
                                value: TipoNegociacao.especial,
                                icon: Icon(Icons.star_outlined, size: 16),
                                label: Text('Negociação Especial'),
                              ),
                            ],
                            selected: {_tipoNegociacao},
                            onSelectionChanged: (s) => setState(() {
                              _tipoNegociacao = s.first;
                              _autoEspecial = false;
                              if (_tipoNegociacao == TipoNegociacao.tabela) {
                                _solicitarAprovacao = false;
                              }
                            }),
                            style: ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              textStyle: WidgetStatePropertyAll(
                                  const TextStyle(fontSize: 12)),
                            ),
                          ),
                          if (_autoEspecial) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade700.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.amber.shade700.withValues(alpha: 0.35)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        size: 14, color: Colors.amber.shade800),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Valor abaixo do mínimo — Negociação Especial',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.amber.shade900),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── 2 colunas: Valores | Detalhes ──────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── COLUNA ESQUERDA: campos financeiros ─
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Escolher produto
                                OutlinedButton.icon(
                                  onPressed: _abrirEscolhaProduto,
                                  icon: const Icon(Icons.villa_outlined, size: 18),
                                  label: Text(
                                    _produtoSelecionado != null
                                        ? 'Produto: ${_produtoSelecionado!.nome} — ${_moeda.format(_produtoSelecionado!.valor)}'
                                        : 'Escolher produto',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    alignment: Alignment.centerLeft,
                                    minimumSize: const Size(double.infinity, 44),
                                    textStyle: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Valor original
                                TextFormField(
                                  controller: _valorOriginalCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Valor original',
                                    prefixIcon: Icon(Icons.attach_money),
                                    prefixText: 'R\$ ',
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Informe o valor';
                                    if (_parse(v) <= 0) return 'Valor inválido';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Desconto + toggle
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _descontoCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Desconto (${_tipoDesconto == TipoDesconto.percentual ? '%' : 'R\$'})',
                                          prefixIcon: const Icon(Icons.discount_outlined),
                                        ),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: SegmentedButton<TipoDesconto>(
                                        segments: const [
                                          ButtonSegment(value: TipoDesconto.fixo, label: Text('R\$')),
                                          ButtonSegment(value: TipoDesconto.percentual, label: Text('%')),
                                        ],
                                        selected: {_tipoDesconto},
                                        onSelectionChanged: (s) => setState(() {
                                          _tipoDesconto = s.first;
                                          _recalcular();
                                        }),
                                        style: const ButtonStyle(visualDensity: VisualDensity.compact),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Valor final
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: cs.primaryContainer.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Valor final', style: TextStyle(fontSize: 13, color: cs.onSurface)),
                                      Text(
                                        _moeda.format(_valorFinal),
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: cs.primary),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Entrada + Parcelas
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _valorEntradaCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Valor de entrada',
                                          prefixIcon: Icon(Icons.payments_outlined),
                                          prefixText: 'R\$ ',
                                        ),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _parcelasCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Qtd. parcelas',
                                          prefixIcon: Icon(Icons.calendar_month_outlined),
                                        ),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      ),
                                    ),
                                  ],
                                ),

                                // Banner: parcelas > 80 → obrigatório especial
                                if ((int.tryParse(_parcelasCtrl.text) ?? 0) > 80)
                                  Container(
                                    margin: const EdgeInsets.only(top: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: cs.tertiaryContainer.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline, size: 15, color: cs.onTertiaryContainer),
                                        const SizedBox(width: 7),
                                        Expanded(
                                          child: Text(
                                            'Acima de 80x → Negociação Especial obrigatória',
                                            style: TextStyle(fontSize: 12, color: cs.onTertiaryContainer),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 12),

                                // Valor da parcela
                                TextFormField(
                                  controller: _valorParcelaCtrl,
                                  decoration: InputDecoration(
                                    labelText: _parcelaManual
                                        ? 'Valor da parcela (manual)'
                                        : 'Valor da parcela (calculado)',
                                    prefixIcon: const Icon(Icons.receipt_long_outlined),
                                    prefixText: 'R\$ ',
                                    suffixIcon: _parcelaManual
                                        ? IconButton(
                                            icon: const Icon(Icons.refresh),
                                            tooltip: 'Usar valor calculado',
                                            onPressed: _resetarParcela,
                                          )
                                        : Icon(Icons.calculate_outlined, color: cs.onSurfaceVariant),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                                ),

                                // Divergência
                                if (_parcelaManual && _parcelaCalculada != null)
                                  Builder(builder: (context) {
                                    final cs = Theme.of(context).colorScheme;
                                    final manual = _parse(_valorParcelaCtrl.text);
                                    if ((manual - _parcelaCalculada!).abs() > 0.01) {
                                      return Container(
                                        margin: const EdgeInsets.only(top: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: cs.errorContainer.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.warning_amber_rounded, size: 16, color: cs.error),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Divergente do calculado (${_moeda.format(_parcelaCalculada!)})',
                                                style: TextStyle(fontSize: 12, color: cs.error),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  }),
                              ],
                            ),
                          ),

                          const SizedBox(width: 16),

                          // ── COLUNA DIREITA: detalhes ─────────
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Observações
                                TextFormField(
                                  controller: _obsCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Observações (opcional)',
                                    prefixIcon: Icon(Icons.notes_outlined),
                                    alignLabelWithHint: true,
                                  ),
                                  maxLines: 4,
                                  textCapitalization: TextCapitalization.sentences,
                                ),
                                const SizedBox(height: 12),

                                // Identificação do cliente (só quando sem clienteId fixo)
                                if (widget.clienteId == null) ...[
                                  _sectionLabel(cs, 'Identificação do cliente'),
                                  const SizedBox(height: 8),
                                  if (_vinculoClienteId == null) ...[
                                    TextFormField(
                                      controller: _nomeClienteCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Nome do cliente (opcional)',
                                        prefixIcon: Icon(Icons.person_outline),
                                        hintText: 'Digite ou vincule um lead',
                                      ),
                                      textCapitalization: TextCapitalization.words,
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: _abrirBuscaLead,
                                      icon: const Icon(Icons.person_search_outlined, size: 18),
                                      label: const Text('Vincular a um lead'),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(double.infinity, 40),
                                        textStyle: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ] else ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: cs.primaryContainer.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.person_rounded, size: 18, color: cs.primary),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _vinculoClienteNome ?? '',
                                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface),
                                            ),
                                          ),
                                          TextButton.icon(
                                            onPressed: () => setState(() {
                                              _vinculoClienteId = null;
                                              _vinculoClienteNome = null;
                                              _atualizarTitulo();
                                            }),
                                            icon: const Icon(Icons.link_off, size: 14),
                                            label: const Text('Desvincular', style: TextStyle(fontSize: 12)),
                                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                ],

                                // Embaixador
                                if (_carregandoUsuarios)
                                  const LinearProgressIndicator()
                                else if (_isAdmin)
                                  DropdownButtonFormField<Usuario>(
                                    value: _embaixador,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Embaixador',
                                      prefixIcon: Icon(Icons.person_outlined),
                                    ),
                                    hint: const Text('Selecione o embaixador'),
                                    items: _usuarios
                                        .map((u) => DropdownMenuItem(value: u, child: Text(u.nome)))
                                        .toList(),
                                    onChanged: (v) => setState(() => _embaixador = v),
                                  )
                                else
                                  InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'Embaixador',
                                      prefixIcon: const Icon(Icons.person_outlined),
                                      suffixIcon: Tooltip(
                                        message: 'Somente Admin pode alterar o embaixador',
                                        child: Icon(Icons.lock_outline, size: 18, color: cs.onSurfaceVariant),
                                      ),
                                    ),
                                    child: Text(
                                      _embaixador?.nome ?? '—',
                                      style: TextStyle(fontSize: 14, color: cs.onSurface),
                                    ),
                                  ),
                                const SizedBox(height: 12),

                                // Título (read-only, gerado automaticamente)
                                _sectionLabel(cs, 'Título da proposta'),
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: cs.outlineVariant),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.label_outline, size: 16, color: cs.onSurfaceVariant),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _tituloCtrl.text.isEmpty
                                              ? 'Gerado ao escolher o produto…'
                                              : _tituloCtrl.text,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: _tituloCtrl.text.isEmpty
                                                ? cs.onSurfaceVariant
                                                : cs.onSurface,
                                            fontStyle: _tituloCtrl.text.isEmpty
                                                ? FontStyle.italic
                                                : FontStyle.normal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // ── Rentabilidade (full width) ────────────────────
                      _buildRentabilidade(cs),

                      // ── Condições Especiais (full width, se especial) ─
                      if (isEspecial) ...[
                        const SizedBox(height: 16),
                        Divider(color: Colors.amber.shade700.withValues(alpha: 0.4)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade700),
                            const SizedBox(width: 6),
                            _sectionLabel(cs, 'Condições Especiais'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 6,
                              child: TextFormField(
                                controller: _condicaoEspecialCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Condição especial de fechamento',
                                  prefixIcon: Icon(Icons.star_outlined, color: Colors.amber.shade700),
                                  alignLabelWithHint: true,
                                ),
                                maxLines: 3,
                                textCapitalization: TextCapitalization.sentences,
                                validator: isEspecial
                                    ? (v) => v?.trim().isEmpty == true ? 'Descreva a condição especial' : null
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Prazo de resposta
                                  InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: _selecionarPrazo,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: cs.outline),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.timer_outlined,
                                              color: _prazoResposta != null ? cs.primary : cs.onSurfaceVariant,
                                              size: 20),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _prazoResposta != null
                                                  ? 'Prazo: ${DateFormat('dd/MM/yyyy').format(_prazoResposta!)}'
                                                  : 'Prazo de resposta (máx. 7 dias)',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: _prazoResposta != null ? cs.onSurface : cs.onSurfaceVariant),
                                            ),
                                          ),
                                          if (_prazoResposta != null)
                                            IconButton(
                                              icon: Icon(Icons.clear, size: 18, color: cs.outline),
                                              onPressed: () => setState(() => _prazoResposta = null),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Solicitar aprovação
                                  CheckboxListTile(
                                    value: _solicitarAprovacao,
                                    onChanged: (v) => setState(() => _solicitarAprovacao = v ?? false),
                                    title: const Text('Solicitar aprovação da Gerência',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                    subtitle: const Text('O gerente será notificado',
                                        style: TextStyle(fontSize: 11)),
                                    secondary: const Icon(Icons.admin_panel_settings_outlined, size: 20),
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),

            // ── Ações ────────────────────────────────────────────────────
            Divider(height: 1, color: cs.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _salvando ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: _salvando
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(isEditing ? Icons.save_outlined : Icons.add_circle_outline),
                    label: Text(isEditing ? 'Salvar' : 'Adicionar'),
                    onPressed: _salvando ? null : _salvar,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Seção de Rentabilidade ────────────────────────────────────────────────
  Widget _buildRentabilidade(ColorScheme cs) {
    final diasPlano    = _diasPlanoProduto;
    final qtdDiarias   = _qtdDiarias;
    final anosEquiv    = _anosEquivalentes;
    final vd           = _parse(_valorDiariaCtrl.text);
    const taxas        = [0.50, 0.63, 0.80, 1.00];
    final verde        = Colors.green.shade700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Divider(color: verde.withValues(alpha: 0.3)),
        const SizedBox(height: 10),

        // ── Cabeçalho da seção ──────────────────────────────────────────────
        Row(
          children: [
            Icon(Icons.trending_up, size: 16, color: verde),
            const SizedBox(width: 6),
            Text(
              'RENTABILIDADE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: verde,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Controles: diária + taxa de ocupação ────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Diária do resort
            SizedBox(
              width: 190,
              child: TextFormField(
                controller: _valorDiariaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Diária do resort',
                  prefixIcon: Icon(Icons.hotel_outlined),
                  prefixText: 'R\$ ',
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                ],
              ),
            ),
            const SizedBox(width: 20),

            // Taxa de ocupação
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label + toggle %/dias
                  Row(
                    children: [
                      Text(
                        'Taxa de ocupação',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: diasPlano != null
                            ? () => setState(() => _modoOcupacaoDias = !_modoOcupacaoDias)
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: diasPlano != null
                                ? (_modoOcupacaoDias
                                    ? cs.primaryContainer
                                    : cs.surfaceContainerHighest)
                                : cs.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: cs.outlineVariant),
                          ),
                          child: Text(
                            _modoOcupacaoDias ? 'Dias' : '%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: diasPlano != null ? cs.primary : cs.outline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<double>(
                    segments: taxas.map((t) {
                      final String label;
                      if (_modoOcupacaoDias && diasPlano != null) {
                        final d = (diasPlano * t).round();
                        label = '${d}d';
                      } else {
                        label = '${(t * 100).toInt()}%';
                      }
                      return ButtonSegment<double>(value: t, label: Text(label));
                    }).toList(),
                    selected: {_taxaOcupacao},
                    onSelectionChanged: (s) => setState(() => _taxaOcupacao = s.first),
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // ── Card de resultado ───────────────────────────────────────────────
        if (qtdDiarias != null && diasPlano != null && anosEquiv != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: verde.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: verde.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Linha 1: X diárias = Y anos
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.villa_outlined, size: 16, color: verde),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(fontSize: 13, color: cs.onSurface, height: 1.4),
                          children: [
                            const TextSpan(text: 'Com '),
                            TextSpan(
                              text: _moeda.format(vd),
                              style: TextStyle(fontWeight: FontWeight.bold, color: verde),
                            ),
                            const TextSpan(text: '/dia você teria '),
                            TextSpan(
                              text: '${qtdDiarias.round()} diárias',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const TextSpan(text: ' = '),
                            TextSpan(
                              text: '${anosEquiv.toStringAsFixed(1)} anos',
                              style: TextStyle(fontWeight: FontWeight.bold, color: verde),
                            ),
                            TextSpan(
                              text: ' de uso no resort'
                                  ' (${((_taxaOcupacao) * 100).toInt()}% de ocupação)',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Linha 2: Vitalício
                Row(
                  children: [
                    Icon(Icons.all_inclusive, size: 16, color: verde),
                    const SizedBox(width: 8),
                    Text(
                      'Com a Villamor, o acesso é vitalício!',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: verde,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else if (_valorFinal > 0 && _produtoSelecionado != null && diasPlano == null) ...[
          // Produto Diamante — plano não tem dias fixos semanais
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.info_outline, size: 13, color: cs.outline),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Cálculo de anos disponível para planos Bronze, Prata e Ouro',
                  style: TextStyle(fontSize: 11, color: cs.outline),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _sectionLabel(ColorScheme cs, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: cs.primary,
        letterSpacing: 0.3,
      ),
    );
  }
}

// ── Diálogo de busca de lead ──────────────────────────────────────────────────
class _BuscaLeadDialog extends StatefulWidget {
  final FirestoreService service;
  const _BuscaLeadDialog({required this.service});

  @override
  State<_BuscaLeadDialog> createState() => _BuscaLeadDialogState();
}

class _BuscaLeadDialogState extends State<_BuscaLeadDialog> {
  final _buscaCtrl = TextEditingController();
  List<Cliente> _todos = [];
  List<Cliente> _filtrados = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarClientes();
    _buscaCtrl.addListener(_filtrar);
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarClientes() async {
    // Faz uma leitura única (não stream) para simplificar o diálogo
    final stream = widget.service.getTodosClientesStream();
    final lista = await stream.first;
    if (!mounted) return;
    setState(() {
      _todos = lista;
      _filtrados = lista;
      _carregando = false;
    });
  }

  void _filtrar() {
    final q = _buscaCtrl.text.trim().toLowerCase();
    setState(() {
      _filtrados = q.isEmpty
          ? _todos
          : _todos.where((c) {
              return c.nome.toLowerCase().contains(q) ||
                  (c.nomeEsposa?.toLowerCase().contains(q) ?? false) ||
                  (c.telefoneContato?.contains(q) ?? false);
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      child: SizedBox(
        width: 460,
        height: 520,
        child: Column(
          children: [
            // ── Cabeçalho ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
              child: Row(
                children: [
                  Icon(Icons.person_search_outlined,
                      color: cs.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Vincular a um lead',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                    onPressed: () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            // ── Busca ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _buscaCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Nome, cônjuge ou telefone...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _buscaCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _buscaCtrl.clear(),
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: cs.outlineVariant),

            // ── Lista ──────────────────────────────────────────────────
            Expanded(
              child: _carregando
                  ? const Center(child: CircularProgressIndicator())
                  : _filtrados.isEmpty
                      ? Center(
                          child: Text('Nenhum lead encontrado.',
                              style: TextStyle(color: cs.onSurfaceVariant)),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: _filtrados.length,
                          itemBuilder: (ctx, i) {
                            final c = _filtrados[i];
                            final nome = c.nomeEsposa?.isNotEmpty == true
                                ? '${c.nome} e ${c.nomeEsposa}'
                                : c.nome;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    cs.primaryContainer.withValues(alpha: 0.5),
                                child: Text(
                                  c.nome[0].toUpperCase(),
                                  style: TextStyle(
                                      color: cs.onPrimaryContainer,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(nome,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              subtitle: Text(
                                c.fase.nomeDisplay +
                                    (c.vendedorNome != null
                                        ? ' · ${c.vendedorNome}'
                                        : ''),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant),
                              ),
                              onTap: () => Navigator.of(ctx).pop(c),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
