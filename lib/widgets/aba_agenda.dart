import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/cliente_model.dart';

class AbaAgenda extends StatefulWidget {
  final Map<DateTime, List<Cliente>> events;
  const AbaAgenda({super.key, required this.events});

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
                          size: 48, color: cs.outline.withValues(alpha: 0.5)),
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
                  final cor = isVisita ? Colors.orange.shade700 : cs.primary;

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: cor.withValues(alpha: 0.12),
                        child: Icon(
                          isVisita
                              ? Icons.location_on_outlined
                              : Icons.phone_outlined,
                          color: cor,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        cliente.nome,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        isVisita ? 'Visita agendada' : 'Próximo contato',
                        style: TextStyle(color: cor, fontSize: 12),
                      ),
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
}
