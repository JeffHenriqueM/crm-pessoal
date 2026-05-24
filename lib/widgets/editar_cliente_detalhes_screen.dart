import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../models/usuario_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class EditarClienteDetalhesScreen extends StatefulWidget {
  final Cliente cliente;
  const EditarClienteDetalhesScreen({super.key, required this.cliente});

  @override
  State<EditarClienteDetalhesScreen> createState() =>
      _EditarClienteDetalhesScreenState();
}

class _EditarClienteDetalhesScreenState
    extends State<EditarClienteDetalhesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();
  final _authService = AuthService();

  late TextEditingController _nomeController;
  late TextEditingController _telefoneController;
  late TextEditingController _nomeParceiroController;
  late TextEditingController _motivoPerdaDescricaoController;

  late FaseCliente _faseSelecionada;
  late String _tipoSelecionado;
  String? _origemSelecionada;

  DateTime? _proximoContatoSelecionado;
  DateTime? _dataVisitaSelecionada;
  DateTime? _dataCaptacaoSelecionada;
  Usuario? _captadorSelecionado;
  Usuario? _vendedorSelecionado;
  List<Usuario> _listaDeUsuarios = [];
  bool _carregandoDados = true;

  static const _origemOpcoes = ['Presencial', 'WhatsApp', 'Instagram'];
  static const _motivosOpcoes = [
    'Financeiro',
    'Distância',
    'Não conhecem a Villamor',
    'Sem interesse',
    'Perfil Inadequado',
    'Sem retorno',
    'Outro',
  ];
  String? _motivoPerdaSelecionado;

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  Future<void> _carregarDadosIniciais() async {
    try {
      final usuarios = await _firestoreService.getTodosUsuarios();
      if (!mounted) return;
      setState(() {
        _listaDeUsuarios = usuarios;
        _inicializarDadosDoFormulario();
        _carregandoDados = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregandoDados = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar dados: $e')),
      );
    }
  }

  void _inicializarDadosDoFormulario() {
    _nomeController = TextEditingController(text: widget.cliente.nome);
    _telefoneController =
        TextEditingController(text: widget.cliente.telefoneContato);
    _nomeParceiroController =
        TextEditingController(text: widget.cliente.nomeEsposa);
    _motivoPerdaDescricaoController =
        TextEditingController(text: widget.cliente.motivoNaoVenda);

    _faseSelecionada = widget.cliente.fase;
    _tipoSelecionado = widget.cliente.tipo;
    _proximoContatoSelecionado = widget.cliente.proximoContato;
    _dataVisitaSelecionada = widget.cliente.dataVisita;
    _motivoPerdaSelecionado = widget.cliente.motivoNaoVendaDropdown;
    _dataCaptacaoSelecionada = widget.cliente.dataEntradaSala;

    if (_origemOpcoes.contains(widget.cliente.origem)) {
      _origemSelecionada = widget.cliente.origem;
    }

    if (widget.cliente.captadorId != null) {
      try {
        _captadorSelecionado = _listaDeUsuarios
            .firstWhere((u) => u.id == widget.cliente.captadorId);
      } catch (_) {}
    }
    if (widget.cliente.vendedorId != null) {
      try {
        _vendedorSelecionado = _listaDeUsuarios
            .firstWhere((u) => u.id == widget.cliente.vendedorId);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _telefoneController.dispose();
    _nomeParceiroController.dispose();
    _motivoPerdaDescricaoController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData(
      Function(DateTime) onSelect, DateTime? initialDate) async {
    final data = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (data != null && mounted) setState(() => onSelect(data));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _authService.getCurrentUser();
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: Usuário não autenticado.')),
      );
      return;
    }

    final dados = {
      'nome': _nomeController.text.trim(),
      'tipo': _tipoSelecionado,
      'nomeEsposa': _tipoSelecionado == 'Casal'
          ? _nomeParceiroController.text.trim()
          : null,
      'telefoneContato': _telefoneController.text.trim(),
      'fase': _faseSelecionada.toString().split('.').last,
      'origem': _origemSelecionada,
      'proximoContato': _proximoContatoSelecionado,
      'dataVisita': _dataVisitaSelecionada,
      'captadorId': _captadorSelecionado?.id,
      'captadorNome': _captadorSelecionado?.nome,
      'dataEntradaSala': _dataCaptacaoSelecionada,
      'vendedorId': _vendedorSelecionado?.id,
      'vendedorNome': _vendedorSelecionado?.nome,
      'motivoNaoVenda': _faseSelecionada == FaseCliente.perdido
          ? _motivoPerdaDescricaoController.text.trim()
          : null,
      'motivoNaoVendaDropdown': _faseSelecionada == FaseCliente.perdido
          ? _motivoPerdaSelecionado
          : null,
      'dataAtualizacao': FieldValue.serverTimestamp(),
      'atualizadoPorId': user.uid,
    };

    try {
      await _firestoreService.atualizarClienteDetalhes(
          widget.cliente.id!, dados);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_nomeController.text} atualizado!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Editar: ${widget.cliente.nome}')),
      body: _carregandoDados
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _nomeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do Cliente',
                        prefixIcon: Icon(Icons.person_outlined),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          (v?.trim().isEmpty ?? true) ? 'Insira o nome.' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _tipoSelecionado,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de Cliente',
                        prefixIcon: Icon(Icons.group_outlined),
                      ),
                      items: ['Solteiro', 'Casal']
                          .map((t) =>
                              DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _tipoSelecionado = v;
                            if (v == 'Solteiro') _nomeParceiroController.clear();
                          });
                        }
                      },
                    ),
                    if (_tipoSelecionado == 'Casal') ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nomeParceiroController,
                        decoration: const InputDecoration(
                          labelText: 'Nome do Cônjuge/Parceiro(a)',
                          prefixIcon: Icon(Icons.favorite_border),
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                    ],
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _origemSelecionada,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Origem do Cliente *',
                        prefixIcon: Icon(Icons.public_outlined),
                      ),
                      hint: const Text('Selecione a origem'),
                      validator: (v) =>
                          v == null ? 'A origem é obrigatória.' : null,
                      items: _origemOpcoes
                          .map((o) =>
                              DropdownMenuItem(value: o, child: Text(o)))
                          .toList(),
                      onChanged: (v) => setState(() => _origemSelecionada = v),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<FaseCliente>(
                      decoration: const InputDecoration(
                        labelText: 'Fase no Funil',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      value: _faseSelecionada,
                      items: FaseCliente.values
                          .map((f) =>
                              DropdownMenuItem(value: f, child: Text(f.nomeDisplay)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _faseSelecionada = v!),
                    ),
                    if (_faseSelecionada == FaseCliente.perdido) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _motivoPerdaSelecionado,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Motivo da Perda',
                          prefixIcon: Icon(Icons.mood_bad_outlined),
                        ),
                        hint: const Text('Selecione o motivo'),
                        items: _motivosOpcoes
                            .map((m) =>
                                DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _motivoPerdaSelecionado = v),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _motivoPerdaDescricaoController,
                        decoration: const InputDecoration(
                          labelText: 'Descrição do Motivo (Opcional)',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                        maxLines: 3,
                      ),
                    ],
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Usuario>(
                      value: _captadorSelecionado,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Captador',
                        prefixIcon: Icon(Icons.person_add_alt_1_outlined),
                      ),
                      hint: const Text('Nenhum captador definido'),
                      items: _listaDeUsuarios
                          .map((u) =>
                              DropdownMenuItem(value: u, child: Text(u.nome)))
                          .toList(),
                      onChanged: (v) => setState(() => _captadorSelecionado = v),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Usuario>(
                      value: _vendedorSelecionado,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Vendedor Responsável',
                        prefixIcon: Icon(Icons.store_outlined),
                      ),
                      hint: const Text('Nenhum vendedor atribuído'),
                      items: _listaDeUsuarios
                          .map((u) =>
                              DropdownMenuItem(value: u, child: Text(u.nome)))
                          .toList(),
                      onChanged: (v) => setState(() => _vendedorSelecionado = v),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _telefoneController,
                      decoration: const InputDecoration(
                        labelText: 'Telefone',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _buildDateTile(
                      'Data da Captação',
                      _dataCaptacaoSelecionada,
                      Icons.person_add_alt_1_outlined,
                      () => _selecionarData(
                          (d) => _dataCaptacaoSelecionada = d,
                          _dataCaptacaoSelecionada),
                      () => setState(() => _dataCaptacaoSelecionada = null),
                    ),
                    const SizedBox(height: 8),
                    _buildDateTile(
                      'Próximo Contato',
                      _proximoContatoSelecionado,
                      Icons.phone_in_talk_outlined,
                      () => _selecionarData(
                          (d) => _proximoContatoSelecionado = d,
                          _proximoContatoSelecionado),
                      () =>
                          setState(() => _proximoContatoSelecionado = null),
                    ),
                    const SizedBox(height: 8),
                    _buildDateTile(
                      'Data da Visita',
                      _dataVisitaSelecionada,
                      Icons.location_on_outlined,
                      () => _selecionarData(
                          (d) => _dataVisitaSelecionada = d,
                          _dataVisitaSelecionada),
                      () => setState(() => _dataVisitaSelecionada = null),
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('SALVAR ALTERAÇÕES',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDateTile(
    String label,
    DateTime? date,
    IconData icon,
    VoidCallback onTap,
    VoidCallback onClear,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 1,
      child: ListTile(
        leading: Icon(icon, color: date != null ? cs.primary : cs.outline),
        title: Text(
          date == null
              ? label
              : '$label: ${DateFormat('dd/MM/yyyy').format(date)}',
          style: TextStyle(
            fontWeight:
                date != null ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: date != null
            ? IconButton(
                icon: Icon(Icons.clear, color: cs.outline),
                onPressed: onClear,
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
