// lib/screens/adicionar_cliente_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 1. IMPORTAR PACOTE INTl

// Certifique-se de que estes imports estão corretos (ajuste se a estrutura de pastas for diferente)
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../services/firestore_service.dart';

class AdicionarClienteScreen extends StatefulWidget {
  const AdicionarClienteScreen({super.key});

  @override
  State<AdicionarClienteScreen> createState() => _AdicionarClienteScreenState();
}

class _AdicionarClienteScreenState extends State<AdicionarClienteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _telefoneContatoController = TextEditingController();
  final _nomeEsposaController = TextEditingController();
  final _motivoController = TextEditingController(); // ADICIONE AQUI
  final FirestoreService _firestoreService = FirestoreService();
  DateTime? _proximoContatoSelecionado;
  DateTime? _dataVisitaSelecionada;
  String? _motivoDropdownSelecionado; // Novo estado para o Dropdown
  final List<String> _motivosOpcoes = [
    'Financeiro',
    'Distância',
    'Não conhecem a Villamor',
    'Sem interesse',
    'Perfil Inadequado',
    'Sem retorno'
  ];


  // Estados iniciais do formulário
  String? _tipoSelecionado = 'Solteiro';
  FaseCliente _faseSelecionada = FaseCliente.prospeccao;

  String _origemSelecionada = 'Online';

  // 2. FUNÇÃO PARA SELECIONAR DATA E HORA
  Future<void> _selecionarProximoContato(BuildContext context) async {
    final DateTime? dataEscolhida = await showDatePicker(
      context: context,
      initialDate: _proximoContatoSelecionado ?? DateTime.now(),
      firstDate: DateTime.now(),
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
      firstDate: DateTime.now(),
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


  // Função de submissão do formulário
  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final String? esposa = _tipoSelecionado == 'Casal'
          ? _nomeEsposaController.text
          : null;
      final novoCliente = Cliente(
        nome: _nomeController.text,
        tipo: _tipoSelecionado!,
        fase: _faseSelecionada,
        telefoneContato: _telefoneContatoController.text,
        dataCadastro: DateTime.now(),
        dataAtualizacao: DateTime.now(),
        nomeEsposa: esposa,
        proximoContato: _proximoContatoSelecionado,
        dataVisita: _dataVisitaSelecionada,
        origem: _origemSelecionada,
        // Campo NOVO: Armazena apenas a opção selecionada para o GRÁFICO
        motivoNaoVendaDropdown: _faseSelecionada == FaseCliente.perdido
            ? _motivoDropdownSelecionado
            : null,

        // Campo ANTIGO: Armazena a descrição detalhada (preserva o histórico)
        motivoNaoVenda: _faseSelecionada == FaseCliente.perdido
            ? _motivoController.text
            : null,

      );

      try {
        await _firestoreService.adicionarCliente(novoCliente);

        // Mostrar feedback de sucesso
        if (mounted) {

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cliente ${_nomeController.text} adicionado com sucesso!')),
          );
          // Limpa o formulário após o sucesso
          _telefoneContatoController.clear();
          _nomeEsposaController.clear();
          _nomeController.clear();
          setState(() {
            _tipoSelecionado = 'Solteiro';
            _faseSelecionada = FaseCliente.prospeccao;
            _proximoContatoSelecionado = null; // Limpa a data selecionada também
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao salvar no Firebase. Verifique a conexão.')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _telefoneContatoController.dispose(); // CORREÇÃO: use dispose() ao invés de clear()
    _nomeEsposaController.dispose();   // CORREÇÃO: use dispose() ao invés de clear()
    _motivoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar Novo Cliente'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              // ... (seus outros campos de formulário como Nome, Telefone, etc)
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Cliente',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o nome.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _telefoneContatoController,
                decoration: const InputDecoration(
                  labelText: 'Telefone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) => value == null || value.isEmpty ? 'Insira o telefone.' : null,
              ),
              const SizedBox(height: 20),
              if (_faseSelecionada == FaseCliente.perdido) ...[
                DropdownButtonFormField<String>(
                  value: _motivoDropdownSelecionado,
                  decoration: const InputDecoration(
                    labelText: 'Motivo Principal da Perda',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.list, color: Colors.orange),
                  ),
                  items: _motivosOpcoes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) => setState(() => _motivoDropdownSelecionado = val),
                  validator: (value) => _faseSelecionada == FaseCliente.perdido && value == null
                      ? 'Selecione o motivo principal'
                      : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _motivoController,
                  decoration: const InputDecoration(
                    labelText: 'Detalhes do Motivo (Opcional)',
                    hintText: 'Descreva observações adicionais...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.comment_bank, color: Colors.orange),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
              ],
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Ponto de Captação (Origem)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_searching),
                ),

                value: _origemSelecionada,
                items: ['Online', 'Presencial', 'Indicação', 'Outro'].map((String origem) {
                  return DropdownMenuItem<String>(
                    value: origem,
                    child: Text(origem),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _origemSelecionada = value!),
              ),
              const SizedBox(height: 20),


              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Tipo de Cliente',
                  border: OutlineInputBorder(),
                ),
                value: _tipoSelecionado,
                items: ['Solteiro', 'Casal'].map((String tipo) {
                  return DropdownMenuItem<String>(
                    value: tipo,
                    child: Text(tipo),
                  );
                }).toList(),
                onChanged: (String? novoTipo) {
                  setState(() {
                    _tipoSelecionado = novoTipo;
                  });
                  if (novoTipo == 'Solteiro') {
                    _nomeEsposaController.clear();
                  }
                },
              ),
              const SizedBox(height: 20),

              if (_tipoSelecionado == 'Casal')
                Column(
                  children: [
                    TextFormField(
                      controller: _nomeEsposaController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do(a) Parceiro(a)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Insira o nome do(a) parceiro(a).' : null,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),

              DropdownButtonFormField<FaseCliente>(
                decoration: const InputDecoration(
                  labelText: 'Fase Atual do Cliente',
                  border: OutlineInputBorder(),
                ),
                value: _faseSelecionada,
                items: FaseCliente.values.map((FaseCliente fase) {
                  return DropdownMenuItem<FaseCliente>(
                    value: fase,
                    child: Text(fase.nomeDisplay),
                  );
                }).toList(),
                onChanged: (FaseCliente? novaFase) {
                  setState(() {
                    _faseSelecionada = novaFase!;
                  });
                },
              ),
              const SizedBox(height: 20),

              // 4. WIDGET PARA SELECIONAR A DATA DO PRÓXIMO CONTATO
              Card(
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: ListTile(
                  leading: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                  title: Text(
                    _proximoContatoSelecionado == null
                        ? 'Agendar Próximo Contato'
                        : 'Próximo contato: ${DateFormat('dd/MM/yyyy HH:mm').format(_proximoContatoSelecionado!)}',
                    style: TextStyle(
                      color: _proximoContatoSelecionado == null ? Colors.grey.shade600 : Colors.black,
                    ),
                  ),
                  trailing: _proximoContatoSelecionado != null ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red),
                    onPressed: () => setState(() => _proximoContatoSelecionado = null),
                  ) : null,
                  onTap: () => _selecionarProximoContato(context),
                ),
              ),

              Card(
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: ListTile(
                  leading: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                  title: Text(
                    _dataVisitaSelecionada == null
                        ? 'Data de visita do cliente'
                        : 'Próxima visita: ${DateFormat('dd/MM/yyyy HH:mm').format(_dataVisitaSelecionada!)}',
                    style: TextStyle(
                      color: _dataVisitaSelecionada == null ? Colors.grey.shade600 : Colors.black,
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

              ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.save),
                label: const Text('SALVAR CLIENTE', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
