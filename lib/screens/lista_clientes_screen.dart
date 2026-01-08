// lib/screens/lista_clientes_screen.dart

import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:crm_pessoal/screens/dashboard_screen.dart'; // <--- 1. IMPORTAR DASHBOARD
import 'package:crm_pessoal/services/auth_service.dart';    // <--- 2. IMPORTAR AUTH SERVICE
import 'package:crm_pessoal/widgets/editar_cliente_detalhes_screen.dart';
import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../services/firestore_service.dart';
import 'adicionar_cliente_screen.dart';
import '../widgets/cliente_list_filtered.dart';
import 'interacoes_screen.dart';
import 'gerenciar_usuarios_screen.dart';

class ListaClientesScreen extends StatefulWidget {
  final FaseCliente? faseInicial;
  const ListaClientesScreen({super.key, this.faseInicial});

  @override
  State<ListaClientesScreen> createState() => _ListaClientesScreenState();
}

class _ListaClientesScreenState extends State<ListaClientesScreen> with SingleTickerProviderStateMixin {
  String _userProfile = 'vendedor'; // Valor padrão
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService(); // <--- 3. INSTANCIAR AUTH SERVICE

  String _filtroTexto = "";
  String _ordenarPor = "dataAtualizacao";
  bool _descendente = true;
  bool _estaPesquisando = false;
  final TextEditingController _searchController = TextEditingController();

  late Stream<List<Cliente>> _clientesStream;

  @override
  void initState() {
    super.initState();
    _clientesStream = _firestoreService.getTodosClientesStream();
    _authService.getCurrentUserProfile().then((perfil) {
      if (mounted) setState(() => _userProfile = perfil);
    });

    int initialIndex = widget.faseInicial != null ? FaseCliente.values.indexOf(widget.faseInicial!) : 0;
    _tabController = TabController(length: FaseCliente.values.length, vsync: this, initialIndex: initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Cliente>>(
      stream: _clientesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text("Erro: ${snapshot.error}")));
        }

