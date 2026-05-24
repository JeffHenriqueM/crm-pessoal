import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../models/usuario_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/aba_admin_overview.dart';
import '../widgets/aba_agenda.dart';
import '../widgets/aba_estatisticas.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  String _userProfile = 'vendedor';
  List<Usuario> _todosVendedores = [];
  String? _vendedorIdFiltro;

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  void _carregarDadosIniciais() {
    final currentUser = _authService.getCurrentUser();
    _authService.getCurrentUserProfile().then((perfil) {
      if (!mounted) return;
      setState(() {
        _userProfile = perfil;
        if (perfil != 'admin') {
          _vendedorIdFiltro = currentUser?.uid;
        }
        // Admin começa sem filtro (vê todos)
      });
      if (perfil == 'admin') {
        _firestoreService.getTodosUsuarios().then((vendedores) {
          if (!mounted) return;
          setState(() => _todosVendedores = vendedores);
        });
      }
    });
  }

  Map<DateTime, List<Cliente>> _processarEventos(List<Cliente> clientes) {
    final events = <DateTime, List<Cliente>>{};
    for (final c in clientes) {
      if (c.proximoContato != null) {
        final d = DateTime.utc(
            c.proximoContato!.year,
            c.proximoContato!.month,
            c.proximoContato!.day);
        events.putIfAbsent(d, () => []).add(c);
      }
      if (c.dataVisita != null) {
        final d = DateTime.utc(
            c.dataVisita!.year, c.dataVisita!.month, c.dataVisita!.day);
        events.putIfAbsent(d, () => []).add(c);
      }
    }
    return events;
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _userProfile == 'admin';

    return DefaultTabController(
      length: isAdmin ? 3 : 2,
      child: isAdmin ? _buildAdminDashboard() : _buildVendedorDashboard(),
    );
  }

  // ── Dashboard para admin (3 abas) ─────────────────────────────────────────
  Widget _buildAdminDashboard() {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          // Filtro de vendedor (usado nas abas Estatísticas e Agenda)
          if (_todosVendedores.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Center(
                child: DropdownButton<String?>(
                  value: _vendedorIdFiltro,
                  hint: Text(
                    'Vendedor',
                    style:
                        TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                  ),
                  onChanged: (v) => setState(() => _vendedorIdFiltro = v),
                  underline: const SizedBox.shrink(),
                  icon: Icon(Icons.people_outlined,
                      color: cs.onSurfaceVariant, size: 20),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todos',
                          style:
                              TextStyle(color: cs.onSurface, fontSize: 14)),
                    ),
                    ..._todosVendedores.map((v) => DropdownMenuItem<String?>(
                          value: v.id,
                          child: Text(v.nome,
                              style: TextStyle(
                                  color: cs.onSurface, fontSize: 14)),
                        )),
                  ],
                ),
              ),
            ),
        ],
        bottom: const TabBar(
          indicatorWeight: 3,
          isScrollable: false,
          tabs: [
            Tab(
              text: 'Equipe',
              icon: Icon(Icons.groups_outlined),
            ),
            Tab(
              text: 'Estatísticas',
              icon: Icon(Icons.bar_chart_rounded),
            ),
            Tab(
              text: 'Agenda',
              icon: Icon(Icons.calendar_month_outlined),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<Cliente>>(
        // Para admin: busca TODOS os clientes (sem filtro de vendedor)
        // A visão de equipe sempre precisa de todos os clientes
        stream: _firestoreService.getTodosClientesStream(vendedorId: null),
        builder: (context, snapshotTodos) {
          final todosClientes = snapshotTodos.data ?? [];

          // Clientes filtrados pelo dropdown (para Estatísticas e Agenda)
          final clientesFiltrados = _vendedorIdFiltro != null
              ? todosClientes
                  .where((c) => c.vendedorId == _vendedorIdFiltro)
                  .toList()
              : todosClientes;

          final eventos = _processarEventos(clientesFiltrados);

          if (snapshotTodos.connectionState == ConnectionState.waiting &&
              todosClientes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            children: [
              // Aba 0: Visão da equipe (sempre todos)
              AbaAdminOverview(
                todosClientes: todosClientes,
                todosVendedores: _todosVendedores,
              ),
              // Aba 1: Estatísticas (responde ao filtro de vendedor)
              AbaEstatisticas(clientes: clientesFiltrados),
              // Aba 2: Agenda (responde ao filtro de vendedor)
              AbaAgenda(events: eventos),
            ],
          );
        },
      ),
    );
  }

  // ── Dashboard para vendedor (2 abas) ──────────────────────────────────────
  Widget _buildVendedorDashboard() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        bottom: const TabBar(
          indicatorWeight: 3,
          tabs: [
            Tab(
                text: 'Estatísticas',
                icon: Icon(Icons.bar_chart_rounded)),
            Tab(
                text: 'Agenda',
                icon: Icon(Icons.calendar_month_outlined)),
          ],
        ),
      ),
      body: StreamBuilder<List<Cliente>>(
        stream: _firestoreService.getTodosClientesStream(
            vendedorId: _vendedorIdFiltro),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
                child: Text('Nenhum dado encontrado.'));
          }

          final clientes = snapshot.data!;
          final eventos = _processarEventos(clientes);

          return TabBarView(
            children: [
              AbaEstatisticas(clientes: clientes),
              AbaAgenda(events: eventos),
            ],
          );
        },
      ),
    );
  }
}
