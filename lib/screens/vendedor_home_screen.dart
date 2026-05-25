import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../screens/interacoes_screen.dart';
import '../screens/lista_clientes_screen.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/theme_controller.dart';
import '../widgets/aba_agenda.dart';
import '../widgets/notificacao_bell.dart';
import 'adicionar_cliente_screen.dart';
import 'dashboard_screen.dart';

class VendedorHomeScreen extends StatefulWidget {
  const VendedorHomeScreen({super.key});

  @override
  State<VendedorHomeScreen> createState() => _VendedorHomeScreenState();
}

class _VendedorHomeScreenState extends State<VendedorHomeScreen> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  late final String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.getCurrentUser()?.uid;
  }

  Map<DateTime, List<Cliente>> _processarEventos(List<Cliente> clientes) {
    final events = <DateTime, List<Cliente>>{};
    for (final c in clientes) {
      if (c.proximoContato != null) {
        final d = DateTime.utc(c.proximoContato!.year,
            c.proximoContato!.month, c.proximoContato!.day);
        events.putIfAbsent(d, () => []).add(c);
      }
      if (c.dataVisita != null) {
        final d = DateTime.utc(
            c.dataVisita!.year, c.dataVisita!.month, c.dataVisita!.day);
        events.putIfAbsent(d, () => []).add(c);
      }
    }
    return events;
  }

  Future<void> _handleLogout() async => _authService.signOut();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: _buildAppBar(context, cs),
      body: StreamBuilder<List<Cliente>>(
        stream: _firestoreService.getTodosClientesStream(
            vendedorId: _currentUserId),
        builder: (context, snapshot) {
          final clientes = snapshot.data ?? [];

          if (snapshot.connectionState == ConnectionState.waiting &&
              clientes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final eventos = _processarEventos(clientes);
          final hoje = DateTime.now();
          final inicioDoDia = DateTime(hoje.year, hoje.month, hoje.day);
          final fimDoDia = inicioDoDia.add(const Duration(days: 1));

          final contatosHoje = clientes.where((c) =>
              c.proximoContato != null &&
              !c.proximoContato!.isBefore(inicioDoDia) &&
              c.proximoContato!.isBefore(fimDoDia) &&
              c.fase != FaseCliente.fechado &&
              c.fase != FaseCliente.perdido).toList();

          final visitasHoje = clientes.where((c) =>
              c.dataVisita != null &&
              !c.dataVisita!.isBefore(inicioDoDia) &&
              c.dataVisita!.isBefore(fimDoDia)).toList();

          final atrasados = clientes.where((c) =>
              c.proximoContato != null &&
              c.proximoContato!.isBefore(inicioDoDia) &&
              c.fase != FaseCliente.fechado &&
              c.fase != FaseCliente.perdido).length;

          return Column(
            children: [
              // ── Faixa do dia ──────────────────────────────────────────
              _buildHojeStrip(
                  context, cs, contatosHoje, visitasHoje, atrasados),
              // ── Calendário ────────────────────────────────────────────
              Expanded(child: AbaAgenda(events: eventos)),
            ],
          );
        },
      ),
      // ── FAB: acesso rápido ao kanban ──────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ListaClientesScreen()),
        ),
        icon: const Icon(Icons.view_list_outlined),
        label: const Text('Ver Leads'),
        heroTag: 'leads_fab',
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context, ColorScheme cs) {
    return AppBar(
      leading: Padding(
        padding: const EdgeInsets.all(10),
        child: Image.asset('assets/images/logo.png',
            filterQuality: FilterQuality.medium),
      ),
      title: const Text('Villamor CRM'),
      actions: [
        NotificacaoBell(vendedorId: _currentUserId),
        AnimatedBuilder(
          animation: ThemeController.instance,
          builder: (_, __) {
            final isDark = ThemeController.instance.isDark;
            return IconButton(
              icon: Icon(isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined),
              tooltip: isDark ? 'Modo claro' : 'Modo escuro',
              onPressed: ThemeController.instance.toggle,
            );
          },
        ),
        PopupMenuButton<String>(
          tooltip: 'Mais opções',
          onSelected: (value) {
            if (value == 'dashboard') {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DashboardScreen()),
              );
            } else if (value == 'add_client') {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const AdicionarClienteScreen()),
              );
            } else if (value == 'logout') {
              _handleLogout();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'add_client',
              child: ListTile(
                leading: Icon(Icons.person_add_outlined),
                title: Text('Novo Cliente'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            PopupMenuItem(
              value: 'dashboard',
              child: ListTile(
                leading: Icon(Icons.bar_chart_rounded),
                title: Text('Estatísticas'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            PopupMenuDivider(),
            PopupMenuItem(
              value: 'logout',
              child: ListTile(
                leading: Icon(Icons.logout),
                title: Text('Sair'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Faixa de resumo do dia ────────────────────────────────────────────────
  Widget _buildHojeStrip(
    BuildContext context,
    ColorScheme cs,
    List<Cliente> contatosHoje,
    List<Cliente> visitasHoje,
    int atrasados,
  ) {
    final hoje = DateTime.now();
    final dataFormatada =
        DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(hoje);
    // Capitaliza primeira letra
    final dataDisplay =
        dataFormatada[0].toUpperCase() + dataFormatada.substring(1);

    final temEventos =
        contatosHoje.isNotEmpty || visitasHoje.isNotEmpty || atrasados > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dataDisplay,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          if (temEventos) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Contatos de hoje
                  if (contatosHoje.isNotEmpty)
                    ...contatosHoje.map((c) => _eventoChip(
                          context,
                          cs,
                          Icons.phone_outlined,
                          Colors.blue.shade700,
                          c.nome.split(' ').first,
                          () => _abrirCliente(context, c),
                        )),

                  // Visitas de hoje
                  if (visitasHoje.isNotEmpty)
                    ...visitasHoje.map((c) => _eventoChip(
                          context,
                          cs,
                          Icons.location_on_outlined,
                          Colors.teal.shade700,
                          c.nome.split(' ').first,
                          () => _abrirCliente(context, c),
                        )),

                  // Atrasados
                  if (atrasados > 0)
                    _eventoChip(
                      context,
                      cs,
                      Icons.access_time_outlined,
                      const Color(0xFFB45309),
                      '$atrasados atrasado${atrasados != 1 ? 's' : ''}',
                      null,
                    ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              'Nenhuma pendência para hoje ✓',
              style: TextStyle(fontSize: 12, color: Colors.green.shade700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _eventoChip(
    BuildContext context,
    ColorScheme cs,
    IconData icon,
    Color cor,
    String label,
    VoidCallback? onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.10),
            border: Border.all(color: cor.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: cor),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _abrirCliente(BuildContext context, Cliente cliente) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InteracoesScreen(cliente: cliente),
      ),
    );
  }
}
