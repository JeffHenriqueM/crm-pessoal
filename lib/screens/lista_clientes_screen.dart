import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../models/usuario_model.dart';
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

  // ── Filtros avançados ────────────────────────────────────────────────────
  String? _filtroOrigem;
  String? _filtroEmbaixadorId;
  String? _filtroEmbaixadorNome;
  DateTimeRange? _filtroPeriodo;
  List<Usuario> _vendedores = [];

  int get _totalFiltrosAtivos =>
      (_filtroOrigem != null ? 1 : 0) +
      (_filtroEmbaixadorId != null ? 1 : 0) +
      (_filtroPeriodo != null ? 1 : 0);

  bool get _isAdmin => _userProfile == 'admin' || _userProfile == 'super admin';

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
      if (perfil == 'admin' || perfil == 'super admin') {
        setState(() {
          _vendedorIdFiltro = widget.vendedorIdInicial;
          _clientesStream = _firestoreService.getTodosClientesStream(
            vendedorId: _vendedorIdFiltro,
            ordenarPor: _ordenarPor,
            descendente: _descendente,
          );
        });
        // Carrega lista de embaixadores para o filtro
        _firestoreService.getTodosUsuarios().then((lista) {
          if (mounted) setState(() => _vendedores = lista);
        });
      }
    });

    // Exclui atendimento das abas do funil (só aparece na recepção)
    final fasesVisiveis = FaseCliente.values
        .where((f) => f != FaseCliente.atendimento)
        .toList();
    final initialIndex = widget.faseInicial != null &&
            fasesVisiveis.contains(widget.faseInicial!)
        ? fasesVisiveis.indexOf(widget.faseInicial!)
        : 0;
    _tabController = TabController(
      length: fasesVisiveis.length,
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
        builder: (_) => FichaClienteScreen(cliente: cliente, userProfile: _userProfile),
      ),
    );
  }

  // ── Lógica de filtros ────────────────────────────────────────────────────
  List<Cliente> _aplicarFiltros(List<Cliente> lista) {
    var resultado = lista;
    if (_filtroOrigem != null) {
      resultado =
          resultado.where((c) => c.origem == _filtroOrigem).toList();
    }
    if (_filtroEmbaixadorId != null) {
      resultado = resultado
          .where((c) => c.vendedorId == _filtroEmbaixadorId)
          .toList();
    }
    if (_filtroPeriodo != null) {
      final fim = _filtroPeriodo!.end
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1));
      resultado = resultado.where((c) {
        return !c.dataCadastro.isBefore(_filtroPeriodo!.start) &&
            !c.dataCadastro.isAfter(fim);
      }).toList();
    }
    return resultado;
  }

  void _limparFiltros() =>
      setState(() {
        _filtroOrigem = null;
        _filtroEmbaixadorId = null;
        _filtroEmbaixadorNome = null;
        _filtroPeriodo = null;
      });

  void _abrirFiltros() {
    final fmt = DateFormat('dd/MM/yy');
    String? origemTemp = _filtroOrigem;
    String? embaixadorIdTemp = _filtroEmbaixadorId;
    String? embaixadorNomeTemp = _filtroEmbaixadorNome;
    DateTimeRange? periodoTemp = _filtroPeriodo;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final cs = Theme.of(ctx).colorScheme;
          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Handle ──────────────────────────────────────────
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Título + limpar ──────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Filtros avançados',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface)),
                    TextButton(
                      onPressed: () => setSheet(() {
                        origemTemp = null;
                        embaixadorIdTemp = null;
                        embaixadorNomeTemp = null;
                        periodoTemp = null;
                      }),
                      child: const Text('Limpar tudo'),
                    ),
                  ],
                ),
                const Divider(height: 16),

                // ── Origem ───────────────────────────────────────────
                Text('Origem',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['Presencial', 'WhatsApp', 'Instagram']
                      .map((o) {
                        final sel = origemTemp == o;
                        return FilterChip(
                          label: Text(o),
                          selected: sel,
                          labelStyle: TextStyle(color: cs.onSurface),
                          onSelected: (v) =>
                              setSheet(() => origemTemp = v ? o : null),
                        );
                      })
                      .toList(),
                ),

                // ── Embaixador (admin only) ──────────────────────────
                if (_isAdmin && _vendedores.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Embaixador',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: embaixadorIdTemp,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      isDense: true,
                      hintText: 'Todos os embaixadores',
                      hintStyle:
                          TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todos',
                            style: TextStyle(
                                color: cs.onSurface, fontSize: 14)),
                      ),
                      ..._vendedores.map((v) => DropdownMenuItem<String?>(
                            value: v.id,
                            child: Text(v.nome,
                                style: TextStyle(
                                    color: cs.onSurface, fontSize: 14)),
                          )),
                    ],
                    onChanged: (v) => setSheet(() {
                      embaixadorIdTemp = v;
                      embaixadorNomeTemp = v == null
                          ? null
                          : _vendedores
                              .firstWhere((u) => u.id == v,
                                  orElse: () => Usuario(
                                      id: '', nome: '', email: '', perfil: ''))
                              .nome;
                    }),
                  ),
                ],

                // ── Período ──────────────────────────────────────────
                const SizedBox(height: 16),
                Text('Período de cadastro',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    final range = await showDateRangePicker(
                      context: ctx,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now(),
                      initialDateRange: periodoTemp,
                      locale: const Locale('pt', 'BR'),
                    );
                    if (range != null) setSheet(() => periodoTemp = range);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.date_range_outlined,
                            size: 16, color: cs.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            periodoTemp != null
                                ? '${fmt.format(periodoTemp!.start)}  →  ${fmt.format(periodoTemp!.end)}'
                                : 'Qualquer período',
                            style: TextStyle(
                              fontSize: 14,
                              color: periodoTemp != null
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (periodoTemp != null)
                          GestureDetector(
                            onTap: () => setSheet(() => periodoTemp = null),
                            child: Icon(Icons.close,
                                size: 16, color: cs.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Botão aplicar ────────────────────────────────────
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      setState(() {
                        _filtroOrigem = origemTemp;
                        _filtroEmbaixadorId = embaixadorIdTemp;
                        _filtroEmbaixadorNome = embaixadorNomeTemp;
                        _filtroPeriodo = periodoTemp;
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Aplicar filtros'),
                  ),
                ),
              ],
            ),
          );
        },
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
            onFiltroTap: _abrirFiltros,
            filtrosAtivos: _totalFiltrosAtivos,
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
    final fmt = DateFormat('dd/MM/yy');

    // ── Kanban ──────────────────────────────────────────────────────
    if (_usarKanban) {
      return KanbanView(
        clientes: _aplicarFiltros(todosClientes),
        isAdmin: _isAdmin,
        onCardTap: _abrirFicha,
      );
    }

    // ── Busca ────────────────────────────────────────────────────────
    if (_estaPesquisando) {
      return _buildSearchResults(todosClientes);
    }

    // ── Barra de filtros ativos + abas ───────────────────────────────
    return Column(
      children: [
        // Chips de filtros ativos
        if (_totalFiltrosAtivos > 0)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.primaryContainer
                .withValues(alpha: 0.4),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (_filtroOrigem != null)
                        _filtroChip('Origem: $_filtroOrigem',
                            () => setState(() => _filtroOrigem = null)),
                      if (_filtroEmbaixadorNome != null)
                        _filtroChip(
                            'Embaixador: $_filtroEmbaixadorNome',
                            () => setState(() {
                                  _filtroEmbaixadorId = null;
                                  _filtroEmbaixadorNome = null;
                                })),
                      if (_filtroPeriodo != null)
                        _filtroChip(
                            '${fmt.format(_filtroPeriodo!.start)} → ${fmt.format(_filtroPeriodo!.end)}',
                            () => setState(
                                () => _filtroPeriodo = null)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _limparFiltros,
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(48, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('Limpar', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),

        // Lista por abas (atendimento excluído — fica só na recepção)
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: FaseCliente.values
                .where((f) => f != FaseCliente.atendimento)
                .map((fase) {
              final clientesDaAba = _aplicarFiltros(
                  todosClientes.where((c) => c.fase == fase).toList());
              return ClienteListFiltered(
                clientes: clientesDaAba,
                filtroNome: '',
                onTileTap: _abrirFicha,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _filtroChip(String label, VoidCallback onRemover) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemover,
            child: Icon(Icons.close, size: 13, color: cs.onPrimaryContainer),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(List<Cliente> todosClientes) {
    final busca = _filtroTexto.toLowerCase().trim();
    final filtrados = _aplicarFiltros(todosClientes.where((c) {
      return c.nome.toLowerCase().contains(busca) ||
          (c.nomeEsposa ?? '').toLowerCase().contains(busca) ||
          (c.vendedorNome ?? '').toLowerCase().contains(busca);
    }).toList());

    return ClienteListFiltered(
      clientes: filtrados,
      filtroNome: _filtroTexto,
      onTileTap: _abrirFicha,
    );
  }
}
