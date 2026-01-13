// lib/screens/lista_clientlista_clientes_screenes_screen.dart

import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:crm_pessoal/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:crm_pessoal/services/auth_service.dart';
import 'package:flutter/material.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Ícone do WhatsApp
import '../utils/url_launcher_service.dart'; // Nosso serviço para abrir a URL
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../models/usuario_model.dart';
import '../services/firestore_service.dart';
import '../widgets/app_bar.dart';
import '../widgets/cliente_list_filtered.dart';
import '../widgets/editar_cliente_detalhes_screen.dart';
import 'adicionar_cliente_screen.dart';
import 'dashboard_screen.dart';
import 'interacoes_screen.dart';

class ListaClientesScreen extends StatefulWidget {
  final FaseCliente? faseInicial;
  const ListaClientesScreen({super.key, this.faseInicial});

  @override
  State<ListaClientesScreen> createState() => _ListaClientesScreenState();
}

class _ListaClientesScreenState extends State<ListaClientesScreen> with SingleTickerProviderStateMixin {
  // Serviços
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  // Controladores
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  // Estado da UI
  String _userProfile = 'vendedor';
  bool _estaPesquisando = false;

  // Estado dos Dados
  late Stream<List<Cliente>> _clientesStream;
  List<Usuario> _todosVendedores = [];
  String? _vendedorIdFiltro;
  String _filtroTexto = "";
  String _ordenarPor = "dataAtualizacao";
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
      ordenarPor: _ordenarPor,      // <-- Passa a ordenação padrão
      descendente: _descendente,   // <-- Passa a direção padrão
    );

    _authService.getCurrentUserProfile().then((perfil) {
      if (!mounted) return;
      setState(() => _userProfile = perfil);
      if (perfil == 'admin') {
        _firestoreService.getTodosUsuarios().then((vendedores) {
          if (mounted) setState(() => _todosVendedores = vendedores);
        });
      }
    });

    int initialIndex = widget.faseInicial != null ? FaseCliente.values.indexOf(widget.faseInicial!) : 0;
    _tabController = TabController(length: FaseCliente.values.length, vsync: this, initialIndex: initialIndex);
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

  // Funções de Callback
  void _handleSearchStateChange(bool isTyping) {
    if (isTyping && mounted) {
      // Apenas atualiza o estado para reconstruir com o novo texto do filtro
      setState(() {});
      return;
    }
    if (mounted) {
      setState(() {
        if (_estaPesquisando) {
          _filtroTexto = "";
          _searchController.clear();
        }
        _estaPesquisando = !_estaPesquisando;
      });
    }
  }

  void _handleVendedorChange(String? novoVendedorId) {
    if (mounted) {
      setState(() {
        _vendedorIdFiltro = novoVendedorId;
        // CORREÇÃO: Adicione os parâmetros de ordenação aqui também!
        _clientesStream = _firestoreService.getTodosClientesStream(
          vendedorId: _vendedorIdFiltro,
          ordenarPor: _ordenarPor,
          descendente: _descendente,
        );
      });
    }
  }

  void _handleSortChange(String novaOrdem) {
    if (mounted) {
      setState(() {
        if (_ordenarPor == novaOrdem) {
          // Se estamos no mesmo campo, apenas invertemos a direção.
          // Com os dois índices (ASC e DESC), o Firestore agora permite isso.
          _descendente = !_descendente;
        } else {
          // Se estamos mudando para um novo campo de ordenação...
          _ordenarPor = novaOrdem;

          // ...definimos a direção inicial padrão para esse campo.
          _descendente = (novaOrdem == 'dataAtualizacao'); // true para data, false para nome
        }

        // Recria o stream com os parâmetros corretos
        _clientesStream = _firestoreService.getTodosClientesStream(
          vendedorId: _vendedorIdFiltro,
          ordenarPor: _ordenarPor,
          descendente: _descendente,
        );
      });
    }
  }

  Future<void> _handleLogout() async {
    await _authService.signOut();
  }

  void _abrirDashboard() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DashboardScreen(),
      ),
    );
  }

  // Função para abrir a tela de adicionar cliente
  void _abrirAdicionarCliente() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AdicionarClienteScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Cliente>>(
      stream: _clientesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(appBar: AppBar(title: const Text("Erro")), body: Center(child: Text("Erro: ${snapshot.error}")));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(appBar: AppBar(title: const Text("Carregando...")), body: const Center(child: CircularProgressIndicator()));
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
          // Botão flutuante adicionado aqui
          floatingActionButton: FloatingActionButton(
            onPressed: _abrirAdicionarCliente,
            tooltip: 'Adicionar Cliente',
            child: const Icon(Icons.add),
          ),
          body: _estaPesquisando
              ? _buildSearchResults(todosClientes) // Se estiver pesquisando, mostra a lista global
              : TabBarView( // Caso contrário, mostra as abas
            controller: _tabController,
            children: FaseCliente.values.map((fase) {
              final clientesDaAba = todosClientes.where((c) => c.fase == fase).toList();
              return ClienteListFiltered(
                clientes: clientesDaAba,
                filtroNome: "", // O filtro de texto é aplicado globalmente, não aqui.
                onTileTap: (ctx, cliente, svc) => _mostrarOpcoesCliente(ctx, cliente, svc),
                onDismissed: (cliente) => _handleDismissed(context, cliente, _firestoreService),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // Widget auxiliar que constrói a lista de resultados da busca global
  Widget _buildSearchResults(List<Cliente> todosClientes) {
    final busca = _filtroTexto.toLowerCase().trim();
    final clientesFiltrados = todosClientes.where((c) {
      return c.nome.toLowerCase().contains(busca) ||
          (c.nomeEsposa ?? "").toLowerCase().contains(busca) ||
          (c.vendedorNome ?? "").toLowerCase().contains(busca);
    }).toList();

    return ClienteListFiltered(
      clientes: clientesFiltrados,
      filtroNome: _filtroTexto,
      onTileTap: (ctx, cliente, svc) => _mostrarOpcoesCliente(ctx, cliente, svc),
      onDismissed: (cliente) => _handleDismissed(context, cliente, _firestoreService),
    );
  }

  // Funções para interação com os clientes (menu de opções)
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
            if (cliente.telefoneContato != null && cliente.telefoneContato!.isNotEmpty)
              ListTile(
                leading: const Icon(FontAwesomeIcons.whatsapp, color: Colors.green),
                title: const Text('Conversar no WhatsApp'),
                onTap: () async {
                  Navigator.of(ctx).pop(); // Fecha o menu de opções
                  final urlService = UrlLauncherService();
                  try {
                    // A chamada do método agora usa 'telefoneContato'
                    // A exclamação (!) é segura por causa do 'if' acima
                    await urlService.abrirWhatsApp(cliente.telefoneContato!);
                  } catch (e) {
                    // Se der erro (ex: WhatsApp não instalado), mostra um aviso
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  }
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja apagar permanentemente o cliente "${cliente.nome}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              await firestoreService.deletarCliente(cliente.id!);

              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }

              if (mounted) {
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
