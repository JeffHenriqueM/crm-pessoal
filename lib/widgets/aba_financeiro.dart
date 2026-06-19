// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/baixa_financeira_model.dart';
import '../models/cliente_model.dart';
import '../models/contrato_model.dart';
import '../services/analise_imoveis.dart';
import '../services/financeiro_excel_parser.dart';
import '../services/firestore_service.dart';
import '../services/relatorio_recebimentos_export.dart';
import '../screens/ficha_contrato_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AbaFinanceiro
// ─────────────────────────────────────────────────────────────────────────────
/// Aba de análise financeira de baixas.
///
/// Permissões: 'admin', 'financeiro', 'super admin'.
/// Recebe [clientes] para manter a assinatura do DashboardScreen inalterada,
/// mas os KPIs desta aba vêm das [_baixas] carregadas do Firestore
/// (coleção `baixas_financeiras`) ou importadas via Excel.
class AbaFinanceiro extends StatefulWidget {
  final List<Cliente> clientes;
  final String userProfile;

  const AbaFinanceiro({
    super.key,
    required this.clientes,
    this.userProfile = '',
  });

  @override
  State<AbaFinanceiro> createState() => _AbaFinanceiroState();
}

class _AbaFinanceiroState extends State<AbaFinanceiro> {
  final _firestore = FirestoreService();

  List<BaixaFinanceira> _baixas = [];
  List<Contrato> _contratos = [];
  bool _importando = false;
  bool _carregando = true; // true enquanto faz a leitura inicial do Firestore
  String? _mesFiltro; // null = todos os meses

