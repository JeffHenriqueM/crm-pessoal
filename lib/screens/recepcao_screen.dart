// lib/screens/recepcao_screen.dart
//
// Fluxo: Recepção registra atendimento (fase=atendimento) inline na aba "Registrar".
// Aba "Meus Leads" mostra todos os atendimentos criados pela recepcionista.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../models/usuario_model.dart';
import '../services/ficha_pdf.dart';
import '../services/firestore_service.dart';
import '../widgets/contatos_embaixador_tab.dart';
import 'ficha_cliente_screen.dart';

// ── Máscara de telefone ───────────────────────────────────────────────────────
// Internacional (começa com +): permite +CC e até 15 dígitos (E.164), sem máscara.
// Brasileiro: aplica (XX) XXXXX-XXXX com limite de 11 dígitos.
class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;

    if (raw.startsWith('+')) {
      final digits = raw.substring(1).replaceAll(RegExp(r'\D'), '');
      final s = '+$digits';
      // E.164 permite até 15 dígitos após o +
      final limited = s.length > 16 ? s.substring(0, 16) : s;
      return TextEditingValue(
        text: limited,
        selection: TextSelection.collapsed(offset: limited.length),
      );
    }

    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length && i < 11; i++) {
      if (i == 0) buf.write('(');
      if (i == 2) buf.write(') ');
      if (i == 7) buf.write('-');
      buf.write(digits[i]);
    }
    final s = buf.toString();
    return TextEditingValue(
      text: s,
      selection: TextSelection.collapsed(offset: s.length),
    );
  }
}

// ── Shell da recepção (app bar + 2 abas) ────────────────────────────────────
class RecepcaoShell extends StatelessWidget {
  final String? currentUserId;
  const RecepcaoShell({super.key, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Recepção'),
          toolbarHeight: 50,
          bottom: TabBar(
            tabs: const [
              Tab(icon: Icon(Icons.add_circle_outline), text: 'Registrar'),
              Tab(icon: Icon(Icons.people_outline), text: 'Meus Leads'),
              Tab(icon: Icon(Icons.contacts_outlined), text: 'Contatos'),
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
            ContatosEmbaixadorTab(),
          ],
        ),
      ),
    );
  }
}

// ── Formulário de registro ───────────────────────────────────────────────────
class RecepcaoScreen extends StatefulWidget {
  const RecepcaoScreen({super.key});

  @override
  State<RecepcaoScreen> createState() => _RecepcaoScreenState();
}

