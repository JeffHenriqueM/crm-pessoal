// lib/widgets/editar_cliente_detalhes_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../services/firestore_service.dart';
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
  late TextEditingController _motivoPerdaDescricaoController;

  late FaseCliente _faseSelecionada;
  late String _tipoSelecionado;

  DateTime? _proximoContatoSelecionado;
  DateTime? _proximaVisitaSelecionada;

  // --- LÓGICA DE PERDA ---
  String? _motivoPerdaSelecionado;
  final List<String> _motivosOpcoes = [
    'Financeiro', 'Distância', 'Não conhecem a Villamor', 'Sem interesse',
    'Perfil Inadequado', 'Sem retorno', 'Outro'
  ];
  // --- FIM LÓGICA DE PERDA ---

  // +++ CAMPO DE ORIGEM CORRIGIDO +++
  String? _origemSelecionada;
  // A lista de opções volta ao normal, sem "Antigo"
  final List<String> _origemOpcoes = ['Presencial', 'WhatsApp', 'Instagram'];
  // +++++++++++++++++++++++++++++++

  // Vendedores
  Usuario? _vendedorSelecionado;
  List<Usuario> _listaDeVendedores = [];
  bool _carregandoVendedores = true;

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
    _motivoPerdaDescricaoController = TextEditingController(text: widget.cliente.motivoNaoVenda);

    _faseSelecionada = widget.cliente.fase;
    _tipoSelecionado = widget.cliente.tipo;
    _proximoContatoSelecionado = widget.cliente.proximoContato;
    _proximaVisitaSelecionada = widget.cliente.dataVisita; // Corrigido aqui

    _motivoPerdaSelecionado = widget.cliente.motivoNaoVendaDropdown;

    if (_origemOpcoes.contains(widget.cliente.origem)) {
      _origemSelecionada = widget.cliente.origem;
    } else {
      _origemSelecionada = null; // Deixa o campo sem valor, mostrando o "hintText"
    }
    // +++++++++++++++++++++++++++++++++++++++++++++++++
  }

  Future<void> _carregarVendedores() async {
    final vendedores = await _firestoreService.getTodosUsuarios();
    if (mounted) {
      setState(() {
        _listaDeVendedores = vendedores;
        if (widget.cliente.vendedorId != null) {
          try {
            _vendedorSelecionado = _listaDeVendedores.firstWhere(
                    (v) => v.id == widget.cliente.vendedorId
            );
          } catch (e) {
            _vendedorSelecionado = null;
          }
        }
        _carregandoVendedores = false;
      });
    }
  }

  Future<void> _selecionarData(BuildContext context, Function(DateTime) onSelect) async {
    final DateTime? dataEscolhida = await showDatePicker(
      context: context,
      initialDate: _proximaVisitaSelecionada ?? _proximoContatoSelecionado ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );

    if (dataEscolhida == null || !mounted) return;

    onSelect(DateTime(dataEscolhida.year, dataEscolhida.month, dataEscolhida.day));
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final Map<String, dynamic> dadosParaAtualizar = {
        'nome': _nomeController.text.trim(),
        'tipo': _tipoSelecionado,
        'nomeEsposa': _tipoSelecionado == 'Casal' ? _nomeParceiroController.text.trim() : null,
        'telefoneContato': _telefoneController.text.trim(),
        'fase': _faseSelecionada.toString().split('.').last,
        'proximoContato': _proximoContatoSelecionado,
        'proximaVisita': _proximaVisitaSelecionada,
        'origem': _origemSelecionada,
        'vendedorId': _vendedorSelecionado?.id,
        'vendedorNome': _vendedorSelecionado?.nome,
        'motivoNaoVenda': _faseSelecionada == FaseCliente.perdido ? _motivoPerdaDescricaoController.text.trim() : null,
        'motivoNaoVendaDropdown': _faseSelecionada == FaseCliente.perdido ? _motivoPerdaSelecionado : null,
      };

      try {
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
      body: Padding(
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
              // Agora, se o valor for antigo, o hintText "Selecione a origem" será exibido
              DropdownButtonFormField<String>(
                value: _origemSelecionada,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Origem do Cliente *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.public),
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
              const SizedBox(height: 20),
              DropdownButtonFormField<FaseCliente>(
                decoration: const InputDecoration(labelText: 'Fase no Funil', border: OutlineInputBorder(), prefixIcon: Icon(Icons.flag_outlined)),
                value: _faseSelecionada,
                items: FaseCliente.values.map((fase) => DropdownMenuItem(value: fase, child: Text(fase.nomeDisplay))).toList(),
                onChanged: (v) => setState(() => _faseSelecionada = v!),
              ),
              const SizedBox(height: 20),
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
              _buildDateTile('Próxima Visita', _proximaVisitaSelecionada, () => _selecionarData(context, (date) => setState(() => _proximaVisitaSelecionada = date)), () => setState(() => _proximaVisitaSelecionada = null)),

              if (_faseSelecionada == FaseCliente.perdido) ...[
                const Divider(height: 40),
                const Text("Dados de Desistência", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Motivo Principal', border: OutlineInputBorder()),
                  value: _motivoPerdaSelecionado,
                  items: _motivosOpcoes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setState(() => _motivoPerdaSelecionado = v),
                  validator: (v) => _faseSelecionada == FaseCliente.perdido && v == null ? 'Selecione um motivo' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _motivoPerdaDescricaoController,
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
        title: Text(date == null ? label : '$label: ${DateFormat('dd/MM/yyyy').format(date)}', style: TextStyle(fontWeight: date != null ? FontWeight.bold: FontWeight.normal)),
        trailing: date != null ? IconButton(icon: const Icon(Icons.clear, color: Colors.red), onPressed: onClear) : null,
        onTap: onTap,
      ),
    );
  }
}
