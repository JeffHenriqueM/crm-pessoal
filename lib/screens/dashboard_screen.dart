import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../models/usuario_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
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
            c.proximoContato!.year, c.proximoContato!.month, c.proximoContato!.day);
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
    final cs = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
          actions: [
            if (_userProfile == 'admin')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: DropdownButton<String?>(
                  value: _vendedorIdFiltro,
                  hint: Text(
                    'Todos',
                    style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.8)),
                  ),
                  dropdownColor: cs.primary,
                  icon: Icon(Icons.filter_list, color: cs.onPrimary),
                  underline: const SizedBox.shrink(),
                  onChanged: (v) => setState(() => _vendedorIdFiltro = v),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child:
                          Text('Todos', style: TextStyle(color: cs.onPrimary)),
                    ),
                    ..._todosVendedores.map(
                      (v) => DropdownMenuItem<String?>(
                        value: v.id,
                        child: Text(v.nome,
                            style: TextStyle(color: cs.onPrimary)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          bottom: const TabBar(
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Estatísticas', icon: Icon(Icons.bar_chart_rounded)),
              Tab(text: 'Agenda', icon: Icon(Icons.calendar_month_outlined)),
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
                  child: Text('Nenhum dado encontrado para este filtro.'));
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
      ),
    );
  }
}
