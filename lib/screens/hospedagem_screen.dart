// lib/screens/hospedagem_screen.dart
//
// Módulo "Hospedagem" → "Festa dos Sócios": mapa de quartos do Villamor Prime
// agrupado por categoria, preenchido com os hóspedes do café (Hospedin)
// cruzados com os contratos. Quem deve mudar de categoria recebe um SINAL DE
// TROCA; o gestor valida (aprovar/recusar) e pode ASSOCIAR manualmente um
// quarto a um contrato/sócio. Tudo persiste no Firestore.
import 'package:flutter/material.dart';
import '../models/contrato_model.dart';
import '../models/quarto_festa_socios.dart';
import '../models/festa_ocupacao_gerado.dart';
import '../models/festa_validacao.dart';
import '../models/festa_associacao.dart';
import '../models/festa_espera.dart';
import '../models/festa_regras.dart';
import '../services/festa_pdf.dart';
import '../services/firestore_service.dart';

const String _periodoFesta = '19 a 23 de julho';

String _catLabel(String? key) =>
    const {
      'luxo': 'Luxo',
      'studio': 'Estúdio',
      'triplo': 'Triplo',
      'comfort': 'Comfort',
      'master': 'Master',
      'duplex': 'Duplex',
      'suiteDuplex': 'Suíte Duplex',
      'suiteVillamor': 'Suíte Villamor',
    }[key] ??
    (key ?? '—');

/// Ordena quartos pelo número (numérico, não lexicográfico).
int _porNumero(QuartoFestaSocios a, QuartoFestaSocios b) =>
    (int.tryParse(a.numero) ?? 0).compareTo(int.tryParse(b.numero) ?? 0);

/// Ocupação efetiva do quarto: associação manual (se houver) tem prioridade
/// sobre o dado gerado automaticamente.
OcupacaoQuarto? ocupacaoEfetiva(
    QuartoFestaSocios q, Map<String, FestaAssociacao> assocs) {
  final a = assocs[q.numero];
  if (a == null) return ocupacaoFesta[q.numero];
  // Quarto esvaziado por uma movimentação manual → fica vago.
  if (a.vago) return null;
  final base = ocupacaoFesta[q.numero];
  final ocupante = a.ocupante.isNotEmpty ? a.ocupante : (base?.ocupante ?? '—');
  // Categoria definida manualmente (hóspede sem contrato)
  if (a.ehManual) {
    final acao = acaoFesta(categoriaKey(q.categoria), a.categoriaManual);
    return OcupacaoQuarto(
      ocupante: ocupante,
      tier: a.tier,
      pct: a.pct?.round(),
      atrasado: a.atrasado,
      acao: acao,
      recomendada: a.categoriaManual,
      confianca: 'manual',
      flags: [if (a.atrasado) 'ATRASADO'],
    );
  }
  // Vínculo com contrato → recalcula pela regra
  final rec = recomendarFesta(a.tier ?? '?', a.pct ?? 0);
  final acao = acaoFesta(categoriaKey(q.categoria), rec.categoria);
  return OcupacaoQuarto(
    ocupante: ocupante,
    tier: a.tier,
    pct: a.pct?.round(),
    atrasado: a.atrasado,
    acao: acao,
    recomendada: rec.categoria,
    confianca: 'manual',
    flags: [...rec.flags, if (a.atrasado) 'ATRASADO'],
  );
}

class HospedagemScreen extends StatelessWidget {
  final String userProfile;
  const HospedagemScreen({super.key, required this.userProfile});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hospedagem'),
          automaticallyImplyLeading: false,
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Mapa', icon: Icon(Icons.grid_view_outlined)),
              Tab(text: 'Trocas', icon: Icon(Icons.swap_horiz)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FestaSociosView(),
            _TrocasView(),
          ],
        ),
      ),
    );
  }
}

class _FestaSociosView extends StatefulWidget {
  const _FestaSociosView();
  @override
  State<_FestaSociosView> createState() => _FestaSociosViewState();
}

class _FestaSociosViewState extends State<_FestaSociosView> {
  final _service = FirestoreService();
  bool _todasExpandidas = true;
  int _versao = 0;
  bool _soTrocas = false;

  Map<CategoriaQuarto, List<QuartoFestaSocios>> get _porCategoria {
    final m = <CategoriaQuarto, List<QuartoFestaSocios>>{};
    for (final c in CategoriaQuarto.values) {
      final lista = quartosFestaSocios.where((q) => q.categoria == c).toList()
        ..sort(_porNumero);
      if (lista.isNotEmpty) m[c] = lista;
    }
    return m;
  }

  bool _passaFiltro(QuartoFestaSocios q, Map<String, FestaAssociacao> a) {
    if (!_soTrocas) return true;
    return ocupacaoEfetiva(q, a)?.deveTrocar ?? false;
  }

  static int _tierRank(String? t) =>
      const {'bronze': 1, 'prata': 2, 'ouro': 3, 'diamante': 4, 'integral': 5}[
          t ?? ''] ??
      0;

