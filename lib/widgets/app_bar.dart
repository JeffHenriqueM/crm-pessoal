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
  final VoidCallback? onFiltroTap;
  final int filtrosAtivos;

  const ListaClientesAppBar({
    super.key,
    required this.estaPesquisando,
    required this.usarKanban,
    required this.searchController,
    required this.tabController,
    required this.onSearchStateChange,
    required this.onSortChange,
    required this.onToggleView,
    this.onFiltroTap,
    this.filtrosAtivos = 0,
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
        // Filtros avançados
        if (!usarKanban)
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: Icon(
                  Icons.filter_list,
                  color: filtrosAtivos > 0
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                tooltip: 'Filtros',
                onPressed: onFiltroTap,
              ),
              if (filtrosAtivos > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$filtrosAtivos',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
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
