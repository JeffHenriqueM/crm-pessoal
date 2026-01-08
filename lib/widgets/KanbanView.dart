// lib/widgets/lista_clientes/kanban_view.dart

import 'package:flutter/material.dart';
import '../../models/cliente_model.dart';
import '../../models/fase_enum.dart';
import '../../services/firestore_service.dart';
import 'cliente_list_filtered.dart';

class KanbanView extends StatelessWidget {
  final TabController tabController;
  final List<Cliente> todosClientes;
  final String filtroTexto;
  final String ordenarPor;
  final bool descendente;
  final void Function(BuildContext, Cliente, FirestoreService) onMostrarOpcoes;
  final void Function(BuildContext, Cliente, FirestoreService) onDismissed;

  const KanbanView({
    super.key,
    required this.tabController,
    required this.todosClientes,
    required this.filtroTexto,
    required this.ordenarPor,
    required this.descendente,
    required this.onMostrarOpcoes,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final List<FaseCliente> fases = FaseCliente.values;

    return TabBarView(
      controller: tabController,
      children: fases.map((fase) {
        List<Cliente> clientesFiltrados;

        if (filtroTexto.trim().isNotEmpty) {
          clientesFiltrados = todosClientes.where((c) {
            final busca = filtroTexto.toLowerCase().trim();
            return c.nome.toLowerCase().contains(busca) ||
                (c.nomeEsposa ?? "").toLowerCase().contains(busca) ||
                (c.vendedorNome ?? "").toLowerCase().contains(busca);
          }).toList();
        } else {
          clientesFiltrados = todosClientes.where((c) => c.fase == fase).toList();
        }

        clientesFiltrados.sort((a, b) {
          dynamic valA, valB;
          if (ordenarPor == "nome") {
            valA = a.nome.toLowerCase();
            valB = b.nome.toLowerCase();
          } else if (ordenarPor == "proximoContato") {
            valA = a.proximoContato ?? DateTime(2100);
            valB = b.proximoContato ?? DateTime(2100);
          } else {
            valA = a.dataAtualizacao;
            valB = b.dataAtualizacao;
          }
          return descendente ? valB.compareTo(valA) : valA.compareTo(valB);
        });

        return ClienteListFiltered(
          clientes: clientesFiltrados,
          filtroNome: filtroTexto,
          onTileTap: (ctx, cliente, svc) => onMostrarOpcoes(context, cliente, svc),
          onDismissed: (cliente) => onDismissed(context, cliente, FirestoreService()),
        );
      }).toList(),
    );
  }
}
