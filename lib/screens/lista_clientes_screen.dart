import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:crm_pessoal/widgets/editar_cliente_detalhes_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../services/firestore_service.dart';
import 'adicionar_cliente_screen.dart';
import '../widgets/cliente_list_filtered.dart';
import 'interacoes_screen.dart';

// 1. ALTERADO PARA STATEFULWIDGET
class ListaClientesScreen extends StatefulWidget {
  final FaseCliente? faseInicial; // Novo parâmetro para receber a fase do Dashboard

  const ListaClientesScreen({super.key, this.faseInicial});

  @override
  State<ListaClientesScreen> createState() => _ListaClientesScreenState();
}

class _ListaClientesScreenState extends State<ListaClientesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();

    // 2. LOGICA PARA DEFINIR A ABA INICIAL
    int initialIndex = 0;
    if (widget.faseInicial != null) {
      initialIndex = FaseCliente.values.indexOf(widget.faseInicial!);
    }

    _tabController = TabController(
      length: FaseCliente.values.length,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- MANTIDAS TODAS AS SUAS FUNÇÕES ORIGINAIS (AGENDA, DIALOGS, ETC) ---

  void _adicionarEventoNaAgenda(BuildContext context, Cliente cliente) {
    if (cliente.proximoContato == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este cliente não tem um próximo contato agendado.')),
      );
      return;
    }

    final Event evento = Event(
      title: 'Contato: ${cliente.nome}',
      description: 'Acompanhamento do cliente ${cliente.nome}.\nFase: ${cliente.fase.nomeDisplay}.\nTelefone: ${cliente.telefoneContato ?? 'Não informado'}.',
      location: 'Telefone/Remoto',
      startDate: cliente.proximoContato!,
      endDate: cliente.proximoContato!.add(const Duration(hours: 1)),
      iosParams: const IOSParams(reminder: Duration(minutes: 30)),
      androidParams: const AndroidParams(emailInvites: []),
    );

    Add2Calendar.addEvent2Cal(evento).then((success) {
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Evento para ${cliente.nome} enviado para a agenda!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  void _mostrarMudarFaseDialog(BuildContext context, Cliente cliente, FirestoreService service) {
    final List<FaseCliente> fases = FaseCliente.values;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Mudar Fase de ${cliente.nome}'),
          content: SingleChildScrollView(
            child: ListBody(
              children: fases.map((fase) {
                return ListTile(
                  title: Text(fase.nomeDisplay),
                  onTap: () async {
                    Navigator.of(context).pop();
                    if (fase == FaseCliente.perdido) {
                      _confirmarPerda(context, cliente, service);
                    } else {
                      if (cliente.id != null) {
                        await service.atualizarFaseCliente(cliente.id!, fase);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Fase alterada para ${fase.nomeDisplay}')),
                          );
                        }
                      }
                    }
                  },
                );
              }).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(child: const Text('CANCELAR'), onPressed: () => Navigator.of(context).pop()),
          ],
        );
      },
    );
  }

  void _mostrarOpcoesCliente(BuildContext context, Cliente cliente, FirestoreService service) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Editar Detalhes'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => EditarClienteDetalhesScreen(cliente: cliente)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.compare_arrows),
              title: const Text('Mudar Fase'),
              onTap: () {
                Navigator.of(ctx).pop();
                _mostrarMudarFaseDialog(context, cliente, service);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Ver Histórico/Interações'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => InteracoesScreen(cliente: cliente)));
              },
            ),
            if (cliente.proximoContato != null)
              ListTile(
                leading: const Icon(Icons.calendar_month, color: Colors.green),
                title: const Text('Adicionar à Agenda'),
                subtitle: Text('Evento em: ${DateFormat('dd/MM/yy \'às\' HH:mm').format(cliente.proximoContato!)}'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _adicionarEventoNaAgenda(context, cliente);
                },
              ),
          ],
        );
      },
    );
  }

  void _handleDismissed(BuildContext context, Cliente cliente, FirestoreService firestoreService) async {
    if (cliente.id != null) {
      await firestoreService.deletarCliente(cliente.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${cliente.nome} deletado permanentemente.')),
        );
      }
    }
  }

  void _confirmarPerda(BuildContext context, Cliente cliente, FirestoreService service) {
    final TextEditingController detalheController = TextEditingController();
    String? motivoSelecionado;

    final List<String> motivosOpcoes = [
      'Financeiro',
      'Distância',
      'Não conhecem a Villamor',
      'Sem interesse',
      'Perfil Inadequado',
      'Sem retorno'
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Motivo da Não Venda'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: motivoSelecionado,
                    decoration: const InputDecoration(
                      labelText: 'Motivo Principal',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Selecione um motivo'),
                    items: motivosOpcoes.map((m) {
                      return DropdownMenuItem(value: m, child: Text(m));
                    }).toList(),
                    onChanged: (val) {
                      setState(() => motivoSelecionado = val);
                    },
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: detalheController,
                    decoration: const InputDecoration(
                      hintText: 'Ex: O cliente achou longe...',
                      labelText: 'Descrição detalhada (Opcional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCELAR'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (motivoSelecionado == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Por favor, selecione o motivo principal.')),
                    );
                    return;
                  }

                  if (cliente.id != null) {
                    // AJUSTE AQUI: Enviamos os dois campos separadamente
                    // Certifique-se de que seu FirestoreService.atualizarFaseCliente
                    // aceite o parâmetro motivoDropdown
                    await service.atualizarFaseCliente(
                        cliente.id!,
                        FaseCliente.perdido,
                        motivo: detalheController.text, // Campo antigo (descrição)
                        motivoDropdown: motivoSelecionado // Campo novo (estatística)
                    );
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cliente movido para Perdido')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('CONFIRMAR PERDA', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<FaseCliente> fases = FaseCliente.values;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CRM Pessoal (Kanban)'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AdicionarClienteScreen()));
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController, // USANDO O CONTROLLER MANUAL
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: fases.map((fase) => Tab(text: fase.nomeDisplay)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController, // USANDO O CONTROLLER MANUAL
        children: fases.map((fase) {
          return ClienteListFiltered(
            fase: fase,
            onTileTap: (ctx, cliente, svc) => _mostrarOpcoesCliente(context, cliente, svc),
            onDismissed: (cliente) => _handleDismissed(context, cliente, _firestoreService),
          );
        }).toList(),
      ),
    );
  }
}