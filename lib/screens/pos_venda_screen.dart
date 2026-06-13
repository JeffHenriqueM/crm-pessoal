import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/contrato_model.dart';
import '../services/contrato_csv_parser.dart';
import '../services/contrato_import_diff.dart';
import '../services/firestore_service.dart';
import '../widgets/esolution_button.dart';
import 'ficha_contrato_screen.dart';

class PosVendaScreen extends StatefulWidget {
  final String userProfile;
  const PosVendaScreen({super.key, required this.userProfile});

  @override
  State<PosVendaScreen> createState() => _PosVendaScreenState();
}

class _PosVendaScreenState extends State<PosVendaScreen> {
  final _fs = FirestoreService();

  String _busca = '';
  // Situação do contrato: por padrão mostra só os Ativos (null = ambos).
  String? _filtroStatus = 'Ativo';
  String? _filtroStatusFin;
  String? _filtroAssinatura;
  String? _filtroProduto;
  // Ordenação: 'nome' | 'imovel' | 'valorVendido' | 'aReceber'.
  String _ordenacao = 'nome';

  List<Contrato> _todos = [];
  bool _carregando = true;

  StreamSubscription<List<Contrato>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _fs.getContratosStream().listen(
      (lista) => setState(() {
        _todos = lista;
        _carregando = false;
      }),
      onError: (_) {
        if (mounted) setState(() => _carregando = false);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  List<Contrato> get _filtrados {
    return _todos.where((c) {
      final q = _busca.toLowerCase();
      final buscaOk =
          q.isEmpty ||
          c.nomeComprador.toLowerCase().contains(q) ||
          (c.nomeComprador2?.toLowerCase().contains(q) ?? false) ||
          c.cpfComprador.contains(q) ||
          c.localizador.contains(q) ||
          c.cidade.toLowerCase().contains(q);

      // "Ativo" = status Ativo; "Inativo" = qualquer outro (Cancelado,
      // Revertido, Não efetivado, Pendente…); null = todos.
      final ativo = c.status.trim().toLowerCase() == 'ativo';
      final statusOk = _filtroStatus == null ||
          (_filtroStatus == 'Ativo' ? ativo : !ativo);
      final finOk =
          _filtroStatusFin == null || c.statusFinanceiro == _filtroStatusFin;
      final assOk = _filtroAssinatura == null ||
          (_filtroAssinatura!.startsWith('grupo:')
              ? c.statusAssinatura.grupo.name ==
                  _filtroAssinatura!.substring('grupo:'.length)
              : c.statusAssinatura.value == _filtroAssinatura);
      final prodOk = _filtroProduto == null || c.produto == _filtroProduto;

      return buscaOk && statusOk && finOk && assOk && prodOk;
    }).toList()
      ..sort(_comparar);
  }

  int _comparar(Contrato a, Contrato b) {
    switch (_ordenacao) {
      case 'imovel':
        final cmpBloco = a.bloco.compareTo(b.bloco);
        if (cmpBloco != 0) return cmpBloco;
        return (int.tryParse(a.imovel) ?? 0).compareTo(int.tryParse(b.imovel) ?? 0);
      case 'valorVendido':
        return b.valorTotalReajustado.compareTo(a.valorTotalReajustado);
      case 'aReceber':
        return b.saldoRestante.compareTo(a.saldoRestante);
      default:
        return a.nomeComprador.toLowerCase().compareTo(b.nomeComprador.toLowerCase());
    }
  }

  /// Quantos filtros (além da busca) estão ativos — para o badge do botão.
  int get _filtrosAtivos => [
        _filtroStatus,
        _filtroStatusFin,
        _filtroAssinatura,
        _filtroProduto,
      ].where((f) => f != null).length;

  static const _labelsOrdenacao = {
    'nome': 'Nome (A–Z)',
    'imovel': 'Nº do imóvel',
    'valorVendido': 'Valor vendido',
    'aReceber': 'Valor a receber',
  };

  /// Texto da contagem que reflete o filtro de situação:
  /// "500 contratos ativos" · "12 contratos inativos" · "520 contratos".
  String _textoContagem(int n) {
    final base = n == 1 ? 'contrato' : 'contratos';
    if (_filtroStatus == 'Ativo') return '$n $base ${n == 1 ? 'ativo' : 'ativos'}';
    if (_filtroStatus == 'Inativo') {
      return '$n $base ${n == 1 ? 'inativo' : 'inativos'}';
    }
    return '$n $base';
  }

  List<String> get _produtos {
    return _todos.map((c) => c.produto).where((p) => p.isNotEmpty).toSet().toList()..sort();
  }

  bool get _podeImportar =>
      widget.userProfile == 'admin' ||
      widget.userProfile == 'super admin' ||
      widget.userProfile == 'pós-venda';

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── Barra de busca + botão de importar ─────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome, CPF, localizador ou cidade…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _busca.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _busca = ''),
                          )
                        : null,
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _busca = v),
                ),
              ),
              const SizedBox(width: 4),
              const EsolutionButton(),
              const SizedBox(width: 4),
              Badge(
                isLabelVisible: _filtrosAtivos > 0,
                label: Text('$_filtrosAtivos'),
                child: IconButton.filledTonal(
                  icon: const Icon(Icons.tune),
                  tooltip: 'Filtrar e ordenar',
                  onPressed: () => _abrirFiltros(context),
                ),
              ),
              if (_podeImportar) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.upload_file_outlined),
                  tooltip: 'Importar Excel/CSV',
                  onPressed: () => _abrirImportDialog(context),
                ),
              ],
            ],
          ),
        ),
        // ── Contagem (reflete o filtro) + ordenação atual ──────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _textoContagem(filtrados.length),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                'ordenado por ${_labelsOrdenacao[_ordenacao]}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        // ── Lista ──────────────────────────────────────────────────────────
        Expanded(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : filtrados.isEmpty
              ? const Center(child: Text('Nenhum contrato encontrado.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                  itemCount: filtrados.length,
                  itemBuilder: (ctx, i) => _ContratoCard(contrato: filtrados[i]),
                ),
        ),
      ],
    );
  }

  void _abrirFiltros(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final cs = Theme.of(ctx).colorScheme;

            void aplicar(VoidCallback fn) {
              setState(fn);
              setSheet(() {});
            }

            ChoiceChip opc(String label, bool sel, VoidCallback onTap) =>
                ChoiceChip(
                  label: Text(
                    label,
                    style: TextStyle(
                      color: sel ? cs.onPrimary : cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  selected: sel,
                  showCheckmark: false,
                  backgroundColor: cs.surfaceContainerHighest,
                  selectedColor: cs.primary,
                  side: BorderSide(
                      color: sel ? Colors.transparent : cs.outlineVariant),
                  onSelected: (_) => aplicar(onTap),
                );

            Widget grupo(String titulo, List<Widget> chips) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 14, bottom: 6),
                      child: Text(titulo,
                          style: Theme.of(ctx).textTheme.titleSmall),
                    ),
                    Wrap(spacing: 8, runSpacing: 8, children: chips),
                  ],
                );

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.85),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Filtrar e ordenar',
                              style: Theme.of(ctx).textTheme.titleLarge),
                          const Spacer(),
                          TextButton(
                            onPressed: () => aplicar(() {
                              _filtroStatus = 'Ativo';
                              _filtroStatusFin = null;
                              _filtroAssinatura = null;
                              _filtroProduto = null;
                              _ordenacao = 'nome';
                            }),
                            child: const Text('Limpar'),
                          ),
                        ],
                      ),
                      grupo('Ordenar por', [
                        for (final e in _labelsOrdenacao.entries)
                          opc(e.value, _ordenacao == e.key,
                              () => _ordenacao = e.key),
                      ]),
                      grupo('Situação', [
                        opc('Todos', _filtroStatus == null,
                            () => _filtroStatus = null),
                        opc('Ativo', _filtroStatus == 'Ativo',
                            () => _filtroStatus = 'Ativo'),
                        opc('Inativo', _filtroStatus == 'Inativo',
                            () => _filtroStatus = 'Inativo'),
                      ]),
                      grupo('Status financeiro', [
                        opc('Todos', _filtroStatusFin == null,
                            () => _filtroStatusFin = null),
                        opc('Em andamento', _filtroStatusFin == 'Em andamento',
                            () => _filtroStatusFin = 'Em andamento'),
                        opc('Quitado', _filtroStatusFin == 'Quitado',
                            () => _filtroStatusFin = 'Quitado'),
                      ]),
                      grupo('Formalização', [
                        opc('Todas', _filtroAssinatura == null,
                            () => _filtroAssinatura = null),
                        for (final g in GrupoFormalizacao.values)
                          opc('Grupo: ${g.label}', _filtroAssinatura == 'grupo:${g.name}',
                              () => _filtroAssinatura = 'grupo:${g.name}'),
                        for (final s in StatusAssinatura.values)
                          opc(s.label, _filtroAssinatura == s.value,
                              () => _filtroAssinatura = s.value),
                      ]),
                      grupo('Produto', [
                        opc('Todos', _filtroProduto == null,
                            () => _filtroProduto = null),
                        for (final p in _produtos)
                          opc(p, _filtroProduto == p, () => _filtroProduto = p),
                      ]),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Ver ${_filtrados.length} contrato(s)'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Import Excel/CSV ───────────────────────────────────────────────────────

  void _abrirImportDialog(BuildContext context) {
    final upload = html.FileUploadInputElement()..accept = '.xlsx,.csv';
    upload.click();

    upload.onChange.listen((_) {
      final file = upload.files?.first;
      if (file == null) return;
      final nome = file.name;
      final ehExcel = nome.toLowerCase().endsWith('.xlsx');
      final reader = html.FileReader();
      reader.onLoadEnd.listen((_) {
        // ignore: use_build_context_synchronously
        if (context.mounted) _processarArquivo(context, reader, nome, ehExcel);
      });
      if (ehExcel) {
        reader.readAsArrayBuffer(file);
      } else {
        reader.readAsText(file, 'UTF-8');
      }
    });
  }

  Future<void> _processarArquivo(BuildContext context, html.FileReader reader,
      String nomeArq, bool ehExcel) async {
    final messenger = ScaffoldMessenger.of(context);

    // Loading desde o início: a leitura do .xlsx é síncrona e pesada para
    // arquivos grandes; sem isso a tela fica congelada sem feedback.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AnalisandoDialog(mensagem: 'Processando planilha…'),
    );
    // Cede um frame para o loading pintar antes do parse travar a UI thread.
    await Future.delayed(const Duration(milliseconds: 50));

    List<Contrato> contratos;
    try {
      if (ehExcel) {
        final res = reader.result;
        final Uint8List bytes = res is ByteBuffer
            ? res.asUint8List()
            : res is Uint8List
                ? res
                : Uint8List.fromList(res as List<int>);
        contratos = parsearExcelContratos(bytes);
      } else {
        contratos = parsearCsvContratos(reader.result as String? ?? '');
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop(); // fecha o loading
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erro ao ler ${ehExcel ? 'Excel' : 'CSV'}: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Análise: compara a planilha com o estado atual da base e separa o que
    // realmente muda. O mesmo loading segue aberto enquanto carrega a base.
    DiffImportContratos diff;
    try {
      final atuais = await _fs.getContratos();
      final porLoc = {for (final c in atuais) c.localizador: c};
      diff = analisarImportContratos(contratos, porLoc);
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop(); // fecha o loading
      messenger.showSnackBar(
        SnackBar(
            content: Text('Erro ao analisar: $e'),
            backgroundColor: Colors.red),
      );
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).pop(); // fecha o loading

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ImportPreviewDialog(
        diff: diff,
        totalArquivo: contratos.length,
        nomeArquivo: nomeArq,
        onConfirmar: () => _importar(context, diff.paraGravar),
      ),
    );
  }

  Future<void> _importar(BuildContext context, List<Contrato> contratos) async {
    Navigator.of(context).pop();

    if (contratos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nada a atualizar — tudo já está igual.')),
      );
      return;
    }

    final overlay = _ProgressOverlay(context: context, total: contratos.length);
    overlay.show();

    try {
      const batchSz = 400;
      for (var i = 0; i < contratos.length; i += batchSz) {
        final fatia = contratos.skip(i).take(batchSz).toList();
        await _fs.salvarContratosLote(fatia);
        overlay.update(i + fatia.length);
      }
      overlay.dismiss();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${contratos.length} contrato(s) atualizado(s) com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      overlay.dismiss();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro na importação: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

}

