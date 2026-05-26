import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../models/usuario_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/aba_admin_overview.dart';
import '../widgets/aba_estatisticas.dart';
import '../widgets/aba_motivos_perda.dart';

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
      });
      if (perfil == 'admin') {
        _firestoreService.getTodosUsuarios().then((vendedores) {
          if (!mounted) return;
          setState(() => _todosVendedores = vendedores);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _userProfile == 'admin';

    return DefaultTabController(
      length: isAdmin ? 3 : 1,
      child: isAdmin ? _buildAdminDashboard() : _buildVendedorDashboard(),
    );
  }

  // ── Chip de filtro de vendedor ────────────────────────────────────────────
  Widget _buildFiltroVendedor() {
    final cs = Theme.of(context).colorScheme;
    final vendedorSelecionado = _vendedorIdFiltro != null
        ? _todosVendedores.where((v) => v.id == _vendedorIdFiltro).firstOrNull
        : null;
    final label = vendedorSelecionado != null
        ? vendedorSelecionado.nome.split(' ').first // primeiro nome
        : 'Todos';

    return PopupMenuButton<String?>(
      tooltip: 'Filtrar por vendedor',
      offset: const Offset(0, 40),
      onSelected: (v) => setState(() => _vendedorIdFiltro = v),
      itemBuilder: (_) => [
        PopupMenuItem<String?>(
          value: null,
          child: Row(
            children: [
              Icon(Icons.people_outlined, size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 10),
              const Text('Todos'),
              if (_vendedorIdFiltro == null) ...[
                const Spacer(),
                Icon(Icons.check, size: 16, color: cs.primary),
              ],
            ],
          ),
        ),
        if (_todosVendedores.isNotEmpty)
          const PopupMenuDivider(),
        ..._todosVendedores.map((v) => PopupMenuItem<String?>(
              value: v.id,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: cs.primaryContainer,
                    child: Text(
                      v.nome.isNotEmpty ? v.nome[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 10, color: cs.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(v.nome, overflow: TextOverflow.ellipsis)),
                  if (_vendedorIdFiltro == v.id) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.check, size: 16, color: cs.primary),
                  ],
                ],
              ),
            )),
      ],
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _vendedorIdFiltro != null
              ? cs.primaryContainer
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_outlined,
              size: 15,
              color: _vendedorIdFiltro != null
                  ? cs.onPrimaryContainer
                  : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _vendedorIdFiltro != null
                    ? cs.onPrimaryContainer
                    : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: _vendedorIdFiltro != null
                  ? cs.onPrimaryContainer
                  : cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  // ── Dashboard para admin (3 abas) ─────────────────────────────────────────
  Widget _buildAdminDashboard() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          if (_todosVendedores.isNotEmpty) _buildFiltroVendedor(),
          const SizedBox(width: 8),
        ],
        bottom: const TabBar(
          indicatorWeight: 3,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'Equipe',      icon: Icon(Icons.groups_outlined)),
            Tab(text: 'Estatísticas', icon: Icon(Icons.bar_chart_rounded)),
            Tab(text: 'Perdas',      icon: Icon(Icons.person_off_outlined)),
          ],
        ),
      ),
      body: StreamBuilder<List<Cliente>>(
        stream: _firestoreService.getTodosClientesStream(vendedorId: null),
        builder: (context, snapshotTodos) {
          final todosClientes = snapshotTodos.data ?? [];

          final clientesFiltrados = _vendedorIdFiltro != null
              ? todosClientes
                  .where((c) => c.vendedorId == _vendedorIdFiltro)
                  .toList()
              : todosClientes;

          if (snapshotTodos.connectionState == ConnectionState.waiting &&
              todosClientes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            children: [
              AbaAdminOverview(
                todosClientes: todosClientes,
                todosVendedores: _todosVendedores,
              ),
              AbaEstatisticas(clientes: clientesFiltrados),
              AbaMotivosPerda(clientes: todosClientes),
            ],
          );
        },
      ),
    );
  }

  // ── Dashboard para vendedor (1 aba) ───────────────────────────────────────
  Widget _buildVendedorDashboard() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        bottom: const TabBar(
          indicatorWeight: 3,
          tabs: [
            Tab(text: 'Estatísticas', icon: Icon(Icons.bar_chart_rounded)),
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
            return const Center(child: Text('Nenhum dado encontrado.'));
          }
          return TabBarView(
            children: [
              AbaEstatisticas(clientes: snapshot.data!),
            ],
          );
        },
      ),
    );
  }
}
