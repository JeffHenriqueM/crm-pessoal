import 'package:flutter/material.dart';
import '../models/fase_enum.dart';

/// AppBar exclusivo da tela de Leads (busca + ordenação + toggle kanban/lista).
/// Navegação, notificações, tema e logout ficam na barra lateral (MainShell).
class ListaClientesAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final bool estaPesquisando;
  final bool usarKanban;
  final TextEditingController searchController;
  final TabController tabController;
  final Function(bool) onSearchStateChange;
  final Function(String) onSortChange;
  final VoidCallback onToggleView;

  const ListaClientesAppBar({
    super.key,
    required this.estaPesquisando,
    required this.usarKanban,
    required this.searchController,
    required this.tabController,
    required this.onSearchStateChange,
    required this.onSortChange,
    required this.onToggleView,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showTabs = !estaPesquisando && !usarKanban;

    return AppBar(
      automaticallyImplyLeading: false,
      title: estaPesquisando
          ? TextField(
              controller: searchController,
              autofocus: true,
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'Pesquisar clientes...',
                hintStyle: TextStyle(color: cs.onSurfaceVariant),
                border: InputBorder.none,
                filled: false,
              ),
              onChanged: (_) => onSearchStateChange(true),
            )
          : Row(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 26,
                  filterQuality: FilterQuality.medium,
                ),
                const SizedBox(width: 8),
                const Text('Leads'),
              ],
            ),
      actions: [
        // Toggle: lista ↔ kanban
        IconButton(
          icon: Icon(usarKanban
              ? Icons.view_list_outlined
              : Icons.view_kanban_outlined),
          tooltip: usarKanban ? 'Visão em lista' : 'Visão Kanban',
          onPressed: onToggleView,
        ),
        // Busca (só na lista)
        if (!usarKanban)
          IconButton(
            icon: Icon(estaPesquisando ? Icons.close : Icons.search),
            tooltip: estaPesquisando ? 'Fechar busca' : 'Pesquisar',
            onPressed: () => onSearchStateChange(false),
          ),
        // Ordenação
        if (!usarKanban)
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Ordenar',
            onSelected: onSortChange,
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'dataAtualizacao',
                child: Text('Ordenar por Data'),
              ),
              PopupMenuItem<String>(
                value: 'nome',
                child: Text('Ordenar por Nome'),
              ),
            ],
          ),
      ],
      bottom: showTabs
          ? TabBar(
              controller: tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: FaseCliente.values
                  .map((fase) => Tab(text: fase.nomeDisplay))
                  .toList(),
            )
          : null,
    );
  }

  @override
  Size get preferredSize {
    final showTabs = !estaPesquisando && !usarKanban;
    return Size.fromHeight(
        kToolbarHeight + (showTabs ? kTextTabBarHeight : 0));
  }
}
