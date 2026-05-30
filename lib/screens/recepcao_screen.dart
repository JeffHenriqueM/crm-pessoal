// lib/screens/recepcao_screen.dart
//
// Fluxo: Recepção cria Atendimento (fase=atendimento) → aparece na lista.
// Quando o vendedor completar e mudar a fase → vira lead nos streams normais.

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

// ── Máscara de telefone (XX) XXXXX-XXXX ─────────────────────────────────────
class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
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

// ── Shell da recepção (perfil recepcao — tem próprio AppBar + Sair) ──────────
class RecepcaoShell extends StatefulWidget {
  final String? currentUserId;
  const RecepcaoShell({super.key, this.currentUserId});

  @override
  State<RecepcaoShell> createState() => _RecepcaoShellState();
}

class _RecepcaoShellState extends State<RecepcaoShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(children: [
          Image.asset('assets/images/logo.png',
              height: 28, filterQuality: FilterQuality.medium),
          const SizedBox(width: 10),
          const Text('Recepção — Villamor'),
        ]),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.logout_outlined,
                size: 18, color: cs.onSurfaceVariant),
            label: Text('Sair',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            onPressed: () => AuthService().signOut(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          const RecepcaoScreen(),
          _FunilRecepcaoTab(currentUserId: widget.currentUserId),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.badge_outlined),
            selectedIcon: Icon(Icons.badge),
            label: 'Atendimentos',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_kanban_outlined),
            selectedIcon: Icon(Icons.view_kanban),
            label: 'Funil',
          ),
        ],
      ),
    );
  }
}

// ── Tab de funil para recepcionista ─────────────────────────────────────────
class _FunilRecepcaoTab extends StatelessWidget {
  final String? currentUserId;
  const _FunilRecepcaoTab({this.currentUserId});

  static final _dataFmt = DateFormat('dd/MM/yyyy');

  Color _corFase(FaseCliente fase) {
    switch (fase) {
      case FaseCliente.prospeccao:  return const Color(0xFF6366F1);
      case FaseCliente.contato:     return const Color(0xFF0EA5E9);
      case FaseCliente.negociacao:  return const Color(0xFFF59E0B);
      case FaseCliente.visita:      return const Color(0xFF8B5CF6);
      case FaseCliente.fechado:     return const Color(0xFF10B981);
      case FaseCliente.perdido:     return const Color(0xFFEF4444);
      default:                      return const Color(0xFF9CA3AF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<Cliente>>(
      stream: service.getFunilRecepcaoStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          debugPrint('[FunilRecepcao] erro: ${snap.error}');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Erro ao carregar leads: ${snap.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.error, fontSize: 13)),
            ),
          );
        }
        final leads = snap.data ?? [];

        if (leads.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.view_kanban_outlined,
                  size: 56, color: cs.outline.withValues(alpha: 0.35)),
              const SizedBox(height: 14),
              Text('Nenhum lead no funil ainda.',
                  style: TextStyle(color: cs.outline, fontSize: 14)),
            ]),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          itemCount: leads.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, i) {
            final c = leads[i];
            final cor = _corFase(c.fase);
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: cs.outlineVariant),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        FichaClienteScreen(cliente: c, userProfile: 'recepcao'),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: cor.withValues(alpha: 0.15),
                      child: Text(
                        c.nome.isNotEmpty ? c.nome[0].toUpperCase() : '?',
                        style: TextStyle(
                            color: cor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
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
                        if (c.vendedorNome?.isNotEmpty == true)
                          Text('Vendedor: ${c.vendedorNome}',
                              style: TextStyle(
                                  fontSize: 12, color: cs.onSurfaceVariant)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: cor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(c.fase.nomeDisplay,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: cor)),
                      ),
                      const SizedBox(height: 4),
                      Text(_dataFmt.format(c.dataAtualizacao),
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant)),
                    ]),
                  ]),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Lista de atendimentos + FAB "Novo Atendimento" ───────────────────────────
class RecepcaoScreen extends StatelessWidget {
  const RecepcaoScreen({super.key});

  static final _horaFmt = DateFormat('HH:mm');
  static final _dataFmt = DateFormat('dd/MM/yyyy');

