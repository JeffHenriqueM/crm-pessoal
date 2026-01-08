// lib/screens/dashboard_screen.dart
import 'package:crm_pessoal/models/usuario_model.dart';
import 'package:crm_pessoal/services/auth_service.dart';
import 'package:crm_pessoal/screens/lista_clientes_screen.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/cliente_model.dart';
import '../widgets/aba_agenda.dart';
import '../widgets/aba_estatisticas.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  // Estados do filtro
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

  // Função para processar os clientes e criar os eventos do calendário
  Map<DateTime, List<Cliente>> _processarEventos(List<Cliente> clientes) {
    Map<DateTime, List<Cliente>> events = {};
    for (var cliente in clientes) {
      if (cliente.proximoContato != null) {
        final date = DateTime.utc(cliente.proximoContato!.year, cliente.proximoContato!.month, cliente.proximoContato!.day);
        events.putIfAbsent(date, () => []).add(cliente);
      }
      if (cliente.dataVisita != null) {
        final date = DateTime.utc(cliente.dataVisita!.year, cliente.dataVisita!.month, cliente.dataVisita!.day);
        events.putIfAbsent(date, () => []).add(cliente);
      }
    }
    return events;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('CRM Villamor'),
          centerTitle: true,
          backgroundColor: const Color(0xFF673AB7),
          foregroundColor: Colors.white,
          actions: [
            if (_userProfile == 'admin')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: DropdownButton<String?>(
                  value: _vendedorIdFiltro,
                  hint: const Text("Filtrar", style: TextStyle(color: Colors.white70)),
                  dropdownColor: const Color(0xFF673AB7).withOpacity(0.9),
                  icon: const Icon(Icons.filter_list, color: Colors.white),
                  underline: Container(),
                  onChanged: (novoVendedorId) {
                    setState(() => _vendedorIdFiltro = novoVendedorId);
                  },
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text("Todos", style: TextStyle(color: Colors.white))),
                    ..._todosVendedores.map((v) => DropdownMenuItem<String?>(value: v.id, child: Text(v.nome, style: const TextStyle(color: Colors.white)))),
                  ],
                ),
              ),
            IconButton(
              icon: const Icon(Icons.group),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ListaClientesScreen())),
              tooltip: 'Ver Clientes',
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3.0,
            labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(fontSize: 14),
            tabs: [
              Tab(text: 'Estatísticas', icon: Icon(Icons.bar_chart)),
              Tab(text: 'Agenda', icon: Icon(Icons.calendar_month)),
            ],
          ),
        ),
        body: StreamBuilder<List<Cliente>>(
          stream: _firestoreService.getTodosClientesStream(vendedorId: _vendedorIdFiltro),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('Nenhum dado encontrado para este filtro.'));
            }

            final clientes = snapshot.data!;
            final eventos = _processarEventos(clientes);

            return TabBarView(
              children: [
                // Aba 1: Usa o novo widget e passa os dados
                AbaEstatisticas(clientes: clientes),
                // Aba 2: Usa o novo widget e passa os dados
                AbaAgenda(events: eventos),
              ],
            );
          },
        ),
      ),
    );
  }
}
