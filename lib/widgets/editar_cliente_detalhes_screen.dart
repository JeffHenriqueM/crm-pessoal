// lib/screens/editar_cliente_detalhes_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 1. IMPORTAR PACOTE INTl
import '../models/cliente_model.dart';
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
  late String _tipoSelecionado;
  DateTime? _proximoContatoSelecionado; // 2. ADICIONAR ESTADO PARA A DATA
  DateTime? _dataVisitaSelecionada;

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();

    // Inicializa os controladores com os DADOS EXISTENTES do cliente
    _nomeController = TextEditingController(text: widget.cliente.nome);
    _telefoneController = TextEditingController(text: widget.cliente.telefoneContato);
    _nomeParceiroController = TextEditingController(text: widget.cliente.nomeEsposa);
    _tipoSelecionado = widget.cliente.tipo;
    _proximoContatoSelecionado = widget.cliente.proximoContato;
    _dataVisitaSelecionada = widget.cliente.dataVisita;
  }

  // 4. FUNÇÃO PARA SELECIONAR DATA E HORA
  Future<void> _selecionarProximoContato(BuildContext context) async {
    final DateTime? dataEscolhida = await showDatePicker(
      context: context,
      initialDate: _proximoContatoSelecionado ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)), // Permite ver/editar datas passadas recentes
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
        dataEscolhida.year,
        dataEscolhida.month,
        dataEscolhida.day,
        horaEscolhida.hour,
        horaEscolhida.minute,
      );
    });
  }

  Future<void> _selecionarDataVisita(BuildContext context) async {
    final DateTime? dataEscolhida = await showDatePicker(
      context: context,
      initialDate: _dataVisitaSelecionada ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)), // Permite ver/editar datas passadas recentes
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
        dataEscolhida.year,
        dataEscolhida.month,
        dataEscolhida.day,
        horaEscolhida.hour,
        horaEscolhida.minute,
      );
    });
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {

      final String? parceiro = _tipoSelecionado == 'Casal'
          ? _nomeParceiroController.text
          : null;

      try {
        // Usa o método de atualização do FirestoreService
        await _firestoreService.atualizarClienteDetalhes(
          widget.cliente.id!,
          _nomeController.text,
          _tipoSelecionado,
          _telefoneController.text,
          parceiro,
          _proximoContatoSelecionado, // 5. ENVIAR A NOVA DATA
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Editar Cliente: ${widget.cliente.nome}'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              // ... Seus campos existentes (Nome, Telefone, Tipo, etc.) ...
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: 'Nome do Cliente', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'Insira o nome.' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _telefoneController,
                decoration: const InputDecoration(labelText: 'Telefone', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
                validator: (v) => v == null || v.isEmpty ? 'Insira o telefone.' : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Tipo de Cliente', border: OutlineInputBorder()),
                value: _tipoSelecionado,
                items: ['Solteiro', 'Casal'].map((t) => DropdownMenuItem<String>(value: t, child: Text(t))).toList(),
                onChanged: (v) {
                  setState(() => _tipoSelecionado = v!);
                  if (v == 'Solteiro') _nomeParceiroController.clear();
                },
              ),
              const SizedBox(height: 20),
              if (_tipoSelecionado == 'Casal')
                Column(
                  children: [
                    TextFormField(
                      controller: _nomeParceiroController,
                      decoration: const InputDecoration(labelText: 'Nome do(a) Parceiro(a)', border: OutlineInputBorder()),
                      validator: (v) => _tipoSelecionado == 'Casal' && (v == null || v.isEmpty) ? 'Insira o nome.' : null,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),

              // 6. WIDGET PARA EDITAR A DATA
              Card(
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: ListTile(
                  leading: const Icon(Icons.calendar_today, color: Colors.indigo),
                  title: Text(
                    _proximoContatoSelecionado == null
                        ? 'Agendar Próximo Contato'
                        : 'Próximo contato: ${DateFormat('dd/MM/yyyy HH:mm').format(_proximoContatoSelecionado!)}',
                    style: TextStyle(
                      color: _proximoContatoSelecionado == null ? Colors.grey.shade600 : Colors.white,
                      fontWeight: _proximoContatoSelecionado == null ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  trailing: _proximoContatoSelecionado != null ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red),
                    onPressed: () => setState(() => _proximoContatoSelecionado = null),
                  ) : null,
                  onTap: () => _selecionarProximoContato(context),
                ),
              ),

              // 6. WIDGET PARA EDITAR A DATA
              Card(
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: ListTile(
                  leading: const Icon(Icons.calendar_today, color: Colors.indigo),
                  title: Text(
                    _dataVisitaSelecionada == null
                        ? 'Agendar Proxima Visita'
                        : 'Próxima Visita: ${DateFormat('dd/MM/yyyy HH:mm').format(_dataVisitaSelecionada!)}',
                    style: TextStyle(
                      color: _dataVisitaSelecionada == null ? Colors.grey.shade600 : Colors.white,
                      fontWeight: _dataVisitaSelecionada == null ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  trailing: _dataVisitaSelecionada != null ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red),
                    onPressed: () => setState(() => _dataVisitaSelecionada = null),
                  ) : null,
                  onTap: () => _selecionarDataVisita(context),
                ),
              ),

              const SizedBox(height: 30),

              // Botão de Envio
              ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.edit),
                label: const Text('SALVAR ALTERAÇÕES', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
