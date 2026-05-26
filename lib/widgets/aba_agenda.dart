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

// ── Datas de evento do Villamor Tambaba Resort ─────────────────────────────
final Set<DateTime> _eventosResort = _gerarEventosResort();

Set<DateTime> _gerarEventosResort() {
  final eventos = <DateTime>{};

  void addRange(DateTime start, DateTime end) {
    var dt = start;
    while (!dt.isAfter(end)) {
      eventos.add(dt);
      dt = dt.add(const Duration(days: 1));
    }
  }

  // ── 2026 ──────────────────────────────────────────────────────────────
  addRange(DateTime.utc(2026, 5, 29),  DateTime.utc(2026, 5, 31));  // 29–31/05
  addRange(DateTime.utc(2026, 6, 4),   DateTime.utc(2026, 6, 7));   // 04–07/06
  addRange(DateTime.utc(2026, 6, 12),  DateTime.utc(2026, 6, 14));  // 12–14/06
  addRange(DateTime.utc(2026, 6, 19),  DateTime.utc(2026, 6, 21));  // 19–21/06
  addRange(DateTime.utc(2026, 6, 26),  DateTime.utc(2026, 6, 28));  // 26–28/06
  addRange(DateTime.utc(2026, 7, 3),   DateTime.utc(2026, 7, 5));   // 03–05/07
  addRange(DateTime.utc(2026, 7, 10),  DateTime.utc(2026, 7, 12));  // 10–12/07
  addRange(DateTime.utc(2026, 7, 17),  DateTime.utc(2026, 7, 23));  // 17–23/07 (17–19 + 19–23 fundidos)
  addRange(DateTime.utc(2026, 7, 24),  DateTime.utc(2026, 7, 26));  // 24–26/07
  addRange(DateTime.utc(2026, 7, 31),  DateTime.utc(2026, 8, 2));   // 31/07–02/08
  addRange(DateTime.utc(2026, 8, 7),   DateTime.utc(2026, 8, 9));   // 07–09/08
  addRange(DateTime.utc(2026, 8, 13),  DateTime.utc(2026, 8, 16));  // 13–16/08
  addRange(DateTime.utc(2026, 8, 21),  DateTime.utc(2026, 8, 23));  // 21–23/08
  addRange(DateTime.utc(2026, 8, 28),  DateTime.utc(2026, 8, 30));  // 28–30/08
  addRange(DateTime.utc(2026, 9, 5),   DateTime.utc(2026, 9, 8));   // 05–08/09
  addRange(DateTime.utc(2026, 9, 11),  DateTime.utc(2026, 9, 13));  // 11–13/09
  addRange(DateTime.utc(2026, 9, 18),  DateTime.utc(2026, 9, 20));  // 18–20/09
  addRange(DateTime.utc(2026, 9, 25),  DateTime.utc(2026, 9, 27));  // 25–27/09
  addRange(DateTime.utc(2026, 10, 2),  DateTime.utc(2026, 10, 4));  // 02–04/10
  addRange(DateTime.utc(2026, 10, 8),  DateTime.utc(2026, 10, 11)); // 08–11/10
  addRange(DateTime.utc(2026, 10, 15), DateTime.utc(2026, 10, 18)); // 15–18/10
  addRange(DateTime.utc(2026, 10, 23), DateTime.utc(2026, 10, 25)); // 23–25/10
  addRange(DateTime.utc(2026, 10, 30), DateTime.utc(2026, 11, 1));  // 30/10–01/11
  addRange(DateTime.utc(2026, 11, 6),  DateTime.utc(2026, 11, 8));  // 06–08/11
  addRange(DateTime.utc(2026, 11, 13), DateTime.utc(2026, 11, 15)); // 13–15/11
  addRange(DateTime.utc(2026, 11, 19), DateTime.utc(2026, 11, 22)); // 19–22/11
  addRange(DateTime.utc(2026, 11, 27), DateTime.utc(2026, 11, 29)); // 27–29/11
  addRange(DateTime.utc(2026, 12, 4),  DateTime.utc(2026, 12, 6));  // 04–06/12
  addRange(DateTime.utc(2026, 12, 11), DateTime.utc(2026, 12, 13)); // 11–13/12
  addRange(DateTime.utc(2026, 12, 18), DateTime.utc(2026, 12, 20)); // 18–20/12
  addRange(DateTime.utc(2026, 12, 31), DateTime.utc(2027, 1, 3));   // 31/12–03/01

  return eventos;
}

bool _isEventoResort(DateTime day) {
  final d = DateTime.utc(day.year, day.month, day.day);
  return _eventosResort.contains(d);
}

// ─────────────────────────────────────────────────────────────────────────────
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

  // Cor do label "Evento" — teal suave, lê bem no dark e no light
  static const _eventoLabelColor = Color(0xFF4DB6AC);

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
          rowHeight: 54, // espaço extra para o label "Evento"
          calendarBuilders: CalendarBuilders(
            // ── Destaque: fins de semana (primary) + eventos (label teal) ──
            defaultBuilder: (context, day, focusedDay) {
              final isWeekend = day.weekday == DateTime.saturday ||
                  day.weekday == DateTime.sunday;
              final isEvento = _isEventoResort(day);

              if (!isWeekend && !isEvento) return null;

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      color: isWeekend ? cs.primary : cs.onSurface,
                      fontWeight:
                          isWeekend ? FontWeight.w700 : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  if (isEvento)
                    Text(
                      'Evento',
                      style: const TextStyle(
                        fontSize: 7,
                        color: _eventoLabelColor,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        letterSpacing: 0.3,
                      ),
                    ),
                ],
              );
            },

            // ── Marcadores coloridos por embaixador (modo admin) ────────────
            markerBuilder: widget.showVendedorInfo
                ? (context, day, events) {
                    if (events.isEmpty) return null;
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
            // Fins de semana — cor primary, em negrito
            weekendTextStyle: TextStyle(
              color: cs.primary,
              fontWeight: FontWeight.w700,
            ),
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

        // ── Legenda ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          child: Row(
            children: [
              // Amostra: número + "Evento" como aparece no calendário
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('8',
                      style: TextStyle(fontSize: 11, color: cs.onSurface)),
                  const Text('Evento',
                      style: TextStyle(
                          fontSize: 7,
                          color: _eventoLabelColor,
                          fontWeight: FontWeight.w700,
                          height: 1.2)),
                ],
              ),
              const SizedBox(width: 6),
              Text(
                'Evento na Villamor',
                style: TextStyle(fontSize: 11, color: cs.outline),
              ),
              const SizedBox(width: 16),
              Text(
                'S',
                style: TextStyle(
                    fontSize: 11,
                    color: cs.primary,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 4),
              Text(
                'Fim de semana',
                style: TextStyle(fontSize: 11, color: cs.outline),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // ── Lista de eventos do dia ─────────────────────────────────────────
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
