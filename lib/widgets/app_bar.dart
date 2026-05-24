import 'package:flutter/material.dart';
import '../models/fase_enum.dart';
import '../models/usuario_model.dart';
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
    final cs = Theme.of(context).colorScheme;
    final bool isSmallScreen = MediaQuery.of(context).size.width < 650;

    return AppBar(
      leading: estaPesquisando
          ? null
          : Padding(
              padding: const EdgeInsets.all(10),
              child: Image.asset(
                'assets/images/logo.png',
                filterQuality: FilterQuality.medium,
              ),
            ),
      title: estaPesquisando
          ? TextField(
              controller: searchController,
              autofocus: true,
              style: TextStyle(color: cs.onPrimary),
              decoration: InputDecoration(
                hintText: 'Pesquisar clientes...',
                hintStyle: TextStyle(color: cs.onPrimary.withValues(alpha: 0.7)),
                border: InputBorder.none,
                filled: false,
              ),
              onChanged: (_) => onSearchStateChange(true),
            )
          : const Text('Villamor CRM'),
      actions: _buildActions(context, isSmallScreen),
      bottom: estaPesquisando
          ? null
          : TabBar(
              controller: tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: FaseCliente.values
                  .map((fase) => Tab(text: fase.nomeDisplay))
                  .toList(),
            ),
    );
  }

  List<Widget> _buildActions(BuildContext context, bool isSmallScreen) {
    final cs = Theme.of(context).colorScheme;
    final bool canShowVendedorFilter =
        userProfile == 'admin' && todosVendedores.isNotEmpty;
    final bool isAdmin = userProfile == 'admin';

    if (isSmallScreen) {
      return [
        IconButton(
          icon: const Icon(Icons.bar_chart_rounded),
          tooltip: 'Dashboard',
          onPressed: onShowDashboard,
        ),
        IconButton(
          icon: Icon(estaPesquisando ? Icons.close : Icons.search),
          tooltip: estaPesquisando ? 'Fechar busca' : 'Pesquisar',
          onPressed: () => onSearchStateChange(false),
        ),
        PopupMenuButton<String>(
          tooltip: 'Mais opções',
          onSelected: (value) {
            if (value == 'manage_users') {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const GerenciarUsuariosScreen()),
              );
            } else if (value.startsWith('sort_')) {
              onSortChange(value.substring(5));
            } else if (value == 'logout') {
              onLogout();
            } else if (canShowVendedorFilter) {
              onVendedorChange(value == 'todos' ? null : value);
            }
          },
          itemBuilder: (ctx) {
            final items = <PopupMenuEntry<String>>[];

            if (isAdmin) {
              items.add(const PopupMenuItem<String>(
                value: 'manage_users',
                child: ListTile(
                  leading: Icon(Icons.manage_accounts_outlined),
                  title: Text('Gerenciar Usuários'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ));
              items.add(const PopupMenuDivider());
            }

            if (canShowVendedorFilter) {
              items.add(const PopupMenuItem<String>(
                enabled: false,
                child: Text('Filtrar por vendedor',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ));
              items.add(
                const PopupMenuItem<String>(value: 'todos', child: Text('Todos')));
              items.addAll(todosVendedores.map((v) =>
                  PopupMenuItem<String>(value: v.id, child: Text(v.nome))));
              items.add(const PopupMenuDivider());
            }

            items.add(const PopupMenuItem<String>(
              enabled: false,
              child: Text('Ordenar por',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ));
            items.add(const PopupMenuItem<String>(
                value: 'sort_dataAtualizacao', child: Text('Data')));
            items.add(const PopupMenuItem<String>(
                value: 'sort_nome', child: Text('Nome')));
            items.add(const PopupMenuDivider());
            items.add(const PopupMenuItem<String>(
                value: 'logout', child: Text('Sair')));

            return items;
          },
        ),
      ];
    }

    // Tela grande
    return [
      IconButton(
        icon: const Icon(Icons.bar_chart_rounded),
        tooltip: 'Dashboard',
        onPressed: onShowDashboard,
      ),
      if (isAdmin)
        IconButton(
          icon: const Icon(Icons.manage_accounts_outlined),
          tooltip: 'Gerenciar Usuários',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const GerenciarUsuariosScreen()),
          ),
        ),
      if (canShowVendedorFilter)
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: DropdownButton<String>(
              value: vendedorIdFiltro,
              hint: Text(
                'Vendedor',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8)),
              ),
              onChanged: onVendedorChange,
              underline: const SizedBox.shrink(),
              icon: Icon(Icons.people_outlined,
                  color: Theme.of(context).colorScheme.onPrimary),
              dropdownColor: cs.primary,
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text('Todos',
                      style: TextStyle(color: cs.onPrimary)),
                ),
                ...todosVendedores.map((v) => DropdownMenuItem<String>(
                      value: v.id,
                      child: Text(v.nome,
                          style: TextStyle(color: cs.onPrimary)),
                    )),
              ],
            ),
          ),
        ),
      IconButton(
        icon: Icon(estaPesquisando ? Icons.close : Icons.search),
        tooltip: estaPesquisando ? 'Fechar busca' : 'Pesquisar',
        onPressed: () => onSearchStateChange(false),
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.sort),
        tooltip: 'Ordenar',
        onSelected: onSortChange,
        itemBuilder: (_) => const [
          PopupMenuItem<String>(
              value: 'dataAtualizacao', child: Text('Ordenar por Data')),
          PopupMenuItem<String>(value: 'nome', child: Text('Ordenar por Nome')),
        ],
      ),
      IconButton(
        icon: const Icon(Icons.logout),
        tooltip: 'Sair',
        onPressed: onLogout,
      ),
    ];
  }

  @override
  Size get preferredSize => Size.fromHeight(
      kToolbarHeight + (estaPesquisando ? 0 : kTextTabBarHeight));
}