  /// Move manualmente o ocupante de [origem] para [destino]. Se o destino já
  /// estiver ocupado, pergunta se quer SUBSTITUIR ou JUNTAR os dois no quarto.
  Future<void> _mover(BuildContext context, String origem, String destino,
      Map<String, FestaAssociacao> assocs) async {
    if (origem == destino) return;
    final qOrig = quartosFestaSocios.firstWhere((q) => q.numero == origem);
    final qDest = quartosFestaSocios.firstWhere((q) => q.numero == destino);
    final oOrig = ocupacaoEfetiva(qOrig, assocs);
    if (oOrig == null) return;
    final oDest = ocupacaoEfetiva(qDest, assocs);
    final assocOrig = assocs[origem];

    FestaAssociacao snap(
            {String? nome, String? tier, double? pct, bool manterAjuste = true}) =>
        FestaAssociacao(
          ocupante: nome ?? oOrig.ocupante,
          tier: tier ?? oOrig.tier,
          pct: pct ?? oOrig.pct?.toDouble(),
          atrasado: oOrig.atrasado,
          contratoId: manterAjuste ? assocOrig?.contratoId : null,
          categoriaManual: manterAjuste ? assocOrig?.categoriaManual : null,
          origem: origem,
        );

    if (oDest != null) {
      final escolha = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Quarto $destino ocupado'),
          content: Text(
              'Já está com ${oDest.ocupante}.\n\nSubstituir o ocupante ou '
              'juntar os dois no mesmo quarto?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            TextButton(
                onPressed: () => Navigator.pop(context, 'sub'),
                child: const Text('Substituir')),
            FilledButton(
                onPressed: () => Navigator.pop(context, 'jun'),
                child: const Text('Juntar')),
          ],
        ),
      );
      if (escolha == null) return;
      if (escolha == 'jun') {
        final tierAlto = _tierRank(oOrig.tier) >= _tierRank(oDest.tier)
            ? oOrig.tier
            : oDest.tier;
        final pctAlto =
            [oOrig.pct ?? 0, oDest.pct ?? 0].reduce((a, b) => a > b ? a : b);
        await _service.moverOcupanteFesta(
          origem: origem,
          destino: destino,
          ocupanteDestino: snap(
            nome: '${oDest.ocupante} + ${oOrig.ocupante}',
            tier: tierAlto,
            pct: pctAlto.toDouble(),
            manterAjuste: false,
          ),
        );
      } else {
        await _service.moverOcupanteFesta(
            origem: origem, destino: destino, ocupanteDestino: snap());
      }
    } else {
      await _service.moverOcupanteFesta(
          origem: origem, destino: destino, ocupanteDestino: snap());
    }
  }

  /// Abre o seletor de quarto e coloca a pessoa da espera no destino escolhido.
  Future<void> _abrirMoverEspera(BuildContext context, FestaEspera e,
      Map<String, FestaAssociacao> assocs) async {
    final destino = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SeletorQuartoDestino(
        origem: '',
        associacoes: assocs,
        titulo: 'Colocar ${e.ocupante} em…',
      ),
    );
    if (destino == null || !context.mounted) return;
    await _colocarDaEspera(context, e, destino, assocs);
  }

  Future<void> _colocarDaEspera(BuildContext context, FestaEspera e,
      String destino, Map<String, FestaAssociacao> assocs) async {
    final qDest = quartosFestaSocios.firstWhere((q) => q.numero == destino);
    final oDest = ocupacaoEfetiva(qDest, assocs);

    FestaAssociacao base({String? nome, String? tier, double? pct, bool aj = true}) =>
        FestaAssociacao(
          ocupante: nome ?? e.ocupante,
          tier: tier ?? e.tier,
          pct: pct ?? e.pct,
          atrasado: e.atrasado,
          contratoId: aj ? e.contratoId : null,
          categoriaManual: aj ? e.categoriaManual : null,
          origem: e.origem,
        );

    FestaAssociacao escolhido = base();
    if (oDest != null) {
      final escolha = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Quarto $destino ocupado'),
          content: Text('Já está com ${oDest.ocupante}.\n\nSubstituir o '
              'ocupante ou juntar os dois no mesmo quarto?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            TextButton(
                onPressed: () => Navigator.pop(context, 'sub'),
                child: const Text('Substituir')),
            FilledButton(
                onPressed: () => Navigator.pop(context, 'jun'),
                child: const Text('Juntar')),
          ],
        ),
      );
      if (escolha == null) return;
      if (escolha == 'jun') {
        final tierAlto = _tierRank(e.tier) >= _tierRank(oDest.tier)
            ? e.tier
            : oDest.tier;
        final pctAlto = [e.pct ?? 0, (oDest.pct ?? 0).toDouble()]
            .reduce((a, b) => a > b ? a : b);
        escolhido = base(
            nome: '${oDest.ocupante} + ${e.ocupante}',
            tier: tierAlto,
            pct: pctAlto,
            aj: false);
      }
    }
    await _service.colocarDaEsperaFesta(
        esperaId: e.id, destino: destino, ocupanteDestino: escolhido);
  }

  /// Gera o PDF da ocupação atual (mapa-base + ajustes) para o setor de reservas.
  Future<void> _gerarRelatorio(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final assocs = await _service.getAssociacoesFestaStream().first;
      final espera = await _service.getEsperaFestaStream().first;

      final grupos = <GrupoCategoria>[];
      for (final entry in _porCategoria.entries) {
        final linhas = <LinhaQuarto>[];
        for (final q in entry.value) {
          final o = ocupacaoEfetiva(q, assocs);
          if (o == null || o.ocupante.isEmpty) continue;
          linhas.add((
            numero: q.numero,
            ocupante: o.ocupante,
            tier: o.tier,
            pct: o.pct,
            origem: assocs[q.numero]?.origem,
          ));
        }
        if (linhas.isNotEmpty) {
          grupos.add((categoria: entry.key.label, linhas: linhas));
        }
      }

      final esperaRows = espera
          .map<LinhaEspera>((e) => (
                categoria: _catLabel(e.categoria),
                ocupante: e.ocupante,
                tier: e.tier,
                pct: e.pct?.round(),
                origem: e.origem,
                quartoDesejado: e.quartoDesejado,
              ))
          .toList();

      if (grupos.isEmpty && esperaRows.isEmpty) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Nenhuma ocupação para exportar.')));
        return;
      }

      await FestaPdf.gerar(
        periodo: _periodoFesta,
        grupos: grupos,
        espera: esperaRows,
        agora: DateTime.now(),
      );
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Falha ao gerar o relatório: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final grupos = _porCategoria;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 2),
          child: Row(children: [
            Icon(Icons.celebration_outlined, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Festa dos Sócios',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.event_outlined,
                        size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('Período: $_periodoFesta',
                        style: TextStyle(
                            fontSize: 12.5, color: cs.onSurfaceVariant)),
                  ]),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() {
                _todasExpandidas = !_todasExpandidas;
                _versao++;
              }),
              icon: Icon(
                  _todasExpandidas ? Icons.unfold_less : Icons.unfold_more,
                  size: 18),
              label: Text(_todasExpandidas ? 'Recolher' : 'Expandir'),
            ),
            FilledButton.icon(
              onPressed: () => _gerarRelatorio(context),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('Relatório'),
            ),
            const SizedBox(width: 8),
          ]),
        ),
        Expanded(
          child: StreamBuilder<Map<String, FestaValidacao>>(
            stream: _service.getValidacoesFestaStream(),
            builder: (context, snapVal) {
              final val = snapVal.data ?? const <String, FestaValidacao>{};
              return StreamBuilder<Map<String, FestaAssociacao>>(
                stream: _service.getAssociacoesFestaStream(),
                builder: (context, snapAssoc) {
                  final assocs =
                      snapAssoc.data ?? const <String, FestaAssociacao>{};
                  var trocas = 0, semContrato = 0, decididas = 0;
                  for (final q in quartosFestaSocios) {
                    final o = ocupacaoEfetiva(q, assocs);
                    if (o == null) continue;
                    if (o.deveTrocar) {
                      trocas++;
                      if (val.containsKey(q.numero)) decididas++;
                    }
                    if (o.acao == 'semContrato') semContrato++;
                  }
                  return StreamBuilder<List<FestaEspera>>(
                    stream: _service.getEsperaFestaStream(),
                    builder: (context, snapEsp) {
                      final espera = snapEsp.data ?? const <FestaEspera>[];
                      return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 12, 6),
                        child: Row(children: [
                          _badgeResumo(Icons.swap_vert, '$trocas a trocar',
                              Colors.orange),
                          const SizedBox(width: 6),
                          _badgeResumo(Icons.task_alt,
                              '$decididas/$trocas validadas', Colors.green),
                          const SizedBox(width: 6),
                          _badgeResumo(Icons.help_outline,
                              '$semContrato s/ contrato', cs.outline),
                          const Spacer(),
                          FilterChip(
                            label: const Text('Só trocas'),
                            selected: _soTrocas,
                            onSelected: (v) => setState(() => _soTrocas = v),
                            avatar: Icon(Icons.swap_vert,
                                size: 18,
                                color: _soTrocas
                                    ? Colors.orange
                                    : cs.onSurfaceVariant),
                            showCheckmark: false,
                          ),
                        ]),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                          children: [
                            if (espera.isNotEmpty)
                              _PainelEspera(
                                espera: espera,
                                onMover: (e) =>
                                    _abrirMoverEspera(context, e, assocs),
                                onColocarDesejado: (e) => _colocarDaEspera(
                                    context, e, e.quartoDesejado!, assocs),
                                onRemover: (e) =>
                                    _service.removerEsperaFesta(e.id),
                              ),
                            for (final entry in grupos.entries)
                              if (entry.value
                                  .where((q) => _passaFiltro(q, assocs))
                                  .isNotEmpty)
                                _CategoriaSection(
                                  key: ValueKey(
                                      '${entry.key}-$_versao-$_soTrocas'),
                                  categoria: entry.key,
                                  quartos: entry.value
                                      .where((q) => _passaFiltro(q, assocs))
                                      .toList(),
                                  validacoes: val,
                                  associacoes: assocs,
                                  inicialExpandida: _todasExpandidas,
                                  onTapQuarto: (q) => _abrirDetalhe(
                                      context, q, val[q.numero], assocs),
                                  onMover: (origem, destino) =>
                                      _mover(context, origem, destino, assocs),
                                ),
                          ],
                        ),
                      ),
                    ],
                  );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _badgeResumo(IconData ic, String txt, Color cor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ic, size: 14, color: cor),
          const SizedBox(width: 4),
          Text(txt, style: TextStyle(fontSize: 12, color: cor)),
        ]),
      );

  void _abrirDetalhe(BuildContext context, QuartoFestaSocios q,
      FestaValidacao? val, Map<String, FestaAssociacao> assocs) {
    final cs = Theme.of(context).colorScheme;
    final assoc = assocs[q.numero];
    final o = ocupacaoEfetiva(q, assocs);

    Future<void> validar(String? status) async {
      await _service.setValidacaoFesta(q.numero, status);
      if (context.mounted) Navigator.pop(context);
    }

    Future<void> associar() async {
      final contrato = await showModalBottomSheet<Contrato>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _SeletorContrato(service: _service),
      );
      if (contrato == null) return;
      final tier = tierDeProduto(contrato.produto, contrato.cota);
      await _service.setAssociacaoFesta(
        q.numero,
        FestaAssociacao(
          contratoId: contrato.localizador,
          ocupante: contrato.nomeComprador,
          tier: tier,
          pct: contrato.percentualIntegralizado,
          atrasado: contrato.valorAtrasado > 0,
        ),
      );
      if (context.mounted) Navigator.pop(context);
    }

    Future<void> removerVinculo() async {
      await _service.setAssociacaoFesta(q.numero, null);
      if (context.mounted) Navigator.pop(context);
    }

    Future<void> mover() async {
      final destino = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (_) =>
            _SeletorQuartoDestino(origem: q.numero, associacoes: assocs),
      );
      if (destino == null || !context.mounted) return;
      await _mover(context, q.numero, destino, assocs);
      if (context.mounted) Navigator.pop(context);
    }

    Future<void> definirCategoria() async {
      final cat = await showModalBottomSheet<String>(
        context: context,
        builder: (_) => _SeletorCategoria(atual: o?.recomendada),
      );
      if (cat == null) return;
      await _service.setAssociacaoFesta(
        q.numero,
        FestaAssociacao(
          ocupante: o?.ocupante ?? '',
          categoriaManual: cat,
          atrasado: o?.atrasado ?? false,
        ),
      );
      if (context.mounted) Navigator.pop(context);
    }

    Future<void> enviarEspera() async {
      if (o == null) return;
      final cat = await showModalBottomSheet<String>(
        context: context,
        builder: (_) => _SeletorCategoria(
            atual: o.recomendada ?? categoriaKey(q.categoria)),
      );
      if (cat == null || !context.mounted) return;
      // Passo opcional: quarto desejado (ou "sem preferência").
      final desejado = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _SeletorQuartoDestino(
          origem: q.numero,
          associacoes: assocs,
          titulo: 'Quarto desejado (opcional)',
          permitirSemPreferencia: true,
        ),
      );
      if (desejado == null) return; // cancelou
      await _service.enviarParaEsperaFesta(
        origem: q.numero,
        espera: FestaEspera(
          ocupante: o.ocupante,
          categoria: cat,
          tier: o.tier,
          pct: o.pct?.toDouble(),
          atrasado: o.atrasado,
          origem: q.numero,
          quartoDesejado: desejado.isEmpty ? null : desejado,
          contratoId: assoc?.contratoId,
          categoriaManual: assoc?.categoriaManual,
        ),
      );
      if (context.mounted) Navigator.pop(context);
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: q.categoria.cor,
                    borderRadius: BorderRadius.circular(10)),
                child: Text(q.numero,
                    style: TextStyle(
                        color: q.categoria.corTexto,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quarto ${q.numero}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(q.categoria.label,
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Icon(Icons.person_outline, size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(o?.ocupante ?? 'Sem ocupante',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              if (assoc != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text('vínculo manual',
                      style: TextStyle(fontSize: 10, color: cs.primary)),
                ),
            ]),
            if (assoc?.origem != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.drive_file_move_outline,
                    size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text('Movido do quarto ${assoc!.origem}',
                    style: TextStyle(fontSize: 12.5, color: cs.primary)),
              ]),
            ],
            if (o != null) ...[
              const SizedBox(height: 10),
              if (o.tier != null)
                Text(
                    'Cota: ${o.tier!.toUpperCase()}'
                    '${o.pct != null ? '  ·  ${o.pct}% integralizado' : ''}',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 12),
              _blocoSugestao(context, q, o),
              if (o.flags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: o.flags.map((f) => _flagChip(context, f)).toList(),
                ),
              ],
              if (o.confianca == 'fuzzy') ...[
                const SizedBox(height: 10),
                Text(
                    '⚠ Match por similaridade de nome — confira ou associe manualmente.',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
              if (o.deveTrocar) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                if (val != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      val.aprovada
                          ? '✅ Troca aprovada${val.validadoPorNome != null ? ' por ${val.validadoPorNome}' : ''}'
                          : '⛔ Mantido no quarto${val.validadoPorNome != null ? ' por ${val.validadoPorNome}' : ''}',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: val.aprovada ? Colors.green : cs.outline),
                    ),
                  ),
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => validar('aprovada'),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Aprovar troca'),
                      style:
                          FilledButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => validar('recusada'),
                      icon: const Icon(Icons.block, size: 18),
                      label: const Text('Manter'),
                    ),
                  ),
                ]),
                if (val != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => validar(null),
                      child: const Text('Limpar validação'),
                    ),
                  ),
              ],
            ],
            // ── Associação manual a um sócio ────────────────────────────────
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: associar,
                  icon: const Icon(Icons.link, size: 18),
                  label: Text(
                      assoc == null ? 'Associar a um sócio' : 'Trocar sócio'),
                ),
              ),
              if (assoc != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: removerVinculo,
                  icon: const Icon(Icons.link_off),
                  tooltip: 'Remover vínculo/ajuste',
                ),
              ],
            ]),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: definirCategoria,
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Definir categoria manualmente'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: mover,
              icon: const Icon(Icons.drive_file_move_outline, size: 18),
              label: const Text('Mover para outro quarto'),
            ),
            if (o != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: enviarEspera,
                icon: const Icon(Icons.hourglass_empty, size: 18),
                label: const Text('Enviar p/ lista de espera'),
              ),
            ],
          ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _blocoSugestao(
      BuildContext context, QuartoFestaSocios q, OcupacaoQuarto o) {
    final cs = Theme.of(context).colorScheme;
    late final IconData ic;
    late final Color cor;
    late final String txt;
    switch (o.acao) {
      case 'sobe':
        ic = Icons.arrow_upward;
        cor = Colors.green;
        txt = 'SUBIR: ${q.categoria.label} → ${_catLabel(o.recomendada)}';
        break;
      case 'desce':
        ic = Icons.arrow_downward;
        cor = Colors.deepOrange;
        txt = 'DESCER: ${q.categoria.label} → ${_catLabel(o.recomendada)}';
        break;
      case 'semContrato':
        ic = Icons.help_outline;
        cor = cs.outline;
        txt = 'Sem contrato — associe manualmente a um sócio abaixo.';
        break;
      default:
        ic = Icons.check_circle_outline;
        cor = cs.primary;
        txt = 'Manter na categoria atual.';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(ic, size: 18, color: cor),
        const SizedBox(width: 8),
        Expanded(
            child: Text(txt,
                style: TextStyle(color: cor, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _flagChip(BuildContext context, String f) {
    final vermelho = f.contains('não deveria vir');
    final cor = vermelho ? Colors.red : Colors.orange.shade800;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cor.withValues(alpha: 0.5)),
      ),
      child: Text(f, style: TextStyle(fontSize: 11.5, color: cor)),
    );
  }
}

class _CategoriaSection extends StatelessWidget {
  final CategoriaQuarto categoria;
  final List<QuartoFestaSocios> quartos;
  final Map<String, FestaValidacao> validacoes;
  final Map<String, FestaAssociacao> associacoes;
  final bool inicialExpandida;
  final ValueChanged<QuartoFestaSocios> onTapQuarto;
  final Future<void> Function(String origem, String destino) onMover;
  const _CategoriaSection({
    super.key,
    required this.categoria,
    required this.quartos,
    required this.validacoes,
    required this.associacoes,
    required this.inicialExpandida,
    required this.onTapQuarto,
    required this.onMover,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final trocas = quartos
        .where((q) => ocupacaoEfetiva(q, associacoes)?.deveTrocar ?? false)
        .length;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: inicialExpandida,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
                color: categoria.cor, borderRadius: BorderRadius.circular(4)),
          ),
          title: Text(categoria.label,
              style:
                  TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
          subtitle: trocas > 0
              ? Text('$trocas a trocar',
                  style: const TextStyle(fontSize: 12, color: Colors.orange))
              : null,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: categoria.cor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${quartos.length}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface)),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, color: cs.onSurfaceVariant),
          ]),
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.12,
              ),
              itemCount: quartos.length,
              itemBuilder: (_, i) => _QuartoCard(
                quarto: quartos[i],
                ocupacao: ocupacaoEfetiva(quartos[i], associacoes),
                validacao: validacoes[quartos[i].numero],
                onTap: () => onTapQuarto(quartos[i]),
                onMover: onMover,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuartoCard extends StatelessWidget {
  final QuartoFestaSocios quarto;
  final OcupacaoQuarto? ocupacao;
  final FestaValidacao? validacao;
  final VoidCallback onTap;
  final Future<void> Function(String origem, String destino) onMover;
  const _QuartoCard({
    required this.quarto,
    required this.ocupacao,
    required this.validacao,
    required this.onTap,
    required this.onMover,
  });

  @override
  Widget build(BuildContext context) {
    final o = ocupacao;
    final ocupado = (o?.ocupante.isNotEmpty ?? false);

    // Alvo de arrasto (recebe quem foi arrastado de outro quarto).
    Widget alvo = DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != quarto.numero,
      onAcceptWithDetails: (d) => onMover(d.data, quarto.numero),
      builder: (context, cand, rej) {
        final hover = cand.isNotEmpty;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: hover
                ? Border.all(color: Colors.white, width: 2.5)
                : Border.all(color: Colors.transparent, width: 2.5),
          ),
          child: _cartao(context),
        );
      },
    );

    if (!ocupado) return alvo;
    // Ocupado → pode ser arrastado para outro quarto (estilo kanban).
    return LongPressDraggable<String>(
      data: quarto.numero,
      feedback: _feedbackArrasto(context),
      childWhenDragging: Opacity(opacity: 0.35, child: alvo),
      child: alvo,
    );
  }

  Widget _feedbackArrasto(BuildContext context) {
    final cor = quarto.categoria.cor;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(quarto.numero,
              style: TextStyle(
                  color: quarto.categoria.corTexto,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(ocupacao?.ocupante ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: quarto.categoria.corTexto, fontSize: 11)),
          ),
        ]),
      ),
    );
  }

  Widget _cartao(BuildContext context) {
    final cor = quarto.categoria.cor;
    final corTexto = quarto.categoria.corTexto;
    final o = ocupacao;
    final troca = o?.deveTrocar ?? false;
    final semContrato = o?.acao == 'semContrato';
    return Material(
      color: cor,
      borderRadius: BorderRadius.circular(10),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(quarto.numero,
                      style: TextStyle(
                          color: corTexto,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    o?.ocupante ?? '—',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: corTexto.withValues(alpha: 0.9),
                        fontSize: 10,
                        height: 1.05),
                  ),
                  if (o?.atrasado ?? false) ...[
                    const SizedBox(height: 2),
                    Icon(Icons.schedule,
                        size: 11, color: corTexto.withValues(alpha: 0.8)),
                  ],
                ],
              ),
            ),
            if (troca)
              Positioned(
                top: 3,
                right: 3,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: Icon(
                    o!.acao == 'sobe'
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 14,
                    color: o.acao == 'sobe' ? Colors.green : Colors.deepOrange,
                  ),
                ),
              ),
            if (semContrato)
              const Positioned(
                top: 3,
                right: 3,
                child: CircleAvatar(
                  radius: 9,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.priority_high,
                      size: 13, color: Colors.redAccent),
                ),
              ),
            if (validacao != null)
              Positioned(
                top: 3,
                left: 3,
                child: CircleAvatar(
                  radius: 9,
                  backgroundColor: Colors.white,
                  child: Icon(
                    validacao!.aprovada ? Icons.check_circle : Icons.block,
                    size: 15,
                    color: validacao!.aprovada ? Colors.green : Colors.grey,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Seletor de categoria para definição manual (hóspede sem contrato).
class _SeletorCategoria extends StatelessWidget {
  final String? atual;
  const _SeletorCategoria({this.atual});

  static const _cats = [
    ['luxo', 'Luxo'],
    ['studio', 'Estúdio'],
    ['triplo', 'Triplo'],
    ['comfort', 'Comfort'],
    ['master', 'Master'],
    ['duplex', 'Duplex'],
    ['suiteDuplex', 'Suíte Duplex'],
    ['suiteVillamor', 'Suíte Villamor'],
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Icon(Icons.tune, color: cs.primary),
              const SizedBox(width: 8),
              const Text('Categoria de destino',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
          ),
          ..._cats.map((c) => ListTile(
                leading: Icon(
                  atual == c[0]
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: atual == c[0] ? cs.primary : cs.outline,
                ),
                title: Text(c[1]),
                onTap: () => Navigator.pop(context, c[0]),
              )),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Painel (recolhível) das listas de espera por categoria, no topo do Mapa.
class _PainelEspera extends StatelessWidget {
  final List<FestaEspera> espera;
  final ValueChanged<FestaEspera> onMover;
  final ValueChanged<FestaEspera> onColocarDesejado;
  final ValueChanged<FestaEspera> onRemover;
  const _PainelEspera({
    required this.espera,
    required this.onMover,
    required this.onColocarDesejado,
    required this.onRemover,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Agrupa por categoria, ordenando pelo ranking.
    final porCat = <String, List<FestaEspera>>{};
    for (final e in espera) {
      porCat.putIfAbsent(e.categoria, () => []).add(e);
    }
    final chaves = porCat.keys.toList()
      ..sort((a, b) =>
          (rankCategoria[a] ?? 0).compareTo(rankCategoria[b] ?? 0));

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.amber.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.withValues(alpha: 0.5)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: const Icon(Icons.hourglass_top, color: Colors.amber),
          title: Text('Lista de espera',
              style:
                  TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
          subtitle: Text('${espera.length} aguardando vaga',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            for (final k in chaves) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
                child: Row(children: [
                  Icon(Icons.label_important_outline,
                      size: 15, color: cs.primary),
                  const SizedBox(width: 6),
                  Text('${_catLabel(k)}  ·  ${porCat[k]!.length}',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: cs.onSurfaceVariant)),
                ]),
              ),
              ...porCat[k]!.map((e) => Card(
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: cs.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.ocupante,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            '${e.tier ?? '—'}'
                            '${e.pct != null ? ' · ${e.pct!.round()}%' : ''}'
                            '${e.origem != null ? ' · saiu do ${e.origem}' : ''}',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                          if (e.quartoDesejado != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(children: [
                                Icon(Icons.star_outline,
                                    size: 15, color: Colors.amber.shade800),
                                const SizedBox(width: 4),
                                Text('Deseja o quarto ${e.quartoDesejado}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.amber.shade800)),
                              ]),
                            ),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(
                              child: e.quartoDesejado != null
                                  ? FilledButton.icon(
                                      onPressed: () => onColocarDesejado(e),
                                      icon: const Icon(Icons.star, size: 18),
                                      label: Text(
                                          'Colocar no ${e.quartoDesejado}'),
                                    )
                                  : FilledButton.icon(
                                      onPressed: () => onMover(e),
                                      icon: const Icon(
                                          Icons.meeting_room_outlined,
                                          size: 18),
                                      label: const Text('Colocar num quarto'),
                                    ),
                            ),
                            IconButton(
                              tooltip: 'Remover da espera',
                              onPressed: () => onRemover(e),
                              icon: const Icon(Icons.delete_outline, size: 20),
                            ),
                          ]),
                          if (e.quartoDesejado != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => onMover(e),
                                icon: const Icon(Icons.meeting_room_outlined,
                                    size: 16),
                                label: const Text('Escolher outro quarto'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

/// Seletor de quarto de destino para mover manualmente um ocupante.
class _SeletorQuartoDestino extends StatefulWidget {
  final String origem;
  final Map<String, FestaAssociacao> associacoes;
  final String? titulo;
  final bool permitirSemPreferencia;
  const _SeletorQuartoDestino(
      {required this.origem,
      required this.associacoes,
      this.titulo,
      this.permitirSemPreferencia = false});
  @override
  State<_SeletorQuartoDestino> createState() => _SeletorQuartoDestinoState();
}

class _SeletorQuartoDestinoState extends State<_SeletorQuartoDestino> {
  final _ctrl = TextEditingController();
  String _q = '';
  bool _soVagos = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final qn = _q.toLowerCase().trim();

    final grupos = <CategoriaQuarto, List<QuartoFestaSocios>>{};
    for (final c in CategoriaQuarto.values) {
      final lista = quartosFestaSocios.where((q) {
        if (q.numero == widget.origem) return false;
        final o = ocupacaoEfetiva(q, widget.associacoes);
        if (_soVagos && o != null) return false;
        if (qn.isNotEmpty) {
          final alvo = '${q.numero} ${o?.ocupante ?? ''}'.toLowerCase();
          if (!alvo.contains(qn)) return false;
        }
        return q.categoria == c;
      }).toList()
        ..sort(_porNumero);
      if (lista.isNotEmpty) grupos[c] = lista;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                Icon(Icons.drive_file_move_outline, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      widget.titulo ?? 'Mover do quarto ${widget.origem} para…',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: TextField(
                controller: _ctrl,
                decoration: const InputDecoration(
                  labelText: 'Buscar por número ou nome',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                FilterChip(
                  label: const Text('Só quartos vagos'),
                  selected: _soVagos,
                  onSelected: (v) => setState(() => _soVagos = v),
                  showCheckmark: true,
                ),
                const Spacer(),
                if (widget.permitirSemPreferencia)
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context, ''),
                    icon: const Icon(Icons.do_not_disturb_on_outlined, size: 18),
                    label: const Text('Sem preferência'),
                  ),
              ]),
            ),
            const Divider(height: 12),
            Expanded(
              child: grupos.isEmpty
                  ? Center(
                      child: Text('Nenhum quarto encontrado',
                          style: TextStyle(color: cs.onSurfaceVariant)))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      children: [
                        for (final entry in grupos.entries) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
                            child: Row(children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                    color: entry.key.cor,
                                    borderRadius: BorderRadius.circular(3)),
                              ),
                              const SizedBox(width: 6),
                              Text(entry.key.label,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurfaceVariant,
                                      fontSize: 13)),
                            ]),
                          ),
                          for (final q in entry.value)
                            _tileQuarto(context, q),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tileQuarto(BuildContext context, QuartoFestaSocios q) {
    final cs = Theme.of(context).colorScheme;
    final o = ocupacaoEfetiva(q, widget.associacoes);
    final vago = o == null;
    return ListTile(
      dense: true,
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: q.categoria.cor, borderRadius: BorderRadius.circular(8)),
        child: Text(q.numero,
            style: TextStyle(
                color: q.categoria.corTexto,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      ),
      title: Text(vago ? 'Vago' : o.ocupante,
          style: TextStyle(
              fontWeight: vago ? FontWeight.normal : FontWeight.w600,
              color: vago ? cs.onSurfaceVariant : cs.onSurface)),
      subtitle: vago ? null : const Text('ocupado — vai perguntar o que fazer'),
      trailing: Icon(
          vago ? Icons.check_circle_outline : Icons.warning_amber_rounded,
          color: vago ? Colors.green : Colors.orange),
      onTap: () => Navigator.pop(context, q.numero),
    );
  }
}


/// Aba "Trocas": estado AO VIVO. Movimentações já feitas (origem → quarto
/// atual), trocas ainda recomendadas pela regra (categoria atual → recomendada)
/// e quem está abaixo de 9%. Tudo derivado do mapa-base + ajustes do Firestore.
class _TrocasView extends StatelessWidget {
  const _TrocasView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final service = FirestoreService();
    return StreamBuilder<Map<String, FestaAssociacao>>(
      stream: service.getAssociacoesFestaStream(),
      builder: (context, snap) {
        final assocs = snap.data ?? const <String, FestaAssociacao>{};

        final realizadas = <
            ({
              String antiga,
              String nova,
              String ocupante,
              String? tier,
              int? pct,
              String cat
            })>[];
        final pendentes = <
            ({
              String quarto,
              String ocupante,
              String? tier,
              int? pct,
              String de,
              String para,
              String acao
            })>[];
        final baixos = <
            ({String quarto, String ocupante, String? tier, int? pct})>[];

        final ordenados = [...quartosFestaSocios]..sort(_porNumero);
        for (final q in ordenados) {
          final a = assocs[q.numero];
          final o = ocupacaoEfetiva(q, assocs);
          if (o == null) continue;
          if (a?.origem != null) {
            realizadas.add((
              antiga: a!.origem!,
              nova: q.numero,
              ocupante: o.ocupante,
              tier: o.tier,
              pct: o.pct,
              cat: q.categoria.label,
            ));
          } else if (o.deveTrocar) {
            pendentes.add((
              quarto: q.numero,
              ocupante: o.ocupante,
              tier: o.tier,
              pct: o.pct,
              de: q.categoria.label,
              para: _catLabel(o.recomendada),
              acao: o.acao,
            ));
          }
          if (o.flags.any((f) => f.contains('<9%'))) {
            baixos.add((
              quarto: q.numero,
              ocupante: o.ocupante,
              tier: o.tier,
              pct: o.pct,
            ));
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
          children: [
            // ── Movimentações feitas ────────────────────────────────────────
            _tituloSecao(context, Icons.check_circle_outline, Colors.green,
                'Movimentações feitas', realizadas.length),
            const SizedBox(height: 4),
            Text('Trocas de quarto já aplicadas no mapa.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            if (realizadas.isEmpty)
              _vazio(context, 'Nenhuma movimentação feita ainda.')
            else ...[
              _cabecalhoAntigaNova(context),
              ...realizadas.map((t) => _linhaMov(context, t)),
            ],
            // ── Recomendadas (a fazer) ──────────────────────────────────────
            const SizedBox(height: 20),
            _tituloSecao(context, Icons.swap_horiz, Colors.orange,
                'Recomendadas (a fazer)', pendentes.length),
            const SizedBox(height: 4),
            Text(
                'Sugestão da regra. Arraste o hóspede no Mapa para aplicar a troca.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            if (pendentes.isEmpty)
              _vazio(context, 'Sem trocas pendentes. 🎉')
            else
              ...pendentes.map((p) => _linhaPendente(context, p)),
            // ── Abaixo de 9% ────────────────────────────────────────────────
            if (baixos.isNotEmpty) ...[
              const SizedBox(height: 20),
              _tituloSecao(context, Icons.person_off_outlined, Colors.red,
                  'Abaixo de 9%', baixos.length),
              const SizedBox(height: 6),
              ...baixos.map((b) => _linhaBaixo(context, b)),
            ],
          ],
        );
      },
    );
  }

  Widget _tituloSecao(BuildContext context, IconData ic, Color cor,
      String titulo, int n) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Icon(ic, color: cor),
      const SizedBox(width: 8),
      Text(titulo,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
      const Spacer(),
      Text('$n', style: TextStyle(color: cs.onSurfaceVariant)),
    ]);
  }

  Widget _vazio(BuildContext context, String txt) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(txt, style: TextStyle(color: cs.onSurfaceVariant)),
    );
  }

  Widget _cabecalhoAntigaNova(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(children: [
        Expanded(
            child: Text('ANTIGA',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurfaceVariant))),
        const SizedBox(width: 28),
        Expanded(
            child: Text('NOVA',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurfaceVariant))),
      ]),
    );
  }

  Widget _linhaMov(
      BuildContext context,
      ({
        String antiga,
        String nova,
        String ocupante,
        String? tier,
        int? pct,
        String cat
      }) t) {
    final cs = Theme.of(context).colorScheme;
    Widget box(String room, String cat, Color cor) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cor.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              Text(room,
                  style: TextStyle(fontWeight: FontWeight.bold, color: cor)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(cat,
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
        );
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(t.ocupante,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              if (t.tier != null)
                Text('${t.tier} · ${t.pct ?? '—'}%',
                    style:
                        TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              box(t.antiga, '', cs.outline),
              Icon(Icons.arrow_forward, size: 20, color: cs.primary),
              box(t.nova, t.cat, Colors.green),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _linhaPendente(
      BuildContext context,
      ({
        String quarto,
        String ocupante,
        String? tier,
        int? pct,
        String de,
        String para,
        String acao
      }) p) {
    final cs = Theme.of(context).colorScheme;
    final sobe = p.acao == 'sobe';
    final cor = sobe ? Colors.green : Colors.deepOrange;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8)),
            child: Text(p.quarto, style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.ocupante,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Row(children: [
                  Text(p.de,
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  Icon(sobe ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 14, color: cor),
                  Text(p.para,
                      style: TextStyle(
                          fontSize: 12,
                          color: cor,
                          fontWeight: FontWeight.w600)),
                ]),
              ],
            ),
          ),
          if (p.tier != null)
            Text('${p.tier} · ${p.pct ?? '—'}%',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ]),
      ),
    );
  }

  Widget _linhaBaixo(BuildContext context,
      ({String quarto, String ocupante, String? tier, int? pct}) s) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: cs.surfaceContainerHighest,
          child: Text(s.quarto, style: const TextStyle(fontSize: 11)),
        ),
        title: Text(s.ocupante),
        subtitle: Text('${s.tier ?? '—'} · ${s.pct ?? '—'}% integralizado'),
      ),
    );
  }
}

