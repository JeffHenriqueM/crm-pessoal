// lib/widgets/app_bar.dart

import 'package:flutter/material.dart';
import '../models/fase_enum.dart';
import '../models/usuario_model.dart';
// IMPORTANTE: Adicione o import para a tela de gerenciar usuários
import '../screens/gerenciar_usuarios_screen.dart';

class ListaClientesAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool estaPesquisando;
  final String userProfile;
  final List<Usuario> todosVendedores;
  final String? vendedorIdFiltro;
  final TextEditingController searchController;
  final TabController tabController;
  final Function(bool) onSearchStateChange;
  final Function(String?) onVendedorChange;
  final Function(String) onSortChange;
  final Future<void> Function() onLogout;
  final VoidCallback onShowDashboard;

  const ListaClientesAppBar({
    super.key,
    required this.estaPesquisando,
    required this.userProfile,
    required this.todosVendedores,
    required this.vendedorIdFiltro,
    required this.searchController,
    required this.tabController,
    required this.onSearchStateChange,
    required this.onVendedorChange,
    required this.onSortChange,
    required this.onLogout,
    required this.onShowDashboard,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 650;

    return AppBar(
      title: estaPesquisando
          ? TextField(
        controller: searchController,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Pesquisar clientes...',
          hintStyle: TextStyle(color: Colors.white70),
          border: InputBorder.none,
        ),
        onChanged: (value) => onSearchStateChange(true),
      )
          : const Text('CRM Pessoal'),
      actions: _buildActions(context, isSmallScreen),
      bottom: estaPesquisando // Se estiver pesquisando...
          ? null // ...não mostre a TabBar.
          : TabBar( // Caso contrário, mostre.
        controller: tabController,
        isScrollable: true,
        tabs: FaseCliente.values
            .map((fase) => Tab(text: fase.nomeDisplay))
            .toList(),
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context, bool isSmallScreen) {
    final bool canShowVendedorFilter = userProfile == 'admin' && todosVendedores.isNotEmpty;
    final bool isAdmin = userProfile == 'admin'; // Variável auxiliar para clareza

    if (isSmallScreen) {
      // --- TELA PEQUENA (IPHONE) ---
      return [
        IconButton(
          icon: const Icon(Icons.bar_chart),
          tooltip: 'Ver Dashboard',
          onPressed: onShowDashboard,
        ),
        IconButton(
          icon: Icon(estaPesquisando ? Icons.close : Icons.search),
          tooltip: 'Pesquisar',
          onPressed: () => onSearchStateChange(false),
        ),
        PopupMenuButton<String>(
          tooltip: 'Mais Opções',
          onSelected: (value) {
            if (value == 'manage_users') { // <-- LÓGICA PARA NAVEGAR
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const GerenciarUsuariosScreen()),
              );
            } else if (value.startsWith('sort_')) {
              onSortChange(value.substring(5));
            } else if (value == 'logout') {
              onLogout();
            } else if (canShowVendedorFilter) {
              onVendedorChange(value == 'todos' ? null : value);
            }
          },
          itemBuilder: (BuildContext context) {
            List<PopupMenuEntry<String>> items = [];

            // ===== INÍCIO DA CORREÇÃO (TELA PEQUENA) =====
            if (isAdmin) {
              items.add(const PopupMenuItem<String>(
                value: 'manage_users',
                child: Row(
                  children: [
                    Icon(Icons.manage_accounts, color: Colors.black),
                    SizedBox(width: 8),
                    Text('Gerenciar Usuários'),
                  ],
                ),
              ));
              items.add(const PopupMenuDivider());
            }
            // ===== FIM DA CORREÇÃO =====

            if (canShowVendedorFilter) {
              items.add(const PopupMenuItem<String>(
                enabled: false,
                child: Text('Filtrar Vendedor',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ));
              items.add(
                  const PopupMenuItem<String>(value: 'todos', child: Text('Todos')));
              items.addAll(todosVendedores.map((vendedor) {
                return PopupMenuItem<String>(
                    value: vendedor.id, child: Text(vendedor.nome));
              }).toList());
              items.add(const PopupMenuDivider());
            }

            items.add(const PopupMenuItem<String>(
              enabled: false,
              child: Text('Ordenar Por',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ));
            items.add(const PopupMenuItem<String>(
                value: 'dataAtualizacao', child: Text('Data')));
            items.add(const PopupMenuItem<String>(
                value: 'nome', child: Text('Nome')));
            items.add(const PopupMenuDivider());

            items.add(
                const PopupMenuItem<String>(value: 'logout', child: Text('Sair')));

            return items;
          },
        ),
      ];
    } else {
      // --- TELA GRANDE (MAC/WEB) ---
      List<Widget> actions = [];

      actions.add(IconButton(
        icon: const Icon(Icons.bar_chart),
        tooltip: 'Visualizar Dashboard',
        onPressed: onShowDashboard,
      ));

      // ===== INÍCIO DA CORREÇÃO (TELA GRANDE) =====
      if (isAdmin) {
        actions.add(IconButton(
          icon: const Icon(Icons.manage_accounts_outlined),
          tooltip: 'Gerenciar Usuários',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const GerenciarUsuariosScreen()),
            );
          },
        ));
      }
      // ===== FIM DA CORREÇÃO =====

      if (canShowVendedorFilter) {
        actions.add(Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButton<String>(
              value: vendedorIdFiltro,
              hint:
              const Text('Vendedor', style: TextStyle(color: Colors.white70)),
              onChanged: onVendedorChange,
              underline: Container(),
              icon: const Icon(Icons.people, color: Colors.white),
              dropdownColor: Colors.blue.shade700,
              items: [
                const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Todos', style: TextStyle(color: Colors.white))),
                ...todosVendedores.map((vendedor) {
                  return DropdownMenuItem<String>(
                    value: vendedor.id,
                    child: Text(vendedor.nome,
                        style: const TextStyle(color: Colors.white)),
                  );
                }).toList()
              ],
            ),
          ),
        ));
      }

      actions.add(IconButton(
        icon: Icon(estaPesquisando ? Icons.close : Icons.search),
        tooltip: 'Pesquisar',
        onPressed: () => onSearchStateChange(false),
      ));

      actions.add(PopupMenuButton<String>(
        icon: const Icon(Icons.sort),
        tooltip: 'Ordenar',
        onSelected: onSortChange,
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
              value: 'dataAtualizacao', child: Text('Ordenar por Data')),
          const PopupMenuItem<String>(
              value: 'nome', child: Text('Ordenar por Nome')),
        ],
      ));

      actions.add(IconButton(
        icon: const Icon(Icons.logout),
        tooltip: 'Sair',
        onPressed: onLogout,
      ));

      return actions;
    }
  }

  @override
  Size get preferredSize => Size.fromHeight(
      kToolbarHeight + (estaPesquisando ? 0 : kTextTabBarHeight));
}
