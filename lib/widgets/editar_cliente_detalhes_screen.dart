// lib/widgets/editar_cliente_detalhes_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../services/auth_service.dart'; // Importar para auditoria
import '../services/firestore_service.dart';
import '../models/usuario_model.dart';

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
  final _authService = AuthService(); // Serviço para pegar usuário logado

  // Controladores e Estados
  late TextEditingController _nomeController;
  late TextEditingController _telefoneController;
  late TextEditingController _nomeParceiroController;
  late TextEditingController _motivoPerdaDescricaoController;

  late FaseCliente _faseSelecionada;
  late String _tipoSelecionado;
  String? _origemSelecionada;

  DateTime? _proximoContatoSelecionado;
  DateTime? _dataVisitaSelecionada; // Corrigido
  // NOVOS CAMPOS PARA EDIÇÃO
  DateTime? _dataCaptacaoSelecionada;
  Usuario? _captadorSelecionado;
  // FIM DOS NOVOS CAMPOS

  // Vendedores
  Usuario? _vendedorSelecionado;
  List<Usuario> _listaDeVendedores = [];
  List<Usuario> _listaDeCaptadores = []; // Nova lista
  bool _carregandoDados = true; // Um único 'loading'

  // Opções
  final List<String> _origemOpcoes = ['Presencial', 'WhatsApp', 'Instagram'];
  final List<String> _motivosOpcoes = [
    'Financeiro', 'Distância', 'Não conhecem a Villamor', 'Sem interesse',
    'Perfil Inadequado', 'Sem retorno', 'Outro'
  ];
  String? _motivoPerdaSelecionado;

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  Future<void> _carregarDadosIniciais() async {
    try {
      // Carrega as listas de usuários em paralelo
      final futureVendedores = _firestoreService.getTodosUsuarios(perfil: 'vendedor');
      final futureCaptadores = _firestoreService.getTodosUsuarios(perfil: 'captador');

      final resultados = await Future.wait([futureVendedores, futureCaptadores]);
      if (!mounted) return;

      setState(() {
        _listaDeVendedores = resultados[0];
        _listaDeCaptadores = resultados[1];
        _inicializarDadosDoFormulario(); // Inicializa os campos do formulário
        _carregandoDados = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregandoDados = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao carregar dados dos usuários: $e")),
      );
    }
  }

  void _inicializarDadosDoFormulario() {
    // Controladores de texto
    _nomeController = TextEditingController(text: widget.cliente.nome);
    _telefoneController = TextEditingController(text: widget.cliente.telefoneContato);
    _nomeParceiroController = TextEditingController(text: widget.cliente.nomeEsposa);
    _motivoPerdaDescricaoController = TextEditingController(text: widget.cliente.motivoNaoVenda);

    // Dropdowns e Datas
    _faseSelecionada = widget.cliente.fase;
    _tipoSelecionado = widget.cliente.tipo;
    _proximoContatoSelecionado = widget.cliente.proximoContato;
    _dataVisitaSelecionada = widget.cliente.dataVisita;
    _motivoPerdaSelecionado = widget.cliente.motivoNaoVendaDropdown;

    if (_origemOpcoes.contains(widget.cliente.origem)) {
      _origemSelecionada = widget.cliente.origem;
    }

    // Inicialização dos novos campos
    _dataCaptacaoSelecionada = widget.cliente.dataEntradaSala;
    if (widget.cliente.captadorId != null) {
      try {
        _captadorSelecionado = _listaDeCaptadores.firstWhere((c) => c.id == widget.cliente.captadorId);
      } catch (e) { /* Captador não encontrado, deixa nulo */ }
    }

    if (widget.cliente.vendedorId != null) {
      try {
        _vendedorSelecionado = _listaDeVendedores.firstWhere((v) => v.id == widget.cliente.vendedorId);
      } catch (e) { /* Vendedor não encontrado, deixa nulo */ }
    }
  }

  Future<void> _selecionarData(BuildContext context, Function(DateTime) onSelect) async {
    final DateTime? dataEscolhida = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (dataEscolhida != null) {
      setState(() => onSelect(dataEscolhida));
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = _authService.getCurrentUser();
    if (user == null) {
      // Segurança: Não deve acontecer se a tela só é acessível por usuários logados
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: Usuário não autenticado.')),
      );
      return;
    }

    final Map<String, dynamic> dadosParaAtualizar = {
      'nome': _nomeController.text.trim(),
      'tipo': _tipoSelecionado,
      'nomeEsposa': _tipoSelecionado == 'Casal' ? _nomeParceiroController.text.trim() : null,
      'telefoneContato': _telefoneController.text.trim(),
      'fase': _faseSelecionada.toString().split('.').last,
      'origem': _origemSelecionada,
      'proximoContato': _proximoContatoSelecionado,
      'dataVisita': _dataVisitaSelecionada,
      // Salva os novos campos
      'captadorId': _captadorSelecionado?.id,
      'captadorNome': _captadorSelecionado?.nome,
      'dataEntradaSala': _dataCaptacaoSelecionada,
      // Fim dos novos campos
      'vendedorId': _vendedorSelecionado?.id,
      'vendedorNome': _vendedorSelecionado?.nome,
      'motivoNaoVenda': _faseSelecionada == FaseCliente.perdido ? _motivoPerdaDescricaoController.text.trim() : null,
      'motivoNaoVendaDropdown': _faseSelecionada == FaseCliente.perdido ? _motivoPerdaSelecionado : null,
      // Auditoria
      'dataAtualizacao': FieldValue.serverTimestamp(),
      'atualizadoPorId': user.uid,
      // 'atualizadoPorNome' você precisaria buscar do seu serviço de Firestore, se desejar
    };

    try {
      await _firestoreService.atualizarClienteDetalhes(widget.cliente.id!, dadosParaAtualizar);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Detalhes de ${_nomeController.text} atualizados!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar: $e')),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Editar: ${widget.cliente.nome}'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _carregandoDados
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: 'Nome do Cliente', border: OutlineInputBorder()),
                validator: (v) => v == null || v.trim().isEmpty ? 'Insira o nome.' : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _origemSelecionada,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Origem do Cliente *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.public)),
                hint: const Text('Selecione a origem'),
                validator: (value) => value == null ? 'A origem é obrigatória.' : null,
                items: _origemOpcoes.map((origem) => DropdownMenuItem<String>(value: origem, child: Text(origem))).toList(),
                onChanged: (String? newValue) => setState(() => _origemSelecionada = newValue),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<FaseCliente>(
                decoration: const InputDecoration(labelText: 'Fase no Funil', border: OutlineInputBorder(), prefixIcon: Icon(Icons.flag_outlined)),
                value: _faseSelecionada,
                items: FaseCliente.values.map((fase) => DropdownMenuItem(value: fase, child: Text(fase.nomeDisplay))).toList(),
                onChanged: (v) => setState(() => _faseSelecionada = v!),
              ),
              const SizedBox(height: 20),
              // NOVO DROPDOWN DE CAPTADOR
              DropdownButtonFormField<Usuario>(
                value: _captadorSelecionado,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Captador', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_add_alt_1)),
                hint: const Text('Nenhum captador definido'),
                items: _listaDeCaptadores.map((captador) => DropdownMenuItem<Usuario>(value: captador, child: Text(captador.nome))).toList(),
                onChanged: (Usuario? newValue) => setState(() => _captadorSelecionado = newValue),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<Usuario>(
                value: _vendedorSelecionado,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Vendedor Responsável', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)),
                hint: const Text('Nenhum vendedor atribuído'),
                items: _listaDeVendedores.map((vendedor) => DropdownMenuItem<Usuario>(value: vendedor, child: Text(vendedor.nome))).toList(),
                onChanged: (Usuario? newValue) => setState(() => _vendedorSelecionado = newValue),
              ),
              const SizedBox(height: 20),
              // ... resto dos campos
              TextFormField(
                controller: _telefoneController,
                decoration: const InputDecoration(labelText: 'Telefone', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_outlined)),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),
              // NOVO CAMPO DE DATA DA CAPTAÇÃO
              _buildDateTile('Data da Captação', _dataCaptacaoSelecionada, () => _selecionarData(context, (date) => _dataCaptacaoSelecionada = date), () => setState(() => _dataCaptacaoSelecionada = null)),
              const SizedBox(height: 10),
              _buildDateTile('Próximo Contato', _proximoContatoSelecionado, () => _selecionarData(context, (date) => _proximoContatoSelecionado = date), () => setState(() => _proximoContatoSelecionado = null)),
              const SizedBox(height: 10),
              _buildDateTile('Data da Visita', _dataVisitaSelecionada, () => _selecionarData(context, (date) => _dataVisitaSelecionada = date), () => setState(() => _dataVisitaSelecionada = null)),
              // ...
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.save_alt),
                label: const Text('SALVAR ALTERAÇÕES'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTile(String label, DateTime? date, VoidCallback onTap, VoidCallback onClear) {
    IconData iconData = Icons.calendar_today;
    if (label.contains('Captação')) iconData = Icons.person_add_alt_1;
    if (label.contains('Contato')) iconData = Icons.phone_in_talk;
    if (label.contains('Visita')) iconData = Icons.location_on;

    return Card(
      elevation: 2.0,
      child: ListTile(
        leading: Icon(iconData, color: Colors.indigo),
        title: Text(date == null ? label : '$label: ${DateFormat('dd/MM/yyyy').format(date)}', style: TextStyle(fontWeight: date != null ? FontWeight.bold : FontWeight.normal)),
        trailing: date != null ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: onClear) : null,
        onTap: onTap,
      ),
    );
  }
}