        final todosClientes = snapshot.data ?? [];
        return _buildUI(context, todosClientes);
      },
    );
  }

  Widget _buildUI(BuildContext context, List<Cliente> todosClientes) {
    final List<FaseCliente> fases = FaseCliente.values;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        title: _estaPesquisando
            ? TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Buscar por nome ou parceiro...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          onChanged: (value) => setState(() => _filtroTexto = value),
        )
            : const Text('CRM Pessoal (Kanban)'),
        actions: [
          // ==================== NOVOS BOTÕES ADICIONADOS ====================
          // Botão de Gerenciamento de Usuários (APENAS PARA ADMIN)
          if (_userProfile == 'admin')
      IconButton(
      tooltip: 'Gerenciar Usuários',
      icon: const Icon(Icons.manage_accounts),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const GerenciarUsuariosScreen()),
        );
      },
    )
          ,IconButton(
            tooltip: 'Dashboard',
            icon: const Icon(Icons.dashboard_outlined),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => DashboardScreen(),
              ));
            },
          ),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // O StreamBuilder no main.dart cuidará de redirecionar para a tela de login
              await _authService.signOut();
            },
          ),
          // ================================================================
          IconButton(
            icon: Icon(_estaPesquisando ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_estaPesquisando) {
                  _filtroTexto = "";
                  _searchController.clear();
                }
                _estaPesquisando = !_estaPesquisando;
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'dataAtualizacao', child: Text('Mais Recentes')),
              const PopupMenuItem(value: 'nome', child: Text('Nome (A-Z)')),
              const PopupMenuItem(value: 'proximoContato', child: Text('Próximo Contato')),
            ],
          ),
          IconButton(
            tooltip: 'Adicionar Cliente',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AdicionarClienteScreen())),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: fases.map((fase) => Tab(text: fase.nomeDisplay)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: fases.map((fase) {
          List<Cliente> clientesFiltrados;
          // Se estiver pesquisando, mostra a lista completa filtrada, ignorando as abas.
          if (_filtroTexto.trim().isNotEmpty) {
            clientesFiltrados = todosClientes.where((c) {
              final busca = _filtroTexto.toLowerCase().trim();
              return c.nome.toLowerCase().contains(busca) ||
                  (c.nomeEsposa ?? "").toLowerCase().contains(busca) ||
                  (c.vendedorNome ?? "").toLowerCase().contains(busca); // Adicionado filtro por vendedor
            }).toList();
          } else {
            // Se não, filtra pela fase da aba atual.
            clientesFiltrados = todosClientes.where((c) => c.fase == fase).toList();
          }

          // Ordenação
          clientesFiltrados.sort((a, b) {
            dynamic valA, valB;
            if (_ordenarPor == "nome") {
              valA = a.nome.toLowerCase();
              valB = b.nome.toLowerCase();
            } else if (_ordenarPor == "proximoContato") {
              valA = a.proximoContato ?? DateTime(2100);
              valB = b.proximoContato ?? DateTime(2100);
            } else { // Padrão é dataAtualizacao
              valA = a.dataAtualizacao;
              valB = b.dataAtualizacao;
            }
            return _descendente ? valB.compareTo(valA) : valA.compareTo(valB);
          });

          return ClienteListFiltered(
            clientes: clientesFiltrados,
            filtroNome: _filtroTexto,
            onTileTap: (ctx, cliente, svc) => _mostrarOpcoesCliente(context, cliente, svc),
            onDismissed: (cliente) => _handleDismissed(context, cliente, _firestoreService),
          );
        }).toList(),
      ),
    );
  }

  // ===== FUNÇÕES AUXILIARES (sem alterações) =====

  void _mostrarOpcoesCliente(BuildContext context, Cliente cliente, FirestoreService service) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar Detalhes'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => EditarClienteDetalhesScreen(cliente: cliente),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Ver Interações'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => InteracoesScreen(cliente: cliente),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.move_up),
              title: const Text('Mudar Fase'),
              onTap: () {
                Navigator.of(ctx).pop();
                _mostrarMudarFaseDialog(context, cliente, service);
              },
            ),
            if (cliente.proximoContato != null)
              ListTile(
                leading: const Icon(Icons.event),
                title: const Text('Adicionar à Agenda'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _adicionarEventoNaAgenda(context, cliente);
                },
              ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red.shade700),
              title: Text('Apagar Cliente', style: TextStyle(color: Colors.red.shade700)),
              onTap: () {
                Navigator.of(ctx).pop();
                _handleDismissed(context, cliente, service);
              },
            ),
          ],
        );
      },
    );
  }

  void _mostrarMudarFaseDialog(BuildContext context, Cliente cliente, FirestoreService service) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Mudar Fase do Cliente'),
          content: DropdownButton<FaseCliente>(
            value: cliente.fase,
            isExpanded: true,
            onChanged: (FaseCliente? novaFase) {
              if (novaFase != null) {
                Navigator.of(ctx).pop();
                if (novaFase == FaseCliente.perdido) {
                  _confirmarPerda(context, cliente, service);
                } else {
                  service.atualizarFaseCliente(cliente.id!, novaFase);
                }
              }
            },
            items: FaseCliente.values.map<DropdownMenuItem<FaseCliente>>((FaseCliente fase) {
              return DropdownMenuItem<FaseCliente>(value: fase, child: Text(fase.nomeDisplay));
            }).toList(),
          ),
        );
      },
    );
  }

  void _confirmarPerda(BuildContext context, Cliente cliente, FirestoreService service) {
    final TextEditingController motivoController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Perda'),
        content: TextField(
          controller: motivoController,
          decoration: const InputDecoration(hintText: "Qual o motivo da perda?"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              service.atualizarFaseCliente(
                cliente.id!,
                FaseCliente.perdido,
                motivo: motivoController.text.trim(),
              );
              Navigator.of(ctx).pop();
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _adicionarEventoNaAgenda(BuildContext context, Cliente cliente) {
    if (cliente.proximoContato == null) return;
    final Event event = Event(
      title: 'Contato Cliente: ${cliente.nome}',
      description: 'Ligar para o cliente ${cliente.nome}.',
      location: 'Telefone/CRM',
      startDate: cliente.proximoContato!,
      endDate: cliente.proximoContato!.add(const Duration(minutes: 30)),
    );
    Add2Calendar.addEvent2Cal(event);
  }

  void _handleDismissed(BuildContext context, Cliente cliente, FirestoreService firestoreService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja apagar permanentemente o cliente "${cliente.nome}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              firestoreService.deletarCliente(cliente.id!);
              Navigator.of(ctx).pop();
              if(mounted){
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cliente "${cliente.nome}" apagado.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
  }
}
