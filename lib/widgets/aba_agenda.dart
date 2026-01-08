// lib/widgets/dashboard/aba_agenda.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/cliente_model.dart';

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

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _selectedEvents.value = _getEventsForDay(selectedDay);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            markerDecoration: BoxDecoration(color: Colors.amber.shade700, shape: BoxShape.circle),
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
        ),
        const SizedBox(height: 8.0),
        Expanded(
          child: ValueListenableBuilder<List<Cliente>>(
            valueListenable: _selectedEvents,
            builder: (context, value, _) {
              return ListView.builder(
                itemCount: value.length,
                itemBuilder: (context, index) {
                  final cliente = value[index];
                  bool isVisita = cliente.dataVisita != null && isSameDay(cliente.dataVisita!, _selectedDay!);
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                    child: ListTile(
                      leading: Icon(
                        isVisita ? Icons.location_on : Icons.phone,
                        color: isVisita ? Colors.redAccent : Colors.green,
                      ),
                      title: Text(cliente.nome),
                      subtitle: Text(isVisita ? 'Visita Agendada' : 'Próximo Contato'),
                      onTap: () {
                        // Navegar para detalhes do cliente
                      },
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
