// lib/screens/recepcao_screen.dart
//
// Shell + Tela de recepção: cadastro rápido de casal em sala.
// Perfil 'recepcao' cai diretamente nesta tela (sem sidebar CRM).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../models/usuario_model.dart';
import '../services/auth_service.dart';
import '../services/ficha_pdf.dart';
import '../services/firestore_service.dart';
import 'ficha_cliente_screen.dart';

// ── Shell da recepção (app bar + 2 abas) ────────────────────────────────────
class RecepcaoShell extends StatelessWidget {
  final String? currentUserId;
  const RecepcaoShell({super.key, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 28,
                filterQuality: FilterQuality.medium,
              ),
              const SizedBox(width: 10),
              const Text('Recepção — Villamor'),
            ],
          ),
          actions: [
            TextButton.icon(
              icon: Icon(Icons.logout_outlined,
                  size: 18, color: cs.onSurfaceVariant),
              label: Text('Sair',
                  style:
                      TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              onPressed: () => AuthService().signOut(),
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            tabs: const [
              Tab(icon: Icon(Icons.add_circle_outline), text: 'Registrar'),
              Tab(icon: Icon(Icons.people_outline), text: 'Meus Leads'),
            ],
            indicatorColor: cs.primary,
            labelColor: cs.primary,
            unselectedLabelColor: cs.onSurfaceVariant,
          ),
        ),
        body: const TabBarView(
          children: [
            RecepcaoScreen(),
            _RecepcaoLeadsTab(),
          ],
        ),
      ),
    );
  }
}

// ── Tela principal ───────────────────────────────────────────────────────────
class RecepcaoScreen extends StatefulWidget {
  const RecepcaoScreen({super.key});

  @override
  State<RecepcaoScreen> createState() => _RecepcaoScreenState();
}

