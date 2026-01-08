// lib/widgets/cliente_list_filtered.dart
import 'package:crm_pessoal/models/fase_enum.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../services/firestore_service.dart';

class ClienteListFiltered extends StatelessWidget {
  // AGORA ELE RECEBE A LISTA PRONTA!
  final List<Cliente> clientes;
  final Function(BuildContext, Cliente, FirestoreService) onTileTap;
  final Function(Cliente) onDismissed;
  final String filtroNome;

  const ClienteListFiltered({
    super.key,
    required this.clientes,
    required this.onTileTap,
    required this.onDismissed,
    required this.filtroNome,
  });

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();

    if (clientes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            filtroNome.isEmpty
                ? 'Nenhum cliente nesta fase.'
                : 'Nenhum resultado para "$filtroNome".',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: clientes.length,
      itemBuilder: (context, index) {
        final cliente = clientes[index];
        bool contatoUrgente = false;
        if (cliente.proximoContato != null) {
          contatoUrgente = cliente.proximoContato!.isBefore(DateTime.now());
        }

        return Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
              leading: CircleAvatar(
                backgroundColor: contatoUrgente ? Colors.red : Theme.of(context).primaryColor,
                child: Text(
                  cliente.nome.isNotEmpty ? cliente.nome[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                (cliente.nomeEsposa != null && cliente.nomeEsposa!.isNotEmpty)
                    ? "${cliente.nome} e ${cliente.nomeEsposa}"
                    : cliente.nome,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (filtroNome.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          "📍 FASE: ${cliente.fase.nomeDisplay.toUpperCase()}",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ),
                  Text('Tipo: ${cliente.tipo}'),
                  if (cliente.proximoContato != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        "Contato: ${DateFormat('dd/MM/yy HH:mm').format(cliente.proximoContato!)}",
                        style: TextStyle(
                          fontSize: 12,
                          // AGORA a cor se adapta ao tema (claro ou escuro)
                          color: contatoUrgente
                              ? Colors.redAccent
                              : Theme.of(context).textTheme.bodySmall?.color,
                          fontWeight: contatoUrgente ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),

                  // ===== CÓDIGO ADICIONADO AQUI =====
                  if (cliente.fase == FaseCliente.perdido && cliente.motivoNaoVenda != null && cliente.motivoNaoVenda!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        "Motivo: ${cliente.motivoNaoVenda}",
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  // ===== FIM DO CÓDIGO ADICIONADO =====
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onTileTap(context, cliente, firestoreService),
            ),
          ),
        );
      },
    );
  }
}
