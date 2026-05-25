import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/negociacao_model.dart';
import '../services/firestore_service.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _moedaCompacta = NumberFormat.currency(
    locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);

// ── Aba principal ─────────────────────────────────────────────────────────────
class AbaNegociacoes extends StatelessWidget {
  final String clienteId;
  final int proximoNumero; // para sugerir "Proposta N"

  const AbaNegociacoes({
    super.key,
    required this.clienteId,
    required this.proximoNumero,
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
                onEdit: () => _abrirFormulario(
                    context, service, neg, proximo,
                    editando: neg),
                onDelete: () => _confirmarExclusao(context, service, neg),
                onStatusChange: (s) => service.atualizarNegociacao(
                    clienteId,
                    _comStatus(neg, s)),
              ),
            );
          },
        );
      },
    );
  }

  Negociacao _comStatus(Negociacao neg, StatusNegociacao s) {
    return Negociacao(
      id: neg.id,
      titulo: neg.titulo,
      valorOriginal: neg.valorOriginal,
      tipoDesconto: neg.tipoDesconto,
      desconto: neg.desconto,
      valorEntrada: neg.valorEntrada,
      quantidadeParcelas: neg.quantidadeParcelas,
      valorParcelaOverride: neg.valorParcelaOverride,
      status: s,
      dataCriacao: neg.dataCriacao,
      observacoes: neg.observacoes,
    );
  }

  void _abrirFormulario(
    BuildContext context,
    FirestoreService service,
    Negociacao? base,
    int proximo, {
    Negociacao? editando,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _FormularioNegociacao(
        clienteId: clienteId,
        service: service,
        editando: editando,
        sugestaoTitulo: editando?.titulo ?? 'Proposta $proximo',
      ),
    );
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
              await service.deletarNegociacao(clienteId, neg.id!);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

// ── FAB público (chamado pela InteracoesScreen) ───────────────────────────────
void abrirFormularioNegociacao(
  BuildContext context, {
  required String clienteId,
  required FirestoreService service,
  required int proximoNumero,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _FormularioNegociacao(
      clienteId: clienteId,
      service: service,
      editando: null,
      sugestaoTitulo: 'Proposta $proximoNumero',
    ),
  );
}

// ── Card de negociação ────────────────────────────────────────────────────────
class _NegociacaoCard extends StatelessWidget {
  final Negociacao negociacao;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(StatusNegociacao) onStatusChange;

  const _NegociacaoCard({
    required this.negociacao,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
  });

  static const _statusCores = {
    StatusNegociacao.ativa: Color(0xFF1565C0),
    StatusNegociacao.aceita: Color(0xFF2E7D32),
    StatusNegociacao.recusada: Color(0xFFC62828),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cor = _statusCores[negociacao.status]!;
    final temDesconto = negociacao.desconto > 0;
    final temParcelas =
        negociacao.quantidadeParcelas != null &&
            negociacao.quantidadeParcelas! > 0;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: negociacao.status == StatusNegociacao.aceita
              ? const Color(0xFF2E7D32).withValues(alpha: 0.4)
              : cs.outlineVariant.withValues(alpha: 0.5),
          width: negociacao.status == StatusNegociacao.aceita ? 1.5 : 1,
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
              // ── Cabeçalho ──────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      negociacao.titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
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

              Divider(
                  height: 16,
                  color: cs.outlineVariant.withValues(alpha: 0.5)),

              // ── Valores ────────────────────────────────────────
              _linha(cs, 'Valor original',
                  _moeda.format(negociacao.valorOriginal)),
              if (temDesconto) ...[
                const SizedBox(height: 4),
                _linhaDesconto(cs),
              ],
              const SizedBox(height: 6),
              // Total em destaque
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

              if (negociacao.valorEntrada != null ||
                  temParcelas) ...[
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

              // ── Rodapé ─────────────────────────────────────────
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('dd/MM/yyyy').format(negociacao.dataCriacao),
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                  Row(
                    children: [
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
        Text(label,
            style: TextStyle(fontSize: 12, color: cs.error)),
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
  final String clienteId;
  final FirestoreService service;
  final Negociacao? editando;
  final String sugestaoTitulo;

  const _FormularioNegociacao({
    required this.clienteId,
    required this.service,
    required this.editando,
    required this.sugestaoTitulo,
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

  TipoDesconto _tipoDesconto = TipoDesconto.fixo;
  StatusNegociacao _status = StatusNegociacao.ativa;
  bool _parcelaManual = false;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editando;
    _tituloCtrl =
        TextEditingController(text: e?.titulo ?? widget.sugestaoTitulo);
    _valorOriginalCtrl = TextEditingController(
        text: e != null ? _fmt(e.valorOriginal) : '');
    _descontoCtrl = TextEditingController(
        text: e != null && e.desconto > 0 ? _fmt(e.desconto) : '');
    _valorEntradaCtrl = TextEditingController(
        text: e?.valorEntrada != null ? _fmt(e!.valorEntrada!) : '');
    _parcelasCtrl = TextEditingController(
        text: e?.quantidadeParcelas?.toString() ?? '');
    _tipoDesconto = e?.tipoDesconto ?? TipoDesconto.fixo;
    _status = e?.status ?? StatusNegociacao.ativa;

    final parcelaInicial = e?.valorParcelaOverride != null
        ? _fmt(e!.valorParcelaOverride!)
        : '';
    _valorParcelaCtrl =
        TextEditingController(text: parcelaInicial);
    _parcelaManual = e?.valorParcelaOverride != null;
    _obsCtrl =
        TextEditingController(text: e?.observacoes ?? '');

    // Listeners para recalcular
    for (final ctrl in [
      _valorOriginalCtrl,
      _descontoCtrl,
      _valorEntradaCtrl,
      _parcelasCtrl,
    ]) {
      ctrl.addListener(_recalcular);
    }
    _valorParcelaCtrl.addListener(_onParcelaEditada);
  }

  @override
  void dispose() {
    for (final c in [
      _tituloCtrl, _valorOriginalCtrl, _descontoCtrl,
      _valorEntradaCtrl, _parcelasCtrl, _valorParcelaCtrl, _obsCtrl,
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
  void _recalcular() {
    if (!_parcelaManual) {
      final calc = _parcelaCalculada;
      if (calc != null) {
        _atualizandoParcela = true;
        _valorParcelaCtrl.text = _fmt(calc);
        _atualizandoParcela = false;
      } else {
        _atualizandoParcela = true;
        _valorParcelaCtrl.text = '';
        _atualizandoParcela = false;
      }
    }
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

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    final neg = Negociacao(
      id: widget.editando?.id,
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
      if (widget.editando != null) {
        await widget.service.atualizarNegociacao(widget.clienteId, neg);
      } else {
        await widget.service.adicionarNegociacao(widget.clienteId, neg);
      }
      if (mounted) Navigator.of(context).pop();
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

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.handshake_outlined, color: cs.primary),
          const SizedBox(width: 10),
          Text(isEditing ? 'Editar Proposta' : 'Nova Proposta'),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Título ────────────────────────────────────
                TextFormField(
                  controller: _tituloCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Título da proposta',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => v?.trim().isEmpty == true
                      ? 'Informe um título'
                      : null,
                ),
                const SizedBox(height: 14),

                // ── Valor original ────────────────────────────
                TextFormField(
                  controller: _valorOriginalCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Valor original (R\$)',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[\d.,]')),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Informe o valor';
                    }
                    if (_parse(v) <= 0) return 'Valor inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // ── Desconto ──────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _descontoCtrl,
                        decoration: InputDecoration(
                          labelText: 'Desconto '
                              '(${_tipoDesconto == TipoDesconto.percentual ? '%' : 'R\$'})',
                          prefixIcon:
                              const Icon(Icons.discount_outlined),
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[\d.,]')),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Toggle R$ / %
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SegmentedButton<TipoDesconto>(
                        segments: const [
                          ButtonSegment(
                              value: TipoDesconto.fixo,
                              label: Text('R\$')),
                          ButtonSegment(
                              value: TipoDesconto.percentual,
                              label: Text('%')),
                        ],
                        selected: {_tipoDesconto},
                        onSelectionChanged: (s) => setState(() {
                          _tipoDesconto = s.first;
                          _recalcular();
                        }),
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Valor final calculado ─────────────────────
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Valor final',
                          style: TextStyle(
                              fontSize: 13, color: cs.onSurface)),
                      Text(
                        _moeda.format(_valorFinal),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Entrada e Parcelas ────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _valorEntradaCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Valor de entrada',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[\d.,]')),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _parcelasCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Qtd. parcelas',
                          prefixIcon:
                              Icon(Icons.calendar_month_outlined),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Valor da parcela ──────────────────────────
                TextFormField(
                  controller: _valorParcelaCtrl,
                  decoration: InputDecoration(
                    labelText: _parcelaManual
                        ? 'Valor da parcela (manual)'
                        : 'Valor da parcela (calculado)',
                    prefixIcon: const Icon(Icons.receipt_long_outlined),
                    suffixIcon: _parcelaManual
                        ? IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Usar valor calculado',
                            onPressed: _resetarParcela,
                          )
                        : Icon(Icons.calculate_outlined,
                            color: cs.onSurfaceVariant),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Status ────────────────────────────────────
                DropdownButtonFormField<StatusNegociacao>(
                  value: _status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: StatusNegociacao.values
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.nomeDisplay),
                          ))
                      .toList(),
                  onChanged: (s) =>
                      s != null ? setState(() => _status = s) : null,
                ),
                const SizedBox(height: 14),

                // ── Observações ───────────────────────────────
                TextFormField(
                  controller: _obsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Observações (opcional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _salvando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          icon: _salvando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(isEditing
                  ? Icons.save_outlined
                  : Icons.add_circle_outline),
          label: Text(isEditing ? 'Salvar' : 'Adicionar'),
          onPressed: _salvando ? null : _salvar,
        ),
      ],
    );
  }
}
