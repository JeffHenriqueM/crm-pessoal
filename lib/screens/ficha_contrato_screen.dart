import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/contrato_model.dart';
import '../models/interacao_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/whatsapp_interacao.dart';
import '../widgets/ficha/ficha_timeline_tab.dart';
import '../widgets/interacao_form_dialog.dart';

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

  // Estado local dos marcos de upgrade (a tela não faz stream do contrato).
  late bool _upgradeOferecido = widget.contrato.upgradeOferecido;
  late bool _upgradeRealizado = widget.contrato.upgradeRealizado;
  late String? _linkPdf = widget.contrato.linkContratoDrive;
  // Status de formalização: mantido em estado local para a seleção visual
  // refletir na mesma tela (a tela não faz stream do contrato).
  late StatusAssinatura _statusAssinatura = widget.contrato.statusAssinatura;

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
          _DadosTab(
            contrato: c,
            isAdmin: _isAdmin,
            statusAssinatura: _statusAssinatura,
            onAssinaturaAlterada: _alterarAssinatura,
            upgradeOferecido: _upgradeOferecido,
            upgradeRealizado: _upgradeRealizado,
            onOfereceuUpgrade: _ofereceuUpgrade,
            onFezUpgrade: _fezUpgrade,
            linkPdf: _linkPdf,
            onAbrirPdf: _abrirPdf,
            onEditarLinkPdf: _editarLinkPdf,
          ),
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

  // ── Contrato em PDF (Drive) ────────────────────────────────────────────────

  Future<void> _abrirPdf() async {
    final url = _linkPdf;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link.')),
      );
    }
  }

  Future<void> _editarLinkPdf() async {
    final ctrl = TextEditingController(text: _linkPdf ?? '');
    final novo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Link do contrato (PDF)'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'Cole o link do Drive (PDF)…',
            prefixIcon: Icon(Icons.link),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (novo == null) return; // cancelado
    await _fs.salvarLinkContrato(widget.contrato.localizador, novo);
    if (!mounted) return;
    setState(() => _linkPdf = novo.isEmpty ? null : novo);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(novo.isEmpty ? 'Link removido.' : 'Link salvo.')),
    );
  }

  // ── Assinatura ─────────────────────────────────────────────────────────────

  void _alterarAssinatura(StatusAssinatura novo) async {
    final anterior = _statusAssinatura;
    if (novo == anterior) return;
    // Atualização otimista: a seleção visual muda na hora.
    setState(() => _statusAssinatura = novo);
    try {
      await _fs.atualizarStatusAssinatura(widget.contrato.localizador, novo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Formalização atualizada: ${novo.label}')),
        );
      }
    } catch (e) {
      // Falhou ao gravar: reverte a seleção e avisa.
      if (mounted) {
        setState(() => _statusAssinatura = anterior);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível salvar a formalização.')),
        );
      }
    }
  }

  // ── Upgrade (meta de captação de upgrade do pós-venda) ──────────────────────

  void _ofereceuUpgrade() async {
    await _fs.registrarUpgradeOferecido(widget.contrato.localizador);
    if (!mounted) return;
    setState(() => _upgradeOferecido = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Upgrade marcado como oferecido.')),
    );
  }

  void _fezUpgrade() async {
    await _fs.registrarUpgradeRealizado(widget.contrato.localizador);
    if (!mounted) return;
    setState(() {
      _upgradeRealizado = true;
      _upgradeOferecido = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Upgrade marcado como realizado! 🎉')),
    );
  }

  // ── Interações ─────────────────────────────────────────────────────────────

  void _novaInteracao() {
    InteracaoFormDialog.show(
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
  final StatusAssinatura statusAssinatura;
  final ValueChanged<StatusAssinatura> onAssinaturaAlterada;
  final bool upgradeOferecido;
  final bool upgradeRealizado;
  final VoidCallback onOfereceuUpgrade;
  final VoidCallback onFezUpgrade;
  final String? linkPdf;
  final VoidCallback onAbrirPdf;
  final VoidCallback onEditarLinkPdf;

  const _DadosTab({
    required this.contrato,
    required this.isAdmin,
    required this.statusAssinatura,
    required this.onAssinaturaAlterada,
    required this.upgradeOferecido,
    required this.upgradeRealizado,
    required this.onOfereceuUpgrade,
    required this.onFezUpgrade,
    required this.linkPdf,
    required this.onAbrirPdf,
    required this.onEditarLinkPdf,
  });

  @override
  Widget build(BuildContext context) {
    final c = contrato;
    final fmtMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final fmtData = DateFormat('dd/MM/yyyy');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Alerta de reajuste pendente (correção no sistema de origem).
        if (c.precisaReajuste)
          Card(
            color: Colors.orange.shade50,
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Contrato precisa de reajuste',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        if (c.motivoReajuste != null &&
                            c.motivoReajuste!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(c.motivoReajuste!),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Formalização (ticket #54): 8 categorias em 3 grupos.
        _secao('Formalização', [
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final g in GrupoFormalizacao.values) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Text(
                        g.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _corGrupo(g),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in StatusAssinatura.values
                            .where((s) => s.grupo == g))
                          Builder(builder: (_) {
                            final cor = _corGrupo(g);
                            final selecionado = statusAssinatura == s;
                            // Cores explícitas garantem contraste no dark mode
                            // (chips default ficavam pretos/ilegíveis).
                            return ChoiceChip(
                              label: Text(
                                s.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: selecionado ? Colors.white : cor,
                                  fontWeight: selecionado
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                              selected: selecionado,
                              showCheckmark: false,
                              backgroundColor: cor.withValues(alpha: 0.14),
                              selectedColor: cor,
                              side: BorderSide(
                                  color: cor.withValues(alpha: 0.5)),
                              onSelected: (_) => onAssinaturaAlterada(s),
                            );
                          }),
                      ],
                    ),
                  ],
                ],
              ),
            )
          else
            _campo('Status de formalização', statusAssinatura.label),
        ]),
        const SizedBox(height: 8),

        // Contrato em PDF (Google Drive)
        _secao('Contrato (PDF)', [
          if (linkPdf != null && linkPdf!.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onAbrirPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Abrir contrato'),
                  ),
                ),
                if (isAdmin)
                  IconButton(
                    tooltip: 'Editar link',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: onEditarLinkPdf,
                  ),
              ],
            )
          else if (isAdmin)
            OutlinedButton.icon(
              onPressed: onEditarLinkPdf,
              icon: const Icon(Icons.add_link, size: 18),
              label: const Text('Adicionar link do PDF'),
            )
          else
            _campo('Contrato', 'Nenhum PDF vinculado'),
        ]),
        const SizedBox(height: 8),

        // Upgrade (registro para a meta de captação de upgrade do pós-venda)
        if (isAdmin) ...[
          _secao('Upgrade', [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: upgradeOferecido ? null : onOfereceuUpgrade,
                    icon: Icon(
                        upgradeOferecido
                            ? Icons.check
                            : Icons.local_offer_outlined,
                        size: 16),
                    label: Text(
                        upgradeOferecido ? 'Oferecido' : 'Ofereci upgrade',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: upgradeRealizado ? null : onFezUpgrade,
                    icon: Icon(
                        upgradeRealizado
                            ? Icons.check_circle
                            : Icons.upgrade,
                        size: 16),
                    label: Text(
                        upgradeRealizado ? 'Realizado' : 'Fez upgrade',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ]),
          const SizedBox(height: 8),
        ],

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
                      '${c.percentualEfetivo.toStringAsFixed(1)}% integralizado',
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
                    value: (c.percentualEfetivo / 100).clamp(0.0, 1.0),
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
          if (c.telefoneComprador.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => abrirWhatsAppERegistrarInteracao(
                  context,
                  contratoId: c.localizador,
                  telefone: c.telefoneComprador,
                  nomeContato: c.nomeComprador,
                  esposaContato: c.nomeComprador2,
                ),
                icon: const Icon(Icons.chat_rounded,
                    color: Color(0xFF25D366), size: 18),
                label: const Text('WhatsApp'),
              ),
            ),
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
            if (c.telefoneComprador2 != null &&
                c.telefoneComprador2!.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => abrirWhatsAppERegistrarInteracao(
                    context,
                    contratoId: c.localizador,
                    telefone: c.telefoneComprador2!,
                    nomeContato: c.nomeComprador2,
                  ),
                  icon: const Icon(Icons.chat_rounded,
                      color: Color(0xFF25D366), size: 18),
                  label: const Text('WhatsApp'),
                ),
              ),
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
          if (c.codigoContrato != null && c.codigoContrato!.isNotEmpty)
            _campo('Nº do contrato', c.codigoContrato!),
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

  Color _corGrupo(GrupoFormalizacao g) {
    switch (g) {
      case GrupoFormalizacao.formalizado:
        return Colors.green.shade700;
      case GrupoFormalizacao.emAndamento:
        return Colors.orange.shade700;
      case GrupoFormalizacao.pendente:
        return Colors.grey.shade600;
    }
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
