import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../models/usuario_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/aba_admin_overview.dart';
import '../widgets/aba_captacao.dart';
import '../widgets/aba_estatisticas.dart';
import '../widgets/aba_financeiro.dart';
import '../widgets/aba_motivos_perda.dart';
import '../widgets/aba_relatorios.dart';

class DashboardScreen extends StatefulWidget {
  final String userProfile;
  const DashboardScreen({super.key, this.userProfile = ''});

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
    if (widget.userProfile.isNotEmpty) {
      _userProfile = widget.userProfile;
    }
    _carregarDadosIniciais();
  }

  void _carregarDadosIniciais() {
    final currentUser = _authService.getCurrentUser();

    void aplicar(String perfil) {
      if (!mounted) return;
      setState(() {
        _userProfile = perfil;
        if (perfil != 'admin' && perfil != 'super admin') {
          _vendedorIdFiltro = currentUser?.uid;
        }
      });
      if (perfil == 'admin' || perfil == 'super admin') {
        _firestoreService.getTodosUsuarios().then((vendedores) {
          if (!mounted) return;
          setState(() => _todosVendedores = vendedores);
        });
      }
    }

    if (widget.userProfile.isNotEmpty) {
      // Profile já conhecido — só carrega dados admin se necessário
      final perfil = widget.userProfile;
      if (perfil != 'admin' && perfil != 'super admin') {
        _vendedorIdFiltro = currentUser?.uid;
      } else {
        _firestoreService.getTodosUsuarios().then((vendedores) {
          if (!mounted) return;
          setState(() => _todosVendedores = vendedores);
        });
      }
    } else {
      _authService.getCurrentUserProfile().then(aplicar);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _userProfile == 'admin' || _userProfile == 'super admin';

    return DefaultTabController(
      length: isAdmin ? 6 : 1,
      child: isAdmin ? _buildAdminDashboard() : _buildVendedorDashboard(),
    );
  }

  // ── Dashboard admin (6 abas) ──────────────────────────────────────────────
  Widget _buildAdminDashboard() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        toolbarHeight: 50,
        bottom: const TabBar(
          indicatorWeight: 3,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'Equipe',       icon: Icon(Icons.groups_outlined)),
            Tab(text: 'Financeiro',   icon: Icon(Icons.account_balance_outlined)),
            Tab(text: 'Captação',     icon: Icon(Icons.campaign_outlined)),
            Tab(text: 'Estatísticas', icon: Icon(Icons.bar_chart_rounded)),
            Tab(text: 'Relatórios',   icon: Icon(Icons.analytics_outlined)),
            Tab(text: 'Perdas',       icon: Icon(Icons.person_off_outlined)),
          ],
        ),
      ),
      body: StreamBuilder<List<Cliente>>(
        stream: _firestoreService.getTodosClientesStream(vendedorId: null),
        builder: (context, snapshot) {
          final todos = snapshot.data ?? [];

          if (snapshot.connectionState == ConnectionState.waiting &&
              todos.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            children: [
              // 0 — Equipe (com filtro interno por vendedor)
              AbaAdminOverview(
                todosClientes: todos,
                todosVendedores: _todosVendedores,
              ),
              // 1 — Financeiro
              AbaFinanceiro(clientes: todos),
              // 2 — Captação (com filtro interno por captador)
              AbaCaptacao(
                clientes: todos,
                todosUsuarios: _todosVendedores,
              ),
              // 3 — Estatísticas
              AbaEstatisticas(clientes: todos),
              // 4 — Relatórios
              AbaRelatorios(clientes: todos),
              // 5 — Perdas
              AbaMotivosPerda(clientes: todos),
            ],
          );
        },
      ),
    );
  }

  // ── Dashboard vendedor (1 aba) ────────────────────────────────────────────
  Widget _buildVendedorDashboard() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        toolbarHeight: 50,
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
          final clientes = snapshot.data ?? [];
          return TabBarView(
            children: [
              // Meta mensal fica dentro da tab, rolando junto com as estatísticas
              AbaEstatisticas(
                clientes: clientes,
                userId: _vendedorIdFiltro,
              ),
            ],
          );
        },
      ),
    );
  }
}
