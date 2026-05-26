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
  List<_NavItem> get _navItems {
    // ── Admin: Dashboard primeiro ─────────────────────────────────
    if (_isAdmin) {
      return const [
        _NavItem(icon: Icons.bar_chart_outlined,      activeIcon: Icons.bar_chart_rounded,    label: 'Dashboard'),
        _NavItem(icon: Icons.view_kanban_outlined,     activeIcon: Icons.view_kanban,          label: 'Leads'),
        _NavItem(icon: Icons.handshake_outlined,       activeIcon: Icons.handshake_rounded,    label: 'Negociações'),
        _NavItem(icon: Icons.calendar_month_outlined,  activeIcon: Icons.calendar_month,       label: 'Agenda'),
        _NavItem(icon: Icons.campaign_outlined,        activeIcon: Icons.campaign,             label: 'Campanhas'),
      ];
    }
    // ── Vendedor/captador: Agenda primeiro ────────────────────────
    if (!_isListaProfile) {
      return const [
        _NavItem(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month,    label: 'Agenda'),
        _NavItem(icon: Icons.view_kanban_outlined,    activeIcon: Icons.view_kanban,        label: 'Leads'),
        _NavItem(icon: Icons.handshake_outlined,      activeIcon: Icons.handshake_rounded,  label: 'Negociações'),
        _NavItem(icon: Icons.bar_chart_outlined,      activeIcon: Icons.bar_chart_rounded,  label: 'Dashboard'),
      ];
    }
    // ── pós-venda / financeiro ────────────────────────────────────
    return const [
      _NavItem(icon: Icons.view_kanban_outlined, activeIcon: Icons.view_kanban,       label: 'Leads'),
      _NavItem(icon: Icons.handshake_outlined,   activeIcon: Icons.handshake_rounded, label: 'Negociações'),
      _NavItem(icon: Icons.bar_chart_outlined,   activeIcon: Icons.bar_chart_rounded, label: 'Dashboard'),
    ];
  }

  // ── Páginas (IndexedStack preserva o estado) ──────────────────────────────
  late final List<Widget> _pages = [
    if (_isAdmin) ...[
      const DashboardScreen(),
      const ListaClientesScreen(),
      NegociacoesScreen(userProfile: widget.userProfile, currentUserId: widget.currentUserId),
      VendedorHomeScreen(currentUserId: widget.currentUserId, showAllVendedores: true),
      const CampanhasScreen(),
    ] else if (!_isListaProfile) ...[
      VendedorHomeScreen(currentUserId: widget.currentUserId),
      const ListaClientesScreen(),
      NegociacoesScreen(userProfile: widget.userProfile, currentUserId: widget.currentUserId),
      const DashboardScreen(),
    ] else ...[
      const ListaClientesScreen(),
      NegociacoesScreen(userProfile: widget.userProfile, currentUserId: widget.currentUserId),
      const DashboardScreen(),
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

  // ── Configurações ─────────────────────────────────────────────────────────
  void _abrirConfiguracoes(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return AnimatedBuilder(
          animation: ThemeController.instance,
          builder: (_, __) {
            final isDark = ThemeController.instance.isDark;
            final cs = Theme.of(ctx).colorScheme;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Configurações',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aparência',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Card Light Mode
                        Expanded(
                          child: GestureDetector(
                            onTap: isDark
                                ? ThemeController.instance.toggle
                                : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 20, horizontal: 12),
                              decoration: BoxDecoration(
                                color: !isDark
                                    ? cs.primaryContainer
                                    : cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: !isDark
                                      ? cs.primary
                                      : cs.outlineVariant,
                                  width: !isDark ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.light_mode_rounded,
                                    size: 32,
                                    color: !isDark
                                        ? cs.primary
                                        : cs.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Light Mode',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: !isDark
                                          ? cs.primary
                                          : cs.onSurfaceVariant,
                                    ),
                                  ),
                                  if (!isDark) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: cs.primary,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        'Ativo',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: cs.onPrimary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Card Dark Mode
                        Expanded(
                          child: GestureDetector(
                            onTap: !isDark
                                ? ThemeController.instance.toggle
                                : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 20, horizontal: 12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? cs.primaryContainer
                                    : cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? cs.primary
                                      : cs.outlineVariant,
                                  width: isDark ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.dark_mode_rounded,
                                    size: 32,
                                    color: isDark
                                        ? cs.primary
                                        : cs.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Dark Mode',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? cs.primary
                                          : cs.onSurfaceVariant,
                                    ),
                                  ),
                                  if (isDark) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: cs.primary,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        'Ativo',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: cs.onPrimary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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

          // ── Configurações ──────────────────────────────────────────────
          if (_sidebarExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              child: ListTile(
                leading: Icon(Icons.settings_outlined,
                    color: cs.onSurfaceVariant, size: 20),
                title: Text('Configurações',
                    style: TextStyle(fontSize: 14, color: cs.onSurface)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                horizontalTitleGap: 8,
                dense: true,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                onTap: () => _abrirConfiguracoes(context),
              ),
            )
          else
            Center(
              child: Tooltip(
                message: 'Configurações',
                preferBelow: false,
                child: IconButton(
                  icon: Icon(Icons.settings_outlined,
                      color: cs.onSurfaceVariant, size: 20),
                  onPressed: () => _abrirConfiguracoes(context),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),

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

          // ── Usuários (admin only) ──────────────────────────────────────
          if (_isAdmin)
            if (_sidebarExpanded)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                child: ListTile(
                  leading: Icon(Icons.manage_accounts_outlined,
                      color: cs.onSurfaceVariant, size: 20),
                  title: Text('Usuários',
                      style: TextStyle(fontSize: 14, color: cs.onSurface)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  horizontalTitleGap: 8,
                  dense: true,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const GerenciarUsuariosScreen()),
                  ),
                ),
              )
            else
              Center(
                child: Tooltip(
                  message: 'Usuários',
                  preferBelow: false,
                  child: IconButton(
                    icon: Icon(Icons.manage_accounts_outlined,
                        color: cs.onSurfaceVariant, size: 20),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const GerenciarUsuariosScreen()),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
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