class _RecepcaoScreenState extends State<RecepcaoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = FirestoreService();

  // Titular
  final _nomeCtrl        = TextEditingController();
  final _idadeCtrl       = TextEditingController();
  final _profissaoCtrl   = TextEditingController();
  final _telefoneCtrl    = TextEditingController();

  // Cônjuge
  final _conjugeCtrl          = TextEditingController();
  final _idadeConjugeCtrl     = TextEditingController();
  final _profissaoConjugeCtrl = TextEditingController();
  final _telefoneConjugeCtrl  = TextEditingController();

  // Observação livre sobre o cliente (#53)
  final _observacaoCtrl       = TextEditingController();

  // Geral
  String   _pontoCap = 'Presencial';
  String   _sala     = 'Villa';
  String?  _brinde;
  Usuario? _captador;
  Usuario? _liner;

  List<Usuario> _usuarios          = [];
  bool          _carregandoUsuarios = true;
  bool          _salvando           = false;

  FichaAtendimentoData? _ultimaFicha;

  static const _salas   = ['Villa', 'Online'];
  static const _origens = ['Presencial', 'WhatsApp', 'Instagram'];
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
      _telefoneConjugeCtrl, _observacaoCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _carregarUsuarios() async {
    try {
      final lista = await _service.getTodosUsuarios();
      if (mounted) {
        setState(() {
          _usuarios = lista
              .where((u) => u.ativo &&
                  ['captador', 'vendedor', 'admin', 'super admin']
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

  Future<void> _salvar({bool imprimir = true}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    try {
      final agora = DateTime.now();
      final numeroAtendimento = await _service.proximoNumeroAtendimento();

      final cliente = Cliente(
        nome: _nomeCtrl.text.trim(),
        tipo: 'Casal',
        fase: FaseCliente.atendimento,
        idade: _idadeCtrl.text.trim().isEmpty ? null : _idadeCtrl.text.trim(),
        profissao: _profissaoCtrl.text.trim().isEmpty
            ? null
            : _profissaoCtrl.text.trim(),
        telefoneContato: _telefoneCtrl.text.trim().isEmpty
            ? null
            : _telefoneCtrl.text.trim(),
        nomeEsposa: _conjugeCtrl.text.trim().isEmpty
            ? null
            : _conjugeCtrl.text.trim(),
        idadeConjuge: _idadeConjugeCtrl.text.trim().isEmpty
            ? null
            : _idadeConjugeCtrl.text.trim(),
        profissaoConjuge: _profissaoConjugeCtrl.text.trim().isEmpty
            ? null
            : _profissaoConjugeCtrl.text.trim(),
        telefone2: _telefoneConjugeCtrl.text.trim().isEmpty
            ? null
            : _telefoneConjugeCtrl.text.trim(),
        brinde: _brinde,
        observacao: _observacaoCtrl.text.trim().isEmpty
            ? null
            : _observacaoCtrl.text.trim(),
        sala: _sala,
        origem: _pontoCap,
        captadorId: _captador?.id,
        captadorNome: _captador?.nome,
        linerId: _liner?.id,
        linerNome: _liner?.nome,
        vendedorId: _liner?.id,
        vendedorNome: _liner?.nome,
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
        linerNome: cliente.linerNome,
        vendedorNome: cliente.vendedorNome,
        sala: _sala,
        pontoCapatcao: cliente.origem,
        numeroAtendimento: numeroAtendimento,
        dataEntrada: agora,
      );

      if (imprimir) await FichaAtendimentoPdf.gerar(fichaData);

      if (mounted) {
        setState(() {
          _ultimaFicha = fichaData;
          _salvando = false;
          _limparForm();
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Atendimento Nº ${numeroAtendimento.toString().padLeft(6, '0')} registrado!',
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Imprimir',
            textColor: Colors.white,
            onPressed: () => FichaAtendimentoPdf.gerar(fichaData),
          ),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    }
  }

  void _limparForm() {
    for (final c in [
      _nomeCtrl, _idadeCtrl, _profissaoCtrl, _telefoneCtrl,
      _conjugeCtrl, _idadeConjugeCtrl, _profissaoConjugeCtrl,
      _telefoneConjugeCtrl, _observacaoCtrl,
    ]) {
      c.clear();
    }
    _captador = null;
    _liner = null;
    _brinde = null;
    _sala = 'Villa';
    _pontoCap = 'Presencial';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width > 700;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 80 : 16, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Entrada ───────────────────────────────────────────────
                _card(cs,
                    icon: Icons.meeting_room_outlined,
                    title: 'Entrada',
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        SizedBox(
                          width: 150,
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
                            onChanged: (v) {
                              final novaSala = v ?? _sala;
                              setState(() {
                                final autoAtual =
                                    _sala == 'Villa' ? 'Presencial' : 'WhatsApp';
                                final autoNovo =
                                    novaSala == 'Villa' ? 'Presencial' : 'WhatsApp';
                                if (_pontoCap == autoAtual) _pontoCap = autoNovo;
                                _sala = novaSala;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _pontoCap,
                            decoration: const InputDecoration(
                              labelText: 'Ponto de Captação',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                            items: _origens
                                .map((o) => DropdownMenuItem(
                                    value: o, child: Text(o)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _pontoCap = v);
                            },
                          ),
                        ),
                      ]),
                    ]),
                const SizedBox(height: 16),

                // ── Titular ───────────────────────────────────────────────
                _card(cs,
                    icon: Icons.person_outlined,
                    title: 'Titular',
                    children: [
                      TextFormField(
                        controller: _nomeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome *',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Informe o nome'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _idadeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Idade',
                              hintText: 'anos',
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 5,
                          child: TextFormField(
                            controller: _profissaoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Profissão',
                              prefixIcon: Icon(Icons.work_outline),
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _telefoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Telefone',
                          prefixIcon: Icon(Icons.phone_outlined),
                          hintText: '(XX) XXXXX-XXXX ou +55 11 99999-9999',
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [_PhoneFormatter()],
                      ),
                    ]),
                const SizedBox(height: 16),

                // ── Cônjuge ───────────────────────────────────────────────
                _card(cs,
                    icon: Icons.favorite_outline,
                    title: 'Cônjuge',
                    children: [
                      TextFormField(
                        controller: _conjugeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 12),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _idadeConjugeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Idade',
                              hintText: 'anos',
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 5,
                          child: TextFormField(
                            controller: _profissaoConjugeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Profissão',
                              prefixIcon: Icon(Icons.work_outline),
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _telefoneConjugeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Telefone',
                          prefixIcon: Icon(Icons.phone_outlined),
                          hintText: '(XX) XXXXX-XXXX ou +55 11 99999-9999',
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [_PhoneFormatter()],
                      ),
                    ]),
                const SizedBox(height: 16),

                // ── Equipe ────────────────────────────────────────────────
                _card(cs,
                    icon: Icons.groups_outlined,
                    title: 'Equipe',
                    children: [
                      if (_carregandoUsuarios)
                        const LinearProgressIndicator()
                      else ...[
                        DropdownButtonFormField<Usuario>(
                          value: _captador,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Captador *',
                            prefixIcon: Icon(Icons.person_pin_outlined),
                          ),
                          hint: const Text('Selecione'),
                          items: _usuarios
                              .map((u) => DropdownMenuItem(
                                  value: u, child: Text(u.nome)))
                              .toList(),
                          onChanged: (v) => setState(() => _captador = v),
                          validator: (v) =>
                              v == null ? 'Selecione o captador' : null,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<Usuario>(
                          value: _liner,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Vendedor *',
                            prefixIcon: Icon(Icons.record_voice_over_outlined),
                          ),
                          hint: const Text('Selecione'),
                          items: _usuarios
                              .map((u) => DropdownMenuItem(
                                  value: u, child: Text(u.nome)))
                              .toList(),
                          onChanged: (v) => setState(() => _liner = v),
                          validator: (v) =>
                              v == null ? 'Selecione o vendedor' : null,
                        ),
                        const SizedBox(height: 14),
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
                    ]),
                const SizedBox(height: 16),

                // ── Observação ────────────────────────────────────────────
                _card(cs,
                    icon: Icons.sticky_note_2_outlined,
                    title: 'Observação',
                    children: [
                      TextFormField(
                        controller: _observacaoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Observação sobre o cliente (opcional)',
                          prefixIcon: Icon(Icons.notes_outlined),
                          alignLabelWithHint: true,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                        minLines: 2,
                        maxLines: 5,
                      ),
                    ]),
                const SizedBox(height: 28),

                // ── Botões salvar ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _salvando ? null : () => _salvar(imprimir: true),
                    icon: _salvando
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: cs.onPrimary))
                        : const Icon(Icons.print_outlined),
                    label: Text(
                      _salvando ? 'Registrando...' : 'Registrar e Imprimir Ficha',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _salvando ? null : () => _salvar(imprimir: false),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text(
                      'Salvar sem Imprimir',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ),

                if (_ultimaFicha != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => FichaAtendimentoPdf.gerar(_ultimaFicha!),
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

  Widget _card(
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
            Row(children: [
              Icon(icon, color: cs.primary, size: 20),
              const SizedBox(width: 10),
              Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface)),
            ]),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ── Aba "Meus Leads" ─────────────────────────────────────────────────────────
class _RecepcaoLeadsTab extends StatefulWidget {
  const _RecepcaoLeadsTab();

  @override
  State<_RecepcaoLeadsTab> createState() => _RecepcaoLeadsTabState();
}

class _RecepcaoLeadsTabState extends State<_RecepcaoLeadsTab> {
  final _service    = FirestoreService();
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

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Buscar por nome...',
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            suffixIcon: _busca.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _searchCtrl.clear)
                : null,
          ),
        ),
      ),
      Expanded(
        child: StreamBuilder<List<Cliente>>(
          stream: _service.getClientesRecepcaoStream(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            var leads = snap.data ?? [];
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
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.people_outline,
                    size: 52,
                    color: cs.outline.withValues(alpha: 0.4)),
                const SizedBox(height: 14),
                Text(
                  _busca.isNotEmpty
                      ? 'Nenhum resultado para "$_busca"'
                      : 'Nenhum lead registrado ainda.',
                  style: TextStyle(color: cs.outline, fontSize: 14),
                ),
              ]));
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
                            cliente: c, userProfile: 'recepcao'),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: cs.primaryContainer,
                          child: Text(
                            c.nome.isNotEmpty ? c.nome[0].toUpperCase() : '?',
                            style: TextStyle(
                                color: cs.onPrimaryContainer,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(c.nome,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            if (c.nomeEsposa?.isNotEmpty == true)
                              Text('+ ${c.nomeEsposa}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant)),
                            const SizedBox(height: 4),
                            Row(children: [
                              if (c.telefoneContato?.isNotEmpty == true) ...[
                                Icon(Icons.phone_outlined,
                                    size: 12, color: cs.onSurfaceVariant),
                                const SizedBox(width: 3),
                                Text(c.telefoneContato!,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurfaceVariant)),
                                const SizedBox(width: 10),
                              ],
                              if (c.sala?.isNotEmpty == true) ...[
                                Icon(Icons.meeting_room_outlined,
                                    size: 12, color: cs.onSurfaceVariant),
                                const SizedBox(width: 3),
                                Text(c.sala!,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurfaceVariant)),
                              ],
                            ]),
                          ]),
                        ),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                          if (c.numeroAtendimento != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
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
                            Text(_dataFmt.format(c.dataEntradaSala!),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant)),
                        ]),
                      ]),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}