/// Seletor de contrato (sócio) para associação manual. Busca por nome/CPF.
class _SeletorContrato extends StatefulWidget {
  final FirestoreService service;
  const _SeletorContrato({required this.service});
  @override
  State<_SeletorContrato> createState() => _SeletorContratoState();
}

class _SeletorContratoState extends State<_SeletorContrato> {
  final _buscaCtrl = TextEditingController();
  late final Future<List<Contrato>> _futuro;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _futuro = widget.service.getContratos();
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[áàâã]'), 'a')
      .replaceAll(RegExp(r'[éê]'), 'e')
      .replaceAll(RegExp(r'[í]'), 'i')
      .replaceAll(RegExp(r'[óôõ]'), 'o')
      .replaceAll(RegExp(r'[ú]'), 'u')
      .replaceAll(RegExp(r'[ç]'), 'c')
      .trim();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final qn = _norm(_q);
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _buscaCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Buscar sócio por nome ou CPF',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Contrato>>(
                future: _futuro,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final qDigits = qn.replaceAll(RegExp(r'\D'), '');
                  final tokens =
                      qn.split(' ').where((t) => t.isNotEmpty).toList();
                  final lista = qn.length < 2
                      ? <Contrato>[]
                      : snap.data!.where((c) {
                          if (c.status != 'Ativo') return false; // só ativos
                          final nome = _norm(
                              '${c.nomeComprador} ${c.nomeComprador2 ?? ''}');
                          final nomeOk = tokens.isNotEmpty &&
                              tokens.every((t) => nome.contains(t));
                          final cpf =
                              '${c.cpfComprador}${c.cpfComprador2 ?? ''}'
                                  .replaceAll(RegExp(r'\D'), '');
                          final cpfOk =
                              qDigits.length >= 3 && cpf.contains(qDigits);
                          return nomeOk || cpfOk;
                        }).take(40).toList();
                  if (qn.length < 2) {
                    return Center(
                        child: Text('Digite ao menos 2 letras',
                            style: TextStyle(color: cs.onSurfaceVariant)));
                  }
                  if (lista.isEmpty) {
                    return Center(
                        child: Text('Nenhum contrato encontrado',
                            style: TextStyle(color: cs.onSurfaceVariant)));
                  }
                  return ListView.separated(
                    itemCount: lista.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = lista[i];
                      return ListTile(
                        title: Text(c.nomeComprador),
                        subtitle: Text(
                            '${c.produto} · ${c.cota} · ${c.percentualIntegralizado.toStringAsFixed(0)}%'
                            '${c.valorAtrasado > 0 ? ' · em atraso' : ''}'),
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
