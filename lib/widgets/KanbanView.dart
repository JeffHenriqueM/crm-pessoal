// lib/widgets/KanbanView.dart

import 'package:flutter/material.dart';
import '../../models/cliente_model.dart';
import '../../models/fase_enum.dart';import '../../services/firestore_service.dart';
import 'cliente_list_filtered.dart';

class KanbanView extends StatelessWidget {
  final TabController tabController;
  final List<Cliente> todosClientes;
  final String filtroTexto;
  final String ordenarPor;
  final bool descendente;
  // A assinatura das suas funções está correta, vamos mantê-la
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

  // Função auxiliar para filtrar a lista de clientes
  List<Cliente> _filterClientes(List<Cliente> clientes) {
    if (filtroTexto.trim().isEmpty) {
      return clientes;
    }
    final busca = filtroTexto.toLowerCase().trim();
    // CORREÇÃO: Usa apenas os campos que existem no seu modelo
    return clientes.where((c) {
      return c.nome.toLowerCase().contains(busca) ||
          (c.nomeEsposa ?? "").toLowerCase().contains(busca) ||
          (c.vendedorNome ?? "").toLowerCase().contains(busca);
    }).toList();
  }

  // Função auxiliar para ordenar a lista de clientes
  void _sortClientes(List<Cliente> clientes) {
    // CORREÇÃO: Usa apenas os campos de ordenação que existem
    clientes.sort((a, b) {
      dynamic valA, valB;
      switch (ordenarPor) {
        case "nome":
          valA = a.nome.toLowerCase();
          valB = b.nome.toLowerCase();
          break;
        case "proximoContato":
          valA = a.proximoContato ?? DateTime(2100);
          valB = b.proximoContato ?? DateTime(2100);
          break;
        default: // dataAtualizacao
          valA = a.dataAtualizacao;
          valB = b.dataAtualizacao;
      }
      return descendente ? valB.compareTo(valA) : valA.compareTo(valB);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Ponto de decisão: qual layout usar?
    final bool isLargeScreen = MediaQuery.of(context).size.width > 750;

    if (isLargeScreen) {
      // --- LAYOUT PARA TELA GRANDE (MAC/DESKTOP) ---
      final List<FaseCliente> fases = FaseCliente.values;
      final clientesFiltradosGeral = _filterClientes(todosClientes);

      return Row(
        children: fases.map((fase) {
          // Para cada coluna, pegamos os clientes daquela fase a partir da lista já filtrada pela busca
          final clientesDaColuna = clientesFiltradosGeral.where((c) => c.fase == fase).toList();
          _sortClientes(clientesDaColuna); // Ordena a lista da coluna

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabeçalho da Coluna
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      '${fase.nomeDisplay.toUpperCase()} (${clientesDaColuna.length})',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(height: 1),
                  // Lista de Clientes
                  Expanded(
                    child: ClienteListFiltered(
                      clientes: clientesDaColuna,
                      filtroNome: '', // O filtro já foi aplicado, não precisa passar de novo
                      onTileTap: (ctx, cliente, svc) => onMostrarOpcoes(ctx, cliente, svc),
                      // Passa uma nova instância como seu código original já fazia
                      onDismissed: (cliente) => onDismissed(context, cliente, FirestoreService()),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    } else {
      // --- LAYOUT PARA TELA PEQUENA (CELULAR) - LÓGICA ORIGINAL RESTAURADA ---
      return TabBarView(
        controller: tabController,
        children: FaseCliente.values.map((fase) {
          List<Cliente> clientesDaAba;
          // Lógica idêntica à sua original:
          if (filtroTexto.trim().isNotEmpty) {
            clientesDaAba = _filterClientes(todosClientes);
          } else {
            clientesDaAba = todosClientes.where((c) => c.fase == fase).toList();
          }

          _sortClientes(clientesDaAba);

          return ClienteListFiltered(
            clientes: clientesDaAba,
            filtroNome: filtroTexto,
            onTileTap: (ctx, cliente, svc) => onMostrarOpcoes(ctx, cliente, svc),
            onDismissed: (cliente) => onDismissed(context, cliente, FirestoreService()),
          );
        }).toList(),
      );
    }
  }
}