// ── Card do contrato ─────────────────────────────────────────────────────────

class _ContratoCard extends StatelessWidget {
  final Contrato contrato;
  const _ContratoCard({required this.contrato});

  @override
  Widget build(BuildContext context) {
    final c = contrato;
    final pct = c.percentualEfetivo;
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    Color statusColor;
    switch (c.statusAssinatura.grupo) {
      case GrupoFormalizacao.formalizado:
        statusColor = Colors.green;
      case GrupoFormalizacao.emAndamento:
        statusColor = Colors.orange;
      case GrupoFormalizacao.pendente:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FichaContratoScreen(contrato: c),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.nomeComprador,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (c.temAtrasos)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Em atraso',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${c.produto} · ${c.cota}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '${c.bloco} · Imóvel ${c.imovel} · ${c.cidade}/${c.estado}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              // Barra de integralização
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (pct / 100).clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(
                          c.estaQuitado ? Colors.green : Colors.blue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    c.estaQuitado
                        ? 'Quitado'
                        : 'Saldo: ${fmt.format(c.saldoRestante)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: c.estaQuitado ? Colors.green : null,
                      fontWeight: c.estaQuitado ? FontWeight.w600 : null,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        c.statusAssinatura.label,
                        style: const TextStyle(fontSize: 12),
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
}

// ── Loading enquanto a importação é analisada ────────────────────────────────

class _AnalisandoDialog extends StatelessWidget {
  final String mensagem;
  const _AnalisandoDialog({this.mensagem = 'Analisando alterações…'});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 16),
          Flexible(child: Text(mensagem)),
        ],
      ),
    );
  }
}

