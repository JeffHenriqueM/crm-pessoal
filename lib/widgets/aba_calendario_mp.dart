// lib/widgets/aba_calendario_mp.dart
//
// Aba "Calendário" do módulo Hotel/Multipropriedade. Consulta (só leitura) do
// rodízio fixo de semanas importado da planilha: escolhe tier (Ouro/Prata/
// Bronze), dia de check-in e número da cota, e vê todas as semanas daquela
// cota ao longo dos anos (2027–2078), com tipo de temporada e feriado.
//
// Fase 1 (consulta): o dia de check-in é escolhido manualmente aqui — ainda
// não há vínculo automático contrato → semana.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/semana_mp.dart';
import '../services/firestore_service.dart';

class AbaCalendarioMP extends StatefulWidget {
  final FirestoreService? firestoreService;
  const AbaCalendarioMP({super.key, this.firestoreService});

  @override
  State<AbaCalendarioMP> createState() => _AbaCalendarioMPState();
}

class _AbaCalendarioMPState extends State<AbaCalendarioMP> {
  late final FirestoreService _fs = widget.firestoreService ?? FirestoreService();

  static final _fmt = DateFormat('dd/MM/yyyy');
  static final _diaSem = DateFormat('EEE', 'pt_BR');

  // Tiers e dias disponíveis (batem com as abas da planilha).
  static const _tiers = ['ouro', 'prata', 'bronze'];
  static const _dias = ['domingo', 'segunda', 'quinta', 'sexta', 'sabado'];
  static const _rotuloDia = {
    'domingo': 'Domingo',
    'segunda': 'Segunda',
    'quinta': 'Quinta',
    'sexta': 'Sexta',
    'sabado': 'Sábado',
  };
  static const _rotuloTier = {
    'ouro': 'Ouro',
    'prata': 'Prata',
    'bronze': 'Bronze',
  };
  static const _corTier = {
    'ouro': Color(0xFFC9A227),
    'prata': Color(0xFF7A8390),
    'bronze': Color(0xFF9E6B3F),
  };

  String _tier = 'ouro';
  String _dia = 'domingo';
  int? _cota = 1;
  int? _ano; // null = todos os anos

