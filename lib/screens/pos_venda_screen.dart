import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/contrato_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'ficha_contrato_screen.dart';

class PosVendaScreen extends StatefulWidget {
  const PosVendaScreen({super.key});

  @override
  State<PosVendaScreen> createState() => _PosVendaScreenState();
}

class _PosVendaScreenState extends State<PosVendaScreen> {
  final _fs = FirestoreService();
  final _auth = AuthService();

  String _busca = '';
  String? _filtroStatusFin;
  String? _filtroAssinatura;
  String? _filtroCidade;

  String _perfil = '';
  List<Contrato> _todos = [];
  bool _carregando = true;

  StreamSubscription<List<Contrato>>? _sub;

  @override
  void initState() {
    super.initState();
    _auth.getCurrentUserProfile().then((p) => setState(() => _perfil = p));
    _sub = _fs.getContratosStream().listen(
      (lista) => setState(() {
        _todos = lista;
        _carregando = false;
      }),
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

      final finOk =
          _filtroStatusFin == null || c.statusFinanceiro == _filtroStatusFin;
      final assOk =
          _filtroAssinatura == null ||
          c.statusAssinatura.value == _filtroAssinatura;
      final cidOk = _filtroCidade == null || c.cidade == _filtroCidade;

      return buscaOk && finOk && assOk && cidOk;
    }).toList();
  }

  List<String> get _cidades {
    return _todos.map((c) => c.cidade).toSet().toList()..sort();
  }

  bool get _podeImportar =>
      _perfil == 'admin' || _perfil == 'super admin' || _perfil == 'pós-venda';

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contratos Pós-Venda'),
        actions: [
          if (_podeImportar)
            IconButton(
              icon: const Icon(Icons.upload_file_outlined),
              tooltip: 'Importar CSV',
              onPressed: () => _abrirImportDialog(context),
            ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                fillColor: Theme.of(context).colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _busca = v),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildFiltros(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${filtrados.length} contrato${filtrados.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : filtrados.isEmpty
                ? const Center(
                    child: Text('Nenhum contrato encontrado.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                    itemCount: filtrados.length,
                    itemBuilder: (ctx, i) =>
                        _ContratoCard(contrato: filtrados[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          _FilterChip(
            label: 'Status financeiro',
            valor: _filtroStatusFin,
            opcoes: const ['Em andamento', 'Quitado'],
            onSelecionado: (v) => setState(() => _filtroStatusFin = v),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Assinatura',
            valor: _filtroAssinatura,
            opcoes: StatusAssinatura.values.map((s) => s.value).toList(),
            labels: StatusAssinatura.values.map((s) => s.label).toList(),
            onSelecionado: (v) => setState(() => _filtroAssinatura = v),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Cidade',
            valor: _filtroCidade,
            opcoes: _cidades,
            onSelecionado: (v) => setState(() => _filtroCidade = v),
          ),
        ],
      ),
    );
  }

  // ── Import CSV ─────────────────────────────────────────────────────────────

  void _abrirImportDialog(BuildContext context) {
    final upload = html.FileUploadInputElement()..accept = '.csv';
    upload.click();

    upload.onChange.listen((_) {
      final file = upload.files?.first;
      if (file == null) return;
      final reader = html.FileReader();
      reader.readAsText(file, 'UTF-8');
      reader.onLoadEnd.listen((_) {
        final conteudo = reader.result as String?;
        if (conteudo == null) return;
        // ignore: use_build_context_synchronously
        if (context.mounted) _processarCsv(context, conteudo, file.name);
      });
    });
  }

  void _processarCsv(BuildContext context, String conteudo, String nomeArq) {
    List<Contrato> contratos;
    try {
      contratos = _parsearCsv(conteudo);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao ler CSV: $e'), backgroundColor: Colors.red),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ImportPreviewDialog(
        contratos: contratos,
        nomeArquivo: nomeArq,
        onConfirmar: () => _importar(context, contratos),
      ),
    );
  }

  Future<void> _importar(BuildContext context, List<Contrato> contratos) async {
    Navigator.of(context).pop();

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
            content: Text('${contratos.length} contratos importados com sucesso!'),
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

  // ── Parse CSV ──────────────────────────────────────────────────────────────

  List<Contrato> _parsearCsv(String conteudo) {
    final linhas = const CsvToListConverter(eol: '\n').convert(conteudo);
    if (linhas.isEmpty) throw Exception('Arquivo vazio');

    // Normaliza o cabeçalho removendo BOM e espaços
    final cabecalho = linhas.first
        .map((e) => e.toString().trim().replaceAll('﻿', ''))
        .toList();

    int idx(String nome) {
      final i = cabecalho.indexWhere(
        (h) => h.toLowerCase().contains(nome.toLowerCase()),
      );
      return i; // -1 se não encontrado
    }

    final iLoc = idx('LOCALIZADOR');
    if (iLoc < 0) throw Exception('Coluna LOCALIZADOR não encontrada');

    final contratos = <Contrato>[];

    for (var r = 1; r < linhas.length; r++) {
      final row = linhas[r];
      if (row.isEmpty) continue;

      String cel(int i) =>
          i >= 0 && i < row.length ? row[i].toString().trim() : '';
      double dbl(int i) {
        final s = cel(i).replaceAll('.', '').replaceAll(',', '.');
        return double.tryParse(s) ?? 0.0;
      }

      final localizador = cel(iLoc);
      if (localizador.isEmpty || localizador == 'Qtd:') continue;

      DateTime? parseData(int i) {
        final s = cel(i);
        if (s.isEmpty) return null;
        try {
          // MM/DD/YYYY ou DD/MM/YYYY
          final partes = s.split('/');
          if (partes.length == 3) {
            return DateTime(
              int.parse(partes[2]),
              int.parse(partes[0]),
              int.parse(partes[1]),
            );
          }
        } catch (_) {}
        return null;
      }

      DateTime? parseDataNasc(int i) {
        final s = cel(i);
        if (s.isEmpty) return null;
        try {
          // DD/MM/YYYY
          final partes = s.split('/');
          if (partes.length == 3) {
            return DateTime(
              int.parse(partes[2]),
              int.parse(partes[1]),
              int.parse(partes[0]),
            );
          }
        } catch (_) {}
        return null;
      }

      final dataNasc1 = parseDataNasc(idx('DATA NASCIMENTO CESSIONÁRIO 1'));
      final dataNasc2 = parseDataNasc(idx('DATA NASCIMENTO CESSIONÁRIO 2'));

      contratos.add(
        Contrato(
          localizador: localizador,
          localizadorAtendimento: cel(idx('LOCALIZADOR ATENDIMENTO')),
          dataContrato: parseData(idx('DATA')),
          nomeComprador: cel(idx('CESSIONÁRIO 1')),
          cpfComprador: cel(idx('CPF/CNPJ cessionário 1')),
          emailComprador: cel(idx('E-mail cessionário 1')),
          telefoneComprador: cel(idx('Telefone cessionário 1')),
          dataNascimentoComprador: dataNasc1,
          diaNascimentoComprador: dataNasc1?.day,
          mesNascimentoComprador: dataNasc1?.month,
          nomeComprador2: cel(idx('CESSIONÁRIO 2')).isEmpty
              ? null
              : cel(idx('CESSIONÁRIO 2')),
          cpfComprador2: cel(idx('CPF/CNPJ cessionário 2')).isEmpty
              ? null
              : cel(idx('CPF/CNPJ cessionário 2')),
          emailComprador2: cel(idx('E-mail cessionário 2')).isEmpty
              ? null
              : cel(idx('E-mail cessionário 2')),
          telefoneComprador2: cel(idx('Telefone cessionário 2')).isEmpty
              ? null
              : cel(idx('Telefone cessionário 2')),
          dataNascimentoComprador2: dataNasc2,
          diaNascimentoComprador2: dataNasc2?.day,
          mesNascimentoComprador2: dataNasc2?.month,
          logradouro: cel(idx('LOGRADOURO')),
          numero: cel(idx('NÚMERO')),
          complemento: cel(idx('COMPLEMENTO')),
          bairro: cel(idx('BAIRRO')),
          cidade: cel(idx('CIDADE')),
          estado: cel(idx('ESTADO')),
          pais: cel(idx('PAÍS')).isEmpty ? 'Brasil' : cel(idx('PAÍS')),
          sala: cel(idx('SALA')),
          bloco: cel(idx('BLOCO')),
          imovel: cel(idx('IMÓVEL')),
          produto: cel(idx('PRODUTO')),
          cota: cel(idx('COTA')),
          status: cel(idx('STATUS')).isEmpty ? 'Ativo' : cel(idx('STATUS')),
          statusFinanceiro: cel(idx('STATUS FINANCEIRO')).isEmpty
              ? 'Em andamento'
              : cel(idx('STATUS FINANCEIRO')),
          dataQuitacao: parseData(idx('DATA QUITAÇÃO')),
          entrada: dbl(idx('ENTRADA')),
          saldoRestante: dbl(idx('SALDO RESTANTE')),
          valorFinanciado: dbl(idx('VALOR FINANCIADO')),
          valorIntegralizado: dbl(idx('VALOR INTEGRALIZADO')),
          valorAtrasado: dbl(idx('VALOR ATRASADO')),
          percentualIntegralizado: dbl(idx('PERCENTUAL INTEGRALIZADO')),
          valorTotalReajustado: dbl(idx('VALOR TOTAL REAJUSTADO')),
          dataProximoVencimento: parseData(idx('DATA PRÓXIMO VENCIMENTO')),
          vendedorCloser: cel(idx('VENDEDOR CLOSER')),
          captador: cel(idx('CAPTADOR')),
          vendedorLiner: cel(idx('VENDEDOR LINER')),
          pontoCapatcao: cel(idx('PONTO DE CAPTAÇÃO')),
          statusAssinatura: StatusAssinatura.naoAssinado,
        ),
      );
    }

    return contratos;
  }
}

// ── Card do contrato ─────────────────────────────────────────────────────────

class _ContratoCard extends StatelessWidget {
  final Contrato contrato;
  const _ContratoCard({required this.contrato});

  @override
  Widget build(BuildContext context) {
    final c = contrato;
    final pct = c.percentualIntegralizado;
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    Color statusColor;
    switch (c.statusAssinatura) {
      case StatusAssinatura.assinado:
        statusColor = Colors.green;
      case StatusAssinatura.emAndamento:
        statusColor = Colors.orange;
      case StatusAssinatura.naoAssinado:
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

// ── Chip de filtro ────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final String? valor;
  final List<String> opcoes;
  final List<String>? labels;
  final ValueChanged<String?> onSelecionado;

  const _FilterChip({
    required this.label,
    required this.valor,
    required this.opcoes,
    this.labels,
    required this.onSelecionado,
  });

  @override
  Widget build(BuildContext context) {
    final ativo = valor != null;
    return FilterChip(
      label: Text(
        ativo
            ? (labels != null
                  ? labels![opcoes.indexOf(valor!)]
                  : valor!)
            : label,
        style: TextStyle(fontSize: 12, color: ativo ? Colors.white : null),
      ),
      selected: ativo,
      onSelected: (_) => _mostrarMenu(context),
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedColor: Theme.of(context).colorScheme.primary,
      checkmarkColor: Colors.white,
    );
  }

  void _mostrarMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text('Todos ($label)'),
            leading: valor == null
                ? const Icon(Icons.check, color: Colors.green)
                : const SizedBox(width: 24),
            onTap: () {
              onSelecionado(null);
              Navigator.pop(ctx);
            },
          ),
          ...opcoes.asMap().entries.map(
            (e) => ListTile(
              title: Text(labels != null ? labels![e.key] : e.value),
              leading: valor == e.value
                  ? const Icon(Icons.check, color: Colors.green)
                  : const SizedBox(width: 24),
              onTap: () {
                onSelecionado(e.value);
                Navigator.pop(ctx);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dialog de preview de importação ──────────────────────────────────────────

class _ImportPreviewDialog extends StatelessWidget {
  final List<Contrato> contratos;
  final String nomeArquivo;
  final VoidCallback onConfirmar;

  const _ImportPreviewDialog({
    required this.contratos,
    required this.nomeArquivo,
    required this.onConfirmar,
  });

  @override
  Widget build(BuildContext context) {
    final quitados = contratos.where((c) => c.estaQuitado).length;
    final andamento = contratos.length - quitados;
    final comAtraso = contratos.where((c) => c.temAtrasos).length;

    return AlertDialog(
      title: const Text('Importar Contratos'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Arquivo: $nomeArquivo',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          _linha('Total de contratos', '${contratos.length}'),
          _linha('Em andamento', '$andamento'),
          _linha('Quitados', '$quitados'),
          _linha('Com atraso', '$comAtraso', comAtraso > 0 ? Colors.red : null),
          const SizedBox(height: 8),
          const Text(
            'Contratos com o mesmo localizador serão atualizados (merge).',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: onConfirmar,
          child: const Text('Importar'),
        ),
      ],
    );
  }

  Widget _linha(String label, String valor, [Color? cor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            valor,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }
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