  String _cabecalhoData(DateTime dt) {
    final hoje = DateTime.now();
    final ontem = hoje.subtract(const Duration(days: 1));
    if (_dataFmt.format(dt) == _dataFmt.format(hoje)) return 'HOJE';
    if (_dataFmt.format(dt) == _dataFmt.format(ontem)) return 'ONTEM';
    return _dataFmt.format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<Cliente>>(
      stream: service.getClientesRecepcaoStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final atendimentos = snap.data ?? [];
        final hoje = atendimentos
            .where((c) => _dataFmt.format(c.dataEntradaSala ?? c.dataCadastro) ==
                _dataFmt.format(DateTime.now()))
            .length;

        return Scaffold(
          body: Column(children: [
            // ── Cabeçalho com contagem do dia ─────────────────────────────
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              child: Row(children: [
                Icon(Icons.calendar_today_outlined,
                    size: 15, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  'Hoje: $hoje atendimento${hoje != 1 ? 's' : ''}',
                  style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Text(
                  'Total: ${atendimentos.length}',
                  style:
                      TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ]),
            ),

            // ── Lista ──────────────────────────────────────────────────────
            Expanded(
              child: atendimentos.isEmpty
                  ? Center(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        Icon(Icons.badge_outlined,
                            size: 56,
                            color: cs.outline.withValues(alpha: 0.35)),
                        const SizedBox(height: 14),
                        Text('Nenhum atendimento registrado.',
                            style: TextStyle(
                                color: cs.outline, fontSize: 14)),
                        const SizedBox(height: 6),
                        Text('Toque em "Novo Atendimento" para começar.',
                            style: TextStyle(
                                color: cs.onSurfaceVariant, fontSize: 12)),
                      ]))
                  : _buildLista(context, atendimentos, cs),
            ),
          ]),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _abrirNovoAtendimento(context, service),
            icon: const Icon(Icons.add),
            label: const Text('Novo Atendimento'),
          ),
        );
      },
    );
  }

  Widget _buildLista(
      BuildContext context, List<Cliente> atendimentos, ColorScheme cs) {
    // Agrupa por data
    String? ultimaData;
    final itens = <Widget>[];

    for (final c in atendimentos) {
      final dt = c.dataEntradaSala ?? c.dataCadastro;
      final dataStr = _cabecalhoData(dt);
      if (dataStr != ultimaData) {
        ultimaData = dataStr;
        itens.add(_DateHeader(label: dataStr));
      }
      itens.add(_AtendimentoCard(
        cliente: c,
        horaFmt: _horaFmt,
        onTap: () async {
          final salvo = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    FichaClienteScreen(cliente: c, userProfile: 'recepcao')),
          );
          if (salvo == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Atendimento atualizado!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        onReimprimir: () => _reimprimir(c),
      ));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      children: itens,
    );
  }

  void _abrirNovoAtendimento(
      BuildContext context, FirestoreService service) async {
    final resultado = await Navigator.push<FichaAtendimentoData>(
      context,
      MaterialPageRoute(
          builder: (_) => const _RegistrarAtendimentoScreen()),
    );
    if (resultado != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Atendimento Nº ${resultado.numeroAtendimento.toString().padLeft(6, '0')} registrado!'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Reimprimir',
          textColor: Colors.white,
          onPressed: () => FichaAtendimentoPdf.gerar(resultado),
        ),
      ));
    }
  }

  void _reimprimir(Cliente c) {
    FichaAtendimentoPdf.gerar(FichaAtendimentoData(
      nome: c.nome,
      idade: c.idade,
      profissao: c.profissao,
      telefone: c.telefoneContato,
      conjuge: c.nomeEsposa,
      idadeConjuge: c.idadeConjuge,
      profissaoConjuge: c.profissaoConjuge,
      telefoneConjuge: c.telefone2,
      brinde: c.brinde,
      captadorNome: c.captadorNome,
      linerNome: c.linerNome,
      vendedorNome: c.vendedorNome,
      sala: c.sala ?? 'Villa',
      pontoCapatcao: c.origem,
      numeroAtendimento: c.numeroAtendimento ?? 0,
      dataEntrada: c.dataEntradaSala ?? c.dataCadastro,
    ));
  }
}

// ── Cabeçalho de data na lista ───────────────────────────────────────────────
class _DateHeader extends StatelessWidget {
  final String label;
  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: cs.onPrimaryContainer)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: cs.outlineVariant, height: 1)),
      ]),
    );
  }
}

// ── Card de atendimento ───────────────────────────────────────────────────────
class _AtendimentoCard extends StatelessWidget {
  final Cliente cliente;
  final DateFormat horaFmt;
  final VoidCallback onTap;
  final VoidCallback onReimprimir;

