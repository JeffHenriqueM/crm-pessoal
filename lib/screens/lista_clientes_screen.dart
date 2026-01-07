import 'package:add_2_calendar/add_2_calendar.dart'; // 1. NOVO PACOTE ADICIONADO
import 'package:crm_pessoal/widgets/editar_cliente_detalhes_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 2. NOVO PACOTE ADICIONADO
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../services/firestore_service.dart'; // Contém ClienteOrder e FirestoreService
import 'adicionar_cliente_screen.dart';
import '../widgets/cliente_list_filtered.dart';
import 'interacoes_screen.dart'; // Ajuste o caminho se necessário

class ListaClientesScreen extends StatelessWidget {
  const ListaClientesScreen({super.key});

  // 3. NOVA FUNÇÃO PARA ADICIONAR O EVENTO À AGENDA
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
      iosParams: const IOSParams(
        reminder: Duration(minutes: 30), // Lembrete 30 min antes no iOS
      ),
      androidParams: const AndroidParams(
        emailInvites: [], // Pode adicionar e-mails para convidar
      ),
    );

    // Abre o app de calendário do celular com o evento preenchido
    Add2Calendar.addEvent2Cal(evento).then((success) {
      if (context.mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Evento para ${cliente.nome} enviado para a agenda!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  // Função auxiliar para mudar a fase (usada no BottomSheet)
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
                    Navigator.of(context).pop(); // Fecha o diálogo
                    if (fase == FaseCliente.perdido) {
                      // SE FOR PERDIDO, ABRE O MOTIVO (PASSO 2)
                      _confirmarPerda(context, cliente, service);
                    } else {
                      // SE FOR QUALQUER OUTRA FASE, SEGUE O FLUXO NORMAL
                      if (cliente.id != null) {
                        await service.atualizarFaseCliente(cliente.id!, fase);
                        if (context.mounted) {
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
            TextButton(
              child: const Text('CANCELAR'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Método de Opções (chamado no onTap do ListTile) - ATUALIZADO
  void _mostrarOpcoesCliente(BuildContext context, Cliente cliente, FirestoreService service) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) { // Nome do contexto alterado para ctx para evitar sombreamento
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Editar Detalhes'),
              onTap: () {
                Navigator.of(ctx).pop(); // Fecha o BottomSheet
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => EditarClienteDetalhesScreen(cliente: cliente),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.compare_arrows),
              title: const Text('Mudar Fase'),
              onTap: () {
                Navigator.of(ctx).pop(); // Fecha o BottomSheet
                _mostrarMudarFaseDialog(context, cliente, service);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Ver Histórico/Interações'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => InteracoesScreen(cliente: cliente),
                  ),
                );
              },
            ),
            // 4. OPÇÃO DE ADICIONAR À AGENDA (só aparece se houver data)
            if (cliente.proximoContato != null)
              ListTile(
                leading: const Icon(Icons.calendar_month, color: Colors.green),
                title: const Text('Adicionar à Agenda'),
                subtitle: Text('Evento em: ${DateFormat('dd/MM/yy \'às\' HH:mm').format(cliente.proximoContato!)}'),
                onTap: () {
                  Navigator.of(ctx).pop(); // Fecha o menu
                  _adicionarEventoNaAgenda(context, cliente); // Chama a nova função
                },
              ),
          ],
        );
      },
    );
  }

  // Função de exclusão (chamado no onDismissed)
  void _handleDismissed(BuildContext context, Cliente cliente, FirestoreService firestoreService) async {
    if (cliente.id != null) {
      await firestoreService.deletarCliente(cliente.id!);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${cliente.nome} deletado permanentemente.')),
        );
      }
    }
  }

  void _confirmarPerda(BuildContext context, Cliente cliente, FirestoreService service) {
    final TextEditingController motivoController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Motivo da Não Venda'),
        content: TextField(
          controller: motivoController,
          decoration: const InputDecoration(
            hintText: 'Ex: Preço, comprou em outro lugar...',
            labelText: 'Por que não fechou?',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (cliente.id != null) {
                await service.atualizarFaseCliente(
                  cliente.id!,
                  FaseCliente.perdido,
                  motivo: motivoController.text,
                );
              }
              if (context.mounted) {
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<FaseCliente> fases = FaseCliente.values;
    final FirestoreService firestoreService = FirestoreService();

    return DefaultTabController(
      length: fases.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('CRM Pessoal (Kanban)'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AdicionarClienteScreen(),
                  ),
                );
              },
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: fases.map((fase) => Tab(text: fase.nomeDisplay)).toList(),
          ),
        ),
        body: TabBarView(
          children: fases.map((fase) {
            return ClienteListFiltered(
              fase: fase,
              onTileTap: _mostrarOpcoesCliente,
              onDismissed: (cliente) => _handleDismissed(context, cliente, firestoreService),
            );
          }).toList(),
        ),
      ),
    );
  }
}