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

  // ── Simulação do pool de hospedagem (aba Pool) ────────────────────────────
  final _hotelCtrl = TextEditingController(text: '100'); // aptos no hotel
  final _poolCtrl = TextEditingController(text: '30'); // aptos no pool
  final _diariaCtrl = TextEditingController(text: '550'); // diária média (R$)
  final _taxaCtrl = TextEditingController(text: '15'); // taxa administração (%)
  static const List<double> _ocupacoes = [0.5, 0.7, 1.0];

  // ── Temporadas (aba Pool): só Média e Alta (o hotel não tem baixa) ─────────
  // Movimento alto: mais semanas de alta que de média.
  final _altaSemCtrl = TextEditingController(text: '32'); // semanas
  final _altaDiaCtrl = TextEditingController(text: '750'); // diária (R$)
  final _altaOcupCtrl = TextEditingController(text: '90'); // ocupação (%)
  final _medSemCtrl = TextEditingController(text: '20');
  final _medDiaCtrl = TextEditingController(text: '550');
  final _medOcupCtrl = TextEditingController(text: '70');

  /// Temporadas: (rótulo, semanas, diária, ocupação, cor).
  List<(String, TextEditingController, TextEditingController,
          TextEditingController, Color)>
      get _temporadas => [
            ('Alta', _altaSemCtrl, _altaDiaCtrl, _altaOcupCtrl,
                const Color(0xFFD84315)),
            ('Média', _medSemCtrl, _medDiaCtrl, _medOcupCtrl,
                const Color(0xFFEF6C00)),
          ];

  // Cenários de participação da multipropriedade no hotel (fração dos aptos).
  static const List<(String, double)> _cenariosMP = [
    ('Multipropriedade = 50% do hotel', 0.5),
    ('Multipropriedade = 100% do hotel', 1.0),
  ];

  // ── Custos / Ganhos / Devoluções ──────────────────────────────────────────
  // Composição do custo mensal do hotel (o total é a soma destes itens).
  final _custoEnergiaCtrl = TextEditingController(text: '60000');
  final _custoAguaCtrl = TextEditingController(text: '25000');
  final _custoPessoalCtrl = TextEditingController(text: '120000');
  final _custoManutCtrl = TextEditingController(text: '20000');
  final _custoLimpezaCtrl = TextEditingController(text: '15000');
  final _custoAdmCtrl = TextEditingController(text: '20000');
  final _custoOutrosCtrl = TextEditingController(text: '10000');
  final _minPagoCtrl =
      TextEditingController(text: '30'); // % mínimo pago p/ entrar no pool
  final _naoAceitaCtrl =
      TextEditingController(text: '15'); // % que não aceita a transição
  final _parcelasCtrl =
      TextEditingController(text: '12'); // parcelas do acordo judicial
  final _acrescimoCtrl =
      TextEditingController(text: '20'); // correção + honorários (%)
  // Preço de venda por cota (aba Ganhos — dono do empreendimento).
  // Defaults = média real por tier dos contratos ativos (valorFinanciado).
  final _precoBronzeCtrl = TextEditingController(text: '33645');
  final _precoPrataCtrl = TextEditingController(text: '58455');
  final _precoOuroCtrl = TextEditingController(text: '124008');
  final _precoDiamanteCtrl = TextEditingController(text: '1399759');
  // Aba Comprador (visão de quem compra a cota financiada / alavancagem).
  final _valorCotaCtrl = TextEditingController(text: '116380'); // valor da cota
  final _entradaCompraCtrl = TextEditingController(text: '0'); // entrada (%)
  final _prazoCtrl = TextEditingController(text: '120'); // parcelas (meses)
  final _jurosCtrl = TextEditingController(text: '0.68'); // juros a.m. (%)
  final _yieldACtrl = TextEditingController(text: '6'); // yield fraco (%)
  final _yieldBCtrl = TextEditingController(text: '8'); // yield médio (%)
  final _yieldCCtrl = TextEditingController(text: '10'); // yield ótimo (%)

  /// Receita líquida anual do pool por apartamento (base temporadas).
  double _liqAnualApto(double taxa) {
    double s = 0;
    for (final t in _temporadas) {
      s += _parse(t.$2, 0) * 7 * (_parse(t.$4, 0) / 100.0) * _parse(t.$3, 0);
    }
    return s * (1 - taxa);
  }

  /// Receita BRUTA anual do pool por apartamento (antes da taxa).
  double _brutoAnualApto() {
    double s = 0;
    for (final t in _temporadas) {
      s += _parse(t.$2, 0) * 7 * (_parse(t.$4, 0) / 100.0) * _parse(t.$3, 0);
    }
    return s;
  }

  /// Total de cotas vendidas por tier (conta principal + separados).
  (int, int, int, int) _cotasVendidasPorTier() {
    var b = 0, p = 0, o = 0, d = 0;
    for (final mapa in [_stats, ..._separados.values]) {
      for (final s in mapa.values) {
        b += s.cotasBronze;
        p += s.cotasPrata;
        o += s.cotasOuro;
        d += s.cotasDiamante + s.cotasIntegral;
      }
    }
    return (b, p, o, d);
  }

  /// Itens da composição do custo mensal (rótulo → controlador).
  List<(String, TextEditingController)> get _linhasCusto => [
        ('Energia', _custoEnergiaCtrl),
        ('Água', _custoAguaCtrl),
        ('Funcionários (folha)', _custoPessoalCtrl),
        ('Manutenção', _custoManutCtrl),
        ('Limpeza / lavanderia', _custoLimpezaCtrl),
        ('Administração', _custoAdmCtrl),
        ('Outros', _custoOutrosCtrl),
      ];

  /// Custo mensal total do hotel = soma dos itens da composição.
  double get _custoMensal =>
      _linhasCusto.fold(0.0, (s, l) => s + _parse(l.$2, 0));

  // Dados reais dos contratos ativos (carregados em _carregar).
  double _exposicaoDevolucao = 0; // soma do valorIntegralizado dos ativos
  double _baseDistrato = 0; // soma valorIntegralizado, excl. Matheus+Reynaldo
  int _ativosCount = 0; // qtd de contratos ativos
  List<double> _pctPagos = []; // % efetivo pago de cada contrato ativo

  // ── Aba Reynaldo (projeção de distratos, vendas e payback do aporte) ──────
  final _reyDesistCtrl = TextEditingController(text: '40'); // % desistência
  final _reyDistPrazoCtrl = TextEditingController(text: '48'); // parcelas distrato
  final _reyVendaMesCtrl = TextEditingController(text: '400000'); // venda/mês
  final _reyEntradaCtrl = TextEditingController(text: '10'); // % entrada da venda
  final _reyVendaPrazoCtrl = TextEditingController(text: '60'); // parcelas venda
  final _reyResortCtrl = TextEditingController(text: '300000'); // aporte resort/mês
  final _reyAporteCtrl = TextEditingController(text: '2000000'); // aporte Reynaldo
  final _reyPoolMesCtrl = TextEditingController(text: '50000'); // 15% pool/mês
  final _reyPoolInicioCtrl = TextEditingController(text: '12'); // mês início pool
  final _reyShareVendasCtrl =
      TextEditingController(text: '100'); // % do caixa de vendas p/ Reynaldo

  // Tiers de cota: (rótulo, cotas por apartamento, cor).
  static final List<(String, int, Color)> _tiers = [
    ('Bronze', 52, Color(0xFF9E6B3F)),
    ('Prata', 26, Color(0xFF7A8390)),
    ('Ouro', 13, Color(0xFFC9A227)),
    ('Diamante / Integral', 1, Color(0xFF4A6FA5)),
  ];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _hotelCtrl.dispose();
    _poolCtrl.dispose();
    _diariaCtrl.dispose();
    _taxaCtrl.dispose();
    for (final l in _linhasCusto) {
      l.$2.dispose();
    }
    for (final t in _temporadas) {
      t.$2.dispose();
      t.$3.dispose();
      t.$4.dispose();
    }
    _minPagoCtrl.dispose();
    _naoAceitaCtrl.dispose();
    _parcelasCtrl.dispose();
    _acrescimoCtrl.dispose();
    _precoBronzeCtrl.dispose();
    _precoPrataCtrl.dispose();
    _precoOuroCtrl.dispose();
    _precoDiamanteCtrl.dispose();
    _valorCotaCtrl.dispose();
    _entradaCompraCtrl.dispose();
    _prazoCtrl.dispose();
    _jurosCtrl.dispose();
    _yieldACtrl.dispose();
    _yieldBCtrl.dispose();
    _yieldCCtrl.dispose();
    _reyDesistCtrl.dispose();
    _reyDistPrazoCtrl.dispose();
    _reyVendaMesCtrl.dispose();
    _reyEntradaCtrl.dispose();
    _reyVendaPrazoCtrl.dispose();
    _reyResortCtrl.dispose();
    _reyAporteCtrl.dispose();
    _reyPoolMesCtrl.dispose();
    _reyPoolInicioCtrl.dispose();
    _reyShareVendasCtrl.dispose();
    super.dispose();
  }

  double _parse(TextEditingController c, double fallback) {
    final v = double.tryParse(c.text.replaceAll(',', '.').trim());
    return (v == null || v < 0) ? fallback : v;
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
      // Prioridade de atendimento: contratos ativos (inclui os de "pavimento"/
      // avulsos), EXCETO os clientes tratados à parte (Matheus/Reynaldo),
      // ordenados pelo valor já pago (integralizado).
      final top = contratos
          .where((c) => _clienteSeparado(c.nomeComprador) == null)
          .toList()
        ..sort((a, b) => b.valorIntegralizado.compareTo(a.valorIntegralizado));
      // Exposição de devolução (pior caso) = tudo que já foi pago nos ativos.
      // Elegibilidade ao pool: % efetivo pago de cada contrato ativo.
      final exposicao =
          contratos.fold<double>(0, (s, c) => s + c.valorIntegralizado);
      // Base de distrato: exclui Matheus Camelo e Reynaldo (tratados à parte).
      final baseDist = contratos
          .where((c) => _clienteSeparado(c.nomeComprador) == null)
          .fold<double>(0, (s, c) => s + c.valorIntegralizado);
      final pctPagos = contratos.map((c) => c.percentualEfetivo).toList();
      if (!mounted) return;
      setState(() {
        _stats = _montarStats(imoveis, outros);
        _separados = separados;
        _top30 = top.take(30).toList();
        _exposicaoDevolucao = exposicao;
        _baseDistrato = baseDist;
        _ativosCount = contratos.length;
        _pctPagos = pctPagos;
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
      length: 10,
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
              Tab(text: 'Pool', icon: Icon(Icons.pool_outlined)),
              Tab(text: 'Condomínio', icon: Icon(Icons.receipt_long_outlined)),
              Tab(text: 'Ganhos', icon: Icon(Icons.savings_outlined)),
              Tab(text: 'Comprador', icon: Icon(Icons.handshake_outlined)),
              Tab(text: 'Devoluções', icon: Icon(Icons.money_off_outlined)),
              Tab(text: 'Reynaldo', icon: Icon(Icons.account_balance_outlined)),
              Tab(text: 'Plano', icon: Icon(Icons.checklist_rounded)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _tabApartamentos(cs),
                _tabPrioridade(cs),
                _tabArgumentos(cs),
                _tabPool(cs),
                _tabCondominio(cs),
                _tabGanhos(cs),
                _tabComprador(cs),
                _tabDevolucoes(cs),
                _tabReynaldo(cs),
                _tabPlano(cs),
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
          _cardPrecoMedio(cs),
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

  // ── Aba: Plano (estratégia de transição segura) ───────────────────────────
  // (título, descrição) das estratégias.
  static const List<List<String>> _estrategias = [
    [
      'Começar pelos maiores valores',
      'Priorize os contratos de maior valor pago (aba Prioridade). Garantir o '
          'buy-in dos maiores investidores primeiro reduz o risco e cria '
          'referências de peso para os demais.',
    ],
    [
      'Transição inicial de quem solicitar',
      'Abra a migração voluntária: quem pedir, migra primeiro. Gera casos de '
          'sucesso e prova social para convencer os indecisos, sem pressão.',
    ],
    [
      'Definir o apartamento destino de cada um',
      'Antes de negociar, tenha um mapa de qual apartamento do hotel fica para '
          'cada contrato, respeitando a equivalência de categoria (LUXO/'
          'VILLAMOR e tier). Critério transparente evita disputa.',
    ],
    [
      'Migrar em ondas, não todos de uma vez',
      'Faça em lotes pequenos, valide o processo (contrato, assinatura, '
          'entrega) e ajuste antes de escalar.',
    ],
    [
      'Termo de troca bem redigido (jurídico)',
      'Aditivo/contrato que preserve o valor pago, a cota/semana e todos os '
          'direitos. Assinatura digital para agilizar e registrar tudo.',
    ],
    [
      'Oferecer visita ao hotel antes de assinar',
      'Deixe o cliente conhecer a estrutura pronta. Ver o hotel funcionando '
          'transforma a dúvida em desejo e derruba objeção.',
    ],
    [
      'Comunicação transparente e proativa',
      'Carta + reunião explicando o porquê, os benefícios e as garantias. '
          'Antecipar a informação evita boato e desconfiança.',
    ],
    [
      'Registrar tudo (auditoria)',
      'Controle de quem migrou, quando e para qual apartamento. '
          'Rastreabilidade protege a empresa e o cliente.',
    ],
  ];

  // (pergunta do cliente, direcionamento de resposta).
  static const List<List<String>> _perguntasClientes = [
    [
      'Todo apartamento do hotel será multipropriedade?',
      'Defina e comunique claramente quais unidades entram na multipropriedade '
          'e quais ficam de uso hoteleiro/pool. O cliente precisa saber que o '
          'modelo dele é preservado.',
    ],
    [
      'Terá festa todos os dias?',
      'Alinhar expectativa: o hotel é um empreendimento em operação, com '
          'programação e regras de convivência — não evento diário. Explicar a '
          'experiência real que ele terá.',
    ],
    [
      'O que vai virar o resort?',
      'Ter uma resposta OFICIAL sobre o destino do resort em obras '
          '(continuidade, outro uso, cronograma). Silêncio aqui gera '
          'insegurança e boato.',
    ],
    [
      'Vou poder escolher meu apartamento?',
      'Explicar o critério de alocação (equivalência de categoria + ordem '
          'definida) e quanto há de escolha real para o cliente.',
    ],
    [
      'Minha cota / semana muda?',
      'Não: a fração e o direito de uso são preservados. Reforçar isso por '
          'escrito no termo de troca.',
    ],
    [
      'Quando começo a usar e a receber do pool?',
      'Deixar claro o marco: a partir da assinatura da troca, o uso e a '
          'participação no pool começam (conforme as regras do pool).',
    ],
  ];

  // (item a entender, nota).
  static const List<List<String>> _aEntender = [
    [
      'Documentação p/ o hotel virar multipropriedade',
      'Instituição do regime de multipropriedade (Lei 13.777/2018), convenção, '
          'matrícula/averbação. CONFIRMAR com jurídico/cartório o que é exigido.',
    ],
    [
      'Regras do pool de hospedagem',
      'Adesão, forma de distribuição da receita, periodicidade, custos '
          'descontados, prazo de permanência e regras de saída.',
    ],
    [
      'Prestação de contas',
      'Como e com que frequência o proprietário recebe o relatório de '
          'ocupação/receita; transparência e comprovação.',
    ],
    [
      'Capacidade x nº de contratos',
      'Conferir se o hotel comporta todos os contratos a migrar (apartamentos '
          'disponíveis vs contratos ativos por categoria).',
    ],
    [
      'Tributação da renda do pool',
      'IR sobre os rendimentos, emissão de notas e responsabilidades — alinhar '
          'com a contabilidade.',
    ],
    [
      'Cronograma e responsáveis',
      'Definir fases, datas e quem conduz cada etapa (comercial, jurídico, '
          'operação).',
    ],
  ];

  // ── Aba: Reynaldo (distratos + vendas + payback do aporte de R$ 2M) ───────
  String _mesesTexto(int m) {
    final anos = m ~/ 12;
    final meses = m % 12;
    if (anos == 0) return '$meses ${meses == 1 ? 'mês' : 'meses'}';
    if (meses == 0) return '$anos ${anos == 1 ? 'ano' : 'anos'}';
    return '$anos ${anos == 1 ? 'ano' : 'anos'} e $meses '
        '${meses == 1 ? 'mês' : 'meses'}';
  }

  Widget _tabReynaldo(ColorScheme cs) {
    final base = _baseDistrato;
    final desist = _parse(_reyDesistCtrl, 40) / 100;
    final distPrazo = _parse(_reyDistPrazoCtrl, 48);
    final vendaMes = _parse(_reyVendaMesCtrl, 400000);
    final entradaPct = _parse(_reyEntradaCtrl, 10) / 100;
    final vendaPrazo = _parse(_reyVendaPrazoCtrl, 60);
    final resort = _parse(_reyResortCtrl, 300000);
    final aporte = _parse(_reyAporteCtrl, 2000000);
    final poolMes = _parse(_reyPoolMesCtrl, 50000);
    final poolInicio = _parse(_reyPoolInicioCtrl, 12);
    final share = _parse(_reyShareVendasCtrl, 100) / 100;

    // ── Distratos ──
    final totalDistrato = base * desist;
    final distParcela =
        distPrazo > 0 ? totalDistrato / distPrazo : totalDistrato;
    final resortSobra = resort - distParcela;

    // ── Vendas ──
    final entradaMes = vendaMes * entradaPct;
    final parcelaSafra =
        vendaPrazo > 0 ? vendaMes * (1 - entradaPct) / vendaPrazo : 0.0;

    // ── Simulação mês a mês do retorno do Reynaldo ──
    double cum = 0, cumVendas = 0;
    int? payback;
    const marcosMes = [6, 12, 18, 24, 36, 48, 60];
    final marcos = <int, double>{};
    for (int m = 1; m <= 240; m++) {
      final vintages = (m - 1).clamp(0, vendaPrazo.toInt());
      final vendasCash = entradaMes + parcelaSafra * vintages;
      final pool = m >= poolInicio ? poolMes : 0.0;
      final repayVendas = vendasCash * share;
      cumVendas += repayVendas;
      cum += repayVendas + pool;
      if (payback == null && cum >= aporte) payback = m;
      if (marcosMes.contains(m)) marcos[m] = cum;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Proposta de investimento — Reynaldo',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: cs.primary)),
        const SizedBox(height: 4),
        Text(
          'Aporte de ${_moeda.format(aporte)} para finalizar as obras e os '
          'novos apartamentos da transição. Retorno projetado pelas vendas + '
          '15% do pool. Os distratos e as contas são bancados pelo aporte '
          'mensal do resort.',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 16),

        // ── Payback (destaque) ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reynaldo recupera o aporte em',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              Text(payback == null ? '> 240 meses' : _mesesTexto(payback),
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: cs.primary)),
              if (payback != null)
                Text('$payback meses — devolvendo ${_moeda.format(aporte)} '
                    'com vendas + 15% do pool',
                    style:
                        TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              if (payback != null) ...[
                const Divider(height: 20),
                _linhaInfo('Vindo das vendas (até o payback)',
                    _moeda.format(cumVendas.clamp(0, aporte)), cs),
                _linhaInfo('Vindo do pool 15% (até o payback)',
                    _moeda.format((aporte - cumVendas).clamp(0, aporte)), cs),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Parâmetros ──
        Text('Distratos',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _campoNum('% desistência', _reyDesistCtrl, sufixo: '%'),
          _campoNum('Parcelas distrato', _reyDistPrazoCtrl, sufixo: ''),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.red.shade700.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade700.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _linhaInfo('Base paga (ativos, excl. Matheus/Reynaldo)',
                  _moeda.format(base), cs),
              _linhaInfo(
                  'Total a devolver (${(desist * 100).toStringAsFixed(0)}%)',
                  _moeda.format(totalDistrato),
                  cs),
              _linhaInfo(
                  'Parcela do distrato (${distPrazo.toStringAsFixed(0)}×)',
                  '${_moeda.format(distParcela)}/mês',
                  cs),
              const Divider(height: 18),
              _linhaInfo('Aporte do resort/mês', _moeda.format(resort), cs),
              _linhaInfo(
                  resortSobra >= 0
                      ? 'Sobra p/ outras contas'
                      : 'Falta (resort não cobre)',
                  '${_moeda.format(resortSobra)}/mês',
                  cs),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text('Vendas',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _campoNum('Venda / mês', _reyVendaMesCtrl, sufixo: 'R\$'),
          _campoNum('Entrada', _reyEntradaCtrl, sufixo: '%'),
          _campoNum('Parcelas venda', _reyVendaPrazoCtrl, sufixo: ''),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.green.shade700.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: Colors.green.shade700.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _linhaInfo('Entrada recebida/mês (à vista)',
                  _moeda.format(entradaMes), cs),
              _linhaInfo('Parcela por safra de venda',
                  '${_moeda.format(parcelaSafra)}/mês × ${vendaPrazo.toStringAsFixed(0)}',
                  cs),
              _linhaInfo('Caixa de vendas em regime (cheio)',
                  '${_moeda.format(vendaMes)}/mês', cs),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text('Retorno ao Reynaldo',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _campoNum('Aporte Reynaldo', _reyAporteCtrl, sufixo: 'R\$'),
          _campoNum('% vendas p/ retorno', _reyShareVendasCtrl, sufixo: '%'),
          _campoNum('Pool 15% / mês', _reyPoolMesCtrl, sufixo: 'R\$'),
          _campoNum('Mês início do pool', _reyPoolInicioCtrl, sufixo: ''),
        ]),
        const SizedBox(height: 12),
        Text('Acumulado devolvido ao Reynaldo',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Table(
            border: TableBorder.symmetric(
                inside: BorderSide(color: cs.outlineVariant)),
            columnWidths: const {0: FlexColumnWidth(0.8)},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: BoxDecoration(color: cs.surfaceContainerHighest),
                children: [
                  _celReynaldo(cs, 'Mês', cabecalho: true),
                  _celReynaldo(cs, 'Acumulado', cabecalho: true),
                  _celReynaldo(cs, '% do aporte', cabecalho: true),
                ],
              ),
              for (final m in marcosMes)
                TableRow(children: [
                  _celReynaldo(cs, '$m'),
                  _celReynaldo(cs, _moeda.format(marcos[m] ?? 0)),
                  _celReynaldo(
                      cs,
                      aporte > 0
                          ? '${((marcos[m] ?? 0) / aporte * 100).clamp(0, 100).toStringAsFixed(0)}%'
                          : '—',
                      destaque: true,
                      cor: (marcos[m] ?? 0) >= aporte
                          ? Colors.green.shade700
                          : cs.primary),
                ]),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Modelo: distratos = base paga (excl. Matheus/Reynaldo) × % '
            'desistência, em N parcelas, bancados pelo resort. Vendas = entrada '
            'à vista + parcelas que se acumulam mês a mês (safras). Retorno ao '
            'Reynaldo = % do caixa de vendas + 15% do pool (a partir do mês de '
            'início), até quitar o aporte. Ajuste os campos com os números '
            'reais.',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _celReynaldo(ColorScheme cs, String txt,
      {bool cabecalho = false, bool destaque = false, Color? cor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(txt,
          style: TextStyle(
              fontSize: cabecalho ? 11 : 12,
              fontWeight:
                  cabecalho || destaque ? FontWeight.w700 : FontWeight.w500,
              color: cabecalho ? cs.onSurfaceVariant : cor)),
    );
  }

  Widget _tabPlano(ColorScheme cs) {
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
              Icon(Icons.flag_outlined, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Plano para uma transição mais segura do resort (em obras) '
                  'para o hotel (em operação). Documento vivo — vamos '
                  'evoluindo.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Icon(Icons.rocket_launch_outlined, color: cs.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Estratégias para uma transição segura',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 8),
        for (final e in _estrategias) _cardTituloDesc(cs, e[0], e[1], cs.primary),
        const SizedBox(height: 20),
        Row(children: [
          Icon(Icons.help_outline, color: Colors.orange.shade800),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Prováveis perguntas dos clientes',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 8),
        for (final q in _perguntasClientes) _objecaoTile(cs, q[0], q[1]),
        const SizedBox(height: 20),
        Row(children: [
          Icon(Icons.fact_check_outlined, color: Colors.teal.shade700),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('A entender / pendências',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 8),
        for (final it in _aEntender)
          _cardTituloDesc(cs, it[0], it[1], Colors.teal.shade700,
              icone: Icons.radio_button_unchecked),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Itens jurídicos, fiscais e cartoriais devem ser confirmados com '
            'advogado e contador antes de comunicar aos clientes.',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _cardTituloDesc(
      ColorScheme cs, String titulo, String desc, Color cor,
      {IconData icone = Icons.check_circle_outline}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cor.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: cor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(desc,
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Aba: Pool de hospedagem (simulação de renda) ──────────────────────────
  Widget _tabPool(ColorScheme cs) {
    final hotel = _parse(_hotelCtrl, 100);
    final pool = _parse(_poolCtrl, 30);
    final diaria = _parse(_diariaCtrl, 550);
    final taxa = _parse(_taxaCtrl, 15) / 100.0; // fração
    const diasMes = 30.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Simulação do pool de hospedagem',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: cs.primary)),
        const SizedBox(height: 4),
        Text(
          'Estima quanto cada apartamento do pool pode render, no cenário atual '
          'do hotel em operação. Ajuste os valores abaixo.',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        // ── Parâmetros editáveis ──
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _campoNum('Aptos no hotel', _hotelCtrl, sufixo: ''),
            _campoNum('Aptos no pool', _poolCtrl, sufixo: ''),
            _campoNum('Diária média', _diariaCtrl, sufixo: 'R\$'),
            _campoNum('Taxa administração', _taxaCtrl, sufixo: '%'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '$pool de ${hotel.toStringAsFixed(0)} apartamentos no pool · '
          'diária ${_moeda.format(diaria)} · administração '
          '${(taxa * 100).toStringAsFixed(0)}%',
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        // ── Cenários de ocupação ──
        for (final occ in _ocupacoes) ...[
          _cardPool(cs, occ, pool, diaria, taxa, diasMes),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        _secaoTemporada(cs, taxa),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Como calcula: no pool, a receita é somada e dividida igualmente '
            'entre os apartamentos participantes — cada um recebe pela ocupação '
            'MÉDIA, não só pela própria. Ganho/apto no mês = 30 × ocupação × '
            'diária × (1 − taxa). "Diária média" e "taxa de administração" são '
            'estimativas — ajuste com os números reais do hotel.',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _campoNum(String label, TextEditingController ctrl, {String sufixo = ''}) {
    return SizedBox(
      width: 160,
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          prefixText: sufixo == 'R\$' ? 'R\$ ' : null,
          suffixText: sufixo == '%' ? '%' : null,
        ),
      ),
    );
  }

  Widget _cardPool(ColorScheme cs, double occ, double pool, double diaria,
      double taxa, double diasMes) {
    // Ganho por apartamento (o tamanho do pool não altera o ganho POR apto,
    // pois a receita escala com o pool e é dividida pelo pool).
    final ganhoAptoMes = diasMes * occ * diaria * (1 - taxa);
    final ganhoAptoAno = ganhoAptoMes * 12;
    // Totais do pool (todos os apartamentos participantes juntos).
    final brutoPoolMes = pool * diasMes * occ * diaria;
    final liquidoPoolMes = brutoPoolMes * (1 - taxa);

    final pct = (occ * 100).toStringAsFixed(0);
    final cor = occ >= 1.0
        ? Colors.green.shade700
        : (occ >= 0.7 ? Colors.teal.shade700 : cs.primary);

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
          Row(
            children: [
              Icon(Icons.hotel_outlined, size: 18, color: cor),
              const SizedBox(width: 8),
              Text('Ocupação $pct%',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold, color: cor)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Por apartamento / mês',
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant)),
                    Text(_moeda.format(ganhoAptoMes),
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: cor)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Por apartamento / ano',
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant)),
                    Text(_moeda.format(ganhoAptoAno),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _linhaInfo('Receita bruta do pool / mês',
              _moeda.format(brutoPoolMes), cs),
          _linhaInfo('Receita líquida do pool / mês',
              _moeda.format(liquidoPoolMes), cs),
          _linhaInfo('Diárias ocupadas / mês (pool)',
              (pool * diasMes * occ).toStringAsFixed(0), cs),
        ],
      ),
    );
  }

  static final _moeda2 =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ', decimalDigits: 2);

  // ── Aba: Condomínio (rateio do custo mensal por estilo de cota) ────────────
  Widget _tabCondominio(ColorScheme cs) {
    final custo = _custoMensal;
    final aptos = _parse(_hotelCtrl, 100);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Rateio do condomínio por cota',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: cs.primary)),
        const SizedBox(height: 4),
        Text(
          'Cenário negativo: os apartamentos de multipropriedade absorvem o '
          'custo mensal do hotel. Projetado com a MP em 50% e em 100% do hotel '
          '— quanto menos aptos MP, mais cada um (e cada cota) paga.',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        _composicaoCusto(cs, custo),
        const SizedBox(height: 14),
        _campoNum('Aptos no hotel', _hotelCtrl, sufixo: ''),
        const SizedBox(height: 14),
        for (final cen in _cenariosMP) ...[
          _cenarioCondo(cs, cen.$1, aptos * cen.$2, custo),
          const SizedBox(height: 16),
        ],
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Como calcula: custo mensal ÷ nº de aptos de multipropriedade = '
            'condomínio por apartamento. Cada cota paga a sua fração: Bronze '
            '1/52, Prata 1/26, Ouro 1/13, Diamante/Integral o apartamento '
            'inteiro. Cenário negativo assume que só os aptos MP cobrem o custo '
            'do hotel (por isso 50% dobra o valor por apto). Anual = mensal × 12 '
            '(referência). Ajuste custo e nº de aptos com os números reais.',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  /// Bloco de um cenário de condomínio (MP em 50% ou 100% do hotel).
  Widget _cenarioCondo(
      ColorScheme cs, String titulo, double aptosMP, double custo) {
    final condoApto = aptosMP > 0 ? custo / aptosMP : 0.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.apartment_rounded, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(titulo,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: cs.primary)),
            ),
          ]),
          const SizedBox(height: 8),
          Text('${_moeda.format(condoApto)} / apto / mês',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: cs.primary)),
          Text('${aptosMP.toStringAsFixed(0)} aptos MP  ·  '
              '${_moeda.format(condoApto * 12)} / apto / ano',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          for (final t in _tiers) ...[
            _cardCondoTier(cs, t.$1, t.$2, t.$3, condoApto),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  /// Composição editável do custo mensal do hotel (soma dos itens).
  Widget _composicaoCusto(ColorScheme cs, double total) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.receipt_long_outlined, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            const Text('Composição do custo mensal',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 4),
          Text('Some os custos reais do hotel. O total abaixo alimenta o '
              'rateio e a aba Ganhos.',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final l in _linhasCusto)
                _campoNum(l.$1, l.$2, sufixo: 'R\$'),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Custo mensal total',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              Text(_moeda.format(total),
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: cs.primary)),
            ],
          ),
          Text('${_moeda.format(total * 12)} / ano',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _cardCondoTier(
      ColorScheme cs, String rotulo, int divisor, Color cor, double condoApto) {
    final mes = condoApto / divisor;
    final ano = mes * 12;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rotulo,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: cor)),
                Text(divisor == 1 ? 'apartamento inteiro' : '1/$divisor do apto',
                    style:
                        TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_moeda2.format(mes)} / mês',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold, color: cor)),
              Text('${_moeda2.format(ano)} / ano',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Aba: Ganhos do dono (renda do pool − condomínio) ──────────────────────
  Widget _tabGanhos(ColorScheme cs) {
    final taxa = _parse(_taxaCtrl, 15) / 100.0;
    final aptos = _parse(_hotelCtrl, 100);
    final pool = _parse(_poolCtrl, 30);
    final custo = _custoMensal;
    final liqAnual = _liqAnualApto(taxa);
    final feeApto = _brutoAnualApto() * taxa; // taxa do pool / apto / ano
    final minPago = _parse(_minPagoCtrl, 30);
    final elegiveis = _pctPagos.where((p) => p >= minPago).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Ganhos do dono do empreendimento',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: cs.primary)),
        const SizedBox(height: 4),
        Text(
          'Ótica de quem é dono de tudo e vai vender os apartamentos: '
          '(1) receita de venda das cotas, (2) taxa do pool e (3) resultado '
          'operacional dos apartamentos que ainda são seus.',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _campoNum('Taxa do pool', _taxaCtrl, sufixo: '%'),
            _campoNum('Aptos no hotel', _hotelCtrl, sufixo: ''),
            _campoNum('Aptos no pool', _poolCtrl, sufixo: ''),
            _campoNum('Entrada mín. p/ pool', _minPagoCtrl, sufixo: '%'),
          ],
        ),
        const SizedBox(height: 6),
        Text('Diária e ocupação das temporadas: aba Pool. '
            'Custo do hotel: ${_moeda.format(custo)}/mês (aba Condomínio). '
            'Entrada da cota ≥ ${minPago.toStringAsFixed(0)}% para entrar no '
            'pool: $elegiveis de $_ativosCount contratos ativos elegíveis.',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        const SizedBox(height: 18),

        // ── 1. Venda das cotas ──
        _tituloSecao(cs, '1. Venda das cotas', Icons.sell_outlined),
        const SizedBox(height: 8),
        _secaoVenda(cs),
        const SizedBox(height: 20),

        // ── 2. Taxa do pool ──
        _tituloSecao(cs,
            '2. Taxa do pool (${(taxa * 100).toStringAsFixed(0)}%)',
            Icons.percent_rounded),
        const SizedBox(height: 8),
        _secaoTaxaPool(cs, feeApto, pool),
        const SizedBox(height: 20),

        // ── 3. Resultado operacional ──
        _tituloSecao(
            cs, '3. Resultado operacional (aptos do dono)', Icons.trending_up),
        const SizedBox(height: 4),
        Text(
          'Nos apartamentos que ainda são do dono e entram no pool: renda '
          'líquida do pool − condomínio. Projetado com a MP em 50% e 100% do '
          'hotel (muda o condomínio/apto).',
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        for (final cen in _cenariosMP) ...[
          _cardResultadoOp(
              cs, cen.$1, aptos * cen.$2 > 0 ? custo / (aptos * cen.$2) : 0.0,
              liqAnual),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _tituloSecao(ColorScheme cs, String titulo, IconData icone) {
    return Row(children: [
      Icon(icone, size: 18, color: cs.primary),
      const SizedBox(width: 6),
      Expanded(
        child: Text(titulo,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      ),
    ]);
  }

  /// Seção 1: receita de venda das cotas (dono do empreendimento).
  Widget _secaoVenda(ColorScheme cs) {
    final pb = _parse(_precoBronzeCtrl, 0);
    final pp = _parse(_precoPrataCtrl, 0);
    final po = _parse(_precoOuroCtrl, 0);
    final pd = _parse(_precoDiamanteCtrl, 0);
    // Valor de um apartamento vendido cheio, por tier.
    final aptoBronze = 52 * pb;
    final aptoPrata = 26 * pp;
    final aptoOuro = 13 * po;
    // Receita já vendida (cotas vendidas × preço).
    final (cb, cp, co, cd) = _cotasVendidasPorTier();
    final vendidoBronze = cb * pb;
    final vendidoPrata = cp * pp;
    final vendidoOuro = co * po;
    final vendidoDiamante = cd * pd;
    final totalVendido =
        vendidoBronze + vendidoPrata + vendidoOuro + vendidoDiamante;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Preço de venda por cota',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _campoNum('Bronze', _precoBronzeCtrl, sufixo: 'R\$'),
              _campoNum('Prata', _precoPrataCtrl, sufixo: 'R\$'),
              _campoNum('Ouro', _precoOuroCtrl, sufixo: 'R\$'),
              _campoNum('Diamante', _precoDiamanteCtrl, sufixo: 'R\$'),
            ],
          ),
          const Divider(height: 24),
          Text('Apartamento vendido cheio (por tier)',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          _linhaInfo('Bronze (52 cotas)', _moeda.format(aptoBronze), cs),
          _linhaInfo('Prata (26 cotas)', _moeda.format(aptoPrata), cs),
          _linhaInfo('Ouro (13 cotas)', _moeda.format(aptoOuro), cs),
          _linhaInfo('Diamante (inteiro)', _moeda.format(pd), cs),
          const Divider(height: 24),
          Text('Receita já vendida (cotas ativas × preço)',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          _linhaInfo('Bronze ($cb cotas)', _moeda.format(vendidoBronze), cs),
          _linhaInfo('Prata ($cp cotas)', _moeda.format(vendidoPrata), cs),
          _linhaInfo('Ouro ($co cotas)', _moeda.format(vendidoOuro), cs),
          _linhaInfo(
              'Diamante/Integral ($cd)', _moeda.format(vendidoDiamante), cs),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total vendido em cotas',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text(_moeda.format(totalVendido),
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: cs.primary)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text('Preços default = média real por tier dos contratos ativos, '
              'exceto Matheus Camelo (Bronze R\$ 33.645 · Prata R\$ 58.455 · '
              'Ouro R\$ 124.008 · Diamante R\$ 1.399.759). Edite para simular '
              'outro preço.',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  /// Seção 2: taxa do pool que fica com o dono (renda recorrente).
  Widget _secaoTaxaPool(ColorScheme cs, double feeApto, double pool) {
    final feeTotal = feeApto * pool;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.teal.shade700.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.teal.shade700.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('O dono administra o pool e retém a taxa sobre a receita de '
              'hospedagem.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const SizedBox(height: 10),
          _linhaInfo('Taxa / apartamento / ano', _moeda.format(feeApto), cs),
          _linhaInfo('Apartamentos no pool', pool.toStringAsFixed(0), cs),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Taxa do pool / ano (total)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Text(_moeda.format(feeTotal),
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700)),
            ],
          ),
        ],
      ),
    );
  }

  /// Seção 3: resultado operacional dos apartamentos do dono (pool − condomínio).
  Widget _cardResultadoOp(
      ColorScheme cs, String titulo, double condoApto, double liqAnual) {
    final condoAno = condoApto * 12;
    final resultado = liqAnual - condoAno;
    final positivo = resultado >= 0;
    final cor = positivo ? Colors.green.shade700 : Colors.red.shade700;
    return Container(
      padding: const EdgeInsets.all(14),
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
                  fontSize: 13, fontWeight: FontWeight.w800, color: cor)),
          const SizedBox(height: 8),
          Text('${_moeda.format(resultado)} / apto / ano',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: cor)),
          const Divider(height: 20),
          _linhaInfo(
              'Renda líquida do pool / apto / ano', _moeda.format(liqAnual), cs),
          _linhaInfo('Condomínio / apto / ano', '− ${_moeda.format(condoAno)}',
              cs),
        ],
      ),
    );
  }

  // ── Aba: Comprador (quem compra a cota financiada — alavancagem) ───────────
  Widget _tabComprador(ColorScheme cs) {
    final valor = _parse(_valorCotaCtrl, 116380);
    final entrada = _parse(_entradaCompraCtrl, 0) / 100.0;
    final n = _parse(_prazoCtrl, 120);
    final i = _parse(_jurosCtrl, 0.68) / 100.0;
    final financiado = valor * (1 - entrada);
    final amortizacao = n > 0 ? financiado / n : financiado;
    final jurosMes1 = financiado * i;
    final parcelaInicial = amortizacao + jurosMes1; // SAC: 1ª (maior) parcela
    final yields = [
      _parse(_yieldACtrl, 6),
      _parse(_yieldBCtrl, 8),
      _parse(_yieldCCtrl, 10),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Visão do comprador (cota financiada)',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: cs.primary)),
        const SizedBox(height: 4),
        Text(
          'Para quem compra a cota financiada: o hotel repassa o rendimento '
          '(yield) e a dívida cobra a parcela. O desembolso real do bolso é a '
          'parcela menos o repasse — conforme o desempenho do hotel.',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _campoNum('Valor da cota', _valorCotaCtrl, sufixo: 'R\$'),
            _campoNum('Entrada', _entradaCompraCtrl, sufixo: '%'),
            _campoNum('Prazo (meses)', _prazoCtrl, sufixo: ''),
            _campoNum('Juros a.m.', _jurosCtrl, sufixo: '%'),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _linhaInfo('Valor financiado', _moeda.format(financiado), cs),
              _linhaInfo(
                  'Parcela inicial (SAC, mês 1)',
                  _moeda2.format(parcelaInicial),
                  cs),
              Text('SAC: a parcela cai a cada mês (a inicial é a maior). '
                  'Amortização ${_moeda2.format(amortizacao)} + juros '
                  '${_moeda2.format(jurosMes1)}.',
                  style:
                      TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text('Desempenho do hotel (yield líquido a.a.)',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _campoNum('Yield fraco', _yieldACtrl, sufixo: '%'),
            _campoNum('Yield médio', _yieldBCtrl, sufixo: '%'),
            _campoNum('Yield ótimo', _yieldCCtrl, sufixo: '%'),
          ],
        ),
        const SizedBox(height: 14),
        for (final y in yields) ...[
          _cardComprador(cs, y, valor, parcelaInicial),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        _tituloSecao(cs, 'Retorno real por tier (ROI)', Icons.percent_rounded),
        const SizedBox(height: 4),
        Text(
          'Ganho anual do pool sobre o valor investido. Como o comprador paga '
          'só a entrada de ${_parse(_minPagoCtrl, 30).toStringAsFixed(0)}% e já '
          'recebe o repasse, o ROI sobre a entrada (capital que ele realmente '
          'pôs) é bem maior que sobre o valor total. Edite o preço da cota e a '
          'entrada abaixo.',
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _campoNum('Bronze', _precoBronzeCtrl, sufixo: 'R\$'),
            _campoNum('Prata', _precoPrataCtrl, sufixo: 'R\$'),
            _campoNum('Ouro', _precoOuroCtrl, sufixo: 'R\$'),
            _campoNum('Diamante', _precoDiamanteCtrl, sufixo: 'R\$'),
            _campoNum('Entrada', _minPagoCtrl, sufixo: '%'),
          ],
        ),
        const SizedBox(height: 12),
        Text('ROI bruto (pool)',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        _tabelaRoi(cs, liquido: false),
        const SizedBox(height: 12),
        Text('ROI líquido (− condomínio)',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        _tabelaRoi(cs, liquido: true),
        const SizedBox(height: 16),
        _tituloSecao(cs, 'Fluxo de caixa líquido / mês (mês 1)',
            Icons.account_balance_wallet_outlined),
        const SizedBox(height: 4),
        Text(
          'Junta tudo pelo tier: repasse do pool − parcela da dívida (SAC, '
          'mês 1) − condomínio. Usa o preço, a entrada, o prazo e os juros '
          'acima. No SAC a parcela cai com o tempo, então o fluxo melhora nos '
          'meses seguintes.',
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        _tabelaFluxo(cs),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Como calcula: repasse do hotel/mês = valor da cota × yield ÷ 12. '
            'Desembolso real/mês = parcela inicial − repasse. Veredito pela '
            'cobertura (repasse ÷ parcela): abaixo de 40% o custo da dívida '
            'domina; acima de 55% a alavancagem compensa. Valores do mês 1 '
            '(no SAC a parcela diminui, então o desembolso melhora com o tempo).',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _cardComprador(
      ColorScheme cs, double yieldPct, double valor, double parcela) {
    final repasse = valor * (yieldPct / 100.0) / 12.0;
    final desembolso = parcela - repasse;
    final cobertura = parcela > 0 ? repasse / parcela : 0.0;

    late final Color cor;
    late final String veredito;
    late final IconData ic;
    if (cobertura < 0.40) {
      cor = Colors.red.shade700;
      veredito = 'Furada — o custo da dívida supera o repasse.';
      ic = Icons.trending_down;
    } else if (cobertura < 0.55) {
      cor = Colors.orange.shade800;
      veredito = 'Neutro — vale se focar na valorização do imóvel.';
      ic = Icons.trending_flat;
    } else {
      cor = Colors.green.shade700;
      veredito = 'Excelente — forte alavancagem de patrimônio.';
      ic = Icons.trending_up;
    }

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
          Row(children: [
            Icon(ic, size: 18, color: cor),
            const SizedBox(width: 8),
            Text('Yield ${yieldPct.toStringAsFixed(0)}% a.a.',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: cor)),
          ]),
          const SizedBox(height: 10),
          Text('Desembolso real / mês',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          Text(_moeda2.format(desembolso),
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: cor)),
          const Divider(height: 20),
          _linhaInfo('Repasse do hotel (mês 1)', _moeda2.format(repasse), cs),
          _linhaInfo('Parcela da dívida (mês 1)', _moeda2.format(parcela), cs),
          _linhaInfo('Cobertura (repasse ÷ parcela)',
              '${(cobertura * 100).toStringAsFixed(0)}%', cs),
          const SizedBox(height: 6),
          Text(veredito,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: cor)),
        ],
      ),
    );
  }

  /// Tabela de ROI por tier. [liquido] desconta o condomínio do ganho.
  /// Mostra o ROI sobre o valor total e sobre a entrada (capital investido).
  Widget _tabelaRoi(ColorScheme cs, {required bool liquido}) {
    final taxa = _parse(_taxaCtrl, 15) / 100.0;
    // Receita líquida de uma semana em cada temporada.
    final valA = _temporadas.isNotEmpty
        ? 7 *
            (_parse(_temporadas[0].$4, 0) / 100) *
            _parse(_temporadas[0].$3, 0) *
            (1 - taxa)
        : 0.0;
    final valM = _temporadas.length > 1
        ? 7 *
            (_parse(_temporadas[1].$4, 0) / 100) *
            _parse(_temporadas[1].$3, 0) *
            (1 - taxa)
        : 0.0;
    final liqAnual = _liqAnualApto(taxa);
    // Condomínio anual por apartamento (MP 100% do hotel).
    final aptos = _parse(_hotelCtrl, 100);
    final condoAptoAno = aptos > 0 ? (_custoMensal / aptos) * 12 : 0.0;
    final entrada = _parse(_minPagoCtrl, 30) / 100.0;

    // (rótulo, ganho bruto do pool, preço, divisor do condomínio).
    final tiers = <(String, double, double, int)>[
      ('Bronze', (valA + valM) / 2, _parse(_precoBronzeCtrl, 0), 52),
      ('Prata', valA + valM, _parse(_precoPrataCtrl, 0), 26),
      ('Ouro', 2 * (valA + valM), _parse(_precoOuroCtrl, 0), 13),
      ('Diamante', liqAnual, _parse(_precoDiamanteCtrl, 0), 1),
    ];

    Widget cel(String txt,
            {bool cabecalho = false, bool destaque = false, Color? cor}) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Text(txt,
              style: TextStyle(
                  fontSize: cabecalho ? 10.5 : 11.5,
                  fontWeight: cabecalho || destaque
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: cabecalho ? cs.onSurfaceVariant : cor)),
        );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        border: TableBorder.symmetric(
            inside: BorderSide(color: cs.outlineVariant)),
        columnWidths: const {0: FlexColumnWidth(0.8)},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(color: cs.surfaceContainerHighest),
            children: [
              cel('Cota', cabecalho: true),
              cel('Preço', cabecalho: true),
              cel('Ganho/ano', cabecalho: true),
              cel('ROI total', cabecalho: true),
              cel('ROI entrada', cabecalho: true),
            ],
          ),
          for (final t in tiers)
            _linhaRoi(cs, t.$1, t.$2, t.$3, t.$4, condoAptoAno, entrada,
                liquido, cel),
        ],
      ),
    );
  }

  TableRow _linhaRoi(
      ColorScheme cs,
      String rotulo,
      double ganhoBruto,
      double preco,
      int divisorCondo,
      double condoAptoAno,
      double entrada,
      bool liquido,
      Widget Function(String, {bool cabecalho, bool destaque, Color? cor}) cel) {
    final condoCota = condoAptoAno / divisorCondo;
    final ganho = liquido ? ganhoBruto - condoCota : ganhoBruto;
    final roiTotal = preco > 0 ? ganho / preco * 100 : 0.0;
    final capitalEntrada = preco * entrada;
    final roiEntrada = capitalEntrada > 0 ? ganho / capitalEntrada * 100 : 0.0;
    return TableRow(children: [
      cel(rotulo, destaque: true),
      cel(_moeda.format(preco)),
      cel(_moeda.format(ganho)),
      cel(preco > 0 ? '${roiTotal.toStringAsFixed(1)}%' : '—'),
      cel(capitalEntrada > 0 ? '${roiEntrada.toStringAsFixed(1)}%' : '—',
          destaque: true, cor: cs.primary),
    ]);
  }

  /// Fluxo de caixa líquido mensal por tier (mês 1): repasse − parcela SAC −
  /// condomínio, usando preço, entrada, prazo e juros da aba Comprador.
  Widget _tabelaFluxo(ColorScheme cs) {
    final taxa = _parse(_taxaCtrl, 15) / 100.0;
    final valA = _temporadas.isNotEmpty
        ? 7 *
            (_parse(_temporadas[0].$4, 0) / 100) *
            _parse(_temporadas[0].$3, 0) *
            (1 - taxa)
        : 0.0;
    final valM = _temporadas.length > 1
        ? 7 *
            (_parse(_temporadas[1].$4, 0) / 100) *
            _parse(_temporadas[1].$3, 0) *
            (1 - taxa)
        : 0.0;
    final liqAnual = _liqAnualApto(taxa);
    final aptos = _parse(_hotelCtrl, 100);
    final condoAptoMes = aptos > 0 ? _custoMensal / aptos : 0.0;
    final entrada = _parse(_minPagoCtrl, 30) / 100.0;
    final n = _parse(_prazoCtrl, 120);
    final i = _parse(_jurosCtrl, 0.68) / 100.0;

    // (rótulo, ganho bruto anual do pool, preço, divisor do condomínio).
    final tiers = <(String, double, double, int)>[
      ('Bronze', (valA + valM) / 2, _parse(_precoBronzeCtrl, 0), 52),
      ('Prata', valA + valM, _parse(_precoPrataCtrl, 0), 26),
      ('Ouro', 2 * (valA + valM), _parse(_precoOuroCtrl, 0), 13),
      ('Diamante', liqAnual, _parse(_precoDiamanteCtrl, 0), 1),
    ];

    Widget cel(String txt,
            {bool cabecalho = false, bool destaque = false, Color? cor}) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Text(txt,
              style: TextStyle(
                  fontSize: cabecalho ? 10.5 : 11.5,
                  fontWeight: cabecalho || destaque
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: cabecalho ? cs.onSurfaceVariant : cor)),
        );

    TableRow linha(String rotulo, double ganhoAno, double preco, int div) {
      final repasseMes = ganhoAno / 12;
      final condoMes = condoAptoMes / div;
      final financiado = preco * (1 - entrada);
      final parcela = n > 0 ? financiado / n + financiado * i : financiado;
      final fluxo = repasseMes - parcela - condoMes;
      final cor = fluxo >= 0 ? Colors.green.shade700 : Colors.red.shade700;
      return TableRow(children: [
        cel(rotulo, destaque: true),
        cel(_moeda.format(repasseMes)),
        cel('− ${_moeda.format(parcela)}'),
        cel('− ${_moeda.format(condoMes)}'),
        cel(_moeda.format(fluxo), destaque: true, cor: cor),
      ]);
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        border: TableBorder.symmetric(
            inside: BorderSide(color: cs.outlineVariant)),
        columnWidths: const {0: FlexColumnWidth(0.8)},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(color: cs.surfaceContainerHighest),
            children: [
              cel('Cota', cabecalho: true),
              cel('Repasse', cabecalho: true),
              cel('Parcela', cabecalho: true),
              cel('Condomínio', cabecalho: true),
              cel('Fluxo/mês', cabecalho: true),
            ],
          ),
          for (final t in tiers) linha(t.$1, t.$2, t.$3, t.$4),
        ],
      ),
    );
  }

  // ── Aba: Devoluções (exposição de quem não aceitar a transição) ───────────
  Widget _tabDevolucoes(ColorScheme cs) {
    final pct = _parse(_naoAceitaCtrl, 15) / 100.0;
    final total = _exposicaoDevolucao;
    final provavel = total * pct;
    const cenarios = [5.0, 10.0, 15.0, 20.0, 30.0, 50.0, 100.0];
    // Cenário judicial: base + correção/honorários, pago em parcelas.
    final acrescimo = _parse(_acrescimoCtrl, 20) / 100.0;
    final parcelas = _parse(_parcelasCtrl, 12);
    final baseJudicial = provavel * (1 + acrescimo);
    final valorParcela = parcelas > 0 ? baseJudicial / parcelas : baseJudicial;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Devoluções — quem não aceitar',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: cs.primary)),
        const SizedBox(height: 4),
        Text(
          'Estima quanto provavelmente teríamos que devolver aos donos que não '
          'aceitarem a transição — com base no valor que cada um já pagou.',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade700.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.shade700.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Exposição total (pior caso — 100% recusam)',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              Text(_moeda.format(total),
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700)),
              Text('Soma do valor já pago em $_ativosCount contratos ativos',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _campoNum('% que não aceita', _naoAceitaCtrl, sufixo: '%'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Provável a devolver (${(pct * 100).toStringAsFixed(0)}%)',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              Text(_moeda.format(provavel),
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: cs.primary)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Cenários',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            children: [
              for (var i = 0; i < cenarios.length; i++)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    border: i == cenarios.length - 1
                        ? null
                        : Border(
                            bottom: BorderSide(color: cs.outlineVariant)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${cenarios[i].toStringAsFixed(0)}% não aceitam',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(_moeda.format(total * cenarios[i] / 100),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: cenarios[i] >= 50
                                  ? Colors.red.shade700
                                  : cs.onSurface)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // ── Cenário judicial: pagamento parcelado ──
        Row(children: [
          Icon(Icons.gavel_rounded, size: 18, color: Colors.red.shade700),
          const SizedBox(width: 6),
          const Expanded(
            child: Text('Cenário judicial (pagamento parcelado)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          'Se o cliente entrar na justiça, além do valor pago costuma-se pagar '
          'correção monetária + honorários, e o acordo/sentença pode ser '
          'parcelado. Base: o provável a devolver (${(pct * 100).toStringAsFixed(0)}%).',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _campoNum('Correção + honorários', _acrescimoCtrl, sufixo: '%'),
            _campoNum('Nº de parcelas', _parcelasCtrl, sufixo: ''),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade700.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: Colors.red.shade700.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Valor da parcela (mensal)',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              Text(_moeda.format(valorParcela),
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700)),
              Text('× ${parcelas.toStringAsFixed(0)} parcelas',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              const Divider(height: 20),
              _linhaInfo('Provável a devolver (base)',
                  _moeda.format(provavel), cs),
              _linhaInfo(
                  'Acréscimo (${(acrescimo * 100).toStringAsFixed(0)}%)',
                  '+ ${_moeda.format(baseJudicial - provavel)}',
                  cs),
              _linhaInfo('Total com acréscimo (judicial)',
                  _moeda.format(baseJudicial), cs),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Base: soma do valor integralizado (já pago) de todos os contratos '
            'ativos. Assume devolução integral do que foi pago — o distrato real '
            'pode reter parte (multa/cláusula), reduzindo a devolução; já na via '
            'judicial tende a crescer (correção + honorários). O parcelamento '
            'dilui o desembolso no tempo (parcela mensal). Confirme os '
            'percentuais reais com o jurídico.',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  /// Seção da aba Pool: ganho por cota por temporada (alta/média/baixa).
  Widget _secaoTemporada(ColorScheme cs, double taxa) {
    // Receita líquida anual por apartamento em cada temporada.
    // líquida = semanas × 7 dias × ocupação × diária × (1 − taxa).
    final liqPorTemporada = <double>[];
    double totalSemanas = 0;
    for (final t in _temporadas) {
      final sem = _parse(t.$2, 0);
      final dia = _parse(t.$3, 0);
      final ocup = _parse(t.$4, 0) / 100.0;
      totalSemanas += sem;
      liqPorTemporada.add(sem * 7 * ocup * dia * (1 - taxa));
    }
    final liqTotal = liqPorTemporada.fold(0.0, (s, v) => s + v);
    // Receita líquida de UMA semana em cada temporada (base do revezamento).
    final valorSemana = <double>[];
    for (final t in _temporadas) {
      final dia = _parse(t.$3, 0);
      final ocup = _parse(t.$4, 0) / 100.0;
      valorSemana.add(7 * ocup * dia * (1 - taxa));
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.calendar_month_outlined, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            const Expanded(
              child: Text('Ganho por cota, por temporada',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Só o Bronze (1 semana) reveza — um ano em alta, outro em '
              'média. Prata (1 alta + 1 média) e Ouro (2 alta + 2 média) '
              'recebem as duas temporadas todo ano. Valores líquidos da taxa, '
              'antes do condomínio.',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          // ── Parâmetros por temporada ──
          for (final t in _temporadas) ...[
            Row(children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 6),
                decoration:
                    BoxDecoration(color: t.$5, shape: BoxShape.circle),
              ),
              Text(t.$1,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: t.$5)),
            ]),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _campoNum('Semanas', t.$2, sufixo: ''),
                _campoNum('Diária', t.$3, sufixo: 'R\$'),
                _campoNum('Ocupação', t.$4, sufixo: '%'),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (totalSemanas != 52)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '⚠ Soma das semanas = ${totalSemanas.toStringAsFixed(0)} '
                '(o ideal é 52).',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w600),
              ),
            ),
          // ── Receita líquida anual por apartamento ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Receita líquida / apartamento / ano',
                    style:
                        TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                Text(_moeda.format(liqTotal),
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: cs.primary)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('Ganho por cota (revezando alta / média)',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          _tabelaCotaTemporada(cs, valorSemana),
          const SizedBox(height: 10),
          // Diamante/Integral: apto inteiro, recebe todas as semanas todo ano.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4A6FA5).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: const Color(0xFF4A6FA5).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text('Diamante / Integral (apto inteiro, o ano todo)',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                Text('${_moeda.format(liqTotal)} / ano',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A6FA5))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bronze reveza (1 semana): num ano recebe a parte alta, no outro a '
            'parte média — "Recebe/ano" é a média do ciclo. Prata e Ouro têm '
            'composição fixa (alta + média) e recebem as duas todo ano. '
            'Diamante/Integral possui o apartamento inteiro.',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _tabelaCotaTemporada(ColorScheme cs, List<double> valorSemana) {
    final valAlta = valorSemana.isNotEmpty ? valorSemana[0] : 0.0;
    final valMedia = valorSemana.length > 1 ? valorSemana[1] : 0.0;

    // (rótulo, composição, semanas de alta, semanas de média, reveza?)
    final cotas = <(String, String, int, int, bool)>[
      ('Bronze', '1 sem · reveza', 1, 1, true),
      ('Prata', '1 alta + 1 média', 1, 1, false),
      ('Ouro', '2 alta + 2 média', 2, 2, false),
    ];

    Widget cel(String txt,
            {bool cabecalho = false, bool destaque = false, Color? cor}) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(txt,
              style: TextStyle(
                  fontSize: cabecalho ? 11 : 12,
                  fontWeight: cabecalho || destaque
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: cabecalho ? cs.onSurfaceVariant : cor)),
        );

    TableRow linhaCota(String rotulo, String comp, int semA, int semM,
        bool reveza) {
      final parteAlta = semA * valAlta;
      final parteMedia = semM * valMedia;
      final recebeAno =
          reveza ? (parteAlta + parteMedia) / 2 : parteAlta + parteMedia;
      return TableRow(children: [
        cel(rotulo, destaque: true),
        cel(comp),
        cel(_moeda.format(parteAlta)),
        cel(_moeda.format(parteMedia)),
        cel(_moeda.format(recebeAno), destaque: true, cor: cs.primary),
      ]);
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        border: TableBorder.symmetric(
            inside: BorderSide(color: cs.outlineVariant)),
        columnWidths: const {
          0: FlexColumnWidth(0.9),
          1: FlexColumnWidth(1.4),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(color: cs.surfaceContainerHighest),
            children: [
              cel('Cota', cabecalho: true),
              cel('Composição', cabecalho: true),
              cel('Alta', cabecalho: true),
              cel('Média', cabecalho: true),
              cel('Recebe/ano', cabecalho: true),
            ],
          ),
          for (final c in cotas) linhaCota(c.$1, c.$2, c.$3, c.$4, c.$5),
        ],
      ),
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
        Text(
            'Top 30 contratos ativos por valor pago — exceto clientes tratados '
            'à parte (Matheus / Reynaldo).',
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

  /// Card com o preço médio de venda por cota (média real, sem Matheus Camelo).
  Widget _cardPrecoMedio(ColorScheme cs) {
    final linhas = <(String, TextEditingController)>[
      ('Bronze', _precoBronzeCtrl),
      ('Prata', _precoPrataCtrl),
      ('Ouro', _precoOuroCtrl),
      ('Diamante', _precoDiamanteCtrl),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.sell_outlined, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            const Expanded(
              child: Text('Preço médio por cota (tabela)',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 2),
          Text('Média real dos contratos ativos (exceto Matheus Camelo). '
              'Editável na aba Ganhos.',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          for (final l in linhas)
            _linhaInfo(l.$1, _moeda.format(_parse(l.$2, 0)), cs),
        ],
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
