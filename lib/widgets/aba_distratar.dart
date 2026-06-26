// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/baixa_financeira_model.dart';
import '../models/contrato_model.dart';
import '../screens/ficha_contrato_screen.dart';
import '../services/firestore_service.dart';
import '../utils/analise_distrato.dart';
import 'botoes_contato_contrato.dart';

/// Aba "Distratar" (Pós-Venda) — visível para super admin e pós-venda.
///
/// Triagem de contratos críticos para análise de distrato:
/// - **Maiores atrasos**: contratos com valor em atraso, do maior para o menor.
/// - **Inadimplentes**: não-quitados com saldo devedor há 3+ meses sem pagar.
///
/// O super admin pode marcar/desmarcar um contrato como "em distrato"
/// (gravado no contrato + trilha em audit_log via [FirestoreService]).
class AbaDistratar extends StatefulWidget {
  final String userProfile;
  const AbaDistratar({super.key, required this.userProfile});

  @override
  State<AbaDistratar> createState() => _AbaDistratarState();
}

class _AbaDistratarState extends State<AbaDistratar> {
  final _firestore = FirestoreService();

  List<Contrato> _contratos = [];
  List<BaixaFinanceira> _baixas = [];
  AnaliseDistrato? _analise;
  bool _carregando = true;
  int _modo = 0; // 0 = maiores atrasos, 1 = inadimplentes
  final _processando = <String>{}; // localizadores em gravação

  String _busca = '';
  // Filtro de situação: 'todos' | 'sem' (não marcados) | SituacaoDistrato.valor
  String _filtroSit = 'todos';

