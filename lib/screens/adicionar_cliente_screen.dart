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

  final _nomeController = TextEditingController();
  final _nomeEsposaController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _motivoPerdaDescricaoController = TextEditingController();

  FaseCliente _faseSelecionada = FaseCliente.prospeccao;
  String _tipoCliente = 'Casal';
  DateTime? _proximoContato;
  DateTime? _proximaVisita;
  DateTime? _dataCaptacao;

  String? _origemSelecionada;
  static const _origemOpcoes = ['Presencial', 'WhatsApp', 'Instagram'];

  String? _motivoPerdaSelecionado;
  static const _motivosOpcoes = [
    'Financeiro',
    'Distância',
    'Não conhecem a Villamor',
    'Sem interesse',
    'Perfil Inadequado',
    'Sem retorno',
    'Outro',
  ];

  bool get _mostrarMotivoPerda => _faseSelecionada == FaseCliente.perdido;

  Usuario? _vendedorSelecionado;
  Usuario? _captadorSelecionado;
  List<Usuario> _listaDeUsuarios = [];
  bool _carregandoUsuarios = true;

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
        _carregandoUsuarios = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregandoUsuarios = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar usuários: $e')),
      );
    }
  }

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

  Future<void> _salvarCliente() async {
    if (!_formKey.currentState!.validate()) return;

    final novoCliente = Cliente(
      nome: _nomeController.text.trim(),
      nomeEsposa: _tipoCliente == 'Casal' ? _nomeEsposaController.text.trim() : null,
      telefoneContato: _telefoneController.text.trim(),
      tipo: _tipoCliente,
      origem: _origemSelecionada,
      fase: _faseSelecionada,
      dataCadastro: DateTime.now(),
      dataAtualizacao: DateTime.now(),
      proximoContato: _proximoContato,
      dataVisita: _proximaVisita,
      vendedorId: _vendedorSelecionado?.id,
      vendedorNome: _vendedorSelecionado?.nome,
      captadorId: _captadorSelecionado?.id,
      captadorNome: _captadorSelecionado?.nome,
      dataEntradaSala: _dataCaptacao,
      motivoNaoVendaDropdown: _mostrarMotivoPerda ? _motivoPerdaSelecionado : null,
      motivoNaoVenda: _mostrarMotivoPerda
          ? _motivoPerdaDescricaoController.text.trim()
          : null,
    );

    try {
      await _firestoreService.adicionarCliente(novoCliente);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cliente adicionado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erro ao salvar cliente: $e'),
            backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<void> _selecionarData(Function(DateTime) onSelect) async {
    final data = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (data != null && mounted) setState(() => onSelect(data));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo Cliente')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle('Dados Principais'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome Principal *',
                  prefixIcon: Icon(Icons.person_outlined),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Nome é obrigatório.' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _tipoCliente,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Cliente',
                  prefixIcon: Icon(Icons.group_outlined),
                ),
                items: ['Casal', 'Individual']
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => setState(() => _tipoCliente = v!),
              ),
              if (_tipoCliente == 'Casal') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nomeEsposaController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do Cônjuge/Parceiro(a)',
                    prefixIcon: Icon(Icons.favorite_border),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefone de Contato',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              _sectionTitle('Origem e Fase'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _origemSelecionada,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Origem do Cliente *',
                  prefixIcon: Icon(Icons.public_outlined),
                ),
                hint: const Text('Selecione a origem'),
                validator: (v) => v == null ? 'A origem é obrigatória.' : null,
                items: _origemOpcoes
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
                onChanged: _atualizarFasePorOrigem,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<FaseCliente>(
                value: _faseSelecionada,
                decoration: const InputDecoration(
                  labelText: 'Fase do Funil',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                items: FaseCliente.values
                    .map((f) => DropdownMenuItem(value: f, child: Text(f.nomeDisplay)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _faseSelecionada = v;
                    if (v != FaseCliente.perdido) {
                      _motivoPerdaSelecionado = null;
                      _motivoPerdaDescricaoController.clear();
                    }
                  });
                },
              ),
              if (_mostrarMotivoPerda) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _motivoPerdaSelecionado,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Motivo da Perda',
                    prefixIcon: Icon(Icons.mood_bad_outlined),
                  ),
                  items: _motivosOpcoes
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setState(() => _motivoPerdaSelecionado = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _motivoPerdaDescricaoController,
                  decoration: const InputDecoration(
                    labelText: 'Detalhe do Motivo',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  maxLines: 2,
                ),
              ],
              const SizedBox(height: 24),
              _sectionTitle('Equipe Responsável'),
              const SizedBox(height: 12),
              if (_carregandoUsuarios)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ))
              else ...[
                DropdownButtonFormField<Usuario>(
                  value: _captadorSelecionado,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Captador *',
                    prefixIcon: Icon(Icons.person_add_alt_1_outlined),
                  ),
                  hint: const Text('Quem captou o lead?'),
                  validator: (v) =>
                      v == null ? 'Informe o captador.' : null,
                  items: _listaDeUsuarios
                      .map((u) => DropdownMenuItem(value: u, child: Text(u.nome)))
                      .toList(),
                  onChanged: (v) => setState(() => _captadorSelecionado = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Usuario>(
                  value: _vendedorSelecionado,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Vendedor Responsável *',
                    prefixIcon: Icon(Icons.store_outlined),
                  ),
                  hint: const Text('Atribuir a...'),
                  validator: (v) =>
                      v == null ? 'Selecione um vendedor.' : null,
                  items: _listaDeUsuarios
                      .map((u) => DropdownMenuItem(value: u, child: Text(u.nome)))
                      .toList(),
                  onChanged: (v) => setState(() => _vendedorSelecionado = v),
                ),
              ],
              const SizedBox(height: 24),
              _sectionTitle('Datas'),
              const SizedBox(height: 8),
              _buildDateTile('Data da Captação', _dataCaptacao,
                  Icons.person_add_alt_1_outlined,
                  () => _selecionarData((d) => _dataCaptacao = d),
                  () => setState(() => _dataCaptacao = null)),
              _buildDateTile('Próximo Contato', _proximoContato,
                  Icons.phone_in_talk_outlined,
                  () => _selecionarData((d) => _proximoContato = d),
                  () => setState(() => _proximoContato = null)),
              _buildDateTile('Próxima Visita', _proximaVisita,
                  Icons.location_on_outlined,
                  () => _selecionarData((d) => _proximaVisita = d),
                  () => setState(() => _proximaVisita = null)),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _salvarCliente,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Salvar Cliente',
                    style: TextStyle(fontSize: 16)),
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

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildDateTile(
    String title,
    DateTime? date,
    IconData icon,
    VoidCallback onTap,
    VoidCallback onClear,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: date != null ? cs.primary : cs.outline),
        title: Text(title),
        subtitle: Text(
          date != null
              ? DateFormat('dd/MM/yyyy').format(date)
              : 'Não definido',
          style: TextStyle(
            color: date != null ? cs.primary : cs.outline,
            fontWeight: date != null ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: onTap,
        trailing: date != null
            ? IconButton(
                icon: Icon(Icons.clear, color: cs.outline),
                onPressed: onClear,
                tooltip: 'Limpar',
              )
            : null,
      ),
    );
  }
}
