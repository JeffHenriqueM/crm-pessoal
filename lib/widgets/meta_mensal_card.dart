import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../models/usuario_model.dart';
import '../services/analise_imoveis.dart';
import '../services/firestore_service.dart';

// ── Tipos de meta disponíveis ─────────────────────────────────────────────────
enum _TipoMeta {
  // Vendedor
  fechamentos,
  valorVendido,
  mensagensEnviadas,
  // Captador / recepção
  casaisCaptados,
  vendasCaptadas,
  valorCaptado,
  // Pós-venda
  mensagensPosVenda, // percentual de contratos contatados no mês
  assinaturas, // assinaturas conseguidas no mês
  upgrades, // upgrades realizados no mês
  // Legado (mantido para retrocompatibilidade de dados antigos)
  novosLeads;

  String get label {
    switch (this) {
      case _TipoMeta.fechamentos:
        return 'Fechamentos';
      case _TipoMeta.valorVendido:
        return 'Valor Vendido';
      case _TipoMeta.mensagensEnviadas:
        return 'Mensagens';
      case _TipoMeta.casaisCaptados:
        return 'Casais Captados';
      case _TipoMeta.vendasCaptadas:
        return 'Vendas Captadas';
      case _TipoMeta.valorCaptado:
        return 'Valor Captado';
      case _TipoMeta.mensagensPosVenda:
        return 'Contatos Pós-venda';
      case _TipoMeta.assinaturas:
        return 'Assinaturas';
      case _TipoMeta.upgrades:
        return 'Upgrades';
      case _TipoMeta.novosLeads:
        return 'Novos Leads';
    }
  }

  IconData get icone {
    switch (this) {
      case _TipoMeta.fechamentos:
        return Icons.handshake_outlined;
      case _TipoMeta.valorVendido:
        return Icons.attach_money_outlined;
      case _TipoMeta.mensagensEnviadas:
        return Icons.forum_outlined;
      case _TipoMeta.casaisCaptados:
        return Icons.favorite_outline;
      case _TipoMeta.vendasCaptadas:
        return Icons.shopping_bag_outlined;
      case _TipoMeta.valorCaptado:
        return Icons.savings_outlined;
      case _TipoMeta.mensagensPosVenda:
        return Icons.mark_chat_read_outlined;
      case _TipoMeta.assinaturas:
        return Icons.draw_outlined;
      case _TipoMeta.upgrades:
        return Icons.upgrade;
      case _TipoMeta.novosLeads:
        return Icons.person_add_outlined;
    }
  }

  bool get isMonetario =>
      this == _TipoMeta.valorVendido || this == _TipoMeta.valorCaptado;

  /// Meta expressa em porcentagem (0–100).
  bool get isPercentual => this == _TipoMeta.mensagensPosVenda;

  String get toKey => name;

  static _TipoMeta fromKey(String? key) {
    return _TipoMeta.values.firstWhere(
      (t) => t.name == key,
      orElse: () => _TipoMeta.fechamentos,
    );
  }

  /// Tipos oferecidos conforme o perfil do usuário.
  static List<_TipoMeta> paraPerfil(String? perfil) {
    final p = perfil?.toLowerCase();
    if (p == 'captador' || p == 'recepcao' || p == 'recepção') {
      return const [
        _TipoMeta.casaisCaptados,
        _TipoMeta.vendasCaptadas,
        _TipoMeta.valorCaptado,
      ];
    }
    if (p == 'pós-venda' || p == 'pos-venda') {
      return const [
        _TipoMeta.mensagensPosVenda,
        _TipoMeta.assinaturas,
        _TipoMeta.upgrades,
      ];
    }
    return const [
      _TipoMeta.fechamentos,
      _TipoMeta.valorVendido,
      _TipoMeta.mensagensEnviadas,
    ];
  }

  bool get isCaptacao =>
      this == _TipoMeta.casaisCaptados ||
      this == _TipoMeta.vendasCaptadas ||
      this == _TipoMeta.valorCaptado;
}

/// Meta padrão de contatos do pós-venda (% dos contratos no mês).
const double kMetaPadraoPosVenda = 80.0;

// ── Widget principal ──────────────────────────────────────────────────────────
class MetaMensalCard extends StatefulWidget {
  final String userId;

  /// Perfil do usuário — define quais tipos de meta são oferecidos.
  final String? perfil;

  /// Lista de clientes do usuário — usada para calcular progresso da meta.
  final List<Cliente> clientes;

  const MetaMensalCard({
    super.key,
    required this.userId,
    required this.clientes,
    this.perfil,
  });

  @override
  State<MetaMensalCard> createState() => _MetaMensalCardState();
}

