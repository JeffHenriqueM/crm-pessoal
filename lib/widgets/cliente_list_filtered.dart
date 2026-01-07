// lib/widgets/cliente_list_filtered.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 1. IMPORTE O PACOTE 'intl'
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../services/firestore_service.dart';

class ClienteListFiltered extends StatelessWidget {
  final FaseCliente fase;
  final Function(BuildContext, Cliente, FirestoreService) onTileTap;
  final Function(Cliente) onDismissed;

  const ClienteListFiltered({
    super.key,
    required this.fase,
    required this.onTileTap,
    required this.onDismissed,
  });

  // ADICIONE O MÉTODO AQUI:
  void _confirmarPerda(BuildContext context, String clienteId, FirestoreService service) {
    final TextEditingController motivoController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false, // Obriga o usuário a escolher ou cancelar
      builder: (context) => AlertDialog(
        title: const Text('Motivo da Não Venda'),
        content: TextField(
          controller: motivoController,
          decoration: const InputDecoration(
            hintText: 'Ex: Preço alto, comprou no concorrente...',
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
              await service.atualizarFaseCliente(
                clienteId,
                FaseCliente.perdido,
                motivo: motivoController.text,
              );
              if (context.mounted) Navigator.pop(context);
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
    final FirestoreService firestoreService = FirestoreService();

    return StreamBuilder<List<Cliente>>(
      // Use o stream para obter os clientes da fase correta
      stream: firestoreService.getClientesStream(fase: fase),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              'Nenhum cliente na fase "${fase.nomeDisplay}".',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final clientes = snapshot.data!;

        return ListView.builder(
          itemCount: clientes.length,
          itemBuilder: (context, index) {
            final cliente = clientes[index];

            // 2. LÓGICA PARA DESTACAR CONTATOS URGENTES
            bool contatoUrgente = false;
            if (cliente.proximoContato != null) {
              final hoje = DateTime.now();
              // Contato é urgente se a data já passou ou é hoje
              if (!cliente.proximoContato!.isAfter(hoje)) {
                contatoUrgente = true;
              }
            }

            // 3. WIDGET DO CLIENTE ATUALIZADO (CARD + LISTTILE)
            return Card(
              elevation: 3,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              // Cor da borda muda se o contato for urgente
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  color: contatoUrgente ? Colors.redAccent : Colors.transparent,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Dismissible(
                key: Key(cliente.id!),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20.0),
                  child: const Icon(Icons.delete_forever, color: Colors.white),
                ),
                onDismissed: (_) => onDismissed(cliente),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  leading: CircleAvatar(
                    // Cor do avatar também muda
                    backgroundColor: contatoUrgente ? Colors.red : Theme.of(context).primaryColor,
                    child: Text(
                      cliente.nome.isNotEmpty ? cliente.nome[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    cliente.nome,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  // O SUBTITLE AGORA É UMA COLUNA PARA ACOMODAR A NOVA INFO
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tipo: ${cliente.tipo}'),
                      const SizedBox(height: 4),

                      // 1. BLOCO DO PRÓXIMO CONTATO (Aparece apenas se existir)
                      if (cliente.proximoContato != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.notification_important,
                                size: 16,
                                color: contatoUrgente ? Colors.red.shade700 : Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "Contato: ${DateFormat('dd/MM/yy HH:mm').format(cliente.proximoContato!)}",
                                  style: TextStyle(
                                    color: contatoUrgente ? Colors.red.shade700 : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // 2. BLOCO DA DATA DA VISITA (Aparece apenas se existir - CORREÇÃO AQUI)
                      if (cliente.dataVisita != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.event_available,
                                size: 16,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "Visita: ${DateFormat('dd/MM/yy HH:mm').format(cliente.dataVisita!)}",
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (cliente.fase == FaseCliente.perdido && cliente.motivoNaoVenda != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Row(
                            children: [
                              const Icon(Icons.comment_bank_outlined, size: 14, color: Colors.orangeAccent),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "Motivo: ${cliente.motivoNaoVenda}",
                                  style: const TextStyle(
                                    color: Colors.orangeAccent,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.more_vert),
                  onTap: () async {
                    onTileTap(context, cliente, firestoreService);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
