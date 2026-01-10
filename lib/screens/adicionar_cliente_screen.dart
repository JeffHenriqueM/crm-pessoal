// lib/screens/adicionar_cliente_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../models/usuario_model.dart';
import '../services/firestore_service.dart';

class AdicionarClienteScreen extends StatefulWidget {
  const AdicionarClienteScreen({super.key});

  @override
  State<AdicionarClienteScreen> createState() => _AdicionarClienteScreenState();
}

class _AdicionarClienteScreenState extends State<AdicionarClienteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();

  // Controladores
  final _nomeController = TextEditingController();
  final _nomeEsposaController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _motivoPerdaDescricaoController = TextEditingController();

  // Estado do formulário
  FaseCliente _faseSelecionada = FaseCliente.prospeccao;
  String _tipoCliente = 'Casal';
  DateTime? _proximoContato;
  DateTime? _proximaVisita;
  // NOVO CAMPO DE DATA
  DateTime? _dataCaptacao;

  String? _origemSelecionada;
  final List<String> _origemOpcoes = ['Presencial', 'WhatsApp', 'Instagram'];

  String? _motivoPerdaSelecionado;
  final List<String> _motivosOpcoes = [
    'Financeiro', 'Distância', 'Não conhecem a Villamor', 'Sem interesse',
    'Perfil Inadequado', 'Sem retorno', 'Outro'
  ];
  bool get _mostrarMotivoPerda => _faseSelecionada == FaseCliente.perdido;

  // --- MUDANÇA: LISTAS SEPARADAS PARA VENDEDORES E CAPTADORES ---
  Usuario? _vendedorSelecionado;
  Usuario? _captadorSelecionado; // Novo
  List<Usuario> _listaDeVendedores = [];
  List<Usuario> _listaDeCaptadores = []; // Novo
  bool _carregandoUsuarios = true;
  // --- FIM DA MUDANÇA ---

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  // --- MUDANÇA: CARREGA VENDEDORES E CAPTADORES ---
  Future<void> _carregarDadosIniciais() async {
    try {
      // Carrega as listas em paralelo para otimizar
      final usuarios = _firestoreService.getTodosUsuarios();

      final resultados = await Future.wait([usuarios, usuarios]);

      if (mounted) {
        setState(() {
          _listaDeVendedores = resultados[0];
          _listaDeCaptadores = resultados[1];
          _carregandoUsuarios = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _carregandoUsuarios = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao carregar usuários: $e")),
        );
      }
    }
  }
  // --- FIM DA MUDANÇA ---


  @override
  void dispose() {
    _nomeController.dispose();
    _nomeEsposaController.dispose();
    _telefoneController.dispose();
    _motivoPerdaDescricaoController.dispose();
    super.dispose();
  }

  void _atualizarFasePorOrigem(String? novaOrigem) {
    FaseCliente novaFase;
    if (novaOrigem == 'Presencial') {
      novaFase = FaseCliente.visita;
    } else if (novaOrigem == 'WhatsApp' || novaOrigem == 'Instagram') {
      novaFase = FaseCliente.contato;
    } else {
      novaFase = FaseCliente.prospeccao;
    }
    setState(() {
      _origemSelecionada = novaOrigem;
      _faseSelecionada = novaFase;
      if (_faseSelecionada != FaseCliente.perdido) {
        _motivoPerdaSelecionado = null;
        _motivoPerdaDescricaoController.clear();
      }
    });
  }

  // --- MUDANÇA: ATUALIZADO PARA SALVAR OS NOVOS CAMPOS ---
  Future<void> _salvarCliente() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final novoCliente = Cliente(
      nome: _nomeController.text.trim(),
      nomeEsposa: _tipoCliente == 'Casal' ? _nomeEsposaController.text.trim() : null,
      telefoneContato: _telefoneController.text.trim(),
      tipo: _tipoCliente,
      origem: _origemSelecionada,
      fase: _faseSelecionada,
      dataCadastro: DateTime.now(), // Continua registrando a data de criação no sistema
      dataAtualizacao: DateTime.now(),
      proximoContato: _proximoContato,
      dataVisita: _proximaVisita,
      vendedorId: _vendedorSelecionado?.id,
      vendedorNome: _vendedorSelecionado?.nome,

      // NOVOS CAMPOS SENDO SALVOS
      captadorId: _captadorSelecionado?.id,
      captadorNome: _captadorSelecionado?.nome,
      dataEntradaSala: _dataCaptacao, // Usando a data do novo campo

      motivoNaoVendaDropdown: _mostrarMotivoPerda ? _motivoPerdaSelecionado : null,
      motivoNaoVenda: _mostrarMotivoPerda ? _motivoPerdaDescricaoController.text.trim() : null,
    );

    try {
      await _firestoreService.adicionarCliente(novoCliente);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cliente adicionado com sucesso!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar cliente: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  // --- FIM DA MUDANÇA ---

  // --- MUDANÇA: FUNÇÃO DE DATA AGORA É MAIS GENÉRICA ---
  Future<void> _selecionarData(BuildContext context, Function(DateTime) onSelect) async {
    final DateTime? dataSelecionada = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)), // 1 ano atrás
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)), // 2 anos para frente
    );

    if (dataSelecionada != null) {
      setState(() {
        onSelect(dataSelecionada);
      });
    }
  }
  // --- FIM DA MUDANÇA ---


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar Novo Cliente')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: 'Nome Principal *', border: OutlineInputBorder()),
                validator: (value) => value == null || value.trim().isEmpty ? 'O nome principal é obrigatório.' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _tipoCliente,
                decoration: const InputDecoration(labelText: 'Tipo de Cliente', border: OutlineInputBorder()),
                items: ['Casal', 'Individual'].map((label) => DropdownMenuItem(child: Text(label), value: label)).toList(),
                onChanged: (value) => setState(() => _tipoCliente = value!),
              ),
              if (_tipoCliente == 'Casal') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nomeEsposaController,
                  decoration: const InputDecoration(labelText: 'Nome do Cônjuge/Parceiro(a)', border: OutlineInputBorder()),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _telefoneController,
                decoration: const InputDecoration(labelText: 'Telefone de Contato', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _origemSelecionada,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Origem do Cliente *', border: OutlineInputBorder()),
                hint: const Text('Selecione a origem'),
                validator: (value) => value == null ? 'A origem é obrigatória.' : null,
                items: _origemOpcoes.map((origem) => DropdownMenuItem<String>(value: origem, child: Text(origem))).toList(),
                onChanged: (String? newValue) => _atualizarFasePorOrigem(newValue),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<FaseCliente>(
                value: _faseSelecionada,
                decoration: const InputDecoration(labelText: 'Fase do Funil', border: OutlineInputBorder()),
                items: FaseCliente.values.map((fase) => DropdownMenuItem(value: fase, child: Text(fase.nomeDisplay))).toList(),
                onChanged: (FaseCliente? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _faseSelecionada = newValue;
                      if (_faseSelecionada != FaseCliente.perdido) {
                        _motivoPerdaSelecionado = null;
                        _motivoPerdaDescricaoController.clear();
                      }
                    });
                  }
                },
              ),
              if (_mostrarMotivoPerda) ...[
                // ... seu código de motivo de perda ...
              ],
              const SizedBox(height: 16),

              // --- MUDANÇA: NOVOS DROPDOWNS DE CAPTADOR E VENDEDOR ---
              _carregandoUsuarios
                  ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                  : Column(
                children: [
                  DropdownButtonFormField<Usuario>(
                    value: _captadorSelecionado,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Captador *', border: OutlineInputBorder()),
                    hint: const Text('Selecionar quem captou...'),
                    validator: (value) => value == null ? 'É obrigatório informar o captador.' : null,
                    items: _listaDeCaptadores.map((captador) => DropdownMenuItem<Usuario>(value: captador, child: Text(captador.nome))).toList(),
                    onChanged: (Usuario? newValue) => setState(() => _captadorSelecionado = newValue),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Usuario>(
                    value: _vendedorSelecionado,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Vendedor Responsável *', border: OutlineInputBorder()),
                    hint: const Text('Atribuir a...'),
                    validator: (value) => value == null ? 'É obrigatório selecionar um vendedor.' : null,
                    items: _listaDeVendedores.map((vendedor) => DropdownMenuItem<Usuario>(value: vendedor, child: Text(vendedor.nome))).toList(),
                    onChanged: (Usuario? newValue) => setState(() => _vendedorSelecionado = newValue),
                  ),
                ],
              ),
              // --- FIM DA MUDANÇA ---

              const SizedBox(height: 24),
              const Text('Datas Importantes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

              // --- MUDANÇA: ADICIONADO CAMPO DE DATA DA CAPTAÇÃO ---
              _buildDateTile(
                context: context,
                title: 'Data da Captação',
                date: _dataCaptacao,
                onTap: () => _selecionarData(context, (date) => _dataCaptacao = date),
                onClear: () => setState(() => _dataCaptacao = null),
              ),
              // --- FIM DA MUDANÇA ---

              _buildDateTile(
                context: context,
                title: 'Próximo Contato',
                date: _proximoContato,
                onTap: () => _selecionarData(context, (date) => _proximoContato = date),
                onClear: () => setState(() => _proximoContato = null),
              ),
              _buildDateTile(
                context: context,
                title: 'Próxima Visita',
                date: _proximaVisita,
                onTap: () => _selecionarData(context, (date) => _proximaVisita = date),
                onClear: () => setState(() => _proximaVisita = null),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _salvarCliente,
                icon: const Icon(Icons.save),
                label: const Text('Salvar Cliente'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTile({ required BuildContext context, required String title, required DateTime? date, required VoidCallback onTap, required VoidCallback onClear }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(title.contains('Captação') ? Icons.person_add_alt_1 : (title.contains('Contato') ? Icons.phone_in_talk : Icons.location_on)),
        title: Text(title),
        subtitle: Text(
          date != null ? DateFormat('dd/MM/yyyy').format(date) : 'Não definido',
          style: TextStyle(
            color: date != null ? Theme.of(context).primaryColor : Colors.grey,
            fontWeight: date != null ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: onTap,
        trailing: date != null ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: onClear, tooltip: 'Limpar Data') : null,
      ),
    );
  }
}
