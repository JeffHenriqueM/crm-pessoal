// lib/screens/adicionar_cliente_screen.dart

import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../models/usuario_model.dart'; // <--- IMPORTAR O NOVO MODELO
import '../services/firestore_service.dart';

class AdicionarClienteScreen extends StatefulWidget {
  const AdicionarClienteScreen({super.key});

  @override
  State<AdicionarClienteScreen> createState() => _AdicionarClienteScreenState();
}

class _AdicionarClienteScreenState extends State<AdicionarClienteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();

  // Controladores para os campos do formulário
  final _nomeController = TextEditingController();
  final _nomeEsposaController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _origemController = TextEditingController();

  String _tipoCliente = 'Casal';

  // Variáveis para o dropdown de vendedores
  Usuario? _vendedorSelecionado;
  List<Usuario> _listaDeVendedores = [];
  bool _carregandoVendedores = true;

  @override
  void initState() {
    super.initState();
    _carregarVendedores();
  }

  Future<void> _carregarVendedores() async {
    final vendedores = await _firestoreService.getTodosUsuarios();
    setState(() {
      _listaDeVendedores = vendedores;
      _carregandoVendedores = false;
    });
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _nomeEsposaController.dispose();
    _telefoneController.dispose();
    _origemController.dispose();
    super.dispose();
  }

  Future<void> _salvarCliente() async {
    if (_formKey.currentState!.validate()) {
      // Cria o objeto Cliente com todos os dados, incluindo o vendedor
      final novoCliente = Cliente(
        nome: _nomeController.text,
        nomeEsposa: _nomeEsposaController.text,
        telefoneContato: _telefoneController.text,
        tipo: _tipoCliente,
        origem: _origemController.text,
        fase: FaseCliente.prospeccao,
        dataCadastro: DateTime.now(), // O serviço substituirá pelo timestamp do servidor
        dataAtualizacao: DateTime.now(), // O serviço substituirá pelo timestamp do servidor

        // Atribuindo o vendedor selecionado
        vendedorId: _vendedorSelecionado?.id,
        vendedorNome: _vendedorSelecionado?.nome,
        // Os campos de auditoria (criadoPor, etc.) serão preenchidos pelo FirestoreService
      );

      try {
        await _firestoreService.adicionarCliente(novoCliente);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cliente adicionado com sucesso!')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao salvar cliente: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar Novo Cliente'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: 'Nome Principal'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O nome é obrigatório.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _tipoCliente,
                decoration: const InputDecoration(labelText: 'Tipo de Cliente'),
                items: ['Casal', 'Individual']
                    .map((label) => DropdownMenuItem(
                  child: Text(label),
                  value: label,
                ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _tipoCliente = value!;
                  });
                },
              ),
              if (_tipoCliente == 'Casal') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nomeEsposaController,
                  decoration: const InputDecoration(labelText: 'Nome do Cônjuge/Parceiro(a)'),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _telefoneController,
                decoration: const InputDecoration(labelText: 'Telefone de Contato'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _origemController,
                decoration: const InputDecoration(labelText: 'Origem do Cliente (Ex: Indicação, Instagram)'),
              ),
              const SizedBox(height: 24),

              // ----- NOVO CAMPO DE SELEÇÃO DE VENDEDOR -----
              _carregandoVendedores
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<Usuario>(
                value: _vendedorSelecionado,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Vendedor Responsável',
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Atribuir a...'),
                items: _listaDeVendedores.map((vendedor) {
                  return DropdownMenuItem<Usuario>(
                    value: vendedor,
                    child: Text(vendedor.nome),
                  );
                }).toList(),
                onChanged: (Usuario? newValue) {
                  setState(() {
                    _vendedorSelecionado = newValue;
                  });
                },
                // Permite limpar a seleção
                // Adicione um botão ou lógica se precisar dessa funcionalidade
              ),

              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _salvarCliente,
                icon: const Icon(Icons.save),
                label: const Text('Salvar Cliente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
