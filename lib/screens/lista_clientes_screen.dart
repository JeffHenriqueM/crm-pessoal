import 'package:flutter/material.dart';

import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/app_bar.dart';
import '../widgets/cliente_list_filtered.dart';
import '../widgets/kanban_view.dart';
import 'ficha_cliente_screen.dart';

class ListaClientesScreen extends StatefulWidget {
  final FaseCliente? faseInicial;
  final String? vendedorIdInicial;
  const ListaClientesScreen(
      {super.key, this.faseInicial, this.vendedorIdInicial});

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
  bool _usarKanban = false;
  late Stream<List<Cliente>> _clientesStream;
  String? _vendedorIdFiltro;
  String _filtroTexto = '';
  String _ordenarPor = 'dataAtualizacao';
  bool _descendente = true;

  bool get _isAdmin => _userProfile == 'admin';

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
        setState(() {
          _vendedorIdFiltro = widget.vendedorIdInicial;
          _clientesStream = _firestoreService.getTodosClientesStream(
            vendedorId: _vendedorIdFiltro,
            ordenarPor: _ordenarPor,
            descendente: _descendente,
          );
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
    if (isTyping) return;
    if (!mounted) return;
    setState(() {
      if (_estaPesquisando) {
        _filtroTexto = '';
        _searchController.clear();
      }
      _estaPesquisando = !_estaPesquisando;
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

  void _handleToggleView() {
    setState(() {
      _usarKanban = !_usarKanban;
      // Ao entrar no kanban, fecha a busca se estava aberta
      if (_usarKanban && _estaPesquisando) {
        _estaPesquisando = false;
        _filtroTexto = '';
        _searchController.clear();
      }
    });
  }

  void _abrirFicha(Cliente? cliente) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FichaClienteScreen(cliente: cliente),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Cliente>>(
      stream: _clientesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
                child: Text('Erro ao carregar dados: ${snapshot.error}')),
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
            usarKanban: _usarKanban,
            searchController: _searchController,
            tabController: _tabController,
            onSearchStateChange: _handleSearchStateChange,
            onSortChange: _handleSortChange,
            onToggleView: _handleToggleView,
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _abrirFicha(null),
            tooltip: 'Novo Cliente',
            child: const Icon(Icons.add),
          ),
          body: _buildBody(todosClientes),
        );
      },
    );
  }

  Widget _buildBody(List<Cliente> todosClientes) {
    // ── Kanban ──────────────────────────────────────────────────────
    if (_usarKanban) {
      return KanbanView(
        clientes: todosClientes,
        isAdmin: _isAdmin,
        onCardTap: _abrirFicha,
      );
    }

    // ── Busca ────────────────────────────────────────────────────────
    if (_estaPesquisando) {
      return _buildSearchResults(todosClientes);
    }

    // ── Lista por abas ───────────────────────────────────────────────
    return TabBarView(
      controller: _tabController,
      children: FaseCliente.values.map((fase) {
        final clientesDaAba =
            todosClientes.where((c) => c.fase == fase).toList();
        return ClienteListFiltered(
          clientes: clientesDaAba,
          filtroNome: '',
          onTileTap: _abrirFicha,
        );
      }).toList(),
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
      onTileTap: _abrirFicha,
    );
  }
}
