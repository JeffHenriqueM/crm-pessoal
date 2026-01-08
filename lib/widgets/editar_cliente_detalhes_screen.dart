// lib/screens/editar_cliente_detalhes_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart'; // IMPORTANTE: Certifique-se que o caminho do seu enum está correto aqui
import '../services/firestore_service.dart';

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

  late FaseCliente _faseSelecionada; // Agora é mutável via Dropdown
  late String _tipoSelecionado;

  DateTime? _proximoContatoSelecionado;
  DateTime? _dataVisitaSelecionada;
  String? _motivoDropdownSelecionado;

  final List<String> _motivosOpcoes = [
    'Financeiro',
    'Distância',
    'Não conhecem a Villamor',
    'Sem interesse',
    'Perfil Inadequado',
    'Sem retorno'
  ];

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();

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

  Future<void> _selecionarProximoContato(BuildContext context) async {
    final DateTime? dataEscolhida = await showDatePicker(
      context: context,
      initialDate: _proximoContatoSelecionado ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime(2101),
    );

    if (dataEscolhida == null || !mounted) return;

    final TimeOfDay? horaEscolhida = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_proximoContatoSelecionado ?? DateTime.now()),
    );

    if (horaEscolhida == null) return;

    setState(() {
      _proximoContatoSelecionado = DateTime(
        dataEscolhida.year, dataEscolhida.month, dataEscolhida.day,
        horaEscolhida.hour, horaEscolhida.minute,
      );
    });
  }

  Future<void> _selecionarDataVisita(BuildContext context) async {
    final DateTime? dataEscolhida = await showDatePicker(
      context: context,
      initialDate: _dataVisitaSelecionada ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime(2101),
    );

    if (dataEscolhida == null || !mounted) return;

    final TimeOfDay? horaEscolhida = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dataVisitaSelecionada ?? DateTime.now()),
    );

    if (horaEscolhida == null) return;

    setState(() {
      _dataVisitaSelecionada = DateTime(
        dataEscolhida.year, dataEscolhida.month, dataEscolhida.day,
        horaEscolhida.hour, horaEscolhida.minute,
      );
    });
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final String? parceiro = _tipoSelecionado == 'Casal' ? _nomeParceiroController.text : null;

      try {
        await _firestoreService.atualizarClienteDetalhes(
          widget.cliente.id!,
          _nomeController.text,
          _tipoSelecionado,
          _telefoneController.text,
          parceiro,
          _proximoContatoSelecionado,
          dataVisita: _dataVisitaSelecionada,
          fase: _faseSelecionada, // Enviando a fase atualizada
          motivoNaoVenda: _faseSelecionada == FaseCliente.perdido ? _motivoDetalhamentoController.text : null,
          motivoNaoVendaDropdown: _faseSelecionada == FaseCliente.perdido ? _motivoDropdownSelecionado : null,
        );

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Detalhes de ${_nomeController.text} atualizados!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao atualizar: Tente novamente.')),
          );
        }
      }
    }
  }

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
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: 'Nome do Cliente', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'Insira o nome.' : null,
              ),
              const SizedBox(height: 20),

              // SELETOR DE FASE (NOVO)
              DropdownButtonFormField<FaseCliente>(
                decoration: const InputDecoration(labelText: 'Fase no Funil', border: OutlineInputBorder(), prefixIcon: Icon(Icons.loop)),
                value: _faseSelecionada,
                items: FaseCliente.values.map((fase) => DropdownMenuItem(value: fase, child: Text(fase.nomeDisplay))).toList(),
                onChanged: (v) => setState(() => _faseSelecionada = v!),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _telefoneController,
                decoration: const InputDecoration(labelText: 'Telefone', border: OutlineInputBorder()),
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

              // AGENDAMENTOS
              _buildDateTile('Próximo Contato', _proximoContatoSelecionado, () => _selecionarProximoContato(context), (val) => setState(() => _proximoContatoSelecionado = val)),
              const SizedBox(height: 10),
              _buildDateTile('Próxima Visita', _dataVisitaSelecionada, () => _selecionarDataVisita(context), (val) => setState(() => _dataVisitaSelecionada = val)),

              // CAMPOS DE PERDA (DINÂMICOS)
              if (_faseSelecionada == FaseCliente.perdido) ...[
                const Divider(height: 40),
                const Text("Dados de Desistência", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
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
                  decoration: const InputDecoration(labelText: 'Descrição Detalhada', border: OutlineInputBorder()),
                  maxLines: 3,
                ),
              ],

              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.save),
                label: const Text('SALVAR ALTERAÇÕES'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTile(String label, DateTime? date, VoidCallback onTap, Function(DateTime?) onClear) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_today, color: Colors.indigo),
        title: Text(date == null ? label : '$label: ${DateFormat('dd/MM/yyyy HH:mm').format(date)}'),
        trailing: date != null ? IconButton(icon: const Icon(Icons.clear, color: Colors.red), onPressed: () => onClear(null)) : null,
        onTap: onTap,
      ),
    );
  }
}
