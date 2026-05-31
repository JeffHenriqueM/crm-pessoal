import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/produto_model.dart';
import '../services/firestore_service.dart';

class GerenciarProdutosScreen extends StatefulWidget {
  const GerenciarProdutosScreen({super.key});

  @override
  State<GerenciarProdutosScreen> createState() =>
      _GerenciarProdutosScreenState();
}

class _GerenciarProdutosScreenState extends State<GerenciarProdutosScreen> {
  final _service = FirestoreService();
  final _moeda =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);
  bool _mostrarArquivados = false;

  static const _produtosPadrao = [
    (nome: 'Luxo Bronze', cat: 'Luxo', valor: 45000.0, limite: 37000.0, ordem: 10),
    (nome: 'Luxo Prata', cat: 'Luxo', valor: 77000.0, limite: 61000.0, ordem: 11),
    (nome: 'Luxo Ouro', cat: 'Luxo', valor: 145000.0, limite: 116000.0, ordem: 12),
    (nome: 'Luxo Diamante', cat: 'Luxo', valor: 1750000.0, limite: 1224000.0, ordem: 13),
    (nome: 'Villamor Bronze', cat: 'Villamor', valor: 61000.0, limite: 51000.0, ordem: 20),
    (nome: 'Villamor Prata', cat: 'Villamor', valor: 98000.0, limite: 88000.0, ordem: 21),
    (nome: 'Villamor Ouro', cat: 'Villamor', valor: 192000.0, limite: 171000.0, ordem: 22),
    (nome: 'Villamor Diamante', cat: 'Villamor', valor: 2465000.0, limite: 2190000.0, ordem: 23),
    (nome: 'Bangalô Luxury Bronze', cat: 'Bangalô Luxury', valor: 109000.0, limite: null, ordem: 30),
    (nome: 'Bangalô Luxury Prata', cat: 'Bangalô Luxury', valor: 182000.0, limite: null, ordem: 31),
    (nome: 'Bangalô Luxury Ouro', cat: 'Bangalô Luxury', valor: 363000.0, limite: null, ordem: 32),
    (nome: 'Bangalô Luxury Diamante', cat: 'Bangalô Luxury', valor: 4620000.0, limite: null, ordem: 33),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos'),
        actions: [
          IconButton(
            icon: Icon(_mostrarArquivados
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined),
            tooltip: _mostrarArquivados
                ? 'Ocultar arquivados'
                : 'Mostrar arquivados',
            onPressed: () =>
                setState(() => _mostrarArquivados = !_mostrarArquivados),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormProduto(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Novo Produto'),
      ),
      body: StreamBuilder<List<Produto>>(
        stream: _service.getProdutosStream(apenasAtivos: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }

          final todos = snapshot.data ?? [];
          final ativos = todos.where((p) => p.ativo).toList();
          final arquivados = todos.where((p) => !p.ativo).toList();

          if (todos.isEmpty) return _buildEstadoVazio(context);

          final categorias = ativos.map((p) => p.categoria).toSet().toList()
            ..sort();

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            children: [
              for (final cat in categorias) ...[
                _sectionHeader(context, cat),
                ...ativos
                    .where((p) => p.categoria == cat)
                    .map((p) => _produtoCard(context, p)),
                const SizedBox(height: 8),
              ],
              if (_mostrarArquivados && arquivados.isNotEmpty) ...[
                _sectionHeader(context, 'Arquivados', arquivado: true),
                ...arquivados
                    .map((p) => _produtoCard(context, p, arquivado: true)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildEstadoVazio(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.villa_outlined,
                size: 64, color: cs.outline.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('Nenhum produto cadastrado.',
                style: TextStyle(fontSize: 16, color: cs.outline)),
            const SizedBox(height: 8),
            Text(
              'Adicione produtos manualmente ou importe os produtos padrão Villamor.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.outlineVariant),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _seedProdutosPadrao(context),
              icon: const Icon(Icons.download_outlined),
              label: const Text('Importar produtos padrão'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String titulo,
      {bool arquivado = false}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      child: Text(
        titulo,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: arquivado ? cs.outlineVariant : cs.primary,
        ),
      ),
    );
  }

  Widget _produtoCard(BuildContext context, Produto produto,
      {bool arquivado = false}) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: arquivado ? 0 : 1,
      margin: const EdgeInsets.only(bottom: 6),
      color: arquivado
          ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          produto.nome,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: arquivado ? cs.onSurfaceVariant : cs.onSurface,
          ),
        ),
        subtitle: produto.limiteEspecial != null
            ? Text(
                'Limite especial: ${_moeda.format(produto.limiteEspecial)}',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _moeda.format(produto.valor),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: arquivado ? cs.outlineVariant : cs.primary,
              ),
            ),
            const SizedBox(width: 4),
            if (!arquivado)
              IconButton(
                icon: Icon(Icons.edit_outlined, size: 18, color: cs.primary),
                onPressed: () => _abrirFormProduto(context, produto),
                tooltip: 'Editar',
                visualDensity: VisualDensity.compact,
              ),
            IconButton(
              icon: Icon(
                arquivado
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
              onPressed: () => arquivado
                  ? _service.reativarProduto(produto.id!)
                  : _confirmarArquivar(context, produto),
              tooltip: arquivado ? 'Reativar' : 'Arquivar',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarArquivar(BuildContext context, Produto produto) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arquivar produto?'),
        content: Text(
            '"${produto.nome}" não aparecerá mais nas negociações.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _service.arquivarProduto(produto.id!);
            },
            child: const Text('Arquivar'),
          ),
        ],
      ),
    );
  }

  Future<void> _seedProdutosPadrao(BuildContext context) async {
    try {
      for (final p in _produtosPadrao) {
        await _service.salvarProduto({
          'nome': p.nome,
          'categoria': p.cat,
          'valor': p.valor,
          'limiteEspecial': p.limite,
          'ativo': true,
          'ordem': p.ordem,
        });
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Produtos padrão importados com sucesso!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao importar: $e')),
        );
      }
    }
  }

  void _abrirFormProduto(BuildContext context, Produto? produto) {
    showDialog(
      context: context,
      builder: (ctx) => _FormProduto(produto: produto, service: _service),
    );
  }
}