class _RecepcaoScreenState extends State<RecepcaoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = FirestoreService();

  // Campos — titular
  final _nomeCtrl       = TextEditingController();
  final _idadeCtrl      = TextEditingController();
  final _profissaoCtrl  = TextEditingController();
  final _telefoneCtrl   = TextEditingController();

  // Campos — cônjuge
  final _conjugeCtrl         = TextEditingController();
  final _idadeConjugeCtrl    = TextEditingController();
  final _profissaoConjugeCtrl = TextEditingController();
  final _telefoneConjugeCtrl = TextEditingController();

  // Campos gerais
  final _pontoCapCtrl = TextEditingController();

  String _sala    = 'Villa';
  String? _brinde;
  Usuario? _captador;
  Usuario? _vendedor;
  List<Usuario> _usuarios = [];
  bool _carregandoUsuarios = true;
  bool _salvando = false;

  FichaAtendimentoData? _ultimaFicha;

  static const _salas   = ['Villa', 'Online'];
  static const _brindes = ['Dream Vacation', 'Day Use', 'Drinks', 'Calcinha'];

  @override
  void initState() {
    super.initState();
    _carregarUsuarios();
  }

  @override
  void dispose() {
    for (final c in [
      _nomeCtrl, _idadeCtrl, _profissaoCtrl, _telefoneCtrl,
      _conjugeCtrl, _idadeConjugeCtrl, _profissaoConjugeCtrl,
      _telefoneConjugeCtrl, _pontoCapCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _carregarUsuarios() async {
    try {
      final lista = await _service.getTodosUsuarios(apenasAtivos: true);
      if (mounted) {
        setState(() {
          _usuarios = lista
              .where((u) => ['captador', 'vendedor', 'admin', 'super admin']
                  .contains(u.perfil))
              .toList()
            ..sort((a, b) => a.nome.compareTo(b.nome));
          _carregandoUsuarios = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _carregandoUsuarios = false);
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    try {
      final agora = DateTime.now();
      final numeroAtendimento = await _service.proximoNumeroAtendimento();

      final cliente = Cliente(
        nome: _nomeCtrl.text.trim(),
        tipo: 'Casal',
        fase: FaseCliente.visita,
        idade: _idadeCtrl.text.trim().isEmpty ? null : _idadeCtrl.text.trim(),
        profissao: _profissaoCtrl.text.trim().isEmpty ? null : _profissaoCtrl.text.trim(),
        telefoneContato: _telefoneCtrl.text.trim().isEmpty ? null : _telefoneCtrl.text.trim(),
        nomeEsposa: _conjugeCtrl.text.trim().isEmpty ? null : _conjugeCtrl.text.trim(),
        idadeConjuge: _idadeConjugeCtrl.text.trim().isEmpty ? null : _idadeConjugeCtrl.text.trim(),
        profissaoConjuge: _profissaoConjugeCtrl.text.trim().isEmpty ? null : _profissaoConjugeCtrl.text.trim(),
        telefone2: _telefoneConjugeCtrl.text.trim().isEmpty ? null : _telefoneConjugeCtrl.text.trim(),
        brinde: _brinde,
        sala: _sala,
        origem: _pontoCapCtrl.text.trim().isEmpty ? null : _pontoCapCtrl.text.trim(),
        captadorId: _captador?.id,
        captadorNome: _captador?.nome,
        vendedorId: _vendedor?.id,
        vendedorNome: _vendedor?.nome,
        numeroAtendimento: numeroAtendimento,
        dataEntradaSala: agora,
        dataCadastro: agora,
        dataAtualizacao: agora,
      );

      await _service.adicionarCliente(cliente);

      final fichaData = FichaAtendimentoData(
        nome: cliente.nome,
        idade: cliente.idade,
        profissao: cliente.profissao,
        telefone: cliente.telefoneContato,
        conjuge: cliente.nomeEsposa,
        idadeConjuge: cliente.idadeConjuge,
        profissaoConjuge: cliente.profissaoConjuge,
        telefoneConjuge: cliente.telefone2,
        brinde: cliente.brinde,
        captadorNome: cliente.captadorNome,
        vendedorNome: cliente.vendedorNome,
        sala: _sala,
        pontoCapatcao: cliente.origem,
        numeroAtendimento: numeroAtendimento,
        dataEntrada: agora,
      );

      await FichaAtendimentoPdf.gerar(fichaData);

      if (mounted) {
        setState(() {
          _ultimaFicha = fichaData;
          _salvando = false;
          _nomeCtrl.clear();
          _idadeCtrl.clear();
          _profissaoCtrl.clear();
          _telefoneCtrl.clear();
          _conjugeCtrl.clear();
          _idadeConjugeCtrl.clear();
          _profissaoConjugeCtrl.clear();
          _telefoneConjugeCtrl.clear();
          _pontoCapCtrl.clear();
          _captador = null;
          _vendedor = null;
          _brinde = null;
          _sala = 'Villa';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Atendimento Nº ${numeroAtendimento.toString().padLeft(6, '0')} '
              'registrado! Ficha aberta para impressão.',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Reimprimir',
              textColor: Colors.white,
              onPressed: () => FichaAtendimentoPdf.gerar(fichaData),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width > 700;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 80 : 16,
        vertical: 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Sala / Ponto de Captação ───────────────────────────────
                _sectionCard(
                  cs,
                  icon: Icons.meeting_room_outlined,
                  title: 'Entrada',
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 160,
                          child: DropdownButtonFormField<String>(
                            value: _sala,
                            decoration: const InputDecoration(
                              labelText: 'Sala',
                              prefixIcon: Icon(Icons.villa_outlined),
                            ),
                            items: _salas
                                .map((s) => DropdownMenuItem(
                                    value: s, child: Text(s)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _sala = v ?? _sala),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _pontoCapCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Ponto de Captação',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Titular ────────────────────────────────────────────────
                _sectionCard(
                  cs,
                  icon: Icons.person_outlined,
                  title: 'Titular',
                  children: [
                    TextFormField(
                      controller: _nomeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome *',
                        prefixIcon: Icon(Icons.badge_outlined),
                        hintText: 'Nome completo',
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe o nome'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 100,
                          child: TextFormField(
                            controller: _idadeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Idade',
                              prefixIcon: Icon(Icons.cake_outlined),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _profissaoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Profissão',
                              prefixIcon: Icon(Icons.work_outline),
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _telefoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Telefone *',
                        prefixIcon: Icon(Icons.phone_outlined),
                        hintText: '(XX) XXXXX-XXXX',
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[\d\s()\-+]'))
                      ],
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe o telefone'
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Cônjuge ────────────────────────────────────────────────
                _sectionCard(
                  cs,
                  icon: Icons.favorite_outline,
                  title: 'Cônjuge',
                  children: [
                    TextFormField(
                      controller: _conjugeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        prefixIcon: Icon(Icons.badge_outlined),
                        hintText: 'Nome completo',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 100,
                          child: TextFormField(
                            controller: _idadeConjugeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Idade',
                              prefixIcon: Icon(Icons.cake_outlined),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _profissaoConjugeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Profissão',
                              prefixIcon: Icon(Icons.work_outline),
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _telefoneConjugeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Telefone',
                        prefixIcon: Icon(Icons.phone_outlined),
                        hintText: '(XX) XXXXX-XXXX',
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[\d\s()\-+]'))
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Equipe ─────────────────────────────────────────────────
                _sectionCard(
                  cs,
                  icon: Icons.groups_outlined,
                  title: 'Equipe',
                  children: [
                    if (_carregandoUsuarios)
                      const LinearProgressIndicator()
                    else ...[
                      // Captador
                      DropdownButtonFormField<Usuario>(
                        value: _captador,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Captador *',
                          prefixIcon: Icon(Icons.person_pin_outlined),
                        ),
                        hint: const Text('Selecione o captador'),
                        items: _usuarios
                            .map((u) => DropdownMenuItem(
                                value: u, child: Text(u.nome)))
                            .toList(),
                        onChanged: (v) => setState(() => _captador = v),
                        validator: (v) =>
                            v == null ? 'Selecione o captador' : null,
                      ),
                      const SizedBox(height: 14),

                      // Vendedor
                      DropdownButtonFormField<Usuario>(
                        value: _vendedor,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Vendedor',
                          prefixIcon: Icon(Icons.handshake_outlined),
                        ),
                        hint: const Text('Selecione o vendedor'),
                        items: _usuarios
                            .map((u) => DropdownMenuItem(
                                value: u, child: Text(u.nome)))
                            .toList(),
                        onChanged: (v) => setState(() => _vendedor = v),
                      ),
                      const SizedBox(height: 14),

                      // Brinde
                      DropdownButtonFormField<String>(
                        value: _brinde,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Brinde',
                          prefixIcon: Icon(Icons.card_giftcard_outlined),
                        ),
                        hint: const Text('Selecione o brinde'),
                        items: _brindes
                            .map((b) => DropdownMenuItem(
                                value: b, child: Text(b)))
                            .toList(),
                        onChanged: (v) => setState(() => _brinde = v),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 28),

                // ── Botão salvar ───────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _salvando ? null : _salvar,
                    icon: _salvando
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onPrimary,
                            ),
                          )
                        : const Icon(Icons.print_outlined),
                    label: Text(
                      _salvando
                          ? 'Registrando...'
                          : 'Registrar e Imprimir Ficha',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ),

                // ── Reimprimir último ──────────────────────────────────────
                if (_ultimaFicha != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          FichaAtendimentoPdf.gerar(_ultimaFicha!),
                      icon: const Icon(Icons.replay_outlined, size: 18),
                      label: Text(
                        'Reimprimir última ficha '
                        '(${_ultimaFicha!.nome.split(' ').first})',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helper: card de seção ─────────────────────────────────────────────────
  Widget _sectionCard(
    ColorScheme cs, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: cs.primary, size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ── Aba "Meus Leads" (perfil recepção) ───────────────────────────────────────
class _RecepcaoLeadsTab extends StatefulWidget {
  const _RecepcaoLeadsTab();

  @override
  State<_RecepcaoLeadsTab> createState() => _RecepcaoLeadsTabState();
}

class _RecepcaoLeadsTabState extends State<_RecepcaoLeadsTab> {
  final _service = FirestoreService();
  final _searchCtrl = TextEditingController();
  String _busca = '';

  static final _dataFmt = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _busca = _searchCtrl.text));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Barra de busca
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar por nome...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _busca.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _searchCtrl.clear(),
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),

        // Lista de leads
        Expanded(
          child: StreamBuilder<List<Cliente>>(
            stream: _service.getClientesRecepcaoStream(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Erro: ${snap.error}'));
              }

              var leads = snap.data ?? [];

              // Filtro de busca local
              if (_busca.isNotEmpty) {
                final q = _busca.toLowerCase();
                leads = leads
                    .where((c) =>
                        c.nome.toLowerCase().contains(q) ||
                        (c.nomeEsposa?.toLowerCase().contains(q) ?? false) ||
                        (c.telefoneContato?.contains(q) ?? false))
                    .toList();
              }

              if (leads.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline,
                          size: 52,
                          color:
                              cs.outline.withValues(alpha: 0.4)),
                      const SizedBox(height: 14),
                      Text(
                        _busca.isNotEmpty
                            ? 'Nenhum resultado para "$_busca"'
                            : 'Nenhum lead registrado ainda.',
                        style: TextStyle(color: cs.outline, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                itemCount: leads.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final c = leads[i];
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: cs.outlineVariant),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FichaClienteScreen(
                            cliente: c,
                            userProfile: 'recepcao',
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            // Avatar
                            CircleAvatar(
                              radius: 22,
                              backgroundColor:
                                  cs.primaryContainer,
                              child: Text(
                                c.nome.isNotEmpty
                                    ? c.nome[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                    color: cs.onPrimaryContainer,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Dados
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.nome,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14),
                                  ),
                                  if (c.nomeEsposa?.isNotEmpty == true)
                                    Text(
                                      '+ ${c.nomeEsposa}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant),
                                    ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (c.telefoneContato?.isNotEmpty ==
                                          true) ...[
                                        Icon(Icons.phone_outlined,
                                            size: 12,
                                            color: cs.onSurfaceVariant),
                                        const SizedBox(width: 3),
                                        Text(c.telefoneContato!,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    cs.onSurfaceVariant)),
                                        const SizedBox(width: 10),
                                      ],
                                      if (c.sala?.isNotEmpty == true) ...[
                                        Icon(Icons.meeting_room_outlined,
                                            size: 12,
                                            color: cs.onSurfaceVariant),
                                        const SizedBox(width: 3),
                                        Text(c.sala!,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    cs.onSurfaceVariant)),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Data + atendimento nº
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (c.numeroAtendimento != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: cs.primaryContainer,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '#${c.numeroAtendimento!.toString().padLeft(6, '0')}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onPrimaryContainer,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                if (c.dataEntradaSala != null)
                                  Text(
                                    _dataFmt.format(c.dataEntradaSala!),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: cs.onSurfaceVariant),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