  const _AtendimentoCard({
    required this.cliente,
    required this.horaFmt,
    required this.onTap,
    required this.onReimprimir,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = cliente;
    final dt = c.dataEntradaSala ?? c.dataCadastro;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Avatar com inicial
            CircleAvatar(
              radius: 24,
              backgroundColor: cs.primaryContainer,
              child: Text(
                c.nome.isNotEmpty ? c.nome[0].toUpperCase() : '?',
                style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),

            // Dados principais
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(c.nome,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                if (c.nomeEsposa?.isNotEmpty == true)
                  Text('+ ${c.nomeEsposa}',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  if (c.sala?.isNotEmpty == true)
                    _chip(cs, Icons.villa_outlined, c.sala!),
                  if (c.brinde?.isNotEmpty == true)
                    _chip(cs, Icons.card_giftcard_outlined, c.brinde!),
                  if (c.linerNome?.isNotEmpty == true)
                    _chip(cs, Icons.record_voice_over_outlined,
                        c.linerNome!),
                ]),
              ]),
            ),

            // Número + hora + botão reimprimir
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (c.numeroAtendimento != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '#${c.numeroAtendimento!.toString().padLeft(6, '0')}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cs.onPrimaryContainer),
                  ),
                ),
              const SizedBox(height: 4),
              Text(horaFmt.format(dt),
                  style:
                      TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              InkWell(
                onTap: onReimprimir,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.print_outlined,
                      size: 18, color: cs.onSurfaceVariant),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _chip(ColorScheme cs, IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: cs.onSurfaceVariant),
          const SizedBox(width: 3),
          Text(label,
              style:
                  TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
      );
}

// ── Tela de registro (pushed via Navigator) ───────────────────────────────────
class _RegistrarAtendimentoScreen extends StatefulWidget {
  const _RegistrarAtendimentoScreen();

  @override
  State<_RegistrarAtendimentoScreen> createState() =>
      _RegistrarAtendimentoScreenState();
}

