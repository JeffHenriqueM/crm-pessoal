import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/campanhas_screen.dart';
import '../screens/configuracoes_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/gerenciar_usuarios_screen.dart';
import '../screens/lista_clientes_screen.dart';
import '../screens/negociacoes_screen.dart';
import '../screens/recepcao_screen.dart';
import '../screens/vendedor_home_screen.dart';
import '../services/auth_service.dart';
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

  static const _listaProfiles = {'admin', 'super admin', 'pós-venda', 'financeiro'};

  bool get _isListaProfile => _listaProfiles.contains(widget.userProfile);
  bool get _isAdmin =>
      widget.userProfile == 'admin' || widget.userProfile == 'super admin';

  // ── Item de recepção — aparece em todos os perfis ────────────────────────
  static const _recepcaoItem = _NavItem(
    icon: Icons.meeting_room_outlined,
    activeIcon: Icons.meeting_room,
    label: 'Recepção',
  );

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
        _recepcaoItem,
      ];
    }
    // ── Vendedor/captador: Agenda primeiro ────────────────────────
    if (!_isListaProfile) {
      return const [
        _NavItem(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month,    label: 'Agenda'),
        _NavItem(icon: Icons.view_kanban_outlined,    activeIcon: Icons.view_kanban,        label: 'Leads'),
        _NavItem(icon: Icons.handshake_outlined,      activeIcon: Icons.handshake_rounded,  label: 'Negociações'),
        _NavItem(icon: Icons.bar_chart_outlined,      activeIcon: Icons.bar_chart_rounded,  label: 'Dashboard'),
        _recepcaoItem,
      ];
    }
    // ── pós-venda / financeiro ────────────────────────────────────
    return const [
      _NavItem(icon: Icons.view_kanban_outlined, activeIcon: Icons.view_kanban,       label: 'Leads'),
      _NavItem(icon: Icons.handshake_outlined,   activeIcon: Icons.handshake_rounded, label: 'Negociações'),
      _NavItem(icon: Icons.bar_chart_outlined,   activeIcon: Icons.bar_chart_rounded, label: 'Dashboard'),
      _recepcaoItem,
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
      const RecepcaoScreen(),
    ] else if (!_isListaProfile) ...[
      VendedorHomeScreen(currentUserId: widget.currentUserId),
      const ListaClientesScreen(),
      NegociacoesScreen(userProfile: widget.userProfile, currentUserId: widget.currentUserId),
      const DashboardScreen(),
      const RecepcaoScreen(),
    ] else ...[
      const ListaClientesScreen(),
      NegociacoesScreen(userProfile: widget.userProfile, currentUserId: widget.currentUserId),
      const DashboardScreen(),
      const RecepcaoScreen(),
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConfiguracoesScreen()),
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
            NotificacaoBell(
              vendedorId: _isAdmin ? null : widget.currentUserId,
              showAsListTile: true,
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
                      builder: (_) => GerenciarUsuariosScreen(
                        currentUserPerfil: widget.userProfile,
                      ),
                    ),
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
                        builder: (_) => GerenciarUsuariosScreen(
                          currentUserPerfil: widget.userProfile,
                        ),
                      ),
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
