import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/contrato_model.dart';
import '../models/imovel_model.dart';
import '../services/analise_imoveis.dart';
import '../services/firestore_service.dart';

/// Aba "Transição" (exclusiva do super admin): projeta a futura migração dos
/// contratos do resort para o novo Hotel Villamor.
///
/// Primeira entrega: contar quantos apartamentos estão vendidos por linha de
/// produto — LUXO (blocos A/B/D/E) × VILLAMOR (bloco C) — para dimensionar a
/// transição. Dados carregados sob demanda (não lê o Firestore ao abrir).
class AbaTransicao extends StatefulWidget {
  const AbaTransicao({super.key});

  @override
  State<AbaTransicao> createState() => _AbaTransicaoState();
}

class _LinhaStats {
  int totalUnidades = 0;
  int unidadesVendidas = 0; // com ao menos 1 cota vendida
  int esgotadas = 0;
  // Cotas vendidas por tier — cada tier fraciona o apartamento de um jeito.
  int cotasBronze = 0; // 52 por apartamento
  int cotasPrata = 0; //  26 por apartamento
  int cotasOuro = 0; //   13 por apartamento
  int cotasDiamante = 0; // 1 por apartamento (apto inteiro)
  int cotasIntegral = 0; // 1 por apartamento (apto inteiro)

  int get cotasVendidas =>
      cotasBronze + cotasPrata + cotasOuro + cotasDiamante + cotasIntegral;

  /// Apartamentos vendidos convertendo cotas → apartamento: 52 bronze = 1 ap,
  /// 26 prata = 1 ap, 13 ouro = 1 ap, integral/diamante = 1 ap.
  double get apartamentosEquivalente =>
      cotasBronze / 52 +
      cotasPrata / 26 +
      cotasOuro / 13 +
      cotasDiamante +
      cotasIntegral.toDouble();
}

class _AbaTransicaoState extends State<AbaTransicao> {
  final _fs = FirestoreService();
  bool _carregando = true; // carrega automaticamente ao abrir
  bool _carregado = false;
  Map<String, _LinhaStats> _stats = {}; // conta principal (sem os separados)
  // Clientes separados → estatísticas por linha (mostrados à parte).
  Map<String, Map<String, _LinhaStats>> _separados = {};
  // Top 30 contratos ativos por valor pago (integralizado).
  List<Contrato> _top30 = [];

  static final _moeda =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  /// Clientes cujos contratos ficam FORA da conta principal e são somados à
  /// parte (pedido do gestor). Rótulo → teste no nome do comprador.
  static final Map<String, bool Function(String)> _clientesSeparados = {
    'Matheus Camelo': (n) {
      final u = n.toUpperCase();
      return u.contains('MATHEUS') && u.contains('CAMELO');
    },
    'Reynaldo Fabbri': (n) {
      final u = n.toUpperCase();
      return u.contains('REYNALDO') &&
          (u.contains('FABBRI') || u.contains('FABRI'));
    },
  };

  /// Rótulo do cliente separado a que o nome pertence, ou null.
  static String? _clienteSeparado(String nome) {
    for (final e in _clientesSeparados.entries) {
      if (e.value(nome)) return e.key;
    }
    return null;
  }

