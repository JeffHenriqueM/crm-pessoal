import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../models/usuario_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/url_launcher_service.dart';
import '../widgets/app_bar.dart';
import '../widgets/cliente_list_filtered.dart';
import '../widgets/editar_cliente_detalhes_screen.dart';
import 'adicionar_cliente_screen.dart';
import 'dashboard_screen.dart';
import 'interacoes_screen.dart';

class ListaClientesScreen extends StatefulWidget {
  final FaseCliente? faseInicial;
  final String? vendedorIdInicial;
  const ListaClientesScreen({super.key, this.faseInicial, this.vendedorIdInicial});

  @override
  State<ListaClientesScreen> createState() => _ListaClientesScreenState();
}

class _ListaClientesScreenState extends State<ListaClientesScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  String _userProfile = 'vendedor';
  bool _estaPesquisando = false;
  late Stream<List<Cliente>> _clientesStream;
  List<Usuario> _todosVendedores = [];
  String? _vendedorIdFiltro;
  String _filtroTexto = '';
  String _ordenarPor = 'dataAtualizacao';
  bool _descendente = true;

  @override
  void initState() {
    super.initState();
    _inicializarEstado();
  }

  void _inicializarEstado() {
    _vendedorIdFiltro = _authService.getCurrentUser()?.uid;
    _clientesStream = _firestoreService.getTodosClientesStream(
      vendedorId: _vendedorIdFiltro,
      ordenarPor: _ordenarPor,
      descendente: _descendente,
    );

    _authService.getCurrentUserProfile().then((perfil) {
      if (!mounted) return;
      setState(() => _userProfile = perfil);
      if (perfil == 'admin') {
        _firestoreService.getTodosUsuarios().then((vendedores) {
          if (!mounted) return;
          setState(() {
            _todosVendedores = vendedores;
            // Se veio do dashboard admin com filtro de vendedor, aplicar
            if (widget.vendedorIdInicial != null) {
              _vendedorIdFiltro = widget.vendedorIdInicial;
              _clientesStream = _firestoreService.getTodosClientesStream(
                vendedorId: _vendedorIdFiltro,
                ordenarPor: _ordenarPor,
                descendente: _descendente,
              );
            } else {
              // Admin sem filtro inicial vê todos
              _vendedorIdFiltro = null;
              _clientesStream = _firestoreService.getTodosClientesStream(
                vendedorId: null,
                ordenarPor: _ordenarPor,
                descendente: _descendente,
              );
            }
          });
        });
      }
    });

    final initialIndex = widget.faseInicial != null
        ? FaseCliente.values.indexOf(widget.faseInicial!)
        : 0;
    _tabController = TabController(
      length: FaseCliente.values.length,
      vsync: this,
      initialIndex: initialIndex,
    );
    _searchController.addListener(() {
      if (mounted) setState(() => _filtroTexto = _searchController.text);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchStateChange(bool isTyping) {
    if (isTyping) return; // Listener do controller já atualiza _filtroTexto
    if (!mounted) return;
    setState(() {
      if (_estaPesquisando) {
        _filtroTexto = '';
        _searchController.clear();
      }
      _estaPesquisando = !_estaPesquisando;
    });
  }

  void _handleVendedorChange(String? novoVendedorId) {
    if (!mounted) return;
    setState(() {
      _vendedorIdFiltro = novoVendedorId;
      _clientesStream = _firestoreService.getTodosClientesStream(
        vendedorId: _vendedorIdFiltro,
        ordenarPor: _ordenarPor,
        descendente: _descendente,
      );
    });
  }

  void _handleSortChange(String novaOrdem) {
    if (!mounted) return;
    setState(() {
      if (_ordenarPor == novaOrdem) {
        _descendente = !_descendente;
      } else {
        _ordenarPor = novaOrdem;
        _descendente = novaOrdem == 'dataAtualizacao';
      }
      _clientesStream = _firestoreService.getTodosClientesStream(
        vendedorId: _vendedorIdFiltro,
        ordenarPor: _ordenarPor,
        descendente: _descendente,
      );
    });
  }

  Future<void> _handleLogout() async {
    await _authService.signOut();
  }

  void _abrirDashboard() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  void _abrirAdicionarCliente() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdicionarClienteScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Cliente>>(
      stream: _clientesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Erro ao carregar dados: ${snapshot.error}')),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final todosClientes = snapshot.data ?? [];

        return Scaffold(
          appBar: ListaClientesAppBar(
            estaPesquisando: _estaPesquisando,
            userProfile: _userProfile,
            todosVendedores: _todosVendedores,
            vendedorIdFiltro: _vendedorIdFiltro,
            searchController: _searchController,
            tabController: _tabController,
            onSearchStateChange: _handleSearchStateChange,
            onVendedorChange: _handleVendedorChange,
            onSortChange: _handleSortChange,
            onLogout: _handleLogout,
            onShowDashboard: _abrirDashboard,
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _abrirAdicionarCliente,
            tooltip: 'Adicionar Cliente',
            child: const Icon(Icons.add),
          ),
          body: _estaPesquisando
              ? _buildSearchResults(todosClientes)
              : TabBarView(
                  controller: _tabController,
                  children: FaseCliente.values.map((fase) {
                    final clientesDaAba =
                        todosClientes.where((c) => c.fase == fase).toList();
                    return ClienteListFiltered(
                      clientes: clientesDaAba,
                      filtroNome: '',
                      onTileTap: _mostrarOpcoesCliente,
                    );
                  }).toList(),
                ),
        );
      },
    );
  }

  Widget _buildSearchResults(List<Cliente> todosClientes) {
    final busca = _filtroTexto.toLowerCase().trim();
    final filtrados = todosClientes.where((c) {
      return c.nome.toLowerCase().contains(busca) ||
          (c.nomeEsposa ?? '').toLowerCase().contains(busca) ||
          (c.vendedorNome ?? '').toLowerCase().contains(busca);
    }).toList();

    return ClienteListFiltered(
      clientes: filtrados,
      filtroNome: _filtroTexto,
      onTileTap: _mostrarOpcoesCliente,
    );
  }

  void _mostrarOpcoesCliente(
      BuildContext context, Cliente cliente, FirestoreService service) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Editar Detalhes'),
            onTap: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => EditarClienteDetalhesScreen(cliente: cliente),
              ));
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Ver Interações'),
            onTap: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => InteracoesScreen(cliente: cliente),
              ));
            },
          ),
          if (cliente.telefoneContato?.isNotEmpty == true)
            ListTile(
              leading:
                  const Icon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366)),
              title: const Text('Conversar no WhatsApp'),
              onTap: () async {
                Navigator.of(ctx).pop();
                try {
                  await UrlLauncherService().abrirWhatsApp(cliente.telefoneContato!);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
            ),
          ListTile(
            leading: const Icon(Icons.swap_horiz_outlined),
            title: const Text('Mudar Fase'),
            onTap: () {
              Navigator.of(ctx).pop();
              _mostrarMudarFaseDialog(context, cliente, service);
            },
          ),
          if (cliente.proximoContato != null)
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Adicionar à Agenda'),
              onTap: () {
                Navigator.of(ctx).pop();
                _adicionarEventoNaAgenda(cliente);
              },
            ),
          ListTile(
            leading: Icon(Icons.delete_outline,
                color: Theme.of(ctx).colorScheme.error),
            title: Text('Apagar Cliente',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            onTap: () {
              Navigator.of(ctx).pop();
              _confirmarExclusao(context, cliente, service);
            },
          ),
        ],
      ),
    );
  }

  void _mostrarMudarFaseDialog(
      BuildContext context, Cliente cliente, FirestoreService service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mudar Fase'),
        content: DropdownButton<FaseCliente>(
          value: cliente.fase,
          isExpanded: true,
          onChanged: (novaFase) {
            if (novaFase == null) return;
            Navigator.of(ctx).pop();
            if (novaFase == FaseCliente.perdido) {
              _confirmarPerda(context, cliente, service);
            } else {
              service.atualizarFaseCliente(cliente.id!, novaFase);
            }
          },
          items: FaseCliente.values
              .map((f) => DropdownMenuItem(value: f, child: Text(f.nomeDisplay)))
              .toList(),
        ),
      ),
    );
  }

  void _confirmarPerda(
      BuildContext context, Cliente cliente, FirestoreService service) {
    final motivoCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Perda'),
        content: TextField(
          controller: motivoCtrl,
          decoration:
              const InputDecoration(hintText: 'Qual o motivo da perda?'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              service.atualizarFaseCliente(
                cliente.id!,
                FaseCliente.perdido,
                motivo: motivoCtrl.text.trim(),
              );
              Navigator.of(ctx).pop();
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _adicionarEventoNaAgenda(Cliente cliente) {
    if (cliente.proximoContato == null) return;
    final event = Event(
      title: 'Contato: ${cliente.nome}',
      description: 'Ligar para ${cliente.nome}.',
      location: 'CRM Villamor',
      startDate: cliente.proximoContato!,
      endDate: cliente.proximoContato!.add(const Duration(minutes: 30)),
    );
    Add2Calendar.addEvent2Cal(event);
  }

  void _confirmarExclusao(
      BuildContext context, Cliente cliente, FirestoreService firestoreService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
            'Tem certeza que deseja apagar permanentemente "${cliente.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final errorColor = Theme.of(context).colorScheme.error;
              await firestoreService.deletarCliente(cliente.id!);
              if (ctx.mounted) nav.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text('"${cliente.nome}" foi removido.'),
                  backgroundColor: errorColor,
                ),
              );
            },
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
  }
}
