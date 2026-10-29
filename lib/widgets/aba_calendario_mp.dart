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
  static final _mesFmt = DateFormat('MMMM', 'pt_BR');

  // Tiers e dias disponíveis. 'ourocorrido' = produto "Ouro Dias Corridos"
  // (2 quinzenas de 14 dias: 1 Alta + 1 Média por ano).
  static const _tiers = ['ouro', 'ourocorrido', 'prata', 'bronze', 'titanio'];
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
    'ourocorrido': 'Ouro Dias Corridos',
    'prata': 'Prata',
    'bronze': 'Bronze',
    'titanio': 'Titânio',
  };
  static const _corTier = {
    'ouro': Color(0xFFC9A227),
    'ourocorrido': Color(0xFFB8860B),
    'prata': Color(0xFF7A8390),
    'bronze': Color(0xFF9E6B3F),
    'titanio': Color(0xFF546E7A),
  };

  // Produtos de quinzena (14 dias corridos) — texto adaptado.
  static const _produtosQuinzena = {'ourocorrido', 'titanio'};

  String _tier = 'ouro';
  String _dia = 'domingo';
  int? _cota = 1;
  int? _ano; // null = todos os anos
  bool _agrupadoPorAno = true;

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

  String get _unidade =>
      _produtosQuinzena.contains(_tier) ? 'quinzena(s)' : 'semana(s)';

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

        // Seletor de tier/produto.
        _dropdown<String>(
          cs,
          rotulo: 'Produto',
          value: _tier,
          largura: 230,
          itens: [
            for (final t in _tiers)
              DropdownMenuItem(
                value: t,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle, size: 12, color: _corTier[t]),
                  const SizedBox(width: 8),
                  Text(_rotuloTier[t]!),
                ]),
              ),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _tier = v);
            _carregar();
          },
        ),
        const SizedBox(height: 12),

        // Seletores de dia, cota, ano e modo de exibição.
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
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
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Por Ano', style: TextStyle(fontSize: 12)),
                  icon: Icon(Icons.view_agenda_outlined, size: 15),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Tabela Completa', style: TextStyle(fontSize: 12)),
                  icon: Icon(Icons.table_chart_outlined, size: 15),
                ),
              ],
              selected: {_agrupadoPorAno},
              onSelectionChanged: (s) =>
                  setState(() => _agrupadoPorAno = s.first),
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
          const SizedBox(height: 16),
          if (anosOrdenados.isEmpty)
            _aviso(cs, 'Sem semanas para o filtro selecionado.')
          else if (_agrupadoPorAno)
            for (final ano in anosOrdenados) _blocoAno(cs, ano, porAno[ano]!)
          else
            _tabelaCompleta(cs, semanas),
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
            'Cota $_cota · ~$porAno $_unidade/ano · '
            '${_semanasCota.length} no total (2027–2078)'
            '${_produtosQuinzena.contains(_tier) ? ' · 14 dias cada' : ''}',
            style: TextStyle(fontSize: 13, color: cs.onSurface),
          ),
        ),
      ]),
    );
  }

  Widget _blocoAno(ColorScheme cs, int ano, List<SemanaMP> semanas) {
    final countAlta =
        semanas.where((w) => w.tipo.toLowerCase().startsWith('alta')).length;
    final countMedia = semanas
        .where((w) =>
            w.tipo.toLowerCase().startsWith('méd') ||
            w.tipo.toLowerCase().startsWith('med'))
        .length;
    final countFeriados = semanas.where((w) => w.temFeriado).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(
                bottom:
                    BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.event_outlined, size: 17, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  '$ano',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${semanas.length} $_unidade',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                ),
                const Spacer(),
                if (countAlta > 0) ...[
                  _tagResumo('$countAlta Alta', const Color(0xFFD97706)),
                  const SizedBox(width: 6),
                ],
                if (countMedia > 0) ...[
                  _tagResumo('$countMedia Média', const Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                ],
                if (countFeriados > 0)
                  _tagResumo(
                    '$countFeriados feriado${countFeriados > 1 ? 's' : ''}',
                    const Color(0xFFEA580C),
                    icone: Icons.celebration,
                  ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 680),
              child: Table(
                columnWidths: const {
                  0: FixedColumnWidth(160), // Entrada
                  1: FixedColumnWidth(160), // Saída
                  2: FixedColumnWidth(110), // Mês
                  3: FixedColumnWidth(120), // Tipo de semana
                  4: FlexColumnWidth(), // Feriado
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                border: TableBorder(
                  horizontalInside: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
                    ),
                    children: [
                      _th(cs, 'Entrada'),
                      _th(cs, 'Saída'),
                      _th(cs, 'Mês'),
                      _th(cs, 'Tipo de semana'),
                      _th(cs, 'Feriado'),
                    ],
                  ),
                  for (final w in semanas)
                    TableRow(
                      children: [
                        _td(cs, _celulaData(cs, w.entrada)),
                        _td(cs, _celulaData(cs, w.saida)),
                        _td(
                          cs,
                          Text(
                            _nomeMes(DateTime.tryParse(w.entrada)),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        _td(cs, _badgeTipo(w.tipo)),
                        _td(cs, _badgeFeriado(cs, w.feriado)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabelaCompleta(ColorScheme cs, List<SemanaMP> semanas) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 760),
            child: Table(
              columnWidths: const {
                0: FixedColumnWidth(80), // Ano
                1: FixedColumnWidth(160), // Entrada
                2: FixedColumnWidth(160), // Saída
                3: FixedColumnWidth(110), // Mês
                4: FixedColumnWidth(120), // Tipo de semana
                5: FlexColumnWidth(), // Feriado
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                  ),
                  children: [
                    _th(cs, 'Ano'),
                    _th(cs, 'Entrada'),
                    _th(cs, 'Saída'),
                    _th(cs, 'Mês'),
                    _th(cs, 'Tipo de semana'),
                    _th(cs, 'Feriado'),
                  ],
                ),
                for (final w in semanas)
                  TableRow(
                    children: [
                      _td(
                        cs,
                        Text(
                          '${w.ano}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: cs.primary,
                          ),
                        ),
                      ),
                      _td(cs, _celulaData(cs, w.entrada)),
                      _td(cs, _celulaData(cs, w.saida)),
                      _td(
                        cs,
                        Text(
                          _nomeMes(DateTime.tryParse(w.entrada)),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      _td(cs, _badgeTipo(w.tipo)),
                      _td(cs, _badgeFeriado(cs, w.feriado)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _nomeMes(DateTime? dt) {
    if (dt == null) return '—';
    final m = _mesFmt.format(dt);
    if (m.isEmpty) return '—';
    return '${m[0].toUpperCase()}${m.substring(1)}';
  }

  Widget _celulaData(ColorScheme cs, String dataIso) {
    final dt = DateTime.tryParse(dataIso);
    if (dt == null) {
      return Text(dataIso, style: TextStyle(color: cs.onSurfaceVariant));
    }
    return Text.rich(
      TextSpan(
        text: _fmt.format(dt),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
        children: [
          TextSpan(
            text: ' (${_diaSem.format(dt)})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.normal,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeTipo(String tipo) {
    final t = tipo.trim();
    if (t.isEmpty) {
      return const Text('—');
    }
    final alta = t.toLowerCase().startsWith('alta');
    final cor = alta ? const Color(0xFFD97706) : const Color(0xFF2563EB);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cor.withValues(alpha: 0.35)),
        ),
        child: Text(
          t,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: cor,
          ),
        ),
      ),
    );
  }

  Widget _badgeFeriado(ColorScheme cs, String feriado) {
    final f = feriado.trim();
    if (f.isEmpty) {
      return Text(
        '—',
        style: TextStyle(
          fontSize: 13,
          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEA580C),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEA580C).withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                f,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _th(ColorScheme cs, String titulo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        titulo,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: cs.onSurfaceVariant,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _td(ColorScheme cs, Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: child,
    );
  }

  Widget _tagResumo(String texto, Color cor, {IconData? icone}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 11, color: cor),
            const SizedBox(width: 4),
          ],
          Text(
            texto,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: cor,
            ),
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
    double largura = 150,
  }) {
    return SizedBox(
      width: largura,
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
