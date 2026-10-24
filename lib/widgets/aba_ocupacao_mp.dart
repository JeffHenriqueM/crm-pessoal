// lib/widgets/aba_ocupacao_mp.dart
//
// Aba "Ocupação" do módulo Hotel: agenda de entradas (check-in) e saídas
// (check-out) de sócios por dia, agregada dos contratos ATIVOS cruzados com o
// calendário de rodízio (blocos com check-in cadastrado — hoje B e C).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/ocupacao_mp.dart';
import '../services/firestore_service.dart';

class AbaOcupacaoMP extends StatefulWidget {
  final FirestoreService? firestoreService;
  const AbaOcupacaoMP({super.key, this.firestoreService});

  @override
  State<AbaOcupacaoMP> createState() => _AbaOcupacaoMPState();
}

class _AbaOcupacaoMPState extends State<AbaOcupacaoMP> {
  late final FirestoreService _fs =
      widget.firestoreService ?? FirestoreService();
  static final _fmtDia = DateFormat("EEEE, dd/MM/yyyy", 'pt_BR');

  bool _carregando = true;
  String? _erro;
  OcupacaoMP? _ocup;

  late DateTime _focado;
  DateTime? _selecionado;

  // Uso começa na virada 2027→2028; a agenda abre nessa data.
  static final _inicioUso = DateTime(2027, 12, 26);

  @override
  void initState() {
    super.initState();
    _focado = _inicioUso;
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final o = await _fs.montarOcupacaoMP();
      if (!mounted) return;
      // Foca no 1º dia com entradas a partir do início do uso (26/12/2027).
      final datas = o.entradasPorDia.keys.map(DateTime.parse).toList()..sort();
      final aPartir = datas.where((d) => !d.isBefore(_inicioUso)).toList();
      final foco = aPartir.isNotEmpty
          ? aPartir.first
          : (datas.isNotEmpty ? datas.last : _inicioUso);
      setState(() {
        _ocup = o;
        _focado = foco;
        _selecionado = foco;
        _carregando = false;
      });
    } catch (e) {
      debugPrint('AbaOcupacaoMP._carregar: $e');
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = 'Não consegui montar a ocupação. Tente de novo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erro != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_erro!),
          const SizedBox(height: 8),
          FilledButton(onPressed: _carregar, child: const Text('Tentar de novo')),
        ]),
      );
    }
    final o = _ocup!;
    final sel = _selecionado;
    final entradas = sel == null ? const [] : o.entradasEm(sel);
    final saidas = sel == null ? const [] : o.saidasEm(sel);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Icon(Icons.event_available_outlined, color: cs.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Ocupação da multipropriedade',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          'Entradas e saídas de sócios por dia (contratos ativos, blocos com '
          'check-in cadastrado). ${o.ativos} ativos'
          '${o.naoResolvidos > 0 ? ' · ${o.naoResolvidos} sem calendário' : ''}.',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 12),
        _legenda(cs),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: TableCalendar<Object>(
              locale: 'pt_BR',
              firstDay: DateTime(2027, 1, 1),
              lastDay: DateTime(2078, 12, 31),
              focusedDay: _focado,
              selectedDayPredicate: (d) => isSameDay(_selecionado, d),
              onDaySelected: (sel, foc) => setState(() {
                _selecionado = sel;
                _focado = foc;
              }),
              availableGestures: AvailableGestures.horizontalSwipe,
              eventLoader: (day) {
                // Só para o markerBuilder saber que há algo no dia.
                final n = o.entradasEm(day).length + o.saidasEm(day).length;
                return List.filled(n, const Object());
              },
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, _) {
                  final nIn = o.entradasEm(day).length;
                  final nOut = o.saidasEm(day).length;
                  if (nIn == 0 && nOut == 0) return null;
                  return Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (nIn > 0) _pontoNum(nIn, const Color(0xFF16A34A)),
                        if (nOut > 0) ...[
                          const SizedBox(width: 2),
                          _pontoNum(nOut, const Color(0xFFDC2626)),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (sel != null) ...[
          Text(
            _fmtDia.format(sel),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          _secaoEventos(cs, 'Entram', entradas.cast<EventoOcupacao>(),
              const Color(0xFF16A34A), Icons.login_rounded),
          const SizedBox(height: 10),
          _secaoEventos(cs, 'Saem', saidas.cast<EventoOcupacao>(),
              const Color(0xFFDC2626), Icons.logout_rounded),
        ],
      ],
    );
  }

  Widget _legenda(ColorScheme cs) {
    Widget item(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(t, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ]);
    return Row(children: [
      item(const Color(0xFF16A34A), 'entram'),
      const SizedBox(width: 16),
      item(const Color(0xFFDC2626), 'saem'),
    ]);
  }

  Widget _pontoNum(int n, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
          color: cor, borderRadius: BorderRadius.circular(8)),
      child: Text('$n',
          style: const TextStyle(
              fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
    );
  }

  Widget _secaoEventos(ColorScheme cs, String titulo,
      List<EventoOcupacao> eventos, Color cor, IconData icone) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icone, size: 18, color: cor),
            const SizedBox(width: 6),
            Text('$titulo (${eventos.length})',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: cor, fontSize: 14)),
          ]),
          const SizedBox(height: 6),
          if (eventos.isEmpty)
            Text('Ninguém.',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant))
          else
            for (final e in eventos) _linhaEvento(cs, e),
        ],
      ),
    );
  }

  Widget _linhaEvento(ColorScheme cs, EventoOcupacao e) {
    final alta = e.tipoSemana.toLowerCase().startsWith('alta');
    final corTipo = alta ? const Color(0xFFD97706) : const Color(0xFF2563EB);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.nome,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                  '${e.bloco} · imóvel ${e.imovel} · '
                  '${_tier(e.tier)} Cota ${e.cota}'
                  '${e.feriado.isNotEmpty ? ' · ${e.feriado}' : ''}',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: corTipo.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(e.tipoSemana.isEmpty ? '—' : e.tipoSemana,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: corTipo)),
          ),
        ],
      ),
    );
  }

  String _tier(String t) =>
      {'ouro': 'Ouro', 'prata': 'Prata', 'bronze': 'Bronze'}[t] ?? t;
}