// ── Dialog de confirmação: mostra o diff real contra a base ──────────────────

class _ImportPreviewDialog extends StatelessWidget {
  final DiffImportContratos diff;
  final int totalArquivo;
  final String nomeArquivo;
  final VoidCallback onConfirmar;

  const _ImportPreviewDialog({
    required this.diff,
    required this.totalArquivo,
    required this.nomeArquivo,
    required this.onConfirmar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final aGravar = diff.paraGravar.length;

    return AlertDialog(
      title: const Text('Confirmar importação'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Arquivo: $nomeArquivo',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              _linha('Lidos na planilha', '$totalArquivo'),
              _linha('Com alteração', '${diff.alterados.length}',
                  diff.alterados.isNotEmpty ? cs.primary : null),
              _linha('Novos (não existiam)', '${diff.novos.length}',
                  diff.novos.isNotEmpty ? Colors.teal : null),
              _linha('Sem alteração', '${diff.inalterados}', cs.outline),
              const SizedBox(height: 8),
              if (aGravar == 0)
                Text(
                  'Nada mudou em relação aos dados atuais — não há o que gravar.',
                  style: TextStyle(fontSize: 12, color: cs.outline),
                )
              else ...[
                Text(
                  'Só os $aGravar contrato(s) abaixo serão gravados. '
                  'Os "sem alteração" não são tocados; campos nossos '
                  '(assinatura, link, código…) são sempre preservados.',
                  style: TextStyle(fontSize: 11, color: cs.outline),
                ),
                const SizedBox(height: 4),
                if (diff.alterados.isNotEmpty)
                  _grupo(
                    context,
                    icone: Icons.edit_outlined,
                    cor: cs.primary,
                    titulo: 'Alterados (${diff.alterados.length})',
                    itens: [
                      for (final a in diff.alterados)
                        _ItemDiff(
                          '${a.contrato.localizador} — '
                          '${_nome(a.contrato)}',
                          a.campos.join(', '),
                        ),
                    ],
                  ),
                if (diff.novos.isNotEmpty)
                  _grupo(
                    context,
                    icone: Icons.add_circle_outline,
                    cor: Colors.teal,
                    titulo: 'Novos (${diff.novos.length})',
                    itens: [
                      for (final c in diff.novos)
                        _ItemDiff('${c.localizador} — ${_nome(c)}',
                            'contrato novo'),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: onConfirmar,
          child: Text(aGravar == 0 ? 'Fechar' : 'Gravar $aGravar contrato(s)'),
        ),
      ],
    );
  }

  static String _nome(Contrato c) =>
      c.nomeComprador.isEmpty ? '(sem nome)' : c.nomeComprador;

  Widget _grupo(BuildContext context,
      {required IconData icone,
      required Color cor,
      required String titulo,
      required List<_ItemDiff> itens}) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        initiallyExpanded: itens.length <= 30,
        leading: Icon(icone, color: cor, size: 20),
        title: Text(titulo,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: cor)),
        children: [
          SizedBox(
            height: itens.length > 6 ? 200 : null,
            child: Scrollbar(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: itens.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(itens[i].titulo,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(itens[i].detalhe,
                          style: TextStyle(fontSize: 11, color: cor)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linha(String label, String valor, [Color? cor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(valor,
              style: TextStyle(fontWeight: FontWeight.w600, color: cor)),
        ],
      ),
    );
  }
}

/// Linha da lista de diff: título (localizador — nome) + detalhe (campos).
class _ItemDiff {
  final String titulo;
  final String detalhe;
  const _ItemDiff(this.titulo, this.detalhe);
}

// ── Overlay de progresso durante importação ────────────────────────────────

class _ProgressOverlay {
  final BuildContext context;
  final int total;
  int _atual = 0;

  _ProgressOverlay({required this.context, required this.total});

  OverlayEntry? _entry;

  void show() {
    _entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: ColoredBox(
          color: Colors.black45,
          child: Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('Importando $_atual de $total…'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  void update(int atual) {
    _atual = atual;
    _entry?.markNeedsBuild();
  }

  void dismiss() {
    _entry?.remove();
    _entry = null;
  }
}
