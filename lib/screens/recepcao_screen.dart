// lib/screens/recepcao_screen.dart
//
// Shell + Tela de recepção: cadastro rápido de casal em sala.
// Perfil 'recepcao' cai diretamente nesta tela (sem sidebar CRM).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../models/usuario_model.dart';
import '../services/auth_service.dart';
import '../services/ficha_pdf.dart';
import '../services/firestore_service.dart';

// ── Shell da recepção (app bar simples + logout) ─────────────────────────────
class RecepcaoShell extends StatelessWidget {
  final String? currentUserId;
  const RecepcaoShell({super.key, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
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
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            onPressed: () => AuthService().signOut(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: const RecepcaoScreen(),
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

  // Campos do formulário
  final _nomeCtrl = TextEditingController();
  final _conjugeCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _brindeCtrl = TextEditingController();
  final _pontoCapCtrl = TextEditingController();

  String _sala = 'VILLA';
  Usuario? _captador;
  List<Usuario> _usuarios = [];
  bool _carregandoUsuarios = true;
  bool _salvando = false;

  // Último atendimento salvo (para ação de reimprimir)
  FichaAtendimentoData? _ultimaFicha;

  static const _salas = ['VILLA', 'TAMBABA'];

  @override
  void initState() {
    super.initState();
    _carregarUsuarios();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _conjugeCtrl.dispose();
    _telefoneCtrl.dispose();
    _brindeCtrl.dispose();
    _pontoCapCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarUsuarios() async {
    try {
      final lista = await _service.getTodosUsuarios(apenasAtivos: true);
      if (mounted) setState(() {
        // Mostra captadores e vendedores como opções
        _usuarios = lista
            .where((u) => ['captador', 'vendedor', 'admin', 'super admin']
                .contains(u.perfil))
            .toList()
          ..sort((a, b) => a.nome.compareTo(b.nome));
        _carregandoUsuarios = false;
      });
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
        nomeEsposa: _conjugeCtrl.text.trim().isEmpty
            ? null
            : _conjugeCtrl.text.trim(),
        telefoneContato: _telefoneCtrl.text.trim().isEmpty
            ? null
            : _telefoneCtrl.text.trim(),
        brinde: _brindeCtrl.text.trim().isEmpty
            ? null
            : _brindeCtrl.text.trim(),
        sala: _sala,
        origem: _pontoCapCtrl.text.trim().isEmpty
            ? null
            : _pontoCapCtrl.text.trim(),
        captadorId: _captador?.id,
        captadorNome: _captador?.nome,
        numeroAtendimento: numeroAtendimento,
        dataEntradaSala: agora,
        dataCadastro: agora,
        dataAtualizacao: agora,
      );

      await _service.adicionarCliente(cliente);

      final fichaData = FichaAtendimentoData(
        nome: cliente.nome,
        conjuge: cliente.nomeEsposa,
        telefone: cliente.telefoneContato,
        brinde: cliente.brinde,
        captadorNome: cliente.captadorNome,
        sala: _sala,
        pontoCapatcao: cliente.origem,
        numeroAtendimento: numeroAtendimento,
        dataEntrada: agora,
      );

      // Abre impressão automaticamente
      await FichaAtendimentoPdf.gerar(fichaData);

      if (mounted) {
        setState(() {
          _ultimaFicha = fichaData;
          _salvando = false;
          // Limpa form para o próximo atendimento
          _nomeCtrl.clear();
          _conjugeCtrl.clear();
          _telefoneCtrl.clear();
          _brindeCtrl.clear();
          _pontoCapCtrl.clear();
          _captador = null;
          _sala = 'VILLA';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Atendimento Nº ${numeroAtendimento.toString().padLeft(6, '0')} registrado! '
              'Ficha aberta para impressão.',
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
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Cabeçalho ─────────────────────────────────────────────
                _sectionCard(
                  cs,
                  header: Row(
                    children: [
                      Icon(Icons.meeting_room_outlined,
                          color: cs.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Registrar entrada de casal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    // Sala + Ponto de Captação
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sala
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
                              prefixIcon:
                                  Icon(Icons.location_on_outlined),
                            ),
                            textCapitalization:
                                TextCapitalization.words,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Dados do casal ─────────────────────────────────────────
                _sectionCard(
                  cs,
                  header: Row(
                    children: [
                      Icon(Icons.people_outlined,
                          color: cs.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Dados do casal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    // Nome
                    TextFormField(
                      controller: _nomeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome *',
                        prefixIcon: Icon(Icons.person_outlined),
                        hintText: 'Nome completo do titular',
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe o nome'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    // Cônjuge
                    TextFormField(
                      controller: _conjugeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome do cônjuge',
                        prefixIcon: Icon(Icons.favorite_outline),
                        hintText: 'Nome completo',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 14),

                    // Telefone
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

                // ── Equipe ─────────────────────────────────────────────────
                _sectionCard(
                  cs,
                  header: Row(
                    children: [
                      Icon(Icons.badge_outlined,
                          color: cs.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Equipe',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    // Captador
                    if (_carregandoUsuarios)
                      const LinearProgressIndicator()
                    else
                      DropdownButtonFormField<Usuario>(
                        value: _captador,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Captador *',
                          prefixIcon:
                              Icon(Icons.person_pin_outlined),
                        ),
                        hint: const Text('Selecione o captador'),
                        items: _usuarios
                            .map((u) => DropdownMenuItem(
                                value: u,
                                child: Text(
                                    '${u.nome} (${u.perfil})')))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _captador = v),
                        validator: (v) =>
                            v == null ? 'Selecione o captador' : null,
                      ),
                    const SizedBox(height: 14),

                    // Brinde
                    TextFormField(
                      controller: _brindeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Brinde',
                        prefixIcon: Icon(Icons.card_giftcard_outlined),
                        hintText: 'Ex: Caipirinha, Massagem...',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
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
    required Widget header,
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
            header,
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