  static final _moeda = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$ ',
    decimalDigits: 2,
  );
  static final _dataFmt = DateFormat('dd/MM/yyyy');

  bool get _temPermissao {
    final p = widget.userProfile.toLowerCase().trim();
    return p == 'super admin' || p == 'pós-venda';
  }

  @override
  void initState() {
    super.initState();
    if (_temPermissao) {
      _carregar();
    } else {
      _carregando = false;
    }
  }

  Future<void> _carregar() async {
    try {
      final contratos = await _firestore.getContratos();
      final baixas = await _firestore.getBaixasFinanceiras();
      if (!mounted) return;
      setState(() {
        _contratos = contratos;
        _baixas = baixas;
        _analise = analisarDistrato(contratos, baixas);
        _carregando = false;
      });
    } catch (e) {
      debugPrint('AbaDistratar._carregar: $e');
      if (!mounted) return;
      setState(() => _carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar contratos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Recalcula os rankings a partir do estado atual em memória (barato).
  void _recalcular() {
    _analise = analisarDistrato(_contratos, _baixas);
  }

  /// Exporta a lista atual (já filtrada) para CSV e dispara o download.
  void _exportarCsv(List<Contrato> lista, Map<String, DateTime> ultimoPag) {
    String campo(String s) =>
        (s.contains(';') || s.contains('"') || s.contains('\n'))
            ? '"${s.replaceAll('"', '""')}"'
            : s;
    String num(double v) => v.toStringAsFixed(2).replaceAll('.', ',');
    String data(DateTime? d) => d == null ? '' : _dataFmt.format(d);

    final linhas = <String>[
      [
        'Nome',
        'Codigo',
        'Cota',
        'Valor em atraso',
        'Saldo devedor',
        '% pago',
        'Ultimo pagamento',
        'Situacao',
        'Notificado em',
        'Distrato previsto',
        'Observacao',
      ].join(';'),
    ];
    for (final c in lista) {
      linhas.add([
        campo(c.nomeComprador),
        campo(c.codigoContrato ?? ''),
        campo(c.cota),
        num(c.valorAtrasado),
        num(c.saldoRestante),
        c.percentualIntegralizado.toStringAsFixed(0),
        data(ultimoPag[c.localizador]),
        campo(c.emDistrato
            ? (c.situacaoDistrato ?? SituacaoDistrato.marcado).label
            : ''),
        data(c.notificadoEm),
        data(c.distratoPrevistoEm),
        campo(c.motivoDistrato ?? ''),
      ].join(';'));
    }

    // BOM (﻿) p/ o Excel reconhecer UTF-8 e os acentos saírem certos.
    final bytes = utf8.encode('﻿${linhas.join('\r\n')}');
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final h = DateTime.now();
    final nome = 'distratar_${h.year}${h.month.toString().padLeft(2, '0')}'
        '${h.day.toString().padLeft(2, '0')}.csv';
    html.AnchorElement(href: url)
      ..setAttribute('download', nome)
      ..click();
    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exportados ${lista.length} contratos.')),
    );
  }

  Future<void> _alternarDistrato(Contrato c) async {
    final marcar = !c.emDistrato;
    String? motivo;
    if (marcar) {
      final r = await _pedirMotivo(c);
      if (r == null) return; // cancelou
      motivo = r;
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remover marcação de distrato?'),
          content: Text('${c.nomeComprador} deixará de aparecer como em distrato.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Remover')),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _processando.add(c.localizador));
    try {
      await _firestore.marcarEmDistrato(c.localizador,
          marcar: marcar, motivo: motivo);
      // Update otimista local + recálculo dos rankings.
      final idx = _contratos.indexWhere((x) => x.localizador == c.localizador);
      if (idx != -1) {
        _contratos[idx] = _contratos[idx].copyWith(
          limparDistrato: !marcar,
          distratoEm: marcar ? DateTime.now() : null,
          distratoPorNome: marcar ? 'você' : null,
          motivoDistrato: marcar ? motivo : null,
        );
      }
      if (!mounted) return;
      setState(() {
        _processando.remove(c.localizador);
        _recalcular();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(marcar
              ? '${c.nomeComprador} marcado para distrato.'
              : 'Marcação removida.'),
        ),
      );
    } catch (e) {
      debugPrint('AbaDistratar._alternarDistrato: $e');
      if (!mounted) return;
      setState(() => _processando.remove(c.localizador));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<String?> _pedirMotivo(Contrato c) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marcar para distrato'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.nomeComprador,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                border: OutlineInputBorder(),
                hintText: 'Ex.: inadimplente há 5 meses',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Marcar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_temPermissao) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Acesso restrito ao super admin e pós-venda.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    final analise = _analise;
    if (analise == null) {
      return const Center(child: Text('Sem dados.'));
    }

    final base =
        _modo == 0 ? analise.maioresAtrasos : analise.inadimplentes;
    final lista = base.where(_passaFiltros).toList();
    final totalAtraso = analise.maioresAtrasos
        .fold<double>(0, (s, c) => s + c.valorAtrasado);

    return RefreshIndicator(
      onRefresh: _carregar,
      child: Column(
        children: [
          _cabecalho(analise, totalAtraso, lista),
          Expanded(
            child: lista.isEmpty
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(base.isEmpty
                              ? 'Nenhum contrato nesta lista.'
                              : 'Nenhum contrato com os filtros aplicados.'),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    itemCount: lista.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) =>
                        _cardContrato(lista[i], analise.ultimoPagamento),
                  ),
          ),
        ],
      ),
    );
  }

  /// Aplica busca (nome/código) + filtro de situação do funil.
  bool _passaFiltros(Contrato c) {
    final q = _busca.trim().toLowerCase();
    if (q.isNotEmpty) {
      final nome = c.nomeComprador.toLowerCase();
      final cod = (c.codigoContrato ?? '').toLowerCase();
      if (!nome.contains(q) && !cod.contains(q)) return false;
    }
    switch (_filtroSit) {
      case 'todos':
        return true;
      case 'sem':
        return !c.emDistrato;
      default:
        if (!c.emDistrato) return false;
        return (c.situacaoDistrato ?? SituacaoDistrato.marcado).valor ==
            _filtroSit;
    }
  }

  Widget _cabecalho(
      AnaliseDistrato analise, double totalAtraso, List<Contrato> lista) {
    final cs = Theme.of(context).colorScheme;
    final emDistrato = _contratos.where((c) => c.emDistrato).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              _kpi('Em atraso', _moeda.format(totalAtraso), Icons.trending_down,
                  Colors.orange),
              const SizedBox(width: 8),
              _kpi('Inadimplentes', '${analise.inadimplentes.length}',
                  Icons.warning_amber_rounded, Colors.red),
              const SizedBox(width: 8),
              _kpi('Em distrato', '$emDistrato', Icons.gavel, cs.primary),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(
                value: 0,
                label: Text('Maiores atrasos (${analise.maioresAtrasos.length})'),
                icon: const Icon(Icons.trending_down),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Inadimplentes (${analise.inadimplentes.length})'),
                icon: const Icon(Icons.warning_amber_rounded),
              ),
            ],
            selected: {_modo},
            onSelectionChanged: (s) => setState(() => _modo = s.first),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome ou código…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    suffixIcon: _busca.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _busca = ''),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _busca = v),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: lista.isEmpty
                    ? null
                    : () => _exportarCsv(lista, analise.ultimoPagamento),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text('Exportar (${lista.length})'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _chipsSituacao(analise),
        ],
      ),
    );
  }

  Widget _chipsSituacao(AnaliseDistrato analise) {
    final base =
        _modo == 0 ? analise.maioresAtrasos : analise.inadimplentes;
    int contar(bool Function(Contrato) f) => base.where(f).length;

    // (valor do filtro, rótulo, contagem, cor opcional)
    final itens = <(String, String, int, Color?)>[
      ('todos', 'Todos', base.length, null),
      ('sem', 'Sem marcação', contar((c) => !c.emDistrato), null),
      for (final s in SituacaoDistrato.values)
        (
          s.valor,
          s.label,
          contar((c) =>
              c.emDistrato &&
              (c.situacaoDistrato ?? SituacaoDistrato.marcado) == s),
          _corSituacao(s),
        ),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: itens.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final (valor, label, n, cor) = itens[i];
          final sel = _filtroSit == valor;
          return ChoiceChip(
            label: Text('$label ($n)'),
            selected: sel,
            visualDensity: VisualDensity.compact,
            selectedColor: (cor ?? Theme.of(context).colorScheme.primary)
                .withValues(alpha: 0.18),
            onSelected: (_) => setState(() => _filtroSit = valor),
          );
        },
      ),
    );
  }

  Widget _kpi(String label, String valor, IconData icone, Color cor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cor.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icone, color: cor, size: 20),
            const SizedBox(height: 4),
            Text(valor,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: cor, fontSize: 15)),
            Text(label,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _cardContrato(Contrato c, Map<String, DateTime> ultimoPagamento) {
    final cs = Theme.of(context).colorScheme;
    final ultimo = ultimoPagamento[c.localizador];
    final processando = _processando.contains(c.localizador);

    final subtitlePartes = <String>[
      if ((c.codigoContrato ?? '').isNotEmpty) c.codigoContrato!,
      ultimo != null
          ? 'Último pgto: ${_dataFmt.format(ultimo)}'
          : 'Sem pagamento registrado',
      'Saldo: ${_moeda.format(c.saldoRestante)}',
      '${c.percentualIntegralizado.toStringAsFixed(0)}% pago',
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => FichaContratoScreen(contrato: c)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                c.nomeComprador,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (c.dataContrato != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                'compra ${_dataFmt.format(c.dataContrato!)}',
                                style: TextStyle(
                                    fontSize: 11, color: cs.onSurfaceVariant),
                              ),
                            ],
                            if (c.emDistrato) ...[
                              const SizedBox(width: 6),
                              _situacaoChip(c),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitlePartes.join('  •  '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (c.emDistrato &&
                            (c.notificadoEm != null ||
                                c.distratoPrevistoEm != null)) ...[
                          const SizedBox(height: 4),
                          Text(
                            _linhaDatas(c),
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.primary,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _moeda.format(c.valorAtrasado),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: c.valorAtrasado > 0
                              ? Colors.red.shade700
                              : cs.onSurfaceVariant,
                        ),
                      ),
                      const Text('em atraso', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // ── Contato (WhatsApp + e-mail) ──────────────────────────
                  BotoesContatoContrato(contrato: c, iconSize: 18),
                  const Spacer(),
                  // ── Distrato ─────────────────────────────────────────────
                  if (processando)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (c.emDistrato) ...[
                    FilledButton.tonalIcon(
                      onPressed: () => _atualizarSituacao(c),
                      icon: const Icon(Icons.timeline, size: 18),
                      label: const Text('Atualizar'),
                    ),
                    IconButton(
                      onPressed: () => _alternarDistrato(c),
                      icon: const Icon(Icons.undo, size: 18),
                      tooltip: 'Tirar do distrato',
                      visualDensity: VisualDensity.compact,
                    ),
                  ] else
                    FilledButton.tonalIcon(
                      onPressed: () => _atualizarSituacao(c),
                      icon: const Icon(Icons.playlist_add_check, size: 18),
                      label: const Text('Acompanhar'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _situacaoChip(Contrato c) {
    final s = c.situacaoDistrato ?? SituacaoDistrato.marcado;
    final cor = _corSituacao(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        s.label.toUpperCase(),
        style:
            TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cor),
      ),
    );
  }

  Color _corSituacao(SituacaoDistrato s) {
    switch (s) {
      case SituacaoDistrato.emAnalise:
        return Colors.teal;
      case SituacaoDistrato.marcado:
        return Colors.blueGrey;
      case SituacaoDistrato.notificado:
        return Colors.blue;
      case SituacaoDistrato.emTratativa:
        return Colors.orange;
      case SituacaoDistrato.emNegociacao:
        return Colors.purple;
      case SituacaoDistrato.distratoEnviado:
        return Colors.red;
      case SituacaoDistrato.regularizado:
        return Colors.green;
    }
  }

  String _linhaDatas(Contrato c) {
    final partes = <String>[];
    if (c.notificadoEm != null) {
      partes.add('Notificado: ${_dataFmt.format(c.notificadoEm!)}');
    }
    if (c.distratoPrevistoEm != null) {
      partes.add('Distrato previsto: ${_dataFmt.format(c.distratoPrevistoEm!)}');
    }
    return partes.join('  •  ');
  }

  Future<void> _atualizarSituacao(Contrato c) async {
    final r = await showDialog<_ResultadoSituacao>(
      context: context,
      builder: (_) => _DialogSituacaoDistrato(contrato: c),
    );
    if (r == null) return;
    setState(() => _processando.add(c.localizador));
    try {
      await _firestore.atualizarSituacaoDistrato(
        c.localizador,
        situacao: r.situacao,
        notificadoEm: r.notificadoEm,
        distratoPrevistoEm: r.distratoPrevistoEm,
        motivo: r.motivo,
      );
      final idx = _contratos.indexWhere((x) => x.localizador == c.localizador);
      if (idx != -1) {
        // Update otimista. Se ainda não estava no funil, entra agora
        // (distratoEm). Datas só refletem quando setadas; limpeza aparece no
        // próximo reload — o Firestore já gravou o valor real.
        final atual = _contratos[idx];
        _contratos[idx] = atual.copyWith(
          distratoEm: atual.distratoEm ?? DateTime.now(),
          distratoPorNome: atual.distratoPorNome ?? 'você',
          situacaoDistrato: r.situacao,
          notificadoEm: r.notificadoEm,
          distratoPrevistoEm: r.distratoPrevistoEm,
          motivoDistrato: r.motivo,
        );
      }
      if (!mounted) return;
      setState(() {
        _processando.remove(c.localizador);
        _recalcular(); // rebuild _analise para o card/contadores refletirem
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Situação atualizada: ${r.situacao.label}.')),
      );
    } catch (e) {
      debugPrint('AbaDistratar._atualizarSituacao: $e');
      if (!mounted) return;
      setState(() => _processando.remove(c.localizador));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red),
      );
    }
  }
}

/// Resultado do diálogo de situação do distrato.
class _ResultadoSituacao {
  final SituacaoDistrato situacao;
  final DateTime? notificadoEm;
  final DateTime? distratoPrevistoEm;
  final String? motivo;
  const _ResultadoSituacao(
      this.situacao, this.notificadoEm, this.distratoPrevistoEm, this.motivo);
}

/// Diálogo para registrar a etapa do funil + as datas de acompanhamento.
/// A data prevista do distrato é sugerida como notificação + 15 dias (editável).
class _DialogSituacaoDistrato extends StatefulWidget {
  final Contrato contrato;
  const _DialogSituacaoDistrato({required this.contrato});

  @override
  State<_DialogSituacaoDistrato> createState() =>
      _DialogSituacaoDistratoState();
}

class _DialogSituacaoDistratoState extends State<_DialogSituacaoDistrato> {
  static final _fmt = DateFormat('dd/MM/yyyy');
  late SituacaoDistrato _situacao =
      widget.contrato.situacaoDistrato ?? SituacaoDistrato.emAnalise;
  late DateTime? _notificadoEm = widget.contrato.notificadoEm;
  late DateTime? _distratoPrevistoEm = widget.contrato.distratoPrevistoEm;
  late final _obs =
      TextEditingController(text: widget.contrato.motivoDistrato ?? '');

  @override
  void dispose() {
    _obs.dispose();
    super.dispose();
  }

  Future<void> _pickData({
    required DateTime? atual,
    required ValueChanged<DateTime> onPick,
  }) async {
    final hoje = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: atual ?? hoje,
      firstDate: DateTime(hoje.year - 1),
      lastDate: DateTime(hoje.year + 2),
    );
    if (d != null) onPick(d);
  }

  Widget _campoData(String label, DateTime? valor, VoidCallback onTap,
      {VoidCallback? onClear}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: valor != null && onClear != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18), onPressed: onClear)
              : const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(valor != null ? _fmt.format(valor) : '—'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Situação / acompanhamento'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.contrato.nomeComprador,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<SituacaoDistrato>(
                initialValue: _situacao,
                decoration: const InputDecoration(
                  labelText: 'Situação',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final s in SituacaoDistrato.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: (v) => setState(() => _situacao = v ?? _situacao),
              ),
              const SizedBox(height: 12),
              _campoData(
                'Notificação enviada em',
                _notificadoEm,
                () => _pickData(
                  atual: _notificadoEm,
                  onPick: (d) => setState(() {
                    _notificadoEm = d;
                    // Sugere distrato previsto = notificação + 15 dias se vazio.
                    _distratoPrevistoEm ??= d.add(const Duration(days: 15));
                  }),
                ),
                onClear: () => setState(() => _notificadoEm = null),
              ),
              const SizedBox(height: 12),
              _campoData(
                'Distrato previsto em',
                _distratoPrevistoEm,
                () => _pickData(
                  atual: _distratoPrevistoEm ??
                      _notificadoEm?.add(const Duration(days: 15)),
                  onPick: (d) => setState(() => _distratoPrevistoEm = d),
                ),
                onClear: () => setState(() => _distratoPrevistoEm = null),
              ),
              if (_notificadoEm != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Sugestão: notificação + 15 dias (cláusula 4.7).',
                  style: TextStyle(
                      fontSize: 11, color: Theme.of(context).colorScheme.outline),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _obs,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Observação (opcional)',
                  border: OutlineInputBorder(),
                  hintText: 'Ex.: cliente pediu prazo até dia 10',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _ResultadoSituacao(_situacao, _notificadoEm, _distratoPrevistoEm,
                _obs.text.trim()),
          ),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
