import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/cliente_model.dart';

// Paleta de cores determinística por vendedorId
const _paleta = [
  Color(0xFF1565C0), // Azul
  Color(0xFF2E7D32), // Verde
  Color(0xFF6A1B9A), // Roxo
  Color(0xFFE65100), // Laranja
  Color(0xFF00695C), // Teal
  Color(0xFFC62828), // Vermelho
  Color(0xFF283593), // Índigo
  Color(0xFF558B2F), // Verde-claro
];

Color _corPorVendedor(String? vendedorId) {
  if (vendedorId == null || vendedorId.isEmpty) return Colors.grey.shade600;
  final hash =
      vendedorId.codeUnits.fold<int>(0, (a, b) => a + b);
  return _paleta[hash % _paleta.length];
}

class AbaAgenda extends StatefulWidget {
  final Map<DateTime, List<Cliente>> events;

  /// Quando true, mostra o nome do vendedor/embaixador e cor determinística
  /// em cada item da lista de eventos (usado na visão admin).
  final bool showVendedorInfo;

  const AbaAgenda({
    super.key,
    required this.events,
    this.showVendedorInfo = false,
  });

  @override
  State<AbaAgenda> createState() => _AbaAgendaState();
}

class _AbaAgendaState extends State<AbaAgenda> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  late final ValueNotifier<List<Cliente>> _selectedEvents;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
  }

  @override
  void didUpdateWidget(AbaAgenda oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Atualiza eventos quando o mapa de eventos muda
    if (widget.events != oldWidget.events) {
      _selectedEvents.value = _getEventsForDay(_selectedDay ?? _focusedDay);
    }
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  List<Cliente> _getEventsForDay(DateTime day) {
    return widget.events[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  void _onDaySelected(DateTime selected, DateTime focused) {
    if (!isSameDay(_selectedDay, selected)) {
      setState(() {
        _selectedDay = selected;
        _focusedDay = focused;
        _selectedEvents.value = _getEventsForDay(selected);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        TableCalendar<Cliente>(
          locale: 'pt_BR',
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: _onDaySelected,
          eventLoader: _getEventsForDay,
          calendarBuilders: CalendarBuilders(
            // Marcadores coloridos por embaixador quando em modo admin
            markerBuilder: widget.showVendedorInfo
                ? (context, day, events) {
                    if (events.isEmpty) return null;
                    // Mostra até 3 bolinhas coloridas por embaixador único
                    final vendedoresUnicos = events
                        .map((c) => c.vendedorId)
                        .toSet()
                        .take(3)
                        .toList();
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: vendedoresUnicos.map((vid) {
                        final cor = _corPorVendedor(vid);
                        return Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: cor,
                            shape: BoxShape.circle,
                          ),
                        );
                      }).toList(),
                    );
                  }
                : null,
          ),
          calendarStyle: CalendarStyle(
            markerDecoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            todayTextStyle: TextStyle(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: cs.onSurface,
            ),
            leftChevronIcon: Icon(Icons.chevron_left, color: cs.primary),
            rightChevronIcon: Icon(Icons.chevron_right, color: cs.primary),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ValueListenableBuilder<List<Cliente>>(
            valueListenable: _selectedEvents,
            builder: (context, events, _) {
              if (events.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_available_outlined,
                          size: 48,
                          color: cs.outline.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhum evento neste dia.',
                        style: TextStyle(color: cs.outline),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final cliente = events[index];
                  final isVisita = cliente.dataVisita != null &&
                      isSameDay(cliente.dataVisita!, _selectedDay!);

                  // Cor base: se modo admin usa cor do vendedor, senão usa a cor padrão
                  final corEvento = widget.showVendedorInfo
                      ? _corPorVendedor(cliente.vendedorId)
                      : (isVisita ? Colors.orange.shade700 : cs.primary);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            corEvento.withValues(alpha: 0.12),
                        child: Icon(
                          isVisita
                              ? Icons.location_on_outlined
                              : Icons.phone_outlined,
                          color: corEvento,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        cliente.nome,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        isVisita ? 'Visita agendada' : 'Próximo contato',
                        style: TextStyle(color: corEvento, fontSize: 12),
                      ),
                      // Nome do embaixador à direita (só no modo admin)
                      trailing: widget.showVendedorInfo &&
                              cliente.vendedorNome != null
                          ? _buildVendedorChip(
                              cliente.vendedorNome!, corEvento)
                          : null,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVendedorChip(String nome, Color cor) {
    // Exibe apenas o primeiro nome para economizar espaço
    final primeiroNome = nome.split(' ').first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Text(
        primeiroNome,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: cor,
        ),
      ),
    );
  }
}
