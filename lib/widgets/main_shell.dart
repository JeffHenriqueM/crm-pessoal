import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/campanhas_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/gerenciar_usuarios_screen.dart';
import '../screens/lista_clientes_screen.dart';
import '../screens/negociacoes_screen.dart';
import '../screens/vendedor_home_screen.dart';
import '../services/auth_service.dart';
import '../theme/theme_controller.dart';
import 'notificacao_bell.dart';

// ── Modelo interno de item de nav ─────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

// ── Shell principal ───────────────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  final String userProfile;
  final String? currentUserId;

  const MainShell({
    super.key,
    required this.userProfile,
    required this.currentUserId,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  bool _sidebarExpanded = true;

  static const _listaProfiles = {'admin', 'pós-venda', 'financeiro'};

  bool get _isListaProfile => _listaProfiles.contains(widget.userProfile);
  bool get _isAdmin => widget.userProfile == 'admin';

  // ── Itens de navegação (variam por perfil) ────────────────────────────────
  List<_NavItem> get _navItems => [
        if (!_isListaProfile)
          const _NavItem(
            icon: Icons.calendar_month_outlined,
            activeIcon: Icons.calendar_month,
            label: 'Agenda',
          ),
        const _NavItem(
          icon: Icons.view_kanban_outlined,
          activeIcon: Icons.view_kanban,
          label: 'Leads',
        ),
        const _NavItem(
          icon: Icons.handshake_outlined,
          activeIcon: Icons.handshake_rounded,
          label: 'Negociações',
        ),
        const _NavItem(
          icon: Icons.bar_chart_outlined,
          activeIcon: Icons.bar_chart_rounded,
          label: 'Dashboard',
        ),
        if (_isAdmin) ...[
          const _NavItem(
            icon: Icons.calendar_month_outlined,
            activeIcon: Icons.calendar_month,
            label: 'Agenda',
          ),
          const _NavItem(
            icon: Icons.manage_accounts_outlined,
            activeIcon: Icons.manage_accounts,
            label: 'Usuários',
          ),
          const _NavItem(
            icon: Icons.campaign_outlined,
            activeIcon: Icons.campaign,
            label: 'Campanhas',
          ),
        ],
      ];

  // ── Páginas (IndexedStack preserva o estado) ──────────────────────────────
  late final List<Widget> _pages = [
    if (!_isListaProfile)
      VendedorHomeScreen(currentUserId: widget.currentUserId),
    const ListaClientesScreen(),
    NegociacoesScreen(
      userProfile: widget.userProfile,
      currentUserId: widget.currentUserId,
    ),
    const DashboardScreen(),
    if (_isAdmin) ...[
      VendedorHomeScreen(
        currentUserId: widget.currentUserId,
        showAllVendedores: true,
      ),
      const GerenciarUsuariosScreen(),
      const CampanhasScreen(),
    ],
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _carregarPreferenciaSidebar();
  }

  Future<void> _carregarPreferenciaSidebar() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(
          () => _sidebarExpanded = prefs.getBool('sidebar_expanded') ?? true);
    }
  }

  Future<void> _toggleSidebar() async {
    final novoEstado = !_sidebarExpanded;
    setState(() => _sidebarExpanded = novoEstado);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sidebar_expanded', novoEstado);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    // ── Mobile: bottom navigation bar ─────────────────────────────────────
    if (isMobile) {
      return Scaffold(
        appBar: _buildMobileAppBar(context),
        body: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          destinations: _navItems
              .map((item) => NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.activeIcon),
                    label: item.label,
                  ))
              .toList(),
        ),
      );
    }

    // ── Desktop: collapsible sidebar ───────────────────────────────────────
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSidebarPanel(context),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar para mobile ─────────────────────────────────────────────────────
  PreferredSizeWidget _buildMobileAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Image.asset(
            'assets/images/logo.png',
            height: 26,
            filterQuality: FilterQuality.medium,
          ),
          const SizedBox(width: 8),
          const Text('Villamor CRM'),
        ],
      ),
      actions: [
        NotificacaoBell(
          vendedorId: _isAdmin ? null : widget.currentUserId,
        ),
      ],
    );
  }

  // ── Painel lateral colapsável ──────────────────────────────────────────────
  Widget _buildSidebarPanel(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sidebarWidth = _sidebarExpanded ? 220.0 : 64.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          right: BorderSide(color: cs.outlineVariant, width: 1),
        ),
      ),
      child: _buildSidebarContent(context),
    );
  }

  // ── Conteúdo da barra lateral ──────────────────────────────────────────────
  Widget _buildSidebarContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Logo + botão de toggle ─────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
                _sidebarExpanded ? 14 : 6, 14, 6, 12),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 28,
                  filterQuality: FilterQuality.medium,
                ),
                if (_sidebarExpanded) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Villamor CRM',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                IconButton(
                  icon: Icon(
                    _sidebarExpanded
                        ? Icons.menu_open_rounded
                        : Icons.menu_rounded,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                  onPressed: _toggleSidebar,
                  tooltip: _sidebarExpanded ? 'Recolher menu' : 'Expandir menu',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: 8),

          // ── Itens de navegação ─────────────────────────────────────────
          ...List.generate(_navItems.length, (i) {
            final item = _navItems[i];
            final selected = _selectedIndex == i;

            if (!_sidebarExpanded) {
              // Modo compacto: apenas ícone centralizado com tooltip
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                child: Tooltip(
                  message: item.label,
                  preferBelow: false,
                  child: InkWell(
                    onTap: () => setState(() => _selectedIndex = i),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected
                            ? cs.primaryContainer.withValues(alpha: 0.5)
                            : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(
                          selected ? item.activeIcon : item.icon,
                          color: selected ? cs.primary : cs.onSurfaceVariant,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            // Modo expandido: ícone + label
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              child: ListTile(
                leading: Icon(
                  selected ? item.activeIcon : item.icon,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                  size: 20,
                ),
                title: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: selected ? cs.primary : cs.onSurface,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                selected: selected,
                selectedTileColor: cs.primaryContainer.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                horizontalTitleGap: 8,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                dense: true,
                onTap: () => setState(() => _selectedIndex = i),
              ),
            );
          }),

          const Spacer(),

          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: 4),

          // ── Notificações ───────────────────────────────────────────────
          if (_sidebarExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 12, 0),
              child: Row(
                children: [
                  NotificacaoBell(
                    vendedorId: _isAdmin ? null : widget.currentUserId,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Notificações',
                    style: TextStyle(fontSize: 14, color: cs.onSurface),
                  ),
                ],
              ),
            )
          else
            Center(
              child: NotificacaoBell(
                vendedorId: _isAdmin ? null : widget.currentUserId,
              ),
            ),

          // ── Tema ──────────────────────────────────────────────────────
          AnimatedBuilder(
            animation: ThemeController.instance,
            builder: (_, __) {
              final isDark = ThemeController.instance.isDark;

              if (!_sidebarExpanded) {
                return Center(
                  child: Tooltip(
                    message: isDark ? 'Modo claro' : 'Modo escuro',
                    preferBelow: false,
                    child: IconButton(
                      icon: Icon(
                        isDark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        color: cs.onSurfaceVariant,
                        size: 20,
                      ),
                      onPressed: ThemeController.instance.toggle,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                );
              }

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                child: ListTile(
                  leading: Icon(
                    isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                  title: Text(
                    isDark ? 'Modo claro' : 'Modo escuro',
                    style: TextStyle(fontSize: 14, color: cs.onSurface),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  horizontalTitleGap: 8,
                  dense: true,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  onTap: ThemeController.instance.toggle,
                ),
              );
            },
          ),

          // ── Sair ──────────────────────────────────────────────────────
          if (_sidebarExpanded)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              child: ListTile(
                leading: Icon(Icons.logout_outlined,
                    color: cs.onSurfaceVariant, size: 20),
                title: Text('Sair',
                    style: TextStyle(fontSize: 14, color: cs.onSurface)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12),
                horizontalTitleGap: 8,
                dense: true,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                onTap: () => AuthService().signOut(),
              ),
            )
          else
            Center(
              child: Tooltip(
                message: 'Sair',
                preferBelow: false,
                child: IconButton(
                  icon: Icon(Icons.logout_outlined,
                      color: cs.onSurfaceVariant, size: 20),
                  onPressed: () => AuthService().signOut(),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
