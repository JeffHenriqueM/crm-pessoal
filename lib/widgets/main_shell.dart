import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/apresentacao_screen.dart';
import '../screens/campanhas_screen.dart';
import '../screens/configuracoes_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/gerenciar_produtos_screen.dart';
import '../screens/gerenciar_usuarios_screen.dart';
import '../screens/lista_clientes_screen.dart';
import '../screens/pos_venda_screen.dart';
import '../screens/recepcao_screen.dart';
import 'aba_pos_venda.dart';
import '../screens/tickets_screen.dart';
import '../screens/vendedor_home_screen.dart';
import '../screens/ficha_ticket_screen.dart';
import '../services/auth_service.dart';
import '../utils/env.dart';
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
  final String? currentUserName;

  const MainShell({
    super.key,
    required this.userProfile,
    required this.currentUserId,
    this.currentUserName,
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
  bool get _isPosVenda => widget.userProfile == 'pós-venda';

  // ── Item de recepção — aparece em todos os perfis ────────────────────────
  static const _recepcaoItem = _NavItem(
    icon: Icons.meeting_room_outlined,
    activeIcon: Icons.meeting_room_rounded,
    label: 'Recepção',
  );

  // ── Item de apresentação — aparece em todos exceto recepção ─────────────
  static const _apresentacaoItem = _NavItem(
    icon: Icons.co_present_outlined,
    activeIcon: Icons.co_present,
    label: 'Apresentação',
  );

  // ── Item de tickets — aparece em todos os perfis ─────────────────────────
  static const _ticketsItem = _NavItem(
    icon: Icons.confirmation_number_outlined,
    activeIcon: Icons.confirmation_number_rounded,
    label: 'Tickets',
  );

  // ── Itens de navegação (variam por perfil) ────────────────────────────────
  List<_NavItem> get _navItems {
    // ── Admin: Dashboard primeiro ─────────────────────────────────
    if (_isAdmin) {
      return const [
        _NavItem(icon: Icons.bar_chart_outlined,      activeIcon: Icons.bar_chart_rounded,    label: 'Dashboard'),
        _NavItem(icon: Icons.view_kanban_outlined,     activeIcon: Icons.view_kanban,          label: 'Funil de Vendas'),
        _NavItem(icon: Icons.calendar_month_outlined,  activeIcon: Icons.calendar_month,       label: 'Agenda'),
        _NavItem(icon: Icons.campaign_outlined,        activeIcon: Icons.campaign,             label: 'Campanhas'),
        _NavItem(icon: Icons.description_outlined,      activeIcon: Icons.description,           label: 'Pós-Venda'),
        _apresentacaoItem,
        _ticketsItem,
        _recepcaoItem,
      ];
    }
    // ── Vendedor/captador: Agenda primeiro ────────────────────────
    if (!_isListaProfile) {
      return const [
        _NavItem(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month,    label: 'Agenda'),
        _NavItem(icon: Icons.view_kanban_outlined,    activeIcon: Icons.view_kanban,        label: 'Funil de Vendas'),
        _apresentacaoItem,
        _NavItem(icon: Icons.bar_chart_outlined,      activeIcon: Icons.bar_chart_rounded,  label: 'Dashboard'),
        _ticketsItem,
        _recepcaoItem,
      ];
    }
    // ── pós-venda: Pós-Venda primeiro + mesmos itens do vendedor ─
    if (_isPosVenda) {
      return const [
        _NavItem(icon: Icons.description_outlined,     activeIcon: Icons.description,          label: 'Pós-Venda'),
        _NavItem(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month,     label: 'Agenda'),
        _NavItem(icon: Icons.view_kanban_outlined,    activeIcon: Icons.view_kanban,        label: 'Funil de Vendas'),
        _apresentacaoItem,
        _NavItem(icon: Icons.bar_chart_outlined,      activeIcon: Icons.bar_chart_rounded,  label: 'Dashboard'),
        _ticketsItem,
        _recepcaoItem,
      ];
    }
    // ── financeiro: Dashboard primeiro ────────────────────────────
    return const [
      _NavItem(icon: Icons.bar_chart_outlined,   activeIcon: Icons.bar_chart_rounded, label: 'Dashboard'),
      _NavItem(icon: Icons.view_kanban_outlined,  activeIcon: Icons.view_kanban,       label: 'Funil de Vendas'),
      _apresentacaoItem,
      _ticketsItem,
      _recepcaoItem,
    ];
  }

  // ── Páginas (IndexedStack preserva o estado) ──────────────────────────────
  late final List<Widget> _pages = [
    if (_isAdmin) ...[
      DashboardScreen(userProfile: widget.userProfile),
      ListaClientesScreen(userProfile: widget.userProfile),
      VendedorHomeScreen(currentUserId: widget.currentUserId, showAllVendedores: true),
      const CampanhasScreen(),
      _PosVendaHomeScreen(userProfile: widget.userProfile),
      ApresentacaoScreen(userProfile: widget.userProfile, currentUserId: widget.currentUserId, currentUserName: widget.currentUserName),
      TicketsScreen(userProfile: widget.userProfile, currentUserId: widget.currentUserId, currentUserName: widget.currentUserName),
      const RecepcaoShell(),
    ] else if (!_isListaProfile) ...[
      VendedorHomeScreen(currentUserId: widget.currentUserId),
      ListaClientesScreen(userProfile: widget.userProfile),
      ApresentacaoScreen(userProfile: widget.userProfile, currentUserId: widget.currentUserId, currentUserName: widget.currentUserName),
      DashboardScreen(userProfile: widget.userProfile),
      TicketsScreen(userProfile: widget.userProfile, currentUserId: widget.currentUserId, currentUserName: widget.currentUserName),
      const RecepcaoShell(),
    ] else if (_isPosVenda) ...[
      _PosVendaHomeScreen(userProfile: widget.userProfile),
      VendedorHomeScreen(currentUserId: widget.currentUserId),
      ListaClientesScreen(userProfile: widget.userProfile),
      ApresentacaoScreen(userProfile: widget.userProfile, currentUserId: widget.currentUserId, currentUserName: widget.currentUserName),
      DashboardScreen(userProfile: widget.userProfile),
      TicketsScreen(userProfile: widget.userProfile, currentUserId: widget.currentUserId, currentUserName: widget.currentUserName),
      const RecepcaoShell(),
    ] else ...[
      // financeiro: Dashboard primeiro
      DashboardScreen(userProfile: widget.userProfile),
      ListaClientesScreen(userProfile: widget.userProfile),
      ApresentacaoScreen(userProfile: widget.userProfile, currentUserId: widget.currentUserId, currentUserName: widget.currentUserName),
      TicketsScreen(userProfile: widget.userProfile, currentUserId: widget.currentUserId, currentUserName: widget.currentUserName),
      const RecepcaoShell(),
    ],
  ];

  final _mobileScaffoldKey = GlobalKey<ScaffoldState>();

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

  // ── Nome da tela atual (para contexto do ticket) ──────────────────────────
  String get _nomeTelaAtual {
    final items = _navItems;
    if (_selectedIndex >= items.length) return 'Sistema';
    return items[_selectedIndex].label;
  }

  // ── FAB global de ticket (canto inferior esquerdo) ────────────────────────
  Widget _buildTicketFab(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'global_ticket_fab',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FichaTicketScreen(
            userProfile: widget.userProfile,
            currentUserId: widget.currentUserId,
            currentUserName: widget.currentUserName,
            contexto: _nomeTelaAtual,
          ),
        ),
      ),
      tooltip: 'Abrir ticket',
      backgroundColor: Colors.amber.shade600,
      foregroundColor: Colors.white,
      child: const Icon(Icons.confirmation_number_outlined, size: 20),
    );
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

    // ── Mobile: drawer navigation ──────────────────────────────────────────
    if (isMobile) {
      return Scaffold(
        key: _mobileScaffoldKey,
        appBar: _buildMobileAppBar(context),
        drawer: _buildMobileDrawer(context),
        body: Column(
          children: [
            if (kIsStaging) _buildStagingBanner(),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: _pages,
              ),
            ),
          ],
        ),
        floatingActionButton: _buildTicketFab(context),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      );
    }

    // ── Desktop: collapsible sidebar ───────────────────────────────────────
    return Scaffold(
      body: Column(
        children: [
          if (kIsStaging) _buildStagingBanner(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSidebarPanel(context),
                Expanded(
                  child: Stack(
                    children: [
                      IndexedStack(
                        index: _selectedIndex,
                        children: _pages,
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        child: _buildTicketFab(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Banner de staging ──────────────────────────────────────────────────────
  Widget _buildStagingBanner() {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade700,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.science_outlined, size: 13, color: Colors.white),
          SizedBox(width: 6),
          Text(
            'STAGING — Lançamentos de teste serão excluídos automaticamente',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
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
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: () => _mobileScaffoldKey.currentState?.openDrawer(),
        tooltip: 'Menu',
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
          currentUserId: widget.currentUserId,
          userProfile: widget.userProfile,
          currentUserName: widget.currentUserName,
        ),
      ],
    );
  }

  // ── Drawer de navegação para mobile ───────────────────────────────────────
  Widget _buildMobileDrawer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = _navItems;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Image.asset('assets/images/logo.png',
                      height: 28, filterQuality: FilterQuality.medium),
                  const SizedBox(width: 10),
                  Text(
                    'Villamor CRM',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            const SizedBox(height: 8),

            // Itens de navegação
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  final selected = _selectedIndex == i;
                  return ListTile(
                    leading: Icon(
                      selected ? item.activeIcon : item.icon,
                      color: selected
                          ? cs.onPrimaryContainer
                          : cs.onSurfaceVariant,
                      size: 22,
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 15,
                        color: selected ? cs.onPrimaryContainer : cs.onSurface,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    selected: selected,
                    selectedTileColor:
                        cs.primaryContainer.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    horizontalTitleGap: 8,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    dense: true,
                    onTap: () {
                      setState(() => _selectedIndex = i);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),

            Divider(height: 1, color: cs.outlineVariant),
            const SizedBox(height: 4),

            // Notificações
            NotificacaoBell(
              vendedorId: _isAdmin ? null : widget.currentUserId,
              currentUserId: widget.currentUserId,
              userProfile: widget.userProfile,
              currentUserName: widget.currentUserName,
              showAsListTile: true,
            ),

            // Produtos (super admin only)
            if (widget.userProfile == 'super admin')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                child: ListTile(
                  leading: Icon(Icons.inventory_2_outlined,
                      color: cs.onSurfaceVariant, size: 22),
                  title: Text('Produtos',
                      style: TextStyle(fontSize: 15, color: cs.onSurface)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  horizontalTitleGap: 8,
                  dense: true,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const GerenciarProdutosScreen(),
                      ),
                    );
                  },
                ),
              ),

            // Usuários (admin only)
            if (_isAdmin)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                child: ListTile(
                  leading: Icon(Icons.manage_accounts_outlined,
                      color: cs.onSurfaceVariant, size: 22),
                  title: Text('Usuários',
                      style: TextStyle(fontSize: 15, color: cs.onSurface)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  horizontalTitleGap: 8,
                  dense: true,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GerenciarUsuariosScreen(
                            currentUserPerfil: widget.userProfile),
                      ),
                    );
                  },
                ),
              ),

            // Configurações
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              child: ListTile(
                leading: Icon(Icons.settings_outlined,
                    color: cs.onSurfaceVariant, size: 22),
                title: Text('Configurações',
                    style: TextStyle(fontSize: 15, color: cs.onSurface)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                horizontalTitleGap: 8,
                dense: true,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                onTap: () {
                  Navigator.pop(context);
                  _abrirConfiguracoes(context);
                },
              ),
            ),

            // Sair
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 1, 8, 12),
              child: ListTile(
                leading: Icon(Icons.logout_outlined,
                    color: cs.onSurfaceVariant, size: 22),
                title: Text('Sair',
                    style: TextStyle(fontSize: 15, color: cs.onSurface)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                horizontalTitleGap: 8,
                dense: true,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                onTap: () => AuthService().signOut(),
              ),
            ),
          ],
        ),
      ),
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
                          color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
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
                  color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                  size: 20,
                ),
                title: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: selected ? cs.onPrimaryContainer : cs.onSurface,
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
              currentUserId: widget.currentUserId,
              userProfile: widget.userProfile,
              currentUserName: widget.currentUserName,
              showAsListTile: true,
            )
          else
            Center(
              child: NotificacaoBell(
                vendedorId: _isAdmin ? null : widget.currentUserId,
                currentUserId: widget.currentUserId,
                userProfile: widget.userProfile,
                currentUserName: widget.currentUserName,
              ),
            ),

          // ── Produtos (super admin only) ────────────────────────────────
          if (widget.userProfile == 'super admin')
            if (_sidebarExpanded)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                child: ListTile(
                  leading: Icon(Icons.inventory_2_outlined,
                      color: cs.onSurfaceVariant, size: 20),
                  title: Text('Produtos',
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
                      builder: (_) => const GerenciarProdutosScreen(),
                    ),
                  ),
                ),
              )
            else
              Center(
                child: Tooltip(
                  message: 'Produtos',
                  preferBelow: false,
                  child: IconButton(
                    icon: Icon(Icons.inventory_2_outlined,
                        color: cs.onSurfaceVariant, size: 20),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const GerenciarProdutosScreen(),
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
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

// ── Tela de Pós-Venda: visão geral (KPIs) + lista de contratos ───────────────
class _PosVendaHomeScreen extends StatelessWidget {
  final String userProfile;
  const _PosVendaHomeScreen({required this.userProfile});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pós-Venda'),
          toolbarHeight: 50,
          bottom: const TabBar(
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Visão Geral', icon: Icon(Icons.dashboard_outlined)),
              Tab(text: 'Contratos',   icon: Icon(Icons.description_outlined)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const AbaPosVenda(),
            PosVendaScreen(userProfile: userProfile),
          ],
        ),
      ),
    );
  }
}