  /// Monta as estatísticas por linha (LUXO/VILLAMOR/BANGALÔ) a partir de um
  /// conjunto de contratos.
  Map<String, _LinhaStats> _montarStats(
      List<Imovel> imoveis, List<Contrato> contratos) {
    final resumo = analisarEmpreendimento(imoveis, contratos);
    final map = <String, _LinhaStats>{};
    for (final a in resumo.imoveis) {
      final linha = linhaProduto(a.imovel.tipo);
      final s = map.putIfAbsent(linha, () => _LinhaStats());
      s.totalUnidades++;
      // Cotas vendidas somam no bucket do tier do imóvel (cada imóvel tem um).
      switch (a.tier) {
        case TierCota.bronze:
          s.cotasBronze += a.cotasVendidas;
          break;
        case TierCota.prata:
          s.cotasPrata += a.cotasVendidas;
          break;
        case TierCota.ouro:
          s.cotasOuro += a.cotasVendidas;
          break;
        case TierCota.diamante:
          s.cotasDiamante += a.cotasVendidas;
          break;
        case TierCota.integral:
          s.cotasIntegral += a.cotasVendidas;
          break;
        case null:
          break; // sem venda / tier indefinido
      }
      if (a.situacao != SituacaoImovel.indefinido) {
        s.unidadesVendidas++;
        if (a.situacao == SituacaoImovel.esgotado) s.esgotadas++;
      }
    }
    return map;
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final imoveis = await _fs.getImoveis();
      // contratosEfetivos já mantém SOMENTE contratos com status Ativo.
      final contratos = contratosEfetivos(await _fs.getContratos());
      final outros = contratos
          .where((c) => _clienteSeparado(c.nomeComprador) == null)
          .toList();
      final separados = <String, Map<String, _LinhaStats>>{};
      for (final rotulo in _clientesSeparados.keys) {
        final doCliente = contratos
            .where((c) => _clienteSeparado(c.nomeComprador) == rotulo)
            .toList();
        separados[rotulo] = _montarStats(imoveis, doCliente);
      }
      // Prioridade de atendimento: todos os contratos ativos (inclui os de
      // "pavimento"/avulsos) ordenados pelo valor já pago (integralizado).
      final top = List<Contrato>.from(contratos)
        ..sort((a, b) => b.valorIntegralizado.compareTo(a.valorIntegralizado));
      if (!mounted) return;
      setState(() {
        _stats = _montarStats(imoveis, outros);
        _separados = separados;
        _top30 = top.take(30).toList();
        _carregado = true;
        _carregando = false;
      });
    } catch (e) {
      debugPrint('AbaTransicao._carregar: $e');
      if (!mounted) return;
      setState(() => _carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao carregar a transição.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_carregado) {
      return _prompt(cs);
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: cs.primary,
            unselectedLabelColor: cs.onSurfaceVariant,
            indicatorColor: cs.primary,
            tabs: const [
              Tab(text: 'Apartamentos', icon: Icon(Icons.apartment_outlined)),
              Tab(text: 'Prioridade', icon: Icon(Icons.priority_high_rounded)),
              Tab(text: 'Argumentos', icon: Icon(Icons.forum_outlined)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _tabApartamentos(cs),
                _tabPrioridade(cs),
                _tabArgumentos(cs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Aba: Apartamentos (contagens LUXO/VILLAMOR + clientes separados) ──────
  Widget _tabApartamentos(ColorScheme cs) {
    final luxo = _stats['LUXO'] ?? _LinhaStats();
    final villamor = _stats['VILLAMOR'] ?? _LinhaStats();
    final bangalo = _stats['BANGALÔ'];
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _cabecalho(cs),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _cardLinha(cs, 'LUXO', luxo, cs.primary)),
              const SizedBox(width: 12),
              Expanded(
                  child: _cardLinha(
                      cs, 'VILLAMOR', villamor, Colors.teal.shade700)),
            ],
          ),
          if (bangalo != null) ...[
            const SizedBox(height: 12),
            _cardLinha(cs, 'BANGALÔ', bangalo, Colors.brown.shade600),
          ],
          for (final e in _separados.entries) _blocoSeparado(cs, e.key, e.value),
          const SizedBox(height: 16),
          _rodape(cs),
        ],
      ),
    );
  }

  // ── Aba: Prioridade (top 30 por valor pago) ───────────────────────────────
  Widget _tabPrioridade(ColorScheme cs) {
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [_blocoPrioridade(cs)],
      ),
    );
  }

  // ── Aba: Argumentos (roteiro de abordagem da transição) ───────────────────
  static const List<String> _porqueTrocar = [
    'Uso imediato: o resort ainda está em obras; o hotel já está em pleno '
        'funcionamento. Na troca, o cliente passa a usufruir AGORA, sem '
        'esperar a conclusão da obra.',
    'Fim da incerteza de prazo: elimina o risco de atraso de entrega. A '
        'fruição deixa de ser uma promessa futura e vira realidade.',
    'Estrutura pronta e testada: operação, equipe e serviços já validados por '
        'hóspedes reais — não é projeto no papel.',
    'Antecipa o benefício: qualquer vantagem de uso/estadia começa desde já, '
        'e não daqui a anos.',
    'Mesmo padrão e categoria da cota, só que começando hoje.',
  ];

  static const List<String> _porqueMesmoValor = [
    'É uma troca de ativo equivalente: mesmo investimento, mesma fração '
        '(cotas/semanas) e mesmo direito de uso — muda apenas o local, de um '
        'ativo em obras para um pronto.',
    'Todo o valor já pago é integralmente preservado e transferido para o '
        'novo contrato. O cliente não perde nada.',
    'Não se paga nada a mais — e se recebe mais: o uso imediato que hoje o '
        'cliente ainda não tem.',
    'A categoria/padrão do produto é mantida (a equivalência da cota é '
        'preservada).',
    'Sem custos ou perdas de distrato: as condições do contrato são honradas.',
  ];

  // (objeção do cliente, resposta sugerida)
  static const List<List<String>> _objeoesRespostas = [
    [
      'Eu comprei o resort, não o hotel.',
      'Seu direito de multipropriedade e o valor investido são integralmente '
          'preservados. A troca só antecipa seu benefício para um '
          'empreendimento que JÁ funciona — enquanto o resort segue em obras, '
          'sem data garantida de uso.',
    ],
    [
      'Prefiro esperar o resort ficar pronto.',
      'Enquanto espera, seu investimento fica parado, sem poder ser usado. Na '
          'troca, você começa a usufruir agora, pelo mesmo valor e sem o risco '
          'de novos prazos de obra.',
    ],
    [
      'Quero cancelar e reaver meu dinheiro (distrato).',
      'O distrato normalmente implica perda de parte do que já foi pago. A '
          'troca resolve exatamente a sua insatisfação — não poder usar agora '
          '— mantendo 100% do seu investimento e liberando o uso imediato.',
    ],
    [
      'O hotel tem o mesmo padrão que eu contratei?',
      'A categoria da sua cota é mantida. O hotel já opera com estrutura '
          'validada; convidamos você a conhecer e comprovar o padrão antes de '
          'qualquer decisão.',
    ],
    [
      'E se eu não gostar do hotel?',
      'Antes de decidir, oferecemos uma visita/experiência no hotel para você '
          'conhecer a estrutura e o atendimento na prática.',
    ],
    [
      'Por que vocês querem fazer essa troca?',
      'Transparência total: queremos que você aproveite o que comprou o quanto '
          'antes. Em vez de esperar a obra, entregamos um ativo pronto, '
          'honrando integralmente seu contrato. É um ganha-ganha.',
    ],
  ];

  Widget _tabArgumentos(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.forum_outlined, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Roteiro de abordagem da transição: do resort (em obras) '
                  'para o hotel (em operação). Use como apoio — ajuste ao caso '
                  'e confirme prazos e cláusulas no contrato.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _secaoArg(cs, 'Por que fazer a troca', Icons.swap_horiz_rounded,
            cs.primary, _porqueTrocar),
        const SizedBox(height: 16),
        _secaoArg(cs, 'Por que o valor continua o mesmo',
            Icons.price_check_rounded, Colors.teal.shade700, _porqueMesmoValor),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.question_answer_outlined, color: Colors.orange.shade800),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Objeções dos clientes e como responder',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final qr in _objeoesRespostas) _objecaoTile(cs, qr[0], qr[1]),
      ],
    );
  }

  Widget _secaoArg(ColorScheme cs, String titulo, IconData icone, Color cor,
      List<String> itens) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 18, color: cor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(titulo,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: cor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final t in itens)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: cor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(t, style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _objecaoTile(ColorScheme cs, String objecao, String resposta) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(Icons.chat_bubble_outline, color: Colors.orange.shade800),
        title: Text('"$objecao"',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.subdirectory_arrow_right,
                  size: 16, color: Colors.green.shade700),
              const SizedBox(width: 6),
              Expanded(
                child: Text(resposta,
                    style: TextStyle(
                        fontSize: 13, color: cs.onSurfaceVariant, height: 1.4)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Prioridade de atendimento: top 30 contratos ativos por valor pago.
  Widget _blocoPrioridade(ColorScheme cs) {
    if (_top30.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.priority_high_rounded, color: cs.primary),
            const SizedBox(width: 8),
            const Text('Prioridade de atendimento',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 2),
        Text('Top 30 contratos ativos por valor pago (integralizado).',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            children: [
              for (var i = 0; i < _top30.length; i++)
                _linhaPrioridade(cs, i + 1, _top30[i],
                    ultima: i == _top30.length - 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _linhaPrioridade(ColorScheme cs, int pos, Contrato c,
      {required bool ultima}) {
    final sep = _clienteSeparado(c.nomeComprador);
    final id = imovelIdDoContrato(c);
    final local = id ?? '${c.bloco} ${c.imovel}'.trim();
    final cota = c.cota.trim().isEmpty ? '' : ' · ${c.cota.trim()}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: ultima
            ? null
            : Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text('$pos',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: cs.primary)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(c.nomeComprador,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    if (sep != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade400
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text('separado',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.deepPurple.shade400)),
                      ),
                    ],
                  ],
                ),
                Text(
                  '$local$cota · ${c.percentualEfetivo.toStringAsFixed(0)}% pago'
                  '${c.valorAtrasado > 0 ? ' · em atraso' : ''}',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(_moeda.format(c.valorIntegralizado),
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  /// Bloco separado com os contratos de um cliente fora da conta principal.
  Widget _blocoSeparado(
      ColorScheme cs, String rotulo, Map<String, _LinhaStats> stats) {
    final luxo = stats['LUXO'] ?? _LinhaStats();
    final villamor = stats['VILLAMOR'] ?? _LinhaStats();
    final bangalo = stats['BANGALÔ'] ?? _LinhaStats();
    final totalAp = luxo.apartamentosEquivalente +
        villamor.apartamentosEquivalente +
        bangalo.apartamentosEquivalente;
    if (totalAp == 0) return const SizedBox.shrink();

    final cor = Colors.deepPurple.shade400;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline, size: 18, color: cor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('$rotulo (fora da conta acima)',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: cor)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${_fmtAp(totalAp)} apartamentos',
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold, color: cor)),
            const Divider(height: 20),
            if (luxo.apartamentosEquivalente > 0)
              _linhaInfo(
                  'LUXO', _fmtAp(luxo.apartamentosEquivalente), cs),
            if (villamor.apartamentosEquivalente > 0)
              _linhaInfo(
                  'VILLAMOR', _fmtAp(villamor.apartamentosEquivalente), cs),
            if (bangalo.apartamentosEquivalente > 0)
              _linhaInfo(
                  'Bangalô', _fmtAp(bangalo.apartamentosEquivalente), cs),
            _linhaInfo(
                'Cotas (contratos)',
                '${luxo.cotasVendidas + villamor.cotasVendidas + bangalo.cotasVendidas}',
                cs),
          ],
        ),
      ),
    );
  }

  Widget _cabecalho(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.swap_horiz_rounded, color: cs.primary),
            const SizedBox(width: 8),
            const Text('Transição para o Hotel Villamor',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Projeção da migração dos contratos do resort para o novo hotel. '
          'Comece pelos apartamentos vendidos em cada linha de produto.',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _cardLinha(
      ColorScheme cs, String titulo, _LinhaStats s, Color cor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cor,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Text(_fmtAp(s.apartamentosEquivalente),
              style: TextStyle(
                  fontSize: 40, fontWeight: FontWeight.bold, color: cor)),
          Text('apartamentos vendidos (equivalente)',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const Divider(height: 20),
          if (s.cotasBronze > 0)
            _linhaInfo('Bronze', '${s.cotasBronze} cotas ÷ 52', cs),
          if (s.cotasPrata > 0)
            _linhaInfo('Prata', '${s.cotasPrata} cotas ÷ 26', cs),
          if (s.cotasOuro > 0)
            _linhaInfo('Ouro', '${s.cotasOuro} cotas ÷ 13', cs),
          if (s.cotasDiamante > 0)
            _linhaInfo('Diamante', '${s.cotasDiamante} (apto inteiro)', cs),
          if (s.cotasIntegral > 0)
            _linhaInfo('Integral', '${s.cotasIntegral} (apto inteiro)', cs),
          const Divider(height: 20),
          _linhaInfo('Total de cotas vendidas', '${s.cotasVendidas}', cs),
          _linhaInfo('Unidades com venda', '${s.unidadesVendidas}', cs),
          _linhaInfo('Totalmente vendidas', '${s.esgotadas}', cs),
          _linhaInfo('Unidades no bloco', '${s.totalUnidades}', cs),
        ],
      ),
    );
  }

  /// Formata apartamentos-equivalentes: inteiro sem casa decimal, senão 1 casa.
  String _fmtAp(double v) {
    final s = (v % 1 == 0) ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return s.replaceAll('.', ',');
  }

  Widget _linhaInfo(String label, String valor, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          Text(valor,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _rodape(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Apartamentos vendidos = cotas vendidas convertidas em apartamento: '
        '52 bronze = 1 · 26 prata = 1 · 13 ouro = 1 · integral/diamante = 1. '
        'Fonte: contratos ativos (pós-venda). LUXO reúne os blocos A, B, D e E; '
        'VILLAMOR é o bloco C.',
        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
      ),
    );
  }

  Widget _prompt(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz_rounded, size: 48, color: cs.primary),
            const SizedBox(height: 12),
            const Text('Não foi possível carregar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Tente novamente para ver os apartamentos LUXO e VILLAMOR '
              'vendidos.',
              style: TextStyle(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _carregar,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