  bool _carregando = false;
  String? _erro;
  Map<int, List<SemanaMP>> _dados = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final dados = await _fs.getCalendarioMP(_tier, _dia);
      if (!mounted) return;
      setState(() {
        _dados = dados;
        _carregando = false;
        // Mantém a cota se existir; senão cai na primeira disponível.
        final cotas = dados.keys.toList()..sort();
        if (cotas.isEmpty) {
          _cota = null;
        } else if (_cota == null || !dados.containsKey(_cota)) {
          _cota = cotas.first;
        }
      });
    } catch (e) {
      debugPrint('AbaCalendarioMP._carregar: $e');
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = 'Não consegui carregar o calendário. Tente de novo.';
      });
    }
  }

  List<SemanaMP> get _semanasCota =>
      (_cota == null ? null : _dados[_cota]) ?? const [];

  List<int> get _anosDisponiveis {
    final s = <int>{for (final w in _semanasCota) w.ano};
    final l = s.toList()..sort();
    return l;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cotas = _dados.keys.toList()..sort();
    final semanas = [
      for (final w in _semanasCota)
        if (_ano == null || w.ano == _ano) w,
    ];
    // Agrupa por ano, preservando a ordem (já vêm ordenadas por data).
    final porAno = <int, List<SemanaMP>>{};
    for (final w in semanas) {
      porAno.putIfAbsent(w.ano, () => []).add(w);
    }
    final anosOrdenados = porAno.keys.toList()..sort();
    final porAnoTodos = _semanasCota.isEmpty
        ? 0
        : (_semanasCota.length / _anosDisponiveis.length).round();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Icon(Icons.calendar_month_outlined, color: cs.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Calendário da Multipropriedade',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          'Rodízio fixo de semanas por cota (2027–2078). Escolha o tier, o dia '
          'de check-in e o número da cota para ver as semanas.',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 16),

        // Seletor de tier.
        SegmentedButton<String>(
          segments: [
            for (final t in _tiers)
              ButtonSegment(
                value: t,
                label: Text(_rotuloTier[t]!),
                icon: Icon(Icons.circle, size: 12, color: _corTier[t]),
              ),
          ],
          selected: {_tier},
          onSelectionChanged: (s) {
            setState(() => _tier = s.first);
            _carregar();
          },
        ),
        const SizedBox(height: 12),

        // Seletores de dia, cota e ano.
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _dropdown<String>(
              cs,
              rotulo: 'Check-in',
              value: _dia,
              itens: [
                for (final d in _dias)
                  DropdownMenuItem(value: d, child: Text(_rotuloDia[d]!)),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _dia = v);
                _carregar();
              },
            ),
            _dropdown<int>(
              cs,
              rotulo: 'Cota',
              value: _dados.containsKey(_cota) ? _cota : null,
              itens: [
                for (final c in cotas)
                  DropdownMenuItem(value: c, child: Text('Cota $c')),
              ],
              onChanged: (v) => setState(() => _cota = v),
            ),
            _dropdown<int?>(
              cs,
              rotulo: 'Ano',
              value: _ano,
              itens: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                for (final a in _anosDisponiveis)
                  DropdownMenuItem(value: a, child: Text('$a')),
              ],
              onChanged: (v) => setState(() => _ano = v),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_carregando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_erro != null)
          _aviso(cs, _erro!, acao: _carregar)
        else if (_cota == null)
          _aviso(cs, 'Nenhuma cota encontrada para este tier/dia.')
        else ...[
          _resumo(cs, porAnoTodos),
          const SizedBox(height: 12),
          if (anosOrdenados.isEmpty)
            _aviso(cs, 'Sem semanas para o filtro selecionado.')
          else
            for (final ano in anosOrdenados) ...[
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 6),
                child: Text('$ano',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: cs.primary)),
              ),
              for (final w in porAno[ano]!) _cardSemana(cs, w),
            ],
        ],
      ],
    );
  }

  Widget _resumo(ColorScheme cs, int porAno) {
    final cor = _corTier[_tier]!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(Icons.info_outline, size: 18, color: cor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${_rotuloTier[_tier]} · entrada ${_rotuloDia[_dia]!.toLowerCase()} · '
            'Cota $_cota · ~$porAno semana(s)/ano · '
            '${_semanasCota.length} no total (2027–2078)',
            style: TextStyle(fontSize: 13, color: cs.onSurface),
          ),
        ),
      ]),
    );
  }

  Widget _cardSemana(ColorScheme cs, SemanaMP w) {
    final alta = w.tipo.toLowerCase().startsWith('alta');
    final corTipo = alta ? const Color(0xFFD97706) : const Color(0xFF2563EB);
    final entrada = DateTime.tryParse(w.entrada);
    final saida = DateTime.tryParse(w.saida);
    final periodo = (entrada != null && saida != null)
        ? '${_fmt.format(entrada)} (${_diaSem.format(entrada)}) → '
            '${_fmt.format(saida)} (${_diaSem.format(saida)})'
        : '${w.entrada} → ${w.saida}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
                color: corTipo, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(periodo,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                if (w.temFeriado)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(children: [
                      Icon(Icons.celebration_outlined,
                          size: 13, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(w.feriado,
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                      ),
                    ]),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: corTipo.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(w.tipo.isEmpty ? '—' : w.tipo,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: corTipo)),
          ),
        ],
      ),
    );
  }

  Widget _aviso(ColorScheme cs, String msg, {VoidCallback? acao}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(Icons.info_outline, color: cs.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
        if (acao != null)
          TextButton(onPressed: acao, child: const Text('Tentar de novo')),
      ]),
    );
  }

  Widget _dropdown<T>(
    ColorScheme cs, {
    required String rotulo,
    required T? value,
    required List<DropdownMenuItem<T>> itens,
    required ValueChanged<T?> onChanged,
  }) {
    return SizedBox(
      width: 150,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: rotulo,
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            isDense: true,
            items: itens,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
