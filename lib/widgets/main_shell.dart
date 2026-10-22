import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/apresentacao_screen.dart';
import '../screens/campanhas_screen.dart';
import '../screens/configuracoes_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/fluxo_cliente_screen.dart';
import '../screens/transicao_screen.dart';
import '../screens/hotel_screen.dart';
import '../screens/gerenciar_produtos_screen.dart';
import '../screens/gerenciar_usuarios_screen.dart';
import '../screens/hospedagem_screen.dart';
import '../screens/lista_clientes_screen.dart';
import '../screens/pos_venda_screen.dart';
import '../screens/recepcao_screen.dart';
import 'aba_analise_imoveis.dart';
import 'aba_distratar.dart';
import 'aba_pos_venda.dart';
import '../screens/tickets_screen.dart';
import '../screens/tutorial_screen.dart';
import '../screens/vendedor_home_screen.dart';
import '../screens/ficha_ticket_screen.dart';
import '../services/atualizacao_service.dart';
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

class _NavEntry {
  final _NavItem item;
  final int pageIndex;
  const _NavEntry(this.item, this.pageIndex);
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
  Set<String> _favoritos = {};
  static const _prefsKeyFavoritos = 'sidebar_favoritos';

  List<_NavEntry> get _navEntries => [
    for (var i = 0; i < _navItems.length; i++) _NavEntry(_navItems[i], i),
  ];

  static const _listaProfiles = {
    'admin',
    'super admin',
    'pós-venda',
    'financeiro',
  };

