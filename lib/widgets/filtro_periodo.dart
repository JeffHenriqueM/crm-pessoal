import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Período de filtragem por data, reaproveitado nas abas do dashboard.
enum Periodo { hoje, semana, mes, tudo, personalizado }

/// Estado de um filtro de período + a lógica de "uma data cai no período?".
/// Imutável: cada mudança gera uma nova instância (facilita uso com setState).
class FiltroPeriodo {
  final Periodo periodo;
  final DateTime? inicio;
  final DateTime? fim;

  const FiltroPeriodo({
    this.periodo = Periodo.tudo,
    this.inicio,
    this.fim,
  });

  /// True se [data] está dentro do período selecionado.
  /// Datas nulas nunca entram (exceto em "Tudo", que aceita qualquer não-nula).
  bool contem(DateTime? data) {
    if (data == null) return false;
    final agora = DateTime.now();
    final inicioDia = DateTime(agora.year, agora.month, agora.day);
    switch (periodo) {
      case Periodo.hoje:
        return !data.isBefore(inicioDia);
      case Periodo.semana:
        final ini = inicioDia.subtract(Duration(days: agora.weekday - 1));
        return !data.isBefore(ini);
      case Periodo.mes:
        final ini = DateTime(agora.year, agora.month, 1);
        return !data.isBefore(ini);
      case Periodo.tudo:
        return true;
      case Periodo.personalizado:
        if (inicio == null || fim == null) return true;
        final fimExclusivo = DateTime(fim!.year, fim!.month, fim!.day + 1);
        return !data.isBefore(inicio!) && data.isBefore(fimExclusivo);
    }
  }
}

/// Barra controlada de seleção de período (replica o filtro do Financeiro).
/// O estado é do pai: passe [filtro] e reaja em [onChanged].
class FiltroPeriodoBar extends StatelessWidget {
  final FiltroPeriodo filtro;
  final ValueChanged<FiltroPeriodo> onChanged;

  /// Texto explicativo exibido quando não há intervalo personalizado ativo.
  final String legenda;

  const FiltroPeriodoBar({
    super.key,
    required this.filtro,
    required this.onChanged,
    this.legenda = 'Filtro por data',
  });

  static final _dateFmt = DateFormat('dd/MM/yy');

  Future<void> _onSelectionChanged(
      BuildContext context, Set<Periodo> selecao) async {
    final p = selecao.first;
    if (p == Periodo.personalizado) {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange: filtro.inicio != null && filtro.fim != null
            ? DateTimeRange(start: filtro.inicio!, end: filtro.fim!)
            : null,
      );
      if (range != null) {
        onChanged(FiltroPeriodo(
          periodo: Periodo.personalizado,
          inicio: range.start,
          fim: range.end,
        ));
      }
    } else {
      onChanged(FiltroPeriodo(periodo: p));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final temRange = filtro.periodo == Periodo.personalizado &&
        filtro.inicio != null &&
        filtro.fim != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<Periodo>(
          segments: const [
            ButtonSegment(value: Periodo.hoje, label: Text('Hoje')),
            ButtonSegment(value: Periodo.semana, label: Text('Semana')),
            ButtonSegment(value: Periodo.mes, label: Text('Mês')),
            ButtonSegment(value: Periodo.tudo, label: Text('Tudo')),
            ButtonSegment(
              value: Periodo.personalizado,
              icon: Icon(Icons.calendar_month_outlined, size: 15),
            ),
          ],
          selected: {filtro.periodo},
          onSelectionChanged: (s) {
            _onSelectionChanged(context, s);
          },
        ),
        const SizedBox(height: 4),
        if (temRange)
          Row(
            children: [
              Icon(Icons.date_range, size: 12, color: cs.primary),
              const SizedBox(width: 4),
              Text(
                '${_dateFmt.format(filtro.inicio!)} – ${_dateFmt.format(filtro.fim!)}',
                style: TextStyle(
                    fontSize: 11,
                    color: cs.primary,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => onChanged(const FiltroPeriodo(periodo: Periodo.mes)),
                child: Icon(Icons.close, size: 12, color: cs.primary),
              ),
            ],
          )
        else
          Text(legenda, style: TextStyle(fontSize: 11, color: cs.outline)),
      ],
    );
  }
}