  static final _moeda = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  static final _moedaK = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$ ',
    decimalDigits: 0,
  );

  // ── Ciclo de vida ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _carregarBaixasDoFirestore();
  }

  Future<void> _carregarBaixasDoFirestore() async {
    try {
      final baixas = await _firestore.getBaixasFinanceiras();
      final contratos = await _firestore.getContratos();
      if (!mounted) return;
      setState(() {
        _baixas = baixas;
        _contratos = contratos;
        _carregando = false;
      });
      debugPrint(
        'AbaFinanceiro: ${baixas.length} baixas carregadas do Firestore.',
      );
    } catch (e) {
      debugPrint('AbaFinanceiro._carregarBaixasDoFirestore: $e');
      if (!mounted) return;
      setState(() => _carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar dados: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Permissão ──────────────────────────────────────────────────────────────
  bool get _temPermissao {
    final p = widget.userProfile.toLowerCase().trim();
    return p == 'admin' || p == 'financeiro' || p == 'super admin';
  }

  // ── Filtro de mês ──────────────────────────────────────────────────────────

  /// Converte "yyyy-MM" → "Mmm/yyyy" para exibição no dropdown.
  String _labelMesCreditoKey(String key) {
    const nomes = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
    ];
    final partes = key.split('-');
    if (partes.length != 2) return key;
    final ano = partes[0];
    final mesIdx = int.tryParse(partes[1]);
    if (mesIdx == null || mesIdx < 1 || mesIdx > 12) return key;
    return '${nomes[mesIdx - 1]}/$ano';
  }

  List<BaixaFinanceira> get _baixasFiltradas {
    if (_mesFiltro == null) return _baixas;
    return _baixas.where((b) => _labelMesCreditoKey(b.mesCreditoKey) == _mesFiltro).toList();
  }

  List<String> get _mesesDisponiveis {
    final set = <String>{};
    for (final b in _baixas) {
      if (b.mesCreditoKey.isNotEmpty) set.add(_labelMesCreditoKey(b.mesCreditoKey));
    }
    // Ordena cronologicamente convertendo de volta para "yyyy-MM"
    final lista = set.toList()
      ..sort((a, b) {
        return _labelParaKey(a).compareTo(_labelParaKey(b));
      });
    return lista;
  }

  /// Converte label "Mmm/yyyy" de volta para "yyyy-MM" para ordenação.
  String _labelParaKey(String label) {
    const nomes = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
    ];
    final partes = label.split('/');
    if (partes.length != 2) return label;
    final mesIdx = nomes.indexOf(partes[0]);
    if (mesIdx == -1) return label;
    final mes = (mesIdx + 1).toString().padLeft(2, '0');
    return '${partes[1]}-$mes';
  }

  // ── KPIs ───────────────────────────────────────────────────────────────────
  double get _totalRecebido =>
      _baixasFiltradas.fold(0.0, (s, b) => s + b.valorPago);

  int get _clientesUnicos =>
      _baixasFiltradas.map((b) => b.cliente).toSet().length;

  int get _totalBaixas => _baixasFiltradas.length;

  double get _ticketMedio {
    final n = _clientesUnicos;
    return n == 0 ? 0.0 : _totalRecebido / n;
  }

  /// Média do valor recebido por mês (referência geral, sobre toda a base).
  double get _mediaMensal {
    final r = _receitaPorMes;
    if (r.isEmpty) return 0.0;
    final soma = r.values.fold(0.0, (s, v) => s + v);
    return soma / r.length;
  }

  /// Variação % do mês de referência vs. o mês imediatamente anterior.
  /// Referência = mês filtrado (se houver) ou o mês mais recente.
  /// `null` quando não há mês anterior para comparar.
  double? get _variacaoMensal {
    final r = _receitaPorMes; // ordenado cronologicamente (yyyy-MM)
    if (r.length < 2) return null;
    final keys = r.keys.toList();
    final refKey = _mesFiltro != null ? _labelParaKey(_mesFiltro!) : keys.last;
    final idx = keys.indexOf(refKey);
    if (idx <= 0) return null;
    final anterior = r[keys[idx - 1]]!;
    if (anterior == 0) return null;
    return (r[keys[idx]]! - anterior) / anterior * 100;
  }

  /// Rótulos [mêsRef, mêsAnterior] comparados na variação; null se não há base.
  List<String>? get _mesesVariacao {
    final r = _receitaPorMes;
    if (r.length < 2) return null;
    final keys = r.keys.toList();
    final refKey = _mesFiltro != null ? _labelParaKey(_mesFiltro!) : keys.last;
    final idx = keys.indexOf(refKey);
    if (idx <= 0) return null;
    return [_labelMesCreditoKey(keys[idx]), _labelMesCreditoKey(keys[idx - 1])];
  }

  // ── Receita por mês (série completa, ignora filtro de mês) ────────────────
  Map<String, double> get _receitaPorMes {
    final map = <String, double>{};
    for (final b in _baixas) {
      if (b.mesCreditoKey.isEmpty) continue;
      map[b.mesCreditoKey] = (map[b.mesCreditoKey] ?? 0.0) + b.valorPago;
    }
    final sorted = map.keys.toList()..sort();
    return {for (final k in sorted) k: map[k]!};
  }

  // ── Por categoria de pagamento (respeita o filtro de mês) ──────────────────
  Map<String, double> get _totalPorCategoria {
    final map = <String, double>{};
    for (final b in _baixasFiltradas) {
      // `tipo` contém a forma de pagamento, ex: "017 - BOLETO SICRED"
      final cat = b.tipo;
      map[cat] = (map[cat] ?? 0.0) + b.valorPago;
    }
    return map;
  }

  // ── Top 10 clientes ────────────────────────────────────────────────────────
  List<MapEntry<String, _ClienteStats>> get _topClientes {
    final map = <String, _ClienteStats>{};
    for (final b in _baixasFiltradas) {
      map.update(
        b.cliente,
        (s) => _ClienteStats(s.total + b.valorPago, s.qtd + 1),
        ifAbsent: () => _ClienteStats(b.valorPago, 1),
      );
    }
    final lista = map.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));
    return lista.take(10).toList();
  }

  /// Soma do valor total reajustado (corrigido) dos contratos ativos.
  double get _valorAtualizadoContratos => contratosEfetivos(_contratos)
      .fold<double>(0.0, (s, c) => s + c.valorTotalReajustado);

  /// Soma do saldo restante (o que ainda falta receber) dos contratos ativos.
  double get _saldoAReceberContratos => contratosEfetivos(_contratos)
      .fold<double>(0.0, (s, c) => s + c.saldoRestante);

  /// Recebido no mês de referência: o mês filtrado, ou o mais recente quando
  /// não há filtro.
  double get _recebidoMesReferencia {
    if (_mesFiltro != null) return _totalRecebido; // já é o mês filtrado
    final r = _receitaPorMes;
    if (r.isEmpty) return 0.0;
    return r[r.keys.last]!;
  }

  /// % do recebido no mês sobre o saldo a receber. null se não há base.
  double? get _percRecebidoSobreSaldo {
    final y = _saldoAReceberContratos;
    return y <= 0 ? null : _recebidoMesReferencia / y * 100;
  }

  /// % do recebido no mês sobre o valor total atualizado. null se não há base.
  double? get _percRecebidoSobreAtualizado {
    final y = _valorAtualizadoContratos;
    return y <= 0 ? null : _recebidoMesReferencia / y * 100;
  }

  // ── Contratos sem pagamento registrado ─────────────────────────────────────
  /// Códigos de contrato (documentoCar) que possuem ao menos uma baixa.
  /// Usa todas as baixas ativas (independe do filtro de mês).
  Set<String> get _codigosComPagamento => _baixas
      .map((b) => b.documentoCar.trim())
      .where((s) => s.isNotEmpty)
      .toSet();

  bool _contratoAtivo(Contrato c) {
    final s = c.status.toLowerCase().trim();
    return s == 'ativo' || s == 'pendente';
  }

  bool _contratoQuitado(Contrato c) =>
      c.statusFinanceiro.toLowerCase().trim() == 'quitado' ||
      c.dataQuitacao != null;

  /// Contratos ATIVOS (e pendentes), não quitados, sem nenhuma baixa registrada.
  /// O join é por `codigoContrato` ↔ `documentoCar` da baixa.
  List<Contrato> get _contratosAtivosSemPagamento {
    final pagos = _codigosComPagamento;
    final lista = _contratos.where((c) {
      if (!_contratoAtivo(c)) return false;
      if (_contratoQuitado(c)) return false;
      return !pagos.contains((c.codigoContrato ?? '').trim());
    }).toList();
    lista.sort((a, b) => b.saldoRestante.compareTo(a.saldoRestante));
    return lista;
  }

  // ── Upload HTML ────────────────────────────────────────────────────────────
  void _abrirUpload() {
    final upload = html.FileUploadInputElement()..accept = '.xlsx';
    upload.click();

    upload.onChange.listen((_) {
      final file = upload.files?.first;
      if (file == null) return;
      final reader = html.FileReader();
      reader.onLoadEnd.listen((_) {
        if (mounted) _processarArquivo(reader);
      });
      reader.readAsArrayBuffer(file);
    });
  }

  // ── Exportar relatório de recebimentos do mês ──────────────────────────────
  /// Pergunta o mês, pede a planilha da Central e gera o relatório enriquecido
  /// com "VALOR RECEBIDO NO MÊS" (só os contratos que pagaram no mês).
  Future<void> _exportarRelatorio() async {
    final meses = await _escolherMesesRelatorio();
    if (meses == null || meses.isEmpty || !mounted) return;

    final upload = html.FileUploadInputElement()..accept = '.xlsx';
    upload.click();
    upload.onChange.listen((_) {
      final file = upload.files?.first;
      if (file == null) return;
      final reader = html.FileReader();
      reader.onLoadEnd.listen((_) {
        if (mounted) _gerarRelatorio(reader, meses);
      });
      reader.readAsArrayBuffer(file);
    });
  }

  /// Diálogo de seleção (múltipla) dos meses presentes nas baixas.
  Future<List<String>?> _escolherMesesRelatorio() async {
    final keys = _baixas
        .map((b) => b.mesCreditoKey)
        .where((k) => k.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a)); // mais recente primeiro
    if (keys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Importe baixas antes de gerar o relatório.')),
      );
      return null;
    }
    final selecionados = <String>{};
    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Meses do relatório'),
          content: SizedBox(
            width: 320,
            child: ListView(
              shrinkWrap: true,
              children: keys
                  .map(
                    (k) => CheckboxListTile(
                      dense: true,
                      value: selecionados.contains(k),
                      title: Text(_labelMesCreditoKey(k)),
                      onChanged: (v) => setLocal(() {
                        if (v == true) {
                          selecionados.add(k);
                        } else {
                          selecionados.remove(k);
                        }
                      }),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: selecionados.isEmpty
                  ? null
                  : () => Navigator.pop(ctx, selecionados.toList()),
              child: Text('Gerar (${selecionados.length})'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _gerarRelatorio(
      html.FileReader reader, List<String> meses) async {
    try {
      final res = reader.result;
      final Uint8List bytes = res is ByteBuffer
          ? res.asUint8List()
          : res is Uint8List
              ? res
              : Uint8List.fromList(res as List<int>);

      final r = RelatorioRecebimentosExport.gerar(
        centralBytes: bytes,
        mesKeys: meses,
        contratos: _contratos,
        baixas: _baixas,
      );

      final blob = html.Blob([r.bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'relatorio_recebimentos.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Relatório gerado: ${r.incluidos} contratos com pagamento em '
            '${meses.length} ${meses.length == 1 ? "mês" : "meses"} '
            '(de ${r.totalLinhas} na planilha).',
          ),
        ),
      );
    } catch (e) {
      debugPrint('AbaFinanceiro._gerarRelatorio: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar relatório: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _processarArquivo(html.FileReader reader) async {
    setState(() => _importando = true);
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      final res = reader.result;
      final Uint8List bytes = res is ByteBuffer
          ? res.asUint8List()
          : res is Uint8List
              ? res
              : Uint8List.fromList(res as List<int>);

      // Obter identidade do usuário logado para campos de auditoria.
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'desconhecido';
      final userName = user?.displayName ?? user?.email ?? 'Usuário';

      final baixas = await FinanceiroExcelParser.parseExcel(
        bytes,
        userId: userId,
        userName: userName,
      );

      if (!mounted) return;

      // Feedback de progresso antes de salvar.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${baixas.length} registros lidos. Salvando no banco…',
          ),
          duration: const Duration(seconds: 10),
        ),
      );

      await _firestore.importarBaixasFinanceiras(baixas);

      if (!mounted) return;

      // Recarregar do Firestore para garantir consistência.
      final baixasAtualizadas = await _firestore.getBaixasFinanceiras();

      if (!mounted) return;
      setState(() {
        _baixas = baixasAtualizadas;
        _importando = false;
        _mesFiltro = null;
      });

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${baixasAtualizadas.length} baixas salvas com sucesso',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      debugPrint('AbaFinanceiro._processarArquivo: $e');
      if (!mounted) return;
      setState(() => _importando = false);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao importar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_temPermissao) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Acesso restrito',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Esta aba é exclusiva para perfis Admin, Financeiro e Super Admin.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;

    if (_carregando) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Carregando dados financeiros…'),
          ],
        ),
      );
    }

    if (_importando) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Processando planilha…'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Seção 1: Header ──────────────────────────────────────────────
          _buildHeader(cs),
          const SizedBox(height: 24),

          if (_baixas.isEmpty) ...[
            _buildEmptyState(cs),
          ] else ...[
            // ── Filtro de mês ──────────────────────────────────────────────
            _buildFiltroMes(cs),
            const SizedBox(height: 20),

            // ── Seção 2: KPI cards ─────────────────────────────────────────
            _buildKpiRow(cs),
            const SizedBox(height: 24),

            // ── Seção 3: Receita por mês ───────────────────────────────────
            _buildSecaoReceita(cs),
            const SizedBox(height: 24),

            // ── Seção 4: Formas de pagamento ───────────────────────────────
            _buildSecaoPagamentos(cs),
            const SizedBox(height: 24),

            // ── Seção 5: Top 10 clientes ───────────────────────────────────
            _buildSecaoTopClientes(cs),
            const SizedBox(height: 24),

            // ── Seção 6: Contratos sem pagamento registrado ────────────────
            _buildSecaoSemPagamento(cs),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(ColorScheme cs) {
    return Row(
      children: [
        Expanded(
          child: _baixas.isNotEmpty
              ? Text(
                  '${_baixas.length} baixas carregadas',
                  style: TextStyle(fontSize: 12, color: cs.outline),
                )
              : const SizedBox.shrink(),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _exportarRelatorio,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Exportar relatório'),
            ),
            FilledButton.icon(
              onPressed: _abrirUpload,
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: const Text('Importar Baixas'),
            ),
          ],
        ),
      ],
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.upload_file_outlined, size: 56, color: cs.outline),
            const SizedBox(height: 16),
            Text(
              'Nenhuma baixa importada',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Clique em "Importar Baixas" para carregar\num arquivo .xlsx com os dados financeiros.',
              style: TextStyle(color: cs.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Filtro de mês ──────────────────────────────────────────────────────────
  Widget _buildFiltroMes(ColorScheme cs) {
    return Row(
      children: [
        Text(
          'Filtrar por mês:',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
        const SizedBox(width: 12),
        DropdownButton<String?>(
          value: _mesFiltro,
          underline: const SizedBox(),
          borderRadius: BorderRadius.circular(8),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Todos'),
            ),
            ..._mesesDisponiveis.map(
              (m) => DropdownMenuItem<String?>(value: m, child: Text(m)),
            ),
          ],
          onChanged: (v) => setState(() => _mesFiltro = v),
        ),
      ],
    );
  }

  // ── Seção 2: KPI cards ─────────────────────────────────────────────────────
  Widget _buildKpiRow(ColorScheme cs) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _kpiCard(
          cs,
          'Total Recebido',
          _formatarMoedaCompacta(_totalRecebido),
          Icons.attach_money_rounded,
          Colors.green.shade700,
        ),
        _kpiCard(
          cs,
          'Clientes Únicos',
          '$_clientesUnicos',
          Icons.people_outline_rounded,
          cs.primary,
        ),
        _kpiCard(
          cs,
          'Baixas Realizadas',
          '$_totalBaixas',
          Icons.receipt_long_outlined,
          Colors.orange.shade700,
        ),
        _kpiCard(
          cs,
          'Ticket Médio',
          _formatarMoedaCompacta(_ticketMedio),
          Icons.trending_up_rounded,
          Colors.teal.shade600,
        ),
        _kpiCard(
          cs,
          'Média Mensal',
          _formatarMoedaCompacta(_mediaMensal),
          Icons.calendar_month_outlined,
          Colors.indigo.shade400,
        ),
        _kpiCard(
          cs,
          'Valor Atualizado',
          _formatarMoedaCompacta(_valorAtualizadoContratos),
          Icons.trending_up_rounded,
          Colors.deepPurple.shade400,
        ),
        if (_percRecebidoSobreSaldo != null)
          _kpiCard(
            cs,
            'Recebido no mês / saldo a receber',
            _formatarPctSimples(_percRecebidoSobreSaldo!),
            Icons.savings_outlined,
            Colors.teal.shade700,
          ),
        if (_percRecebidoSobreAtualizado != null)
          _kpiCard(
            cs,
            'Recebido no mês / valor atualizado',
            _formatarPctSimples(_percRecebidoSobreAtualizado!),
            Icons.percent_rounded,
            Colors.indigo.shade600,
          ),
        if (_variacaoMensal != null && _mesesVariacao != null)
          _kpiCard(
            cs,
            'Variação (${_mesesVariacao![0]} vs. ${_mesesVariacao![1]})',
            _formatarPct(_variacaoMensal!),
            _variacaoMensal! >= 0
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            _variacaoMensal! >= 0 ? Colors.green.shade700 : Colors.red.shade700,
          ),
      ],
    );
  }

  Widget _kpiCard(
    ColorScheme cs,
    String label,
    String valor,
    IconData icon,
    Color cor,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: cor.withValues(alpha: 0.12),
                child: Icon(icon, color: cor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      valor,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cor,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(fontSize: 10, color: cs.outline),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Seção 6: Contratos sem pagamento registrado ─────────────────────────────
  Widget _buildSecaoSemPagamento(ColorScheme cs) {
    final lista = _contratosAtivosSemPagamento;
    final cor = Colors.red.shade700;
    return Card(
      child: Theme(
        // remove as bordas divisórias padrão do ExpansionTile
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(Icons.report_gmailerrorred_outlined, color: cor),
          title: Row(
            children: [
              const Expanded(
                child: Text(
                  'Contratos sem pagamento registrado',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${lista.length}',
                  style: TextStyle(color: cor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          subtitle: Text(
            'Ativos, não quitados e sem nenhuma baixa registrada',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            if (lista.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Nenhum — todos os contratos ativos têm pagamento. 🎉',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              )
            else
              ...lista.map(
                (c) => InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FichaContratoScreen(contrato: c),
                    ),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.nomeComprador,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Text(
                                '${(c.codigoContrato ?? '').isEmpty ? c.localizador : c.codigoContrato} · ${c.produto}',
                                style: TextStyle(
                                    fontSize: 11, color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Saldo ${_formatarMoedaCompacta(c.saldoRestante)}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              c.status,
                              style: TextStyle(fontSize: 10, color: cs.outline),
                            ),
                          ],
                        ),
                        Icon(Icons.chevron_right,
                            size: 18, color: cs.outline),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Seção 3: Receita por mês ───────────────────────────────────────────────
  Widget _buildSecaoReceita(ColorScheme cs) {
    final dados = _receitaPorMes; // Map<String (mesCreditoKey), double>
    if (dados.isEmpty) return const SizedBox();

    final chaves = dados.keys.toList();
    final valores = dados.values.toList();
    final maxVal = valores.reduce((a, b) => a > b ? a : b);
    final maxY = maxVal * 1.15;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Receita por Mês',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Série completa (independente do filtro de mês)',
              style: TextStyle(fontSize: 11, color: cs.outline),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barGroups: List.generate(
                    chaves.length,
                    (i) => BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: valores[i],
                          color: cs.primary,
                          width: chaves.length <= 6 ? 28 : 18,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 58,
                        getTitlesWidget: (v, _) => Text(
                          _formatarMoedaCompacta(v),
                          style: TextStyle(fontSize: 9, color: cs.outline),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= chaves.length) {
                            return const Text('');
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _labelMesCreditoKey(chaves[i]),
                              style: TextStyle(
                                fontSize: 9,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => cs.primary,
                      getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
                        '${_labelMesCreditoKey(chaves[gi])}\n${_moeda.format(rod.toY)}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Seção 4: Formas de pagamento ───────────────────────────────────────────
  Widget _buildSecaoPagamentos(ColorScheme cs) {
    final dados = _totalPorCategoria;
    if (dados.isEmpty) return const SizedBox();

    final total = dados.values.fold(0.0, (s, v) => s + v);
    final categorias = dados.keys.toList()
      ..sort((a, b) => dados[b]!.compareTo(dados[a]!));

    const cores = [
      Color(0xFF1565C0), // azul escuro — Boleto
      Color(0xFF2E7D32), // verde escuro — Cartão
      Color(0xFF6A1B9A), // roxo — PIX
      Color(0xFFE65100), // laranja — Outros
      Color(0xFF00695C), // teal
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart_outline_rounded,
                    color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Formas de Pagamento',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _mesFiltro == null ? 'Todos os meses' : 'Mês: $_mesFiltro',
              style: TextStyle(fontSize: 11, color: cs.outline),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Donut
                SizedBox(
                  height: 220,
                  width: 220,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 60,
                      sections: List.generate(categorias.length, (i) {
                        final cat = categorias[i];
                        final val = dados[cat]!;
                        final pct = total > 0 ? val / total * 100 : 0.0;
                        return PieChartSectionData(
                          value: val,
                          color: cores[i % cores.length],
                          radius: 50,
                          title: '${pct.toStringAsFixed(1)}%',
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          titlePositionPercentageOffset: 0.6,
                        );
                      }),
                      sectionsSpace: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Legenda
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(categorias.length, (i) {
                      final cat = categorias[i];
                      final val = dados[cat]!;
                      final pct =
                          total > 0 ? val / total * 100 : 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: cores[i % cores.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cat,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  Text(
                                    '${pct.toStringAsFixed(1)}% · ${_moeda.format(val)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: cs.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Seção 5: Top 10 clientes ───────────────────────────────────────────────
  Widget _buildSecaoTopClientes(ColorScheme cs) {
    final top = _topClientes;
    if (top.isEmpty) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events_outlined,
                    color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Top 10 Clientes',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                if (_mesFiltro != null) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(_mesFiltro!),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            // Cabeçalho da tabela
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      '#',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: cs.outline,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Cliente',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: cs.outline,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: Text(
                      'Total Pago',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: cs.outline,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      'Baixas',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: cs.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Linhas
            ...List.generate(top.length, (i) {
              final entry = top[i];
              final isLast = i == top.length - 1;
              return Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: i == 0
                                  ? Colors.amber.shade700
                                  : i == 1
                                      ? Colors.grey.shade600
                                      : i == 2
                                          ? Colors.brown.shade400
                                          : cs.outline,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: Text(
                            _moeda.format(entry.value.total),
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(
                            '${entry.value.qtd}',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast) Divider(height: 1, color: cs.outlineVariant),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Formatação ─────────────────────────────────────────────────────────────
  String _formatarMoedaCompacta(double valor) {
    if (valor >= 1000000) {
      return 'R\$ ${(valor / 1000000).toStringAsFixed(2)}M';
    }
    if (valor >= 1000) {
      return 'R\$ ${(valor / 1000).toStringAsFixed(0)}k';
    }
    return _moedaK.format(valor);
  }

  /// Formata variação percentual com sinal: "+12,3%" / "-8,1%".
  String _formatarPct(double valor) {
    final sinal = valor > 0 ? '+' : (valor < 0 ? '-' : '');
    return '$sinal${valor.abs().toStringAsFixed(1).replaceAll('.', ',')}%';
  }

  /// Formata porcentagem simples (sem sinal): "2,4%".
  String _formatarPctSimples(double valor) =>
      '${valor.toStringAsFixed(1).replaceAll('.', ',')}%';
}

// ─────────────────────────────────────────────────────────────────────────────
// Modelo interno para stats de cliente no ranking
// ─────────────────────────────────────────────────────────────────────────────
class _ClienteStats {
  final double total;
  final int qtd;
  const _ClienteStats(this.total, this.qtd);
}
