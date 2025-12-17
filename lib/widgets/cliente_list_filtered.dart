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

                      // 4. EXIBIÇÃO DA DATA DO PRÓXIMO CONTATO
                      if (cliente.proximoContato != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.notification_important,
                                size: 16,
                                color: contatoUrgente ? Colors.red.shade700 : Colors.blueGrey,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  // Formatação completa da data e hora
                                  "Prox. contato: ${DateFormat('dd/MM/yy \'às\' HH:mm').format(cliente.proximoContato!)}",
                                  style: TextStyle(
                                    color: contatoUrgente ? Colors.red.shade700 : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  // Formatação completa da data e hora
                                  "Prox. Visita: ${DateFormat('dd/MM/yy \'às\' HH:mm').format(cliente.dataVisita!)}",
                                  style: TextStyle(
                                    color: contatoUrgente ? Colors.red.shade700 : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.more_vert),
                  onTap: () => onTileTap(context, cliente, firestoreService),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