class _RegistrarAtendimentoScreenState
    extends State<_RegistrarAtendimentoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = FirestoreService();

  // Titular
  final _nomeCtrl = TextEditingController();
  final _idadeCtrl = TextEditingController();
  final _profissaoCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();

  // Cônjuge
  final _conjugeCtrl = TextEditingController();
  final _idadeConjugeCtrl = TextEditingController();
  final _profissaoConjugeCtrl = TextEditingController();
  final _telefoneConjugeCtrl = TextEditingController();

  // Geral
  final _pontoCapCtrl = TextEditingController(text: 'Presencial');

  String _sala = 'Villa';
  String? _brinde;
  Usuario? _captador;
  Usuario? _liner; // Vendedor atribuído na recepção

  List<Usuario> _usuarios = [];
  bool _carregandoUsuarios = true;
  bool _salvando = false;

  static const _salas = ['Villa', 'Online'];
  static const _brindes = [
    'Dream Vacation',
    'Day Use',
    'Drinks',
    'Calcinha'
  ];

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
      final lista = await _service.getTodosUsuarios();
      if (mounted) {
        setState(() {
          const perfisValidos = [
            'captador', 'vendedor', 'admin', 'super admin'
          ];
          _usuarios = lista
              .where(
                  (u) => u.ativo && perfisValidos.contains(u.perfil))
              .toList()
            ..sort((a, b) => a.nome.compareTo(b.nome));
          _carregandoUsuarios = false;
        });
      }
    } catch (e) {
      debugPrint('[Recepção] Erro ao carregar usuários: $e');
      if (mounted) setState(() => _carregandoUsuarios = false);
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    try {
      final agora = DateTime.now();
      final numero = await _service.proximoNumeroAtendimento();

      final cliente = Cliente(
        nome: _nomeCtrl.text.trim(),
        tipo: 'Casal',
        fase: FaseCliente.atendimento, // ← pré-lead, só aparece na recepção
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
        sala: _sala,
        origem: _pontoCapCtrl.text.trim().isEmpty
            ? null
            : _pontoCapCtrl.text.trim(),
        captadorId: _captador?.id,
        captadorNome: _captador?.nome,
        linerId: _liner?.id,
        linerNome: _liner?.nome,
        vendedorId: _liner?.id,   // pré-associa o vendedor para aparecer no funil
        vendedorNome: _liner?.nome,
        numeroAtendimento: numero,
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
        numeroAtendimento: numero,
        dataEntrada: agora,
      );

      await FichaAtendimentoPdf.gerar(fichaData);

      if (mounted) {
        // Volta para a lista passando fichaData para o snackbar de reimprimir
        Navigator.of(context).pop(fichaData);
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Atendimento'),
        leading: const BackButton(),
      ),
      body: SingleChildScrollView(
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
                  // ── Entrada ─────────────────────────────────────────────
                  _card(cs,
                      icon: Icons.meeting_room_outlined,
                      title: 'Entrada',
                      children: [
                        Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                          SizedBox(
                            width: 150,
                            child: DropdownButtonFormField<String>(
                              value: _sala,
                              decoration: const InputDecoration(
                                labelText: 'Sala',
                                prefixIcon:
                                    Icon(Icons.villa_outlined),
                              ),
                              items: _salas
                                  .map((s) => DropdownMenuItem(
                                      value: s, child: Text(s)))
                                  .toList(),
                              onChanged: (v) {
                                final novaSala = v ?? _sala;
                                setState(() {
                                  final autoAtual = _sala == 'Villa'
                                      ? 'Presencial'
                                      : 'WhatsApp';
                                  final autoNovo =
                                      novaSala == 'Villa'
                                          ? 'Presencial'
                                          : 'WhatsApp';
                                  if (_pontoCapCtrl.text.isEmpty ||
                                      _pontoCapCtrl.text ==
                                          autoAtual) {
                                    _pontoCapCtrl.text = autoNovo;
                                  }
                                  _sala = novaSala;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _pontoCapCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Ponto de Captação',
                                prefixIcon:
                                    Icon(Icons.location_on_outlined),
                              ),
                              textCapitalization:
                                  TextCapitalization.words,
                            ),
                          ),
                        ]),
                      ]),
                  const SizedBox(height: 16),

                  // ── Titular ──────────────────────────────────────────────
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
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _idadeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Idade',
                                hintText: 'anos',
                                contentPadding:
                                    EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 14),
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
                                prefixIcon:
                                    Icon(Icons.work_outline),
                              ),
                              textCapitalization:
                                  TextCapitalization.words,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _telefoneCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Telefone',
                            prefixIcon: Icon(Icons.phone_outlined),
                            hintText: '(XX) XXXXX-XXXX',
                          ),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [_PhoneFormatter()],
                        ),
                      ]),
                  const SizedBox(height: 16),

                  // ── Cônjuge ──────────────────────────────────────────────
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
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _idadeConjugeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Idade',
                                hintText: 'anos',
                                contentPadding:
                                    EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 14),
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
                                prefixIcon:
                                    Icon(Icons.work_outline),
                              ),
                              textCapitalization:
                                  TextCapitalization.words,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _telefoneConjugeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Telefone',
                            prefixIcon: Icon(Icons.phone_outlined),
                            hintText: '(XX) XXXXX-XXXX',
                          ),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [_PhoneFormatter()],
                        ),
                      ]),
                  const SizedBox(height: 16),

                  // ── Equipe ───────────────────────────────────────────────
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
                              prefixIcon:
                                  Icon(Icons.person_pin_outlined),
                            ),
                            hint: const Text('Selecione'),
                            items: _usuarios
                                .map((u) => DropdownMenuItem(
                                    value: u, child: Text(u.nome)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _captador = v),
                            validator: (v) => v == null
                                ? 'Selecione o captador'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<Usuario>(
                            value: _liner,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Vendedor *',
                              prefixIcon: Icon(
                                  Icons.record_voice_over_outlined),
                            ),
                            hint: const Text('Selecione'),
                            items: _usuarios
                                .map((u) => DropdownMenuItem(
                                    value: u, child: Text(u.nome)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _liner = v),
                            validator: (v) => v == null
                                ? 'Selecione o vendedor'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            value: _brinde,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Brinde',
                              prefixIcon:
                                  Icon(Icons.card_giftcard_outlined),
                            ),
                            hint: const Text('Selecione o brinde'),
                            items: _brindes
                                .map((b) => DropdownMenuItem(
                                    value: b, child: Text(b)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _brinde = v),
                          ),
                        ],
                      ]),
                  const SizedBox(height: 28),

                  // ── Botão salvar ─────────────────────────────────────────
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
                                  color: cs.onPrimary))
                          : const Icon(Icons.print_outlined),
                      label: Text(
                        _salvando
                            ? 'Registrando...'
                            : 'Registrar e Imprimir Ficha',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(ColorScheme cs,
      {required IconData icon,
      required String title,
      required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        ]),
      ),
    );
  }
}