class _MetaMensalCardState extends State<MetaMensalCard> {
  final _service = FirestoreService();
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _moedaCompacto = NumberFormat.compactCurrency(
      locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);

  // Metas definidas: {tipoMeta: valorAlvo}.
  Map<String, double> _metas = {};
  bool _carregando = true;

  // Dados complementares para metas que não saem da lista `clientes`.
  int _interacoesMes = 0;
  List<Cliente> _clientesCaptados = const [];
  // Contratos do pós-venda (para a meta de % contatados no mês).
  int _contratosTotal = 0;
  int _contratosContatados = 0;
  // Usuário (contadores de assinaturas/upgrades) — carregado para pós-venda.
  Usuario? _usuario;

  static const _meses = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril',
    'Maio', 'Junho', 'Julho', 'Agosto',
    'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  List<_TipoMeta> get _tiposDisponiveis => _TipoMeta.paraPerfil(widget.perfil);

  bool get _ehPosVenda =>
      _tiposDisponiveis.contains(_TipoMeta.mensagensPosVenda);

  /// O pós-venda só visualiza (a meta é definida pelo admin).
  bool get _soLeitura => _ehPosVenda;

  /// Metas efetivas: para o pós-venda, garante a meta padrão (80%) de contatos
  /// quando o admin ainda não definiu, e inclui assinaturas/upgrades se houver.
  Map<String, double> get _metasEfetivas {
    if (_ehPosVenda) {
      return {
        'mensagensPosVenda':
            _metas['mensagensPosVenda'] ?? kMetaPadraoPosVenda,
        if (_metas.containsKey('assinaturas'))
          'assinaturas': _metas['assinaturas']!,
        if (_metas.containsKey('upgrades')) 'upgrades': _metas['upgrades']!,
      };
    }
    return _metas;
  }

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    final metas = await _service.getMetas(widget.userId);
    final interacoes = await _service.getInteracoesMesAtual(widget.userId);
    final captados = _tiposDisponiveis.any((t) => t.isCaptacao)
        ? await _service.getClientesCaptados(widget.userId)
        : const <Cliente>[];
    // Meta de pós-venda só considera contratos vigentes (Ativo).
    final contratos = _ehPosVenda
        ? contratosEfetivos(await _service.getContratos())
        : const <dynamic>[];
    final usuario = _ehPosVenda ? await _service.getUsuario(widget.userId) : null;
    if (mounted) {
      setState(() {
        _metas = metas;
        _interacoesMes = interacoes;
        _clientesCaptados = captados;
        _contratosTotal = contratos.length;
        _contratosContatados =
            contratos.where((c) => c.contatadoEsteMes == true).length;
        _usuario = usuario;
        _carregando = false;
      });
    }
  }

  // ── Helpers de data ───────────────────────────────────────────────────────
  DateTime get _inicioMes {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, 1);
  }

  bool _esteMs(DateTime? dt) => dt != null && !dt.isBefore(_inicioMes);

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

      case _TipoMeta.mensagensEnviadas:
        return _interacoesMes.toDouble();

      case _TipoMeta.casaisCaptados:
        return _clientesCaptados
            .where((c) => _esteMs(c.dataCadastro))
            .length
            .toDouble();

      case _TipoMeta.vendasCaptadas:
        return _clientesCaptados
            .where((c) =>
                c.fase == FaseCliente.fechado &&
                _esteMs(c.dataFechamento ?? c.dataAtualizacao))
            .length
            .toDouble();

      case _TipoMeta.valorCaptado:
        return _clientesCaptados
            .where((c) =>
                c.fase == FaseCliente.fechado &&
                _esteMs(c.dataFechamento ?? c.dataAtualizacao))
            .fold(0.0, (soma, c) => soma + (c.valorVendido ?? 0.0));

      case _TipoMeta.mensagensPosVenda:
        if (_contratosTotal == 0) return 0;
        return _contratosContatados / _contratosTotal * 100;

      case _TipoMeta.assinaturas:
        return (_usuario?.assinaturasMesAtual ?? 0).toDouble();

      case _TipoMeta.upgrades:
        return (_usuario?.upgradesMesAtual ?? 0).toDouble();

      case _TipoMeta.novosLeads:
        return widget.clientes
            .where((c) => _esteMs(c.dataCadastro))
            .length
            .toDouble();
    }
  }

  String _formatarValor(double v, _TipoMeta tipo) {
    if (tipo.isPercentual) return '${v.round()}%';
    if (tipo.isMonetario) {
      return v >= 1000 ? _moedaCompacto.format(v) : _moeda.format(v);
    }
    return v.toInt().toString();
  }

  String _formatarMeta(double v, _TipoMeta tipo) {
    if (tipo.isPercentual) return '${v.round()}%';
    if (tipo.isMonetario) return _moedaCompacto.format(v);
    return v.toInt().toString();
  }

  // ── Dialog de gerenciamento (várias metas, uma por tipo) ──────────────────
  Future<void> _editarMetas(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final corErro = Theme.of(context).colorScheme.error;
    final tipos = _tiposDisponiveis;

    // Um controller por tipo, pré-preenchido com a meta atual (se houver).
    final ctrls = {
      for (final t in tipos)
        t: TextEditingController(
          text: _metas.containsKey(t.toKey)
              ? _metas[t.toKey]!.toInt().toString()
              : '',
        ),
    };

    final salvar = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.flag_outlined),
              SizedBox(width: 10),
              Expanded(child: Text('Metas do Mês')),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Defina uma ou mais metas. Deixe em branco para não usar.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                ...tipos.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(t.icone, size: 18, color: cs.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: Text(t.label,
                                style: const TextStyle(fontSize: 13)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: ctrls[t],
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: false),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: t.isMonetario ? 'R\$' : 'qtd',
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    // Monta o novo mapa a partir dos campos preenchidos.
    final novo = <String, double>{};
    for (final t in tipos) {
      final v = double.tryParse(ctrls[t]!.text.trim());
      if (v != null && v > 0) novo[t.toKey] = v;
    }
    for (final c in ctrls.values) {
      c.dispose();
    }

    if (salvar != true) return;

    try {
      await _service.definirMetas(widget.userId, novo);
      if (mounted) setState(() => _metas = novo);
      messenger.showSnackBar(
        const SnackBar(content: Text('Metas atualizadas.')),
      );
    } catch (e) {
      debugPrint('[MetaMensalCard] Erro ao salvar metas: $e');
      messenger.showSnackBar(
        SnackBar(
          content:
              const Text('Não foi possível salvar as metas. Tente novamente.'),
          backgroundColor: corErro,
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_carregando) return const SizedBox(height: 4);

    final cs = Theme.of(context).colorScheme;
    final agora = DateTime.now();
    final nomeMes = _meses[agora.month - 1];
    final metas = _metasEfetivas;

    // ── Sem metas definidas ───────────────────────────────────────────────
    // (Não se aplica ao pós-venda, que sempre tem a meta padrão de 80%.)
    if (metas.isEmpty) {
      return Card(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _editarMetas(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child:
                      Icon(Icons.flag_outlined, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Metas do Mês',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(
                        'Toque para definir suas metas de $nomeMes.',
                        style:
                            TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () => _editarMetas(context),
                  child: const Text('Definir'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Com metas definidas ───────────────────────────────────────────────
    // Ordena pelas posições dos tipos do perfil; tipos legados vão ao fim.
    final tiposOrdenados = metas.keys
        .map(_TipoMeta.fromKey)
        .toList()
      ..sort((a, b) {
        final ia = _tiposDisponiveis.indexOf(a);
        final ib = _tiposDisponiveis.indexOf(b);
        return (ia == -1 ? 99 : ia).compareTo(ib == -1 ? 99 : ib);
      });

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_outlined, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Metas — $nomeMes',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                if (!_soLeitura)
                  IconButton(
                    icon: Icon(Icons.edit_outlined,
                        size: 18, color: cs.outline),
                    onPressed: () => _editarMetas(context),
                    tooltip: 'Editar metas',
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            ...tiposOrdenados.map((tipo) => _linhaMeta(cs, tipo, metas)),
          ],
        ),
      ),
    );
  }

  // ── Linha compacta de uma meta ────────────────────────────────────────────
  Widget _linhaMeta(ColorScheme cs, _TipoMeta tipo, Map<String, double> metas) {
    final alvo = metas[tipo.toKey] ?? 0.0;
    final progresso = _calcularProgresso(tipo);
    final pct = (alvo == 0 ? 0.0 : progresso / alvo).clamp(0.0, 1.0);
    final atingiu = progresso >= alvo;
    final cor = atingiu
        ? Colors.green.shade600
        : pct >= 0.7
            ? Colors.orange.shade600
            : cs.primary;

    // Total acumulado (somente para metas com contagem total no usuário).
    final int? total = tipo == _TipoMeta.assinaturas
        ? _usuario?.assinaturasTotal
        : tipo == _TipoMeta.upgrades
            ? _usuario?.upgradesTotal
            : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(tipo.icone, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                          total != null
                              ? '${tipo.label}  ·  $total no total'
                              : tipo.label,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (atingiu) ...[
                      Icon(Icons.check_circle,
                          size: 14, color: Colors.green.shade600),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      '${_formatarValor(progresso, tipo)} / ${_formatarMeta(alvo, tipo)}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: cor),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: cor.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(cor),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
