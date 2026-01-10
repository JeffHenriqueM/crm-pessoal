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
  // final _origemController = TextEditingController(); // <<< REMOVIDO
  final _motivoPerdaDescricaoController = TextEditingController();

  // Estado do formulário
  FaseCliente _faseSelecionada = FaseCliente.prospeccao; // Correção do valor inicial
  String _tipoCliente = 'Casal';
  DateTime? _proximoContato;
  DateTime? _proximaVisita;

  // --- LÓGICA DE ORIGEM CORRIGIDA ---
  String? _origemSelecionada; // <<< NOVA VARIÁVEL
  final List<String> _origemOpcoes = ['Presencial', 'WhatsApp', 'Instagram']; // <<< OPÇÕES
  // ---------------------------------

  // --- LÓGICA DE PERDA ---
  String? _motivoPerdaSelecionado;
  final List<String> _motivosOpcoes = [
    'Financeiro', 'Distância', 'Não conhecem a Villamor', 'Sem interesse',
    'Perfil Inadequado', 'Sem retorno', 'Outro'
  ];
  bool get _mostrarMotivoPerda => _faseSelecionada == FaseCliente.perdido;
  // -----------------------

  // Vendedores
  Usuario? _vendedorSelecionado;
  List<Usuario> _listaDeVendedores = [];
  bool _carregandoVendedores = true;

  @override
  void initState() {
    super.initState();
    _carregarVendedores();
  }

  Future<void> _carregarVendedores() async {
    try {
      final vendedores = await _firestoreService.getTodosUsuarios();
      if (mounted) {
        setState(() {
          _listaDeVendedores = vendedores;
          _carregandoVendedores = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _carregandoVendedores = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao carregar vendedores: $e")),
        );
      }
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _nomeEsposaController.dispose();
    _telefoneController.dispose();
    // _origemController.dispose(); // <<< REMOVIDO
    _motivoPerdaDescricaoController.dispose();
    super.dispose();
  }

  Future<void> _salvarCliente() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final novoCliente = Cliente(
      nome: _nomeController.text.trim(),
      nomeEsposa: _tipoCliente == 'Casal' ? _nomeEsposaController.text.trim() : null,
      telefoneContato: _telefoneController.text.trim(),
      tipo: _tipoCliente,
      origem: _origemSelecionada, // <<< ALTERADO
      fase: _faseSelecionada,
      dataCadastro: DateTime.now(),
      dataAtualizacao: DateTime.now(),
      proximoContato: _proximoContato,
      dataVisita: _proximaVisita,
      vendedorId: _vendedorSelecionado?.id,
      vendedorNome: _vendedorSelecionado?.nome,
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

  Future<void> _selecionarData(BuildContext context, {required bool isProximoContato}) async {
    final DateTime? dataSelecionada = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (dataSelecionada != null) {
      setState(() {
        if (isProximoContato) {
          _proximoContato = dataSelecionada;
        } else {
          _proximaVisita = dataSelecionada;
        }
      });
    }
  }


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

              // --- CAMPO ORIGEM ALTERADO ---
              DropdownButtonFormField<String>(
                value: _origemSelecionada,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Origem do Cliente *',
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Selecione a origem'),
                validator: (value) => value == null ? 'A origem é obrigatória.' : null,
                items: _origemOpcoes.map((origem) {
                  return DropdownMenuItem<String>(value: origem, child: Text(origem));
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() => _origemSelecionada = newValue);
                },
              ),
              // --- FIM DA ALTERAÇÃO ---

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
                const SizedBox(height: 16),
                const Text('Detalhes da Perda', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _motivoPerdaSelecionado,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Motivo Principal *', border: OutlineInputBorder()),
                  hint: const Text('Selecione o motivo da perda'),
                  validator: (value) => _mostrarMotivoPerda && value == null ? 'O motivo é obrigatório.' : null,
                  items: _motivosOpcoes.map((motivo) {
                    return DropdownMenuItem<String>(value: motivo, child: Text(motivo));
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() => _motivoPerdaSelecionado = newValue);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _motivoPerdaDescricaoController,
                  decoration: const InputDecoration(labelText: 'Descrição Adicional da Perda (Opcional)', border: OutlineInputBorder()),
                  maxLines: 3,
                ),
              ],
              const SizedBox(height: 16),
              _carregandoVendedores
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<Usuario>(
                value: _vendedorSelecionado,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Vendedor Responsável *', border: OutlineInputBorder()),
                hint: const Text('Atribuir a...'),
                validator: (value) => value == null ? 'É obrigatório selecionar um vendedor.' : null,
                items: _listaDeVendedores.map((vendedor) => DropdownMenuItem<Usuario>(value: vendedor, child: Text(vendedor.nome))).toList(),
                onChanged: (Usuario? newValue) => setState(() => _vendedorSelecionado = newValue),
              ),
              const SizedBox(height: 24),
              const Text('Agendamentos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              _buildDateTile(
                context: context,
                title: 'Próximo Contato',
                date: _proximoContato,
                onTap: () => _selecionarData(context, isProximoContato: true),
                onClear: () => setState(() => _proximoContato = null),
              ),
              _buildDateTile(
                context: context,
                title: 'Próxima Visita',
                date: _proximaVisita,
                onTap: () => _selecionarData(context, isProximoContato: false),
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
        leading: Icon(title.contains('Contato') ? Icons.phone_in_talk : Icons.location_on),
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
