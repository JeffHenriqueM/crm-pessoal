// lib/screens/apresentacao_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/produto_model.dart';
import '../services/firestore_service.dart';
import 'negociacoes_screen.dart';

// ── Tela principal ────────────────────────────────────────────────────────────
class ApresentacaoScreen extends StatefulWidget {
  final String userProfile;
  final String? currentUserId;
  final String? currentUserName;

  const ApresentacaoScreen({
    super.key,
    required this.userProfile,
    this.currentUserId,
    this.currentUserName,
  });

  @override
  State<ApresentacaoScreen> createState() => _ApresentacaoScreenState();
}

class _ApresentacaoScreenState extends State<ApresentacaoScreen> {
  final _moeda        = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _moedaCompact = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);
  final _pct          = NumberFormat('##0.00', 'pt_BR');

  late final TextEditingController _valorCtrl;
  late final TextEditingController _diariaCtrl;
  late final TextEditingController _cdiCtrl;
  late final TextEditingController _poupancaCtrl;

  Produto? _produto;
  List<Produto> _produtos = [];
  StreamSubscription<List<Produto>>? _produtosSub;
  double    _taxaOcupacao = 0.63;
  bool      _modoDias     = false; // false = %, true = dias

  static const _taxas = [0.50, 0.63, 0.80, 1.00];

  @override
  void initState() {
    super.initState();
    _valorCtrl    = TextEditingController();
    _diariaCtrl   = TextEditingController(text: '1600');
    _cdiCtrl      = TextEditingController(text: '10.5');
    _poupancaCtrl = TextEditingController(text: '6.17');
    for (final c in [_valorCtrl, _diariaCtrl, _cdiCtrl, _poupancaCtrl]) {
      c.addListener(() { if (mounted) setState(() {}); });
    }
    _produtosSub = FirestoreService()
        .getProdutosStream()
        .listen((lista) {
          if (mounted) setState(() => _produtos = lista);
        });
  }

  @override
  void dispose() {
    _produtosSub?.cancel();
    for (final c in [_valorCtrl, _diariaCtrl, _cdiCtrl, _poupancaCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  double _parse(String s) => double.tryParse(s.replaceAll(',', '.')) ?? 0;

  int? get _diasPlano {
    if (_produto == null) return null;
    final n = _produto!.nome;
    if (n.contains('Bronze')) return 7;
    if (n.contains('Prata'))  return 14;
    if (n.contains('Ouro'))   return 28;
    return null; // Diamante: sem dias fixos por ano
  }

  double get _valor    => _parse(_valorCtrl.text);
  double get _diaria   => _parse(_diariaCtrl.text);
  double get _cdi      => _parse(_cdiCtrl.text);
  double get _poupanca => _parse(_poupancaCtrl.text);

  /// Total de diárias que a cota representa
  double? get _qtdDiarias {
    if (_valor <= 0 || _diaria <= 0) return null;
    return _valor / _diaria;
  }

  /// Anos de uso = diárias ÷ (diasPlano × ocupação)
  double? get _anosEquivalentes {
    final d  = _qtdDiarias;
    final dp = _diasPlano;
    if (d == null || dp == null || dp == 0 || _taxaOcupacao == 0) return null;
    return d / (dp * _taxaOcupacao);
  }

  /// Retorno anual em R$ = diasPlano × ocupação × diária
  double? get _retornoAnual {
    final dp = _diasPlano;
    if (dp == null || _diaria <= 0) return null;
    return dp * _taxaOcupacao * _diaria;
  }

  // ── Selecionar produto ────────────────────────────────────────────────────
  Future<void> _escolherProduto() async {
    if (_produtos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Nenhum produto cadastrado. Peça ao Super Admin para adicionar produtos.'),
        ),
      );
      return;
    }

    final cs = Theme.of(context).colorScheme;
    final categorias = _produtos.map((p) => p.categoria).toSet().toList()
      ..sort((a, b) {
        final ordemA = _produtos.firstWhere((p) => p.categoria == a).ordem;
        final ordemB = _produtos.firstWhere((p) => p.categoria == b).ordem;
        return ordemA.compareTo(ordemB);
      });

    final resultado = await showModalBottomSheet<Produto>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
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
                    Text('Escolher Produto',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface)),
                  ],
                ),
                const SizedBox(height: 16),
                for (final cat in categorias) ...[
                  Text(cat,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                          letterSpacing: 0.4)),
                  const SizedBox(height: 8),
                  ...(_produtos
                      .where((p) => p.categoria == cat)
                      .toList()
                      ..sort((a, b) => a.ordem.compareTo(b.ordem)))
                      .map((p) => _produtoTile(ctx, p, cs)),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (resultado != null && mounted) {
      setState(() {
        _produto = resultado;
        _valorCtrl.text = resultado.valor.toInt().toString();
      });
    }
  }

  Widget _produtoTile(BuildContext ctx, Produto p, ColorScheme cs) {
    final sel = _produto?.nome == p.nome;
    return InkWell(
      onTap: () => Navigator.of(ctx).pop(p),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: sel
              ? cs.primaryContainer.withValues(alpha: 0.4)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: sel ? cs.primary.withValues(alpha: 0.5) : Colors.transparent,
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

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.co_present, size: 20),
              SizedBox(width: 8),
              Text('Apresentação'),
            ],
          ),
          automaticallyImplyLeading: false,
          toolbarHeight: 50,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Negociação'),
              Tab(text: 'Economia'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            NegociacoesBody(
              userProfile: widget.userProfile,
              currentUserId: widget.currentUserId,
              currentUserName: widget.currentUserName,
            ),
            _buildEconomia(),
          ],
        ),
      ),
    );
  }

  // ── Aba Economia (calculadora de rentabilidade) ───────────────────────────
  Widget _buildEconomia() {
    final cs          = Theme.of(context).colorScheme;
    final diasPlano   = _diasPlano;
    final qtdDiarias  = _qtdDiarias;
    final anosEquiv   = _anosEquivalentes;
    final retornoAnual = _retornoAnual;
    final isMobile    = MediaQuery.of(context).size.width < 700;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Selecionar produto ──────────────────────────────────
              OutlinedButton.icon(
                onPressed: _escolherProduto,
                icon: const Icon(Icons.villa_outlined, size: 18),
                label: Text(
                  _produto != null
                      ? 'Produto: ${_produto!.nome} — ${_moeda.format(_produto!.valor)}'
                      : 'Escolher produto (opcional)',
                ),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size(double.infinity, 48),
                  textStyle: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 20),

              // ── Campos: Valor da cota + Diária ──────────────────────
              isMobile
                  ? Column(
                      children: [
                        _campoValor(),
                        const SizedBox(height: 12),
                        _campoDiaria(),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: _campoValor()),
                        const SizedBox(width: 16),
                        Expanded(child: _campoDiaria()),
                      ],
                    ),

              const SizedBox(height: 24),

              // ── Taxa de ocupação ────────────────────────────────────
              Row(
                children: [
                  Text('Taxa de ocupação',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface)),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: diasPlano != null
                        ? () => setState(() => _modoDias = !_modoDias)
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: diasPlano != null
                            ? (_modoDias
                                ? cs.primaryContainer
                                : cs.surfaceContainerHighest)
                            : cs.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Text(
                        _modoDias ? 'Dias' : '%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: diasPlano != null ? cs.primary : cs.outline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SegmentedButton<double>(
                segments: _taxas.map((t) {
                  final String label;
                  if (_modoDias && diasPlano != null) {
                    label = '${(diasPlano * t).round()}d';
                  } else {
                    label = '${(t * 100).toInt()}%';
                  }
                  return ButtonSegment<double>(value: t, label: Text(label));
                }).toList(),
                selected: {_taxaOcupacao},
                onSelectionChanged: (s) =>
                    setState(() => _taxaOcupacao = s.first),
                style: const ButtonStyle(
                  textStyle:
                      WidgetStatePropertyAll(TextStyle(fontSize: 13)),
                ),
              ),

              const SizedBox(height: 20),

              // ── Taxas de referência (CDI / Poupança) ────────────────
              Row(
                children: [
                  Icon(Icons.compare_arrows,
                      size: 15, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text('Taxas de referência',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cdiCtrl,
                      decoration: const InputDecoration(
                        labelText: 'CDI (% ao ano)',
                        prefixIcon: Icon(Icons.percent, size: 18),
                        isDense: true,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _poupancaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Poupança (% ao ano)',
                        prefixIcon: Icon(Icons.savings_outlined, size: 18),
                        isDense: true,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),
              Divider(color: Colors.green.shade700.withValues(alpha: 0.3)),
              const SizedBox(height: 20),

              // ── Resultados ───────────────────────────────────────────
              if (qtdDiarias != null && diasPlano != null &&
                  anosEquiv != null && retornoAnual != null)
                _buildResultados(
                  cs,
                  qtdDiarias: qtdDiarias,
                  diasPlano: diasPlano,
                  anosEquiv: anosEquiv,
                  retornoAnual: retornoAnual,
                )
              else
                _buildPlaceholder(cs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campoValor() => TextFormField(
        controller: _valorCtrl,
        decoration: const InputDecoration(
          labelText: 'Valor da cota (R\$)',
          prefixIcon: Icon(Icons.villa_outlined),
          hintText: 'Ex: 77000',
        ),
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
        ],
      );

  Widget _campoDiaria() => TextFormField(
        controller: _diariaCtrl,
        decoration: const InputDecoration(
          labelText: 'Diária do resort (R\$)',
          prefixIcon: Icon(Icons.hotel_outlined),
          hintText: 'Ex: 1600',
        ),
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
        ],
      );

  // ── Cards de resultado ─────────────────────────────────────────────────────
  Widget _buildResultados(
    ColorScheme cs, {
    required double qtdDiarias,
    required int diasPlano,
    required double anosEquiv,
    required double retornoAnual,
  }) {
    final verde   = Colors.green.shade700;
    final valor   = _valor;
    final diaria  = _diaria;
    final retornoMensal = retornoAnual / 12;
    final roiAnual  = valor > 0 ? retornoAnual / valor * 100 : 0.0;
    final roiMensal = roiAnual / 12;
    final payback   = retornoAnual > 0 ? valor / retornoAnual : double.infinity;
    final ocupacaoInt = (_taxaOcupacao * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

        // ── Dados base ─────────────────────────────────────────────────
        _buildCardBase(cs, verde,
            valor: valor,
            diaria: diaria,
            qtdDiarias: qtdDiarias,
            diasPlano: diasPlano,
            anosEquiv: anosEquiv),

        const SizedBox(height: 16),

        // ── Cenário 1: Rentabilidade ────────────────────────────────────
        _buildCenario1(cs, verde,
            retornoAnual: retornoAnual,
            retornoMensal: retornoMensal,
            roiAnual: roiAnual,
            roiMensal: roiMensal,
            payback: payback,
            ocupacaoInt: ocupacaoInt),

        const SizedBox(height: 16),

        // ── Cenário 2: Comparativo CDI / Poupança ──────────────────────
        _buildCenario2(cs, verde,
            valor: valor,
            retornoAnualVillamor: retornoAnual,
            roiAnualVillamor: roiAnual),
      ],
    );
  }

  // ── Card base: diárias + anos de uso ──────────────────────────────────────
  Widget _buildCardBase(
    ColorScheme cs,
    Color verde, {
    required double valor,
    required double diaria,
    required double qtdDiarias,
    required int diasPlano,
    required double anosEquiv,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: verde.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: verde.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.villa_outlined, size: 16, color: verde),
              const SizedBox(width: 8),
              Text('USO DO RESORT',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: verde,
                      letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(height: 14),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 14, color: cs.onSurface, height: 1.5),
              children: [
                const TextSpan(text: 'Com o valor da sua cota, você conseguiria pagar um total de '),
                TextSpan(
                  text: '${qtdDiarias.round()} diárias',
                  style: TextStyle(fontWeight: FontWeight.bold, color: verde),
                ),
                const TextSpan(text: ', equivalente a '),
                TextSpan(
                  text: '${anosEquiv.toStringAsFixed(1)} anos',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: verde),
                ),
                const TextSpan(text: ' de utilização.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Cenário 1: Rentabilidade ───────────────────────────────────────────────
  Widget _buildCenario1(
    ColorScheme cs,
    Color verde, {
    required double retornoAnual,
    required double retornoMensal,
    required double roiAnual,
    required double roiMensal,
    required double payback,
    required int ocupacaoInt,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: verde.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: verde.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          Row(
            children: [
              Icon(Icons.trending_up, size: 16, color: verde),
              const SizedBox(width: 8),
              Text('CENÁRIO 1 — RENTABILIDADE',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: verde,
                      letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(height: 14),

          // Texto narrativo 1: retorno anual + mensal
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 14, color: cs.onSurface, height: 1.6),
              children: [
                TextSpan(
                  text: 'A previsão de rentabilidade com $ocupacaoInt% de ocupação é de um retorno anual de ',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                TextSpan(
                  text: _moedaCompact.format(retornoAnual),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: verde),
                ),
                TextSpan(
                  text: ', se dividirmos por 12, uma média mensal de ',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                TextSpan(
                  text: _moedaCompact.format(retornoMensal),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: verde),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Métricas ROI em chips
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _metricaChip(cs, verde, 'Retorno anual',
                  _moedaCompact.format(retornoAnual)),
              _metricaChip(cs, verde, 'Retorno mensal',
                  _moedaCompact.format(retornoMensal)),
              _metricaChip(cs, verde, 'ROI anual',
                  '${_pct.format(roiAnual)}%'),
              _metricaChip(cs, verde, 'ROI mensal',
                  '${_pct.format(roiMensal)}%'),
            ],
          ),
          const SizedBox(height: 14),

          // Texto narrativo 2: ROI %
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 14, color: cs.onSurface, height: 1.5),
              children: [
                TextSpan(
                  text: 'Previsão de retorno anual de ',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                TextSpan(
                  text: '${_pct.format(roiAnual)}%',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: verde, fontSize: 15),
                ),
                TextSpan(
                  text: ' e mensal de ',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                TextSpan(
                  text: '${_pct.format(roiMensal)}%',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: verde, fontSize: 15),
                ),
                TextSpan(
                  text: ' sobre o investimento.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Payback
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: verde.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.replay_circle_filled_outlined,
                    size: 18, color: verde),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                          fontSize: 14, color: cs.onSurface, height: 1.4),
                      children: [
                        const TextSpan(
                          text: 'Payback em ',
                        ),
                        TextSpan(
                          text: payback.isFinite
                              ? '${payback.toStringAsFixed(1)} anos'
                              : '—',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: verde),
                        ),
                        TextSpan(
                          text:
                              ' (cenário onde já pagou toda a cota)',
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Cenário 2: Comparativo CDI / Poupança ─────────────────────────────────
  Widget _buildCenario2(
    ColorScheme cs,
    Color verde, {
    required double valor,
    required double retornoAnualVillamor,
    required double roiAnualVillamor,
  }) {
    final retornoMensalVillamor = retornoAnualVillamor / 12;

    final cdi      = _cdi;
    final poupanca = _poupanca;

    final retornoCdiAnual     = valor * cdi / 100;
    final retornoCdiMensal    = retornoCdiAnual / 12;
    final retornoPoupAnual    = valor * poupanca / 100;
    final retornoPoupMensal   = retornoPoupAnual / 12;

    final cor2 = const Color(0xFF1565C0); // azul para CDI/Poupança

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          Row(
            children: [
              Icon(Icons.compare_arrows, size: 16, color: cs.primary),
              const SizedBox(width: 8),
              Text('CENÁRIO 2 — COMPARATIVO CDI E POUPANÇA',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                      letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(height: 14),

          Text(
            'Para o mesmo valor de ${_moedaCompact.format(valor)} investido:',
            style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),

          // Tabela comparativa
          _linhaComparativa(
            cs,
            icon: Icons.percent,
            cor: cor2,
            rotulo: 'CDI',
            taxa: '${_pct.format(cdi)}% ao ano',
            anual: retornoCdiAnual,
            mensal: retornoCdiMensal,
            destaque: false,
          ),
          const SizedBox(height: 8),
          _linhaComparativa(
            cs,
            icon: Icons.savings_outlined,
            cor: const Color(0xFF00796B),
            rotulo: 'Poupança',
            taxa: '${_pct.format(poupanca)}% ao ano',
            anual: retornoPoupAnual,
            mensal: retornoPoupMensal,
            destaque: false,
          ),
          const SizedBox(height: 8),
          _linhaComparativa(
            cs,
            icon: Icons.villa,
            cor: verde,
            rotulo: 'Villamor',
            taxa: '${_pct.format(roiAnualVillamor)}% ao ano',
            anual: retornoAnualVillamor,
            mensal: retornoMensalVillamor,
            destaque: true,
          ),

          const SizedBox(height: 14),
          Divider(color: cs.outlineVariant.withValues(alpha: 0.6)),
          const SizedBox(height: 10),

          // Vitalício
          Row(
            children: [
              Icon(Icons.all_inclusive, size: 20, color: verde),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Além do retorno financeiro, com a Villamor o acesso é vitalício!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: verde,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Chips de métrica ───────────────────────────────────────────────────────
  Widget _metricaChip(
      ColorScheme cs, Color verde, String label, String valor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: verde.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: verde.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
          Text(valor,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: verde)),
        ],
      ),
    );
  }

  // ── Linha de comparativo ──────────────────────────────────────────────────
  Widget _linhaComparativa(
    ColorScheme cs, {
    required IconData icon,
    required Color cor,
    required String rotulo,
    required String taxa,
    required double anual,
    required double mensal,
    required bool destaque,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: destaque
            ? cor.withValues(alpha: 0.08)
            : cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: destaque
              ? cor.withValues(alpha: 0.35)
              : cs.outlineVariant.withValues(alpha: 0.5),
          width: destaque ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(rotulo,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface)),
                    const SizedBox(width: 6),
                    Text(taxa,
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant)),
                    if (destaque) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.star_rounded,
                          size: 14, color: cor),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${_moedaCompact.format(anual)}/ano  ·  ${_moedaCompact.format(mensal)}/mês',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Placeholder ────────────────────────────────────────────────────────────
  Widget _buildPlaceholder(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.calculate_outlined,
              size: 40,
              color: cs.outline.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            _diasPlano == null && _produto != null
                ? 'Cálculo disponível para planos Bronze, Prata e Ouro'
                : 'Escolha um produto Bronze/Prata/Ouro e informe a diária\npara ver a rentabilidade',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
