// lib/widgets/lista_clientes/app_bar.dart

import 'package:flutter/material.dart';import '../../models/usuario_model.dart';
import '../../screens/dashboard_screen.dart';
import '../../screens/gerenciar_usuarios_screen.dart';
import '../../screens/adicionar_cliente_screen.dart';

class ListaClientesAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool estaPesquisando;
  final String userProfile;
  final List<Usuario> todosVendedores;
  final String? vendedorIdFiltro;
  final TextEditingController searchController;
  final TabController tabController;
  final void Function(bool) onSearchStateChange;
  final void Function(String?) onVendedorChange;
  final void Function(String) onSortChange;
  final void Function() onLogout;

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
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.indigo,
      foregroundColor: Colors.white,
      title: estaPesquisando
          ? TextField(
        controller: searchController,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Buscar por nome ou parceiro...',
          hintStyle: TextStyle(color: Colors.white70),
          border: InputBorder.none,
        ),
        onChanged: (value) => onSearchStateChange(true),
      )
          : const Text('CRM Pessoal (Kanban)'),
      actions: [
        if (userProfile == 'admin')
          Row(
            children: [
              if (todosVendedores.isNotEmpty)
                DropdownButton<String?>(
                  value: vendedorIdFiltro,
                  dropdownColor: Colors.indigo.shade700,
                  icon: const Icon(Icons.filter_list, color: Colors.white),
                  underline: Container(),
                  onChanged: (id) => onVendedorChange(id),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text("Todos Vendedores", style: TextStyle(color: Colors.white)),
                    ),
                    ...todosVendedores.map<DropdownMenuItem<String?>>((vendedor) {
                      return DropdownMenuItem<String?>(
                        value: vendedor.id,
                        child: Text(vendedor.nome, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                  ],
                ),
              IconButton(
                tooltip: 'Gerenciar Usuários',
                icon: const Icon(Icons.manage_accounts),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const GerenciarUsuariosScreen()),
                ),
              ),
            ],
          ),
        IconButton(
          tooltip: 'Dashboard',
          icon: const Icon(Icons.dashboard_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          ),
        ),
        IconButton(
          tooltip: 'Pesquisar Cliente',
          icon: Icon(estaPesquisando ? Icons.close : Icons.search),
          onPressed: () => onSearchStateChange(false),
        ),
        PopupMenuButton<String>(
          tooltip: 'Ordenar',
          icon: const Icon(Icons.sort),
          onSelected: onSortChange,
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'dataAtualizacao', child: Text('Mais Recentes')),
            const PopupMenuItem(value: 'nome', child: Text('Nome (A-Z)')),
            const PopupMenuItem(value: 'proximoContato', child: Text('Próximo Contato')),
          ],
        ),
        IconButton(
          tooltip: 'Adicionar Cliente',
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AdicionarClienteScreen()),
          ),
        ),
        IconButton(
          tooltip: 'Sair',
          icon: const Icon(Icons.logout),
          onPressed: onLogout,
        ),
      ],
      bottom: TabBar(
        controller: tabController,
        isScrollable: true,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: Colors.white,
        tabs: const [
          Tab(text: "Lead"),
          Tab(text: "Contato Feito"),
          Tab(text: "Visita Agendada"),
          Tab(text: "Negociação"),
          Tab(text: "Venda Fechada"),
          Tab(text: "Venda Perdida"),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + kTextTabBarHeight);
}
