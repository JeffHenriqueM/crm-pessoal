// lib/widgets/editar_cliente_detalhes_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../services/firestore_service.dart';
// Adicione as importações que faltam, se necessário
import '../models/usuario_model.dart';

class EditarClienteDetalhesScreen extends StatefulWidget {
  final Cliente cliente;

  const EditarClienteDetalhesScreen({super.key, required this.cliente});

  @override
  State<EditarClienteDetalhesScreen> createState() => _EditarClienteDetalhesScreenState();
}

class _EditarClienteDetalhesScreenState extends State<EditarClienteDetalhesScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores e Estados
  late TextEditingController _nomeController;
  late TextEditingController _telefoneController;
  late TextEditingController _nomeParceiroController;
  late TextEditingController _motivoDetalhamentoController;

  late FaseCliente _faseSelecionada;
  late String _tipoSelecionado;

  DateTime? _proximoContatoSelecionado;
  DateTime? _dataVisitaSelecionada;
  String? _motivoDropdownSelecionado;

  // Variáveis para o dropdown de vendedores
  Usuario? _vendedorSelecionado;
  List<Usuario> _listaDeVendedores = [];
  bool _carregandoVendedores = true;

  final List<String> _motivosOpcoes = [
    'Financeiro', 'Distância', 'Não conhecem a Villamor', 'Sem interesse',
    'Perfil Inadequado', 'Sem retorno', 'Outro'
  ];

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _inicializarDados();
    _carregarVendedores();
  }

  void _inicializarDados() {
    _nomeController = TextEditingController(text: widget.cliente.nome);
    _telefoneController = TextEditingController(text: widget.cliente.telefoneContato);
    _nomeParceiroController = TextEditingController(text: widget.cliente.nomeEsposa);
    _motivoDetalhamentoController = TextEditingController(text: widget.cliente.motivoNaoVenda);
    _faseSelecionada = widget.cliente.fase;
    _tipoSelecionado = widget.cliente.tipo;
    _proximoContatoSelecionado = widget.cliente.proximoContato;
    _dataVisitaSelecionada = widget.cliente.dataVisita;
    _motivoDropdownSelecionado = widget.cliente.motivoNaoVendaDropdown;
  }

  Future<void> _carregarVendedores() async {
    final vendedores = await _firestoreService.getTodosUsuarios();
    if (mounted) {
      setState(() {
        _listaDeVendedores = vendedores;
        // Tenta pré-selecionar o vendedor atual do cliente
        if (widget.cliente.vendedorId != null) {
          try {
            _vendedorSelecionado = _listaDeVendedores.firstWhere(
                    (v) => v.id == widget.cliente.vendedorId
            );
          } catch (e) {
            _vendedorSelecionado = null; // Vendedor não encontrado na lista
          }
        }
        _carregandoVendedores = false;
      });
    }
  }

  Future<void> _selecionarData(BuildContext context, Function(DateTime) onSelect) async {
    final DateTime? dataEscolhida = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );

    if (dataEscolhida == null || !mounted) return;

    final TimeOfDay? horaEscolhida = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (horaEscolhida == null) return;

    onSelect(DateTime(
      dataEscolhida.year, dataEscolhida.month, dataEscolhida.day,
      horaEscolhida.hour, horaEscolhida.minute,
    ));
  }

  // ==================== FUNÇÃO _submit() CORRIGIDA ====================
  void _submit() async {
    if (_formKey.currentState!.validate()) {
      // 1. Criar o Mapa de dados a serem atualizados
      final Map<String, dynamic> dadosParaAtualizar = {
        'nome': _nomeController.text.trim(),
        'tipo': _tipoSelecionado,
        'nomeEsposa': _tipoSelecionado == 'Casal' ? _nomeParceiroController.text.trim() : null,
        'telefoneContato': _telefoneController.text.trim(),
        'fase': _faseSelecionada.toString().split('.').last, // Salva o texto do enum
        'proximoContato': _proximoContatoSelecionado,
        'dataVisita': _dataVisitaSelecionada,
        // Atribui o vendedor selecionado (ou nulo se nenhum for)
        'vendedorId': _vendedorSelecionado?.id,
        'vendedorNome': _vendedorSelecionado?.nome,
        // Lógica para campos de perda
        'motivoNaoVenda': _faseSelecionada == FaseCliente.perdido ? _motivoDetalhamentoController.text.trim() : null,
        'motivoNaoVendaDropdown': _faseSelecionada == FaseCliente.perdido ? _motivoDropdownSelecionado : null,
      };

      try {
        // 2. Chamar o método com o ID e o Mapa
        await _firestoreService.atualizarClienteDetalhes(
          widget.cliente.id!,
          dadosParaAtualizar,
        );

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
  }
  // =====================================================================

  @override
  void dispose() {
    _nomeController.dispose();
    _telefoneController.dispose();
    _nomeParceiroController.dispose();
    _motivoDetalhamentoController.dispose();
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              // ... (outros campos não mudaram)
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: 'Nome do Cliente', border: OutlineInputBorder()),
                validator: (v) => v == null || v.trim().isEmpty ? 'Insira o nome.' : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<FaseCliente>(
                decoration: const InputDecoration(labelText: 'Fase no Funil', border: OutlineInputBorder(), prefixIcon: Icon(Icons.flag_outlined)),
                value: _faseSelecionada,
                items: FaseCliente.values.map((fase) => DropdownMenuItem(value: fase, child: Text(fase.nomeDisplay))).toList(),
                onChanged: (v) => setState(() => _faseSelecionada = v!),
              ),
              const SizedBox(height: 20),
              // ----- CAMPO DE SELEÇÃO DE VENDEDOR -----
              _carregandoVendedores
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<Usuario>(
                value: _vendedorSelecionado,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Vendedor Responsável',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                hint: const Text('Nenhum vendedor atribuído'),
                items: _listaDeVendedores.map((vendedor) {
                  return DropdownMenuItem<Usuario>(value: vendedor, child: Text(vendedor.nome));
                }).toList(),
                onChanged: (Usuario? newValue) => setState(() => _vendedorSelecionado = newValue),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _telefoneController,
                decoration: const InputDecoration(labelText: 'Telefone', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_outlined)),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Tipo de Cliente', border: OutlineInputBorder()),
                value: _tipoSelecionado,
                items: ['Solteiro', 'Casal'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) {
                  setState(() => _tipoSelecionado = v!);
                  if (v == 'Solteiro') _nomeParceiroController.clear();
                },
              ),
              const SizedBox(height: 20),
              if (_tipoSelecionado == 'Casal') ...[
                TextFormField(
                  controller: _nomeParceiroController,
                  decoration: const InputDecoration(labelText: 'Nome do(a) Parceiro(a)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
              ],
              _buildDateTile('Próximo Contato', _proximoContatoSelecionado, () => _selecionarData(context, (date) => setState(() => _proximoContatoSelecionado = date)), () => setState(() => _proximoContatoSelecionado = null)),
              const SizedBox(height: 10),
              _buildDateTile('Próxima Visita', _dataVisitaSelecionada, () => _selecionarData(context, (date) => setState(() => _dataVisitaSelecionada = date)), () => setState(() => _dataVisitaSelecionada = null)),

              if (_faseSelecionada == FaseCliente.perdido) ...[
                const Divider(height: 40),
                const Text("Dados de Desistência", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Motivo Principal', border: OutlineInputBorder()),
                  value: _motivoDropdownSelecionado,
                  items: _motivosOpcoes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setState(() => _motivoDropdownSelecionado = v),
                  validator: (v) => _faseSelecionada == FaseCliente.perdido && v == null ? 'Selecione um motivo' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _motivoDetalhamentoController,
                  decoration: const InputDecoration(labelText: 'Descrição Detalhada do Motivo', border: OutlineInputBorder()),
                  maxLines: 3,
                ),
              ],
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
    return Card(
      elevation: 2.0,
      child: ListTile(
        leading: const Icon(Icons.calendar_today, color: Colors.indigo),
        title: Text(date == null ? label : '$label: ${DateFormat('dd/MM/yyyy HH:mm').format(date)}', style: TextStyle(fontWeight: date != null ? FontWeight.bold: FontWeight.normal)),
        trailing: date != null ? IconButton(icon: const Icon(Icons.clear, color: Colors.red), onPressed: onClear) : null,
        onTap: onTap,
      ),
    );
  }
}