  bool get _isListaProfile => _listaProfiles.contains(widget.userProfile);
  bool get _isAdmin =>
      widget.userProfile == 'admin' || widget.userProfile == 'super admin';
  bool get _isSuperAdmin => widget.userProfile == 'super admin';
  bool get _isPosVenda => widget.userProfile == 'pós-venda';
  // Perfil restrito: acessa SOMENTE o módulo de Hospedagem.
  bool get _isReserva => widget.userProfile == 'reserva';
  bool get _isRecepcao => widget.userProfile == 'recepcao';
  // Perfil restrito: acessa SOMENTE o módulo de Transição.
  bool get _isTransicao => widget.userProfile == 'transicao';

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
    label: 'Negociação/Economia',
  );

  // ── Item de tickets — aparece em todos os perfis ─────────────────────────
  static const _ticketsItem = _NavItem(
    icon: Icons.confirmation_number_outlined,
    activeIcon: Icons.confirmation_number_rounded,
    label: 'Tickets',
  );

  // ── Item de fluxo do cliente — visível apenas para admin ─────────────────
  static const _fluxoItem = _NavItem(
    icon: Icons.account_tree_outlined,
    activeIcon: Icons.account_tree,
    label: 'Fluxo',
  );

  // ── Item de hospedagem — admin/super admin e pós-venda ───────────────────
  static const _hospedagemItem = _NavItem(
    icon: Icons.hotel_outlined,
    activeIcon: Icons.hotel,
    label: 'Hospedagem',
  );

  // ── Item de transição — super admin e perfil transição ───────────────────
  static const _transicaoItem = _NavItem(
    icon: Icons.swap_horiz_outlined,
    activeIcon: Icons.swap_horiz_rounded,
    label: 'Transição',
  );

  // ── Item de hotel — super admin e perfil transição ───────────────────────
  static const _hotelItem = _NavItem(
    icon: Icons.hotel_class_outlined,
    activeIcon: Icons.hotel_class,
    label: 'Hotel',
  );

  // ── Itens de navegação (variam por perfil) ────────────────────────────────
  List<_NavItem> get _navItems {
    // ── Transição: só Transição + Hotel ───────────────────────────
    if (_isTransicao) {
      return const [_transicaoItem, _hotelItem];
    }
    // ── Reserva: somente Hospedagem ───────────────────────────────
    if (_isReserva) {
      return const [_hospedagemItem];
    }
    // ── Admin: Dashboard primeiro ─────────────────────────────────
    if (_isAdmin) {
      return [
        const _NavItem(
          icon: Icons.bar_chart_outlined,
          activeIcon: Icons.bar_chart_rounded,
          label: 'Dashboard',
        ),
        const _NavItem(
          icon: Icons.view_kanban_outlined,
          activeIcon: Icons.view_kanban,
          label: 'Funil de Vendas',
        ),
        const _NavItem(
          icon: Icons.calendar_month_outlined,
          activeIcon: Icons.calendar_month,
          label: 'Agenda',
        ),
        const _NavItem(
          icon: Icons.campaign_outlined,
          activeIcon: Icons.campaign,
          label: 'Campanhas',
        ),
        const _NavItem(
          icon: Icons.description_outlined,
          activeIcon: Icons.description,
          label: 'Pós-Venda',
        ),
        _hospedagemItem,
        _apresentacaoItem,
        _ticketsItem,
        _fluxoItem,
        _recepcaoItem,
        if (_isSuperAdmin) _transicaoItem,
        if (_isSuperAdmin) _hotelItem,
      ];
    }
    // ── Vendedor/captador/recepção: Agenda primeiro ───────────────
    if (!_isListaProfile) {
      return [
        const _NavItem(
          icon: Icons.calendar_month_outlined,
          activeIcon: Icons.calendar_month,
          label: 'Agenda',
        ),
        const _NavItem(
          icon: Icons.view_kanban_outlined,
          activeIcon: Icons.view_kanban,
          label: 'Funil de Vendas',
        ),
        _apresentacaoItem,
        const _NavItem(
          icon: Icons.bar_chart_outlined,
          activeIcon: Icons.bar_chart_rounded,
          label: 'Dashboard',
        ),
        if (_isRecepcao) _hospedagemItem,
        _ticketsItem,
        _recepcaoItem,
      ];
    }
    // ── pós-venda: Pós-Venda primeiro + mesmos itens do vendedor ─
    if (_isPosVenda) {
      return const [
        _NavItem(
          icon: Icons.description_outlined,
          activeIcon: Icons.description,
          label: 'Pós-Venda',
        ),
        _hospedagemItem,
        _NavItem(
          icon: Icons.calendar_month_outlined,
          activeIcon: Icons.calendar_month,
          label: 'Agenda',
        ),
        _NavItem(
          icon: Icons.view_kanban_outlined,
          activeIcon: Icons.view_kanban,
          label: 'Funil de Vendas',
        ),
        _apresentacaoItem,
        _NavItem(
          icon: Icons.bar_chart_outlined,
          activeIcon: Icons.bar_chart_rounded,
          label: 'Dashboard',
        ),
        _ticketsItem,
        _recepcaoItem,
      ];
    }
    // ── financeiro: Pós-Venda (sem Dashboard/Funil/Recepção/Financeiro) ─
    return const [
      _NavItem(
        icon: Icons.description_outlined,
        activeIcon: Icons.description,
        label: 'Pós-Venda',
      ),
      _apresentacaoItem,
      _ticketsItem,
    ];
  }

  // ── Páginas (IndexedStack preserva o estado) ──────────────────────────────
  late final List<Widget> _pages = [
    if (_isTransicao) ...[
      const TransicaoScreen(),
      const HotelScreen(),
    ] else if (_isReserva) ...[
      HospedagemScreen(userProfile: widget.userProfile),
    ] else if (_isAdmin) ...[
      DashboardScreen(userProfile: widget.userProfile),
      ListaClientesScreen(userProfile: widget.userProfile),
      VendedorHomeScreen(
        currentUserId: widget.currentUserId,
        showAllVendedores: true,
      ),
      const CampanhasScreen(),
      _PosVendaHomeScreen(userProfile: widget.userProfile),
      HospedagemScreen(userProfile: widget.userProfile),
      ApresentacaoScreen(
        userProfile: widget.userProfile,
        currentUserId: widget.currentUserId,
        currentUserName: widget.currentUserName,
      ),
      TicketsScreen(
        userProfile: widget.userProfile,
        currentUserId: widget.currentUserId,
        currentUserName: widget.currentUserName,
      ),
      const FluxoClienteScreen(),
      const RecepcaoShell(),
      if (_isSuperAdmin) const TransicaoScreen(),
      if (_isSuperAdmin) const HotelScreen(),
    ] else if (!_isListaProfile) ...[
      VendedorHomeScreen(currentUserId: widget.currentUserId),
      ListaClientesScreen(userProfile: widget.userProfile),
      ApresentacaoScreen(
        userProfile: widget.userProfile,
        currentUserId: widget.currentUserId,
        currentUserName: widget.currentUserName,
      ),
      DashboardScreen(userProfile: widget.userProfile),
      if (_isRecepcao) HospedagemScreen(userProfile: widget.userProfile),
      TicketsScreen(
        userProfile: widget.userProfile,
        currentUserId: widget.currentUserId,
        currentUserName: widget.currentUserName,
      ),
      const RecepcaoShell(),
    ] else if (_isPosVenda) ...[
      _PosVendaHomeScreen(userProfile: widget.userProfile),
      HospedagemScreen(userProfile: widget.userProfile),
      VendedorHomeScreen(currentUserId: widget.currentUserId),
      ListaClientesScreen(userProfile: widget.userProfile),
      ApresentacaoScreen(
        userProfile: widget.userProfile,
        currentUserId: widget.currentUserId,
        currentUserName: widget.currentUserName,
      ),
      DashboardScreen(userProfile: widget.userProfile),
      TicketsScreen(
        userProfile: widget.userProfile,
        currentUserId: widget.currentUserId,
        currentUserName: widget.currentUserName,
      ),
      const RecepcaoShell(),
    ] else ...[
      // financeiro: Pós-Venda (sem Dashboard/Funil/Recepção/Financeiro)
      _PosVendaHomeScreen(userProfile: widget.userProfile),
      ApresentacaoScreen(
        userProfile: widget.userProfile,
        currentUserId: widget.currentUserId,
        currentUserName: widget.currentUserName,
      ),
      TicketsScreen(
        userProfile: widget.userProfile,
        currentUserId: widget.currentUserId,
        currentUserName: widget.currentUserName,
      ),
    ],
  ];

  final _mobileScaffoldKey = GlobalKey<ScaffoldState>();

  // ── Perfis que abrem direto na Recepção ───────────────────────────────────
  static const _recepcaoComoPadrao = {'recepcao', 'captador'};

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _carregarPreferenciaSidebar();
    _carregarFavoritos();
    // Recepção/captador abrem direto na aba Recepção.
    if (_recepcaoComoPadrao.contains(widget.userProfile)) {
      final idx = _navItems.indexWhere((it) => it.label == _recepcaoItem.label);
      if (idx >= 0) _selectedIndex = idx;
    }
    // Avisa quando uma nova versão for publicada (só web em produção).
    AtualizacaoService.instance.iniciar();
  }

  Future<void> _carregarPreferenciaSidebar() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(
        () => _sidebarExpanded = prefs.getBool('sidebar_expanded') ?? true,
      );
    }
  }

  Future<void> _carregarFavoritos() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKeyFavoritos) ?? [];
    if (mounted) {
      setState(() => _favoritos = list.toSet());
    }
  }

  Future<void> _toggleFavorito(String label) async {
    final novo = Set<String>.of(_favoritos);
    final adicionou = !novo.contains(label);
    if (adicionou) {
      novo.add(label);
    } else {
      novo.remove(label);
    }
    setState(() => _favoritos = novo);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKeyFavoritos, novo.toList());
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(adicionou
              ? '⭐ "$label" adicionado aos favoritos'
              : '"$label" removido dos favoritos'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

  // ── Tutoriais (#33) ─────────────────────────────────────────────────────────
  void _abrirTutorial(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TutorialScreen()),
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
            _buildAtualizacaoBanner(),
            Expanded(
              child: IndexedStack(index: _selectedIndex, children: _pages),
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
          _buildAtualizacaoBanner(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSidebarPanel(context),
                Expanded(
                  child: Stack(
                    children: [
                      IndexedStack(index: _selectedIndex, children: _pages),
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

  // ── Banner de nova versão disponível ───────────────────────────────────────
  Widget _buildAtualizacaoBanner() {
    return ValueListenableBuilder<bool>(
      valueListenable: AtualizacaoService.instance.disponivel,
      builder: (context, disponivel, _) {
        if (!disponivel) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        return Material(
          color: cs.primary,
          child: InkWell(
            onTap: AtualizacaoService.instance.recarregar,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.system_update_alt, size: 16, color: cs.onPrimary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Nova versão disponível',
                      style: TextStyle(
                        color: cs.onPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: AtualizacaoService.instance.recarregar,
                    style: TextButton.styleFrom(
                      foregroundColor: cs.onPrimary,
                      backgroundColor: cs.onPrimary.withValues(alpha: 0.18),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text(
                      'Atualizar agora',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
                  Image.asset(
                    'assets/images/logo.png',
                    height: 28,
                    filterQuality: FilterQuality.medium,
                  ),
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
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: _buildMobileDrawerNavWidgets(context, cs),
              ),
            ),

            // Financeiro agora é item de navegação (não rota separada).
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
                  leading: Icon(
                    Icons.inventory_2_outlined,
                    color: cs.onSurfaceVariant,
                    size: 22,
                  ),
                  title: Text(
                    'Produtos',
                    style: TextStyle(fontSize: 15, color: cs.onSurface),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  horizontalTitleGap: 8,
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                  leading: Icon(
                    Icons.manage_accounts_outlined,
                    color: cs.onSurfaceVariant,
                    size: 22,
                  ),
                  title: Text(
                    'Usuários',
                    style: TextStyle(fontSize: 15, color: cs.onSurface),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  horizontalTitleGap: 8,
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GerenciarUsuariosScreen(
                          currentUserPerfil: widget.userProfile,
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Tutoriais (#33)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              child: ListTile(
                leading: Icon(
                  Icons.help_outline,
                  color: cs.onSurfaceVariant,
                  size: 22,
                ),
                title: Text(
                  'Tutoriais',
                  style: TextStyle(fontSize: 15, color: cs.onSurface),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                horizontalTitleGap: 8,
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _abrirTutorial(context);
                },
              ),
            ),

            // Configurações
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              child: ListTile(
                leading: Icon(
                  Icons.settings_outlined,
                  color: cs.onSurfaceVariant,
                  size: 22,
                ),
                title: Text(
                  'Configurações',
                  style: TextStyle(fontSize: 15, color: cs.onSurface),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                horizontalTitleGap: 8,
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
                leading: Icon(
                  Icons.logout_outlined,
                  color: cs.onSurfaceVariant,
                  size: 22,
                ),
                title: Text(
                  'Sair',
                  style: TextStyle(fontSize: 15, color: cs.onSurface),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                horizontalTitleGap: 8,
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: () => AuthService().signOut(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMobileDrawerNavWidgets(
      BuildContext context, ColorScheme cs) {
    final entries = _navEntries;
    final favEntries =
        entries.where((e) => _favoritos.contains(e.item.label)).toList();
    final outrosEntries =
        entries.where((e) => !_favoritos.contains(e.item.label)).toList();

    final widgets = <Widget>[];

    if (favEntries.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
          child: Row(
            children: [
              Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade700),
              const SizedBox(width: 6),
              Text(
                'FAVORITOS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Colors.amber.shade800,
                ),
              ),
            ],
          ),
        ),
      );
      for (final entry in favEntries) {
        widgets.add(_buildMobileDrawerItem(context, cs, entry, isFav: true));
      }
      if (outrosEntries.isNotEmpty) {
        widgets.add(const SizedBox(height: 8));
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
            child: Text(
              'TODAS AS ABAS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
        );
      }
    }

    for (final entry in outrosEntries) {
      widgets.add(_buildMobileDrawerItem(context, cs, entry, isFav: false));
    }

    return widgets;
  }

  Widget _buildMobileDrawerItem(
      BuildContext context, ColorScheme cs, _NavEntry entry,
      {required bool isFav}) {
    final item = entry.item;
    final selected = _selectedIndex == entry.pageIndex;
    return ListTile(
      leading: Icon(
        selected ? item.activeIcon : item.icon,
        color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
        size: 22,
      ),
      title: Text(
        item.label,
        style: TextStyle(
          fontSize: 15,
          color: selected ? cs.onPrimaryContainer : cs.onSurface,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: IconButton(
        icon: Icon(
          isFav ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 20,
          color: isFav
              ? Colors.amber.shade700
              : cs.onSurfaceVariant.withValues(alpha: 0.4),
        ),
        tooltip: isFav ? 'Remover dos favoritos' : 'Favoritar',
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        onPressed: () => _toggleFavorito(item.label),
      ),
      selected: selected,
      selectedTileColor: cs.primaryContainer.withValues(
        alpha: 0.5,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      horizontalTitleGap: 8,
      contentPadding: const EdgeInsets.only(left: 12, right: 6),
      dense: true,
      onTap: () {
        setState(() => _selectedIndex = entry.pageIndex);
        Navigator.pop(context);
      },
    );
  }

  // ── Painel lateral colapsável ──────────────────────────────────────────────
  Widget _buildSidebarPanel(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sidebarWidth = _sidebarExpanded ? 236.0 : 64.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(right: BorderSide(color: cs.outlineVariant, width: 1)),
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
            padding: EdgeInsets.fromLTRB(_sidebarExpanded ? 14 : 6, 14, 6, 12),
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

          // ── Itens de navegação (roláveis p/ não estourar em telas baixas) ──
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: _buildSidebarNavWidgets(cs),
            ),
          ),

          // Financeiro agora é item de navegação (não rota separada).
          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: 4),

          // ── Tutoriais (#33) ────────────────────────────────────────────
          if (_sidebarExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              child: ListTile(
                leading: Icon(
                  Icons.help_outline,
                  color: cs.onSurfaceVariant,
                  size: 20,
                ),
                title: Text(
                  'Tutoriais',
                  style: TextStyle(fontSize: 14, color: cs.onSurface),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                horizontalTitleGap: 8,
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: () => _abrirTutorial(context),
              ),
            )
          else
            Center(
              child: Tooltip(
                message: 'Tutoriais',
                preferBelow: false,
                child: IconButton(
                  icon: Icon(
                    Icons.help_outline,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                  onPressed: () => _abrirTutorial(context),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),

          // ── Configurações ──────────────────────────────────────────────
          if (_sidebarExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              child: ListTile(
                leading: Icon(
                  Icons.settings_outlined,
                  color: cs.onSurfaceVariant,
                  size: 20,
                ),
                title: Text(
                  'Configurações',
                  style: TextStyle(fontSize: 14, color: cs.onSurface),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                horizontalTitleGap: 8,
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: () => _abrirConfiguracoes(context),
              ),
            )
          else
            Center(
              child: Tooltip(
                message: 'Configurações',
                preferBelow: false,
                child: IconButton(
                  icon: Icon(
                    Icons.settings_outlined,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                child: ListTile(
                  leading: Icon(
                    Icons.inventory_2_outlined,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                  title: Text(
                    'Produtos',
                    style: TextStyle(fontSize: 14, color: cs.onSurface),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  horizontalTitleGap: 8,
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                    icon: Icon(
                      Icons.inventory_2_outlined,
                      color: cs.onSurfaceVariant,
                      size: 20,
                    ),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                child: ListTile(
                  leading: Icon(
                    Icons.manage_accounts_outlined,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                  title: Text(
                    'Usuários',
                    style: TextStyle(fontSize: 14, color: cs.onSurface),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  horizontalTitleGap: 8,
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                    icon: Icon(
                      Icons.manage_accounts_outlined,
                      color: cs.onSurfaceVariant,
                      size: 20,
                    ),
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              child: ListTile(
                leading: Icon(
                  Icons.logout_outlined,
                  color: cs.onSurfaceVariant,
                  size: 20,
                ),
                title: Text(
                  'Sair',
                  style: TextStyle(fontSize: 14, color: cs.onSurface),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                horizontalTitleGap: 8,
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: () => AuthService().signOut(),
              ),
            )
          else
            Center(
              child: Tooltip(
                message: 'Sair',
                preferBelow: false,
                child: IconButton(
                  icon: Icon(
                    Icons.logout_outlined,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
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

  List<Widget> _buildSidebarNavWidgets(ColorScheme cs) {
    final entries = _navEntries;
    final favEntries =
        entries.where((e) => _favoritos.contains(e.item.label)).toList();
    final outrosEntries =
        entries.where((e) => !_favoritos.contains(e.item.label)).toList();

    final widgets = <Widget>[];

    if (!_sidebarExpanded) {
      // Modo compacto: favoritos primeiro, divisor se ambos tiverem itens, depois outros
      for (final entry in favEntries) {
        widgets.add(_buildCompactNavItem(cs, entry, isFav: true));
      }
      if (favEntries.isNotEmpty && outrosEntries.isNotEmpty) {
        widgets.add(
          Divider(
            height: 12,
            thickness: 1,
            indent: 14,
            endIndent: 14,
            color: cs.outlineVariant.withValues(alpha: 0.6),
          ),
        );
      }
      for (final entry in outrosEntries) {
        widgets.add(_buildCompactNavItem(cs, entry, isFav: false));
      }
      return widgets;
    }

    // Modo expandido:
    if (favEntries.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          child: Row(
            children: [
              Icon(Icons.star_rounded, size: 14, color: Colors.amber.shade700),
              const SizedBox(width: 6),
              Text(
                'FAVORITOS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Colors.amber.shade800,
                ),
              ),
            ],
          ),
        ),
      );
      for (final entry in favEntries) {
        widgets.add(_buildExpandedNavItem(cs, entry, isFav: true));
      }
      if (outrosEntries.isNotEmpty) {
        widgets.add(const SizedBox(height: 6));
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
            child: Text(
              'TODAS AS ABAS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
        );
      }
    }

    for (final entry in outrosEntries) {
      widgets.add(_buildExpandedNavItem(cs, entry, isFav: false));
    }

    return widgets;
  }

  Widget _buildCompactNavItem(ColorScheme cs, _NavEntry entry,
      {required bool isFav}) {
    final item = entry.item;
    final selected = _selectedIndex == entry.pageIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: Tooltip(
        message: isFav
            ? '${item.label} ★ (Favorito — toque longo p/ remover)'
            : '${item.label} (toque longo p/ favoritar)',
        preferBelow: false,
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = entry.pageIndex),
          onLongPress: () => _toggleFavorito(item.label),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: selected
                  ? cs.primaryContainer.withValues(alpha: 0.5)
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  selected ? item.activeIcon : item.icon,
                  color: selected
                      ? cs.onPrimaryContainer
                      : cs.onSurfaceVariant,
                  size: 20,
                ),
                if (isFav)
                  Positioned(
                    top: 6,
                    right: 8,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedNavItem(ColorScheme cs, _NavEntry entry,
      {required bool isFav}) {
    final item = entry.item;
    final selected = _selectedIndex == entry.pageIndex;
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13.5,
            color: selected ? cs.onPrimaryContainer : cs.onSurface,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: IconButton(
          icon: Icon(
            isFav ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 18,
            color: isFav
                ? Colors.amber.shade700
                : cs.onSurfaceVariant.withValues(alpha: 0.35),
          ),
          tooltip: isFav ? 'Remover dos favoritos' : 'Favoritar',
          visualDensity: VisualDensity.compact,
          splashRadius: 16,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
          onPressed: () => _toggleFavorito(item.label),
        ),
        selected: selected,
        selectedTileColor: cs.primaryContainer.withValues(
          alpha: 0.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        horizontalTitleGap: 8,
        contentPadding: const EdgeInsets.only(left: 12, right: 4),
        dense: true,
        onTap: () => setState(() => _selectedIndex = entry.pageIndex),
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
    // A aba "Distratar" é visível para admin, super admin e pós-venda.
    final perfilLc = userProfile.toLowerCase().trim();
    final podeDistrar = perfilLc == 'super admin' ||
        perfilLc == 'pós-venda' ||
        perfilLc == 'admin';

    final tabs = <Tab>[
      const Tab(text: 'Visão Geral', icon: Icon(Icons.dashboard_outlined)),
      const Tab(text: 'Contratos', icon: Icon(Icons.description_outlined)),
      const Tab(text: 'Análise', icon: Icon(Icons.analytics_outlined)),
      if (podeDistrar)
        const Tab(text: 'Distratar', icon: Icon(Icons.gavel_outlined)),
    ];

    final views = <Widget>[
      const AbaPosVenda(),
      PosVendaScreen(userProfile: userProfile),
      AbaAnaliseImoveis(userProfile: userProfile),
      if (podeDistrar) AbaDistratar(userProfile: userProfile),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pós-Venda'),
          toolbarHeight: 50,
          bottom: TabBar(
            indicatorWeight: 3,
            isScrollable: podeDistrar,
            tabs: tabs,
          ),
        ),
        body: TabBarView(children: views),
      ),
    );
  }
}
