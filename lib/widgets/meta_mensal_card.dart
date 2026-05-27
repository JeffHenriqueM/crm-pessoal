import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../services/firestore_service.dart';

// ── Tipos de meta disponíveis ─────────────────────────────────────────────────
enum _TipoMeta {
  fechamentos,
  valorVendido,
  novosLeads;

  String get label {
    switch (this) {
      case _TipoMeta.fechamentos:
        return 'Fechamentos';
      case _TipoMeta.valorVendido:
        return 'Valor Vendido';
      case _TipoMeta.novosLeads:
        return 'Novos Leads';
    }
  }

  String get descricao {
    switch (this) {
      case _TipoMeta.fechamentos:
        return 'Quantos clientes fechados no mês?';
      case _TipoMeta.valorVendido:
        return 'Quanto em vendas (R\$) no mês?';
      case _TipoMeta.novosLeads:
        return 'Quantos novos leads cadastrados no mês?';
    }
  }

  IconData get icone {
    switch (this) {
      case _TipoMeta.fechamentos:
        return Icons.handshake_outlined;
      case _TipoMeta.valorVendido:
        return Icons.attach_money_outlined;
      case _TipoMeta.novosLeads:
        return Icons.person_add_outlined;
    }
  }

  String get toKey => name; // 'fechamentos' | 'valorVendido' | 'novosLeads'

  static _TipoMeta fromKey(String? key) {
    switch (key) {
      case 'valorVendido':
        return _TipoMeta.valorVendido;
      case 'novosLeads':
        return _TipoMeta.novosLeads;
      default:
        return _TipoMeta.fechamentos;
    }
  }
}

// ── Widget principal ──────────────────────────────────────────────────────────
class MetaMensalCard extends StatefulWidget {
  final String userId;

  /// Lista de clientes do usuário — usada para calcular progresso da meta.
  final List<Cliente> clientes;

  const MetaMensalCard({
    super.key,
    required this.userId,
    required this.clientes,
  });

  @override
  State<MetaMensalCard> createState() => _MetaMensalCardState();
}

class _MetaMensalCardState extends State<MetaMensalCard> {
  final _service = FirestoreService();
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _moedaCompacto = NumberFormat.compactCurrency(
      locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);

  Map<String, dynamic>? _meta; // {tipoMeta, valorMeta}
  bool _carregando = true;

  static const _meses = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril',
    'Maio', 'Junho', 'Julho', 'Agosto',
    'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  @override
  void initState() {
    super.initState();
    _carregarMeta();
  }

  Future<void> _carregarMeta() async {
    final meta = await _service.getMeta(widget.userId);
    if (mounted) setState(() { _meta = meta; _carregando = false; });
  }