// ── Formulário de criação/edição ──────────────────────────────────────────────
class _FormProduto extends StatefulWidget {
  final Produto? produto;
  final FirestoreService service;
  const _FormProduto({this.produto, required this.service});

  @override
  State<_FormProduto> createState() => _FormProdutoState();
}

class _FormProdutoState extends State<_FormProduto> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _valorCtrl;
  late final TextEditingController _limiteCtrl;
  late final TextEditingController _ordemCtrl;
  late String _categoria;
  bool _salvando = false;

  static const _categorias = ['Luxo', 'Villamor', 'Bangalô Luxury', 'Outro'];

  @override
  void initState() {
    super.initState();
    final p = widget.produto;
    _nomeCtrl = TextEditingController(text: p?.nome ?? '');
    _valorCtrl =
        TextEditingController(text: p != null ? p.valor.toInt().toString() : '');
    _limiteCtrl = TextEditingController(
        text: p?.limiteEspecial?.toInt().toString() ?? '');
    _ordemCtrl =
        TextEditingController(text: p?.ordem.toString() ?? '0');
    _categoria = (p != null && _categorias.contains(p.categoria))
        ? p.categoria
        : _categorias.first;
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _valorCtrl.dispose();
    _limiteCtrl.dispose();
    _ordemCtrl.dispose();
    super.dispose();
  }

  double _parse(String s) =>
      double.tryParse(s.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final editando = widget.produto != null;
    return AlertDialog(
      title: Text(editando ? 'Editar Produto' : 'Novo Produto'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome do produto *',
                  prefixIcon: Icon(Icons.villa_outlined),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Nome obrigatório.' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(_categoria),
                initialValue: _categoria,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _categorias
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _categoria = v);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _valorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Valor (R\$) *',
                  prefixIcon: Icon(Icons.attach_money_outlined),
                  hintText: 'Ex: 45000',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) =>
                    _parse(v ?? '') <= 0 ? 'Valor deve ser maior que zero.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _limiteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Limite p/ negociação especial (R\$)',
                  prefixIcon: Icon(Icons.star_outline),
                  hintText: 'Opcional',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ordemCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ordem de exibição',
                  prefixIcon: Icon(Icons.sort_outlined),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _salvando ? null : _salvar,
          child: _salvando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(editando ? 'Salvar' : 'Criar'),
        ),
      ],
    );
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    final limiteRaw = _limiteCtrl.text.trim();
    final limite = limiteRaw.isNotEmpty ? _parse(limiteRaw) : null;
    try {
      await widget.service.salvarProduto(
        {
          'nome': _nomeCtrl.text.trim(),
          'categoria': _categoria,
          'valor': _parse(_valorCtrl.text),
          'limiteEspecial': limite,
          'ativo': true,
          'ordem': int.tryParse(_ordemCtrl.text) ?? 0,
        },
        id: widget.produto?.id,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }
}
