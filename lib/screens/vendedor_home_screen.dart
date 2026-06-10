import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/agendamento_model.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../screens/ficha_cliente_screen.dart';
import '../services/firestore_service.dart';
import '../widgets/aba_agenda.dart';

class VendedorHomeScreen extends StatefulWidget {
  final String? currentUserId;

  /// Se true, busca todos os clientes (visão admin) e exibe nome do vendedor
  /// em cada evento da agenda com sua cor determinística.
  final bool showAllVendedores;

  const VendedorHomeScreen({
    super.key,
    this.currentUserId,
    this.showAllVendedores = false,
  });

  @override
  State<VendedorHomeScreen> createState() => _VendedorHomeScreenState();
}

class _VendedorHomeScreenState extends State<VendedorHomeScreen> {
  final _firestoreService = FirestoreService();

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

  Map<DateTime, List<Agendamento>> _processarEventosAgendamentos(
      List<Agendamento> ags) {
    final m = <DateTime, List<Agendamento>>{};
    for (final a in ags) {
      if (!a.isAgendado) continue;
      final d = DateTime.utc(a.dataHora.year, a.dataHora.month, a.dataHora.day);
      m.putIfAbsent(d, () => []).add(a);
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Se showAllVendedores, não filtra por vendedorId (admin vê todos)
    final vendedorIdFiltro =
        widget.showAllVendedores ? null : widget.currentUserId;

    return StreamBuilder<List<Cliente>>(
      stream: _firestoreService.getTodosClientesStream(
          vendedorId: vendedorIdFiltro),
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

        final contatosHoje = clientes
            .where((c) =>
                c.proximoContato != null &&
                !c.proximoContato!.isBefore(inicioDoDia) &&
                c.proximoContato!.isBefore(fimDoDia) &&
                c.fase != FaseCliente.fechado &&
                c.fase != FaseCliente.perdido)
            .toList();

        final visitasHoje = clientes
            .where((c) =>
                c.dataVisita != null &&
                !c.dataVisita!.isBefore(inicioDoDia) &&
                c.dataVisita!.isBefore(fimDoDia))
            .toList();

        final atrasados = clientes
            .where((c) =>
                c.proximoContato != null &&
                c.proximoContato!.isBefore(inicioDoDia) &&
                c.fase != FaseCliente.fechado &&
                c.fase != FaseCliente.perdido)
            .length;

        return Column(
          children: [
            _buildHojeStrip(context, cs, contatosHoje, visitasHoje, atrasados),
            Expanded(
              child: StreamBuilder<List<Agendamento>>(
                stream: _firestoreService.getAgendamentosStream(),
                builder: (context, agSnap) {
                  final agendamentos =
                      _processarEventosAgendamentos(agSnap.data ?? []);
                  return AbaAgenda(
                    events: eventos,
                    agendamentos: agendamentos,
                    showVendedorInfo: widget.showAllVendedores,
                  );
                },
              ),
            ),
          ],
        );
      },
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
          Row(
            children: [
              Text(
                dataDisplay,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
              if (widget.showAllVendedores) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Todos os embaixadores',
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
          if (temEventos) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (contatosHoje.isNotEmpty)
                    ...contatosHoje.map((c) => _eventoChip(
                          context,
                          cs,
                          Icons.phone_outlined,
                          Colors.blue.shade700,
                          widget.showAllVendedores
                              ? '${c.nome.split(' ').first} · ${c.vendedorNome?.split(' ').first ?? '?'}'
                              : c.nome.split(' ').first,
                          () => _abrirCliente(context, c),
                        )),
                  if (visitasHoje.isNotEmpty)
                    ...visitasHoje.map((c) => _eventoChip(
                          context,
                          cs,
                          Icons.location_on_outlined,
                          Colors.teal.shade700,
                          widget.showAllVendedores
                              ? '${c.nome.split(' ').first} · ${c.vendedorNome?.split(' ').first ?? '?'}'
                              : c.nome.split(' ').first,
                          () => _abrirCliente(context, c),
                        )),
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
        builder: (_) => FichaClienteScreen(cliente: cliente),
      ),
    );
  }
}