  // ── Helpers de data ───────────────────────────────────────────────────────
  DateTime get _inicioMes {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, 1);
  }

  bool _esteMs(DateTime? dt) =>
      dt != null && !dt.isBefore(_inicioMes);

  // ── Cálculo do progresso ──────────────────────────────────────────────────
  double _calcularProgresso(_TipoMeta tipo) {
    switch (tipo) {
      case _TipoMeta.fechamentos:
        return widget.clientes
            .where((c) =>
                c.fase == FaseCliente.fechado &&
                _esteMs(c.dataFechamento ?? c.dataAtualizacao))
            .length
            .toDouble();

      case _TipoMeta.valorVendido:
        return widget.clientes
            .where((c) =>
                c.fase == FaseCliente.fechado &&
                _esteMs(c.dataFechamento ?? c.dataAtualizacao))
            .fold(0.0, (soma, c) => soma + (c.valorVendido ?? 0.0));

      case _TipoMeta.novosLeads:
        return widget.clientes
            .where((c) => _esteMs(c.dataCadastro))
            .length
            .toDouble();
    }
  }

  // ── Formata o valor de progresso conforme o tipo ─────────────────────────
  String _formatarValor(double v, _TipoMeta tipo) {
    if (tipo == _TipoMeta.valorVendido) {
      return v >= 1000 ? _moedaCompacto.format(v) : _moeda.format(v);
    }
    return v.toInt().toString();
  }

  String _formatarMeta(double v, _TipoMeta tipo) {
    if (tipo == _TipoMeta.valorVendido) {
      return _moedaCompacto.format(v);
    }
    return v.toInt().toString();
  }

  // ── Dialog de edição ─────────────────────────────────────────────────────
  Future<void> _editarMeta(BuildContext context) async {
    final tipoAtual = _TipoMeta.fromKey(_meta?['tipoMeta'] as String?);
    final valorAtual = (_meta?['valorMeta'] as double?);

    _TipoMeta tipoSelecionado = tipoAtual;
    final ctrl = TextEditingController(
        text: valorAtual != null
            ? (tipoAtual == _TipoMeta.valorVendido
                ? valorAtual.toInt().toString()
                : valorAtual.toInt().toString())
            : '');

    final resultado = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.flag_outlined),
              SizedBox(width: 10),
              Text('Meta do Mês'),
            ],
          ),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Tipo de meta ──────────────────────────────────────────
                Text(
                  'Tipo de meta',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _TipoMeta.values.map((t) {
                    final sel = tipoSelecionado == t;
                    final cs = Theme.of(ctx).colorScheme;
                    return ChoiceChip(
                      avatar: Icon(t.icone,
                          size: 14,
                          color: sel ? cs.onPrimaryContainer : cs.onSurface),
                      label: Text(t.label,
                          style: TextStyle(
                              fontSize: 12,
                              color: sel
                                  ? cs.onPrimaryContainer
                                  : cs.onSurface)),
                      selected: sel,
                      onSelected: (_) =>
                          setSt(() => tipoSelecionado = t),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // ── Valor alvo ────────────────────────────────────────────
                Text(
                  tipoSelecionado.descricao,
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: false),
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: tipoSelecionado == _TipoMeta.valorVendido
                        ? 'Valor alvo (R\$)'
                        : 'Quantidade alvo',
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(tipoSelecionado.icone),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (_meta != null)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(<String, dynamic>{}),
                child: Text('Remover meta',
                    style: TextStyle(
                        color: Theme.of(ctx).colorScheme.error,
                        fontSize: 13)),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(ctrl.text.trim());
                if (v != null && v > 0) {
                  Navigator.of(ctx).pop({
                    'tipoMeta': tipoSelecionado.toKey,
                    'valorMeta': v,
                  });
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    ctrl.dispose();
    if (!mounted || resultado == null) return;

    if (resultado.isEmpty) {
      // Remover meta
      await _service.atualizarMeta(widget.userId, 'fechamentos', null);
      if (mounted) setState(() => _meta = null);
    } else {
      final tipo = resultado['tipoMeta'] as String;
      final valor = resultado['valorMeta'] as double;
      await _service.atualizarMeta(widget.userId, tipo, valor);
      if (mounted) setState(() => _meta = resultado);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_carregando) return const SizedBox(height: 4);

    final cs = Theme.of(context).colorScheme;
    final agora = DateTime.now();
    final nomeMes = _meses[agora.month - 1];

    // ── Sem meta definida ─────────────────────────────────────────────────
    if (_meta == null) {
      return Card(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _editarMeta(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.flag_outlined,
                      color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Meta do Mês',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(
                        'Toque para definir sua meta de $nomeMes.',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () => _editarMeta(context),
                  child: const Text('Definir'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Com meta definida ─────────────────────────────────────────────────
    final tipo = _TipoMeta.fromKey(_meta!['tipoMeta'] as String?);
    final alvo = (_meta!['valorMeta'] as double?) ?? 0.0;
    final progresso = _calcularProgresso(tipo);
    final pct = (alvo == 0 ? 0.0 : progresso / alvo).clamp(0.0, 1.0);
    final atingiu = progresso >= alvo;
    final excedeu = progresso > alvo;

    final corProgresso = atingiu
        ? Colors.green.shade600
        : pct >= 0.7
            ? Colors.orange.shade600
            : cs.primary;

    // ── Texto de status ───────────────────────────────────────────────────
    late final String statusTexto;
    if (atingiu) {
      if (excedeu) {
        final extra = progresso - alvo;
        statusTexto = tipo == _TipoMeta.valorVendido
            ? '🎉 Meta atingida! ${_moedaCompacto.format(extra)} além do esperado.'
            : '🎉 Meta atingida! ${extra.toInt()} além do esperado.';
      } else {
        statusTexto = '🎉 Parabéns! Meta atingida este mês.';
      }
    } else {
      final falta = alvo - progresso;
      if (tipo == _TipoMeta.valorVendido) {
        statusTexto = '${_moedaCompacto.format(falta)} para atingir a meta';
      } else {
        final qtd = falta.ceil();
        final suf = tipo == _TipoMeta.fechamentos
            ? (qtd == 1 ? 'fechamento' : 'fechamentos')
            : (qtd == 1 ? 'lead' : 'leads');
        statusTexto = '$qtd $suf para atingir a meta';
      }
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // ── Anel de progresso ─────────────────────────────────────────
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: pct,
                    strokeWidth: 7,
                    backgroundColor: corProgresso.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(corProgresso),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatarValor(progresso, tipo),
                          style: TextStyle(
                            fontSize: tipo == _TipoMeta.valorVendido
                                ? 13
                                : 20,
                            fontWeight: FontWeight.bold,
                            color: corProgresso,
                            height: 1,
                          ),
                        ),
                        Text(
                          '/ ${_formatarMeta(alvo, tipo)}',
                          style: TextStyle(
                              fontSize: 11, color: cs.outline, height: 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // ── Texto de progresso ────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(tipo.icone,
                          size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${tipo.label} — $nomeMes',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (atingiu)
                        Icon(Icons.check_circle,
                            size: 18, color: Colors.green.shade600),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: corProgresso.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(corProgresso),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    statusTexto,
                    style: TextStyle(
                      fontSize: 12,
                      color: atingiu
                          ? Colors.green.shade700
                          : cs.onSurfaceVariant,
                      fontWeight:
                          atingiu ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            // ── Botão editar ──────────────────────────────────────────────
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 18, color: cs.outline),
              onPressed: () => _editarMeta(context),
              tooltip: 'Editar meta',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
