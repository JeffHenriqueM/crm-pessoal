import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../services/firestore_service.dart';
import 'cliente_list_filtered.dart';

class KanbanView extends StatelessWidget {
  final TabController tabController;
  final List<Cliente> todosClientes;
  final String filtroTexto;
  final String ordenarPor;
  final bool descendente;
  final void Function(BuildContext, Cliente, FirestoreService) onMostrarOpcoes;

  const KanbanView({
    super.key,
    required this.tabController,
    required this.todosClientes,
    required this.filtroTexto,
    required this.ordenarPor,
    required this.descendente,
    required this.onMostrarOpcoes,
  });

  List<Cliente> _filterClientes(List<Cliente> clientes) {
    if (filtroTexto.trim().isEmpty) return clientes;
    final busca = filtroTexto.toLowerCase().trim();
    return clientes.where((c) {
      return c.nome.toLowerCase().contains(busca) ||
          (c.nomeEsposa ?? '').toLowerCase().contains(busca) ||
          (c.vendedorNome ?? '').toLowerCase().contains(busca);
    }).toList();
  }

  void _sortClientes(List<Cliente> clientes) {
    clientes.sort((a, b) {
      dynamic valA, valB;
      switch (ordenarPor) {
        case 'nome':
          valA = a.nome.toLowerCase();
          valB = b.nome.toLowerCase();
          break;
        case 'proximoContato':
          valA = a.proximoContato ?? DateTime(2100);
          valB = b.proximoContato ?? DateTime(2100);
          break;
        default:
          valA = a.dataAtualizacao;
          valB = b.dataAtualizacao;
      }
      return descendente ? valB.compareTo(valA) : valA.compareTo(valB);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isLargeScreen = MediaQuery.of(context).size.width > 750;

    if (isLargeScreen) {
      final clientesFiltrados = _filterClientes(todosClientes);

      return Row(
        children: FaseCliente.values.map((fase) {
          final clientesDaColuna =
              clientesFiltrados.where((c) => c.fase == fase).toList();
          _sortClientes(clientesDaColuna);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '${fase.nomeDisplay.toUpperCase()} (${clientesDaColuna.length})',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ClienteListFiltered(
                      clientes: clientesDaColuna,
                      filtroNome: '',
                      onTileTap: onMostrarOpcoes,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    }

    return TabBarView(
      controller: tabController,
      children: FaseCliente.values.map((fase) {
        List<Cliente> clientesDaAba;
        if (filtroTexto.trim().isNotEmpty) {
          clientesDaAba = _filterClientes(todosClientes);
        } else {
          clientesDaAba = todosClientes.where((c) => c.fase == fase).toList();
        }
        _sortClientes(clientesDaAba);

        return ClienteListFiltered(
          clientes: clientesDaAba,
          filtroNome: filtroTexto,
          onTileTap: onMostrarOpcoes,
        );
      }).toList(),
    );
  }
}
