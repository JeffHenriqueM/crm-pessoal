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
      length: isAdmin ? 6 : 1,
      child: isAdmin ? _buildAdminDashboard() : _buildVendedorDashboard(),
    );
  }

  // ── Chip de filtro de vendedor ─────────────────────────────────────────────
  Widget _buildFiltroVendedor() {
    final cs = Theme.of(context).colorScheme;
    final selecionado = _vendedorIdFiltro != null
        ? _todosVendedores
            .where((v) => v.id == _vendedorIdFiltro)
            .firstOrNull
        : null;
    final label = selecionado != null
        ? selecionado.nome.split(' ').first
        : 'Todos';
    final ativo = _vendedorIdFiltro != null;

    return PopupMenuButton<String?>(
      tooltip: 'Filtrar por vendedor',
      offset: const Offset(0, 40),
      onSelected: (v) => setState(() => _vendedorIdFiltro = v),
      itemBuilder: (_) => [
        PopupMenuItem<String?>(
          value: null,
          child: Row(children: [
            Icon(Icons.people_outlined, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 10),
            const Expanded(child: Text('Todos')),
            if (!ativo) Icon(Icons.check, size: 16, color: cs.primary),
          ]),
        ),
        if (_todosVendedores.isNotEmpty) const PopupMenuDivider(),
        ..._todosVendedores.map((v) => PopupMenuItem<String?>(
              value: v.id,
              child: Row(children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    v.nome.isNotEmpty ? v.nome[0].toUpperCase() : '?',
                    style: TextStyle(
                        fontSize: 10, color: cs.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(v.nome,
                        overflow: TextOverflow.ellipsis)),
                if (_vendedorIdFiltro == v.id) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check, size: 16, color: cs.primary),
                ],
              ]),
            )),
      ],
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: ativo
              ? cs.primaryContainer
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outlined,
                size: 15,
                color: ativo
                    ? cs.onPrimaryContainer
                    : cs.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: ativo
                    ? cs.onPrimaryContainer
                    : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.arrow_drop_down_rounded,
                size: 18,
                color: ativo
                    ? cs.onPrimaryContainer
                    : cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  // ── Dashboard admin (6 abas) ──────────────────────────────────────────────
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
            Tab(text: 'Equipe',       icon: Icon(Icons.groups_outlined)),
            Tab(text: 'Financeiro',   icon: Icon(Icons.account_balance_wallet_outlined)),
            Tab(text: 'Captação',     icon: Icon(Icons.record_voice_over_outlined)),
            Tab(text: 'Estatísticas', icon: Icon(Icons.bar_chart_rounded)),
            Tab(text: 'Relatórios',   icon: Icon(Icons.assessment_outlined)),
            Tab(text: 'Perdas',       icon: Icon(Icons.person_off_outlined)),
          ],
        ),
      ),
      body: StreamBuilder<List<Cliente>>(
        stream: _firestoreService.getTodosClientesStream(vendedorId: null),
        builder: (context, snapshot) {
          final todos = snapshot.data ?? [];

          // Aba Equipe e Captação: sempre todos os leads
          // Aba Financeiro, Estatísticas: responde ao filtro de vendedor
          final filtrados = _vendedorIdFiltro != null
              ? todos.where((c) => c.vendedorId == _vendedorIdFiltro).toList()
              : todos;

          if (snapshot.connectionState == ConnectionState.waiting &&
              todos.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            children: [
              // 0 — Equipe (sempre todos)
              AbaAdminOverview(
                todosClientes: todos,
                todosVendedores: _todosVendedores,
              ),
              // 1 — Financeiro (filtrado por vendedor)
              AbaFinanceiro(clientes: filtrados),
              // 2 — Captação (sempre todos — base captador, não vendedor)
              AbaCaptacao(clientes: todos),
              // 3 — Estatísticas (filtrado por vendedor)
              AbaEstatisticas(clientes: filtrados),
              // 4 — Relatórios (sempre todos)
              AbaRelatorios(clientes: todos),
              // 5 — Perdas (sempre todos)
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
