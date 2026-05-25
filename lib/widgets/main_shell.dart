import 'package:flutter/material.dart';
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

// ── Shell principal com barra lateral ────────────────────────────────────────
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
  final _scaffoldKey = GlobalKey<ScaffoldState>();

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
        if (_isAdmin)
          const _NavItem(
            icon: Icons.manage_accounts_outlined,
            activeIcon: Icons.manage_accounts,
            label: 'Usuários',
          ),
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
    if (_isAdmin) const GerenciarUsuariosScreen(),
  ];

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    if (isWide) {
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

    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildNarrowAppBar(context),
      drawer: Drawer(
        child: _buildSidebarContent(context, inDrawer: true),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
    );
  }

  // ── AppBar minimalista para telas estreitas ───────────────────────────────
  PreferredSizeWidget _buildNarrowAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded),
        tooltip: 'Menu',
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
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

  // ── Painel lateral (telas largas) ─────────────────────────────────────────
  Widget _buildSidebarPanel(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          right: BorderSide(color: cs.outlineVariant, width: 1),
        ),
      ),
      child: _buildSidebarContent(context, inDrawer: false),
    );
  }

  // ── Conteúdo da barra lateral (usado em painel e drawer) ─────────────────
  Widget _buildSidebarContent(BuildContext context, {required bool inDrawer}) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Logo + nome ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 30,
                  filterQuality: FilterQuality.medium,
                ),
                const SizedBox(width: 10),
                Text(
                  'Villamor CRM',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: 8),

          // ── Itens de navegação ────────────────────────────────────
          ...List.generate(_navItems.length, (i) {
            final item = _navItems[i];
            final selected = _selectedIndex == i;
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
                onTap: () {
                  setState(() => _selectedIndex = i);
                  if (inDrawer) Navigator.of(context).pop();
                },
              ),
            );
          }),

          const Spacer(),

          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: 4),

          // ── Notificações ──────────────────────────────────────────
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
          ),

          // ── Tema ──────────────────────────────────────────────────
          AnimatedBuilder(
            animation: ThemeController.instance,
            builder: (_, __) {
              final isDark = ThemeController.instance.isDark;
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

          // ── Sair ──────────────────────────────────────────────────
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
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
