import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/contrato_model.dart';
import '../models/interacao_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/ficha/ficha_timeline_tab.dart';

class FichaContratoScreen extends StatefulWidget {
  final Contrato contrato;

  const FichaContratoScreen({super.key, required this.contrato});

  @override
  State<FichaContratoScreen> createState() => _FichaContratoScreenState();
}

class _FichaContratoScreenState extends State<FichaContratoScreen>
    with SingleTickerProviderStateMixin {
  final _fs = FirestoreService();
  final _auth = AuthService();

  late TabController _tabCtrl;
  List<Interacao> _interacoes = [];
  String _perfil = '';

  StreamSubscription<List<Interacao>>? _interSub;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _auth.getCurrentUserProfile().then((p) => setState(() => _perfil = p));
    _interSub = _fs
        .getInteracoesContrato(widget.contrato.localizador)
        .listen((lista) => setState(() => _interacoes = lista));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _interSub?.cancel();
    super.dispose();
  }

  bool get _isAdmin =>
      _perfil == 'admin' || _perfil == 'super admin' || _perfil == 'pós-venda';

  @override
  Widget build(BuildContext context) {
    final c = widget.contrato;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c.nomeComprador,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              'Localizador ${c.localizador} · ${c.produto}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Dados'),
            Tab(text: 'Interações'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _DadosTab(contrato: c, isAdmin: _isAdmin, onAssinaturaAlterada: _alterarAssinatura),
          _InteracoesTab(
            interacoes: _interacoes,
            onItemTap: (i) => _menuInteracao(i),
          ),
        ],
      ),
      floatingActionButton: _tabCtrl.index == 1
          ? FloatingActionButton(
              onPressed: _novaInteracao,
              tooltip: 'Registrar interação',
              child: const Icon(Icons.add_comment_outlined),
            )
          : null,
    );
  }

  // ── Assinatura ─────────────────────────────────────────────────────────────

  void _alterarAssinatura(StatusAssinatura novo) async {
    await _fs.atualizarStatusAssinatura(
      widget.contrato.localizador,
      novo,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Assinatura atualizada: ${novo.label}')),
      );
    }
  }

  // ── Interações ─────────────────────────────────────────────────────────────

  void _novaInteracao() {
    _InteracaoFormDialog.show(
      context,
      onSalvar: (i) async {
        await _fs.adicionarInteracaoContrato(
          widget.contrato.localizador,
          i,
        );
      },
    );
  }

  void _menuInteracao(Interacao interacao) {
    if (interacao.isSistema) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Excluir interação',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmarExcluirInteracao(interacao);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarExcluirInteracao(Interacao interacao) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir interação?'),
        content: Text(interacao.titulo ?? interacao.nota),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (interacao.id != null) {
                await _fs.deletarInteracaoContrato(
                  widget.contrato.localizador,
                  interacao.id!,
                );
              }
            },
            child: const Text('Excluir',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Aba de dados ──────────────────────────────────────────────────────────────

class _DadosTab extends StatelessWidget {
  final Contrato contrato;
  final bool isAdmin;
  final ValueChanged<StatusAssinatura> onAssinaturaAlterada;

  const _DadosTab({
    required this.contrato,
    required this.isAdmin,
    required this.onAssinaturaAlterada,
  });

  @override
  Widget build(BuildContext context) {
    final c = contrato;
    final fmtMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final fmtData = DateFormat('dd/MM/yyyy');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Assinatura
        _secao('Processo de Assinatura', [
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SegmentedButton<StatusAssinatura>(
                segments: StatusAssinatura.values
                    .map(
                      (s) => ButtonSegment(
                        value: s,
                        label: Text(s.label, style: const TextStyle(fontSize: 12)),
                      ),
                    )
                    .toList(),
                selected: {c.statusAssinatura},
                onSelectionChanged: (sel) => onAssinaturaAlterada(sel.first),
                showSelectedIcon: false,
              ),
            )
          else
            _campo('Status de Assinatura', c.statusAssinatura.label),
        ]),
        const SizedBox(height: 8),

        // Financeiro
        _secao('Financeiro', [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${c.percentualIntegralizado.toStringAsFixed(1)}% integralizado',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      c.estaQuitado ? 'QUITADO' : c.statusFinanceiro,
                      style: TextStyle(
                        color: c.estaQuitado ? Colors.green : null,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (c.percentualIntegralizado / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(
                      c.estaQuitado ? Colors.green : Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _campo('Valor financiado', fmtMoeda.format(c.valorFinanciado)),
          _campo('Valor integralizado', fmtMoeda.format(c.valorIntegralizado)),
          _campo('Saldo restante', fmtMoeda.format(c.saldoRestante)),
          _campo('Entrada', fmtMoeda.format(c.entrada)),
          if (c.temAtrasos)
            _campo(
              'Valor em atraso',
              fmtMoeda.format(c.valorAtrasado),
              destaque: Colors.red,
            ),
          if (c.dataProximoVencimento != null)
            _campo(
              'Próximo vencimento',
              fmtData.format(c.dataProximoVencimento!),
            ),
          if (c.dataQuitacao != null)
            _campo('Data quitação', fmtData.format(c.dataQuitacao!)),
        ]),
        const SizedBox(height: 8),

        // Comprador
        _secao('Comprador Principal', [
          _campo('Nome', c.nomeComprador),
          if (c.cpfComprador.isNotEmpty) _campo('CPF/CNPJ', c.cpfComprador),
          if (c.emailComprador.isNotEmpty) _campo('E-mail', c.emailComprador),
          if (c.telefoneComprador.isNotEmpty)
            _campo('Telefone', c.telefoneComprador),
          if (c.dataNascimentoComprador != null)
            _campo(
              'Data de nascimento',
              fmtData.format(c.dataNascimentoComprador!),
            ),
        ]),
        const SizedBox(height: 8),

        if (c.nomeComprador2 != null && c.nomeComprador2!.isNotEmpty) ...[
          _secao('Comprador 2 / Cônjuge', [
            _campo('Nome', c.nomeComprador2!),
            if (c.cpfComprador2 != null && c.cpfComprador2!.isNotEmpty)
              _campo('CPF/CNPJ', c.cpfComprador2!),
            if (c.emailComprador2 != null && c.emailComprador2!.isNotEmpty)
              _campo('E-mail', c.emailComprador2!),
            if (c.telefoneComprador2 != null && c.telefoneComprador2!.isNotEmpty)
              _campo('Telefone', c.telefoneComprador2!),
            if (c.dataNascimentoComprador2 != null)
              _campo(
                'Data de nascimento',
                fmtData.format(c.dataNascimentoComprador2!),
              ),
          ]),
          const SizedBox(height: 8),
        ],

        // Produto
        _secao('Produto', [
          _campo('Produto', c.produto),
          _campo('Cota', c.cota),
          _campo('Bloco', c.bloco),
          _campo('Imóvel', c.imovel),
          _campo('Sala', c.sala),
        ]),
        const SizedBox(height: 8),

        // Endereço
        _secao('Endereço', [
          _campo(
            'Logradouro',
            [c.logradouro, c.numero, c.complemento]
                .where((s) => s.isNotEmpty)
                .join(', '),
          ),
          _campo(
            'Cidade/Estado',
            '${c.cidade} / ${c.estado}',
          ),
        ]),
        const SizedBox(height: 8),

        // Equipe
        _secao('Equipe Comercial', [
          if (c.vendedorCloser.isNotEmpty)
            _campo('Closer', c.vendedorCloser),
          if (c.captador.isNotEmpty) _campo('Captador', c.captador),
          if (c.vendedorLiner.isNotEmpty) _campo('Liner', c.vendedorLiner),
          if (c.pontoCapatcao.isNotEmpty)
            _campo('Ponto de captação', c.pontoCapatcao),
        ]),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _secao(String titulo, List<Widget> filhos) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            ...filhos,
          ],
        ),
      ),
    );
  }

  Widget _campo(String label, String valor, {Color? destaque}) {
    if (valor.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 148,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    destaque != null ? FontWeight.w700 : FontWeight.normal,
                color: destaque,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Aba de interações (wrapper) ───────────────────────────────────────────────

class _InteracoesTab extends StatefulWidget {
  final List<Interacao> interacoes;
  final void Function(Interacao) onItemTap;

  const _InteracoesTab({
    required this.interacoes,
    required this.onItemTap,
  });

  @override
  State<_InteracoesTab> createState() => _InteracoesTabState();
}

class _InteracoesTabState extends State<_InteracoesTab> {
  // Rebuild when parent updates
  @override
  Widget build(BuildContext context) {
    return FichaTimelineTab(
      interacoes: widget.interacoes,
      isNovo: false,
      onItemTap: widget.onItemTap,
    );
  }
}

// ── Dialog de nova interação ──────────────────────────────────────────────────

class _InteracaoFormDialog extends StatefulWidget {
  final Future<void> Function(Interacao) onSalvar;

  const _InteracaoFormDialog({required this.onSalvar});

  static void show(
    BuildContext context, {
    required Future<void> Function(Interacao) onSalvar,
  }) {
    showDialog(
      context: context,
      builder: (_) => _InteracaoFormDialog(onSalvar: onSalvar),
    );
  }

  @override
  State<_InteracaoFormDialog> createState() => _InteracaoFormDialogState();
}

class _InteracaoFormDialogState extends State<_InteracaoFormDialog> {
  Canal _canal = Canal.whatsapp;
  Modalidade _modalidade = Modalidade.online;
  bool _houveResposta = false;
  final _tituloCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  final _combinamosCtrl = TextEditingController();
  bool _salvando = false;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _notaCtrl.dispose();
    _combinamosCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova Interação'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Canal
            DropdownButtonFormField<Canal>(
              value: _canal,
              decoration: const InputDecoration(labelText: 'Canal'),
              items: Canal.values
                  .where((c) => c != Canal.sistema)
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Icon(c.icone, size: 16, color: c.cor),
                            const SizedBox(width: 8),
                            Text(c.nome),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _canal = v!),
            ),
            const SizedBox(height: 12),
            // Modalidade
            DropdownButtonFormField<Modalidade>(
              value: _modalidade,
              decoration: const InputDecoration(labelText: 'Modalidade'),
              items: Modalidade.values
                  .map((m) => DropdownMenuItem(
                      value: m, child: Text(m.nome)))
                  .toList(),
              onChanged: (v) => setState(() => _modalidade = v!),
            ),
            const SizedBox(height: 12),
            // Houve resposta
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Houve resposta?',
                  style: TextStyle(fontSize: 14)),
              value: _houveResposta,
              onChanged: (v) => setState(() => _houveResposta = v),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _tituloCtrl,
              decoration:
                  const InputDecoration(labelText: 'Título (opcional)'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notaCtrl,
              decoration: const InputDecoration(labelText: 'Observações'),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _combinamosCtrl,
              decoration:
                  const InputDecoration(labelText: 'O que combinamos?'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _salvando ? null : _salvar,
          child: _salvando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }

  Future<void> _salvar() async {
    final titulo = _tituloCtrl.text.trim();
    final nota = _notaCtrl.text.trim();
    if (nota.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insira uma nota para a interação.')),
      );
      return;
    }

    setState(() => _salvando = true);
    final combinamos = _combinamosCtrl.text.trim();
    final interacao = Interacao(
      titulo: titulo.isEmpty ? null : titulo,
      nota: _notaCtrl.text.trim(),
      dataInteracao: DateTime.now(),
      canal: _canal,
      modalidade: _modalidade,
      houveResposta: _houveResposta,
      oQueCombinamos: combinamos.isEmpty ? null : combinamos,
    );

    try {
      await widget.onSalvar(interacao);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }
}
