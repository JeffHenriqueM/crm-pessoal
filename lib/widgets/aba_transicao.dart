import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/contrato_model.dart';
import '../models/imovel_model.dart';
import '../models/versao_preco_hotel.dart';
import '../services/analise_imoveis.dart';
import '../services/argumentos_pdf.dart';
import '../services/firestore_service.dart';
import '../services/reynaldo_pdf.dart';

/// Define qual conjunto de abas o widget mostra.
/// - [transicao]: Apartamentos (vendas), Prioridade, Argumentos, Comprador,
///   Devoluções, Reynaldo, Plano.
/// - [hotel]: Apartamentos (categorias), Áreas, Pool, Condomínio, Ganhos.
enum ModoAba { transicao, hotel }

/// Widget base das telas "Transição" e "Hotel". Compartilha todo o estado
/// (contratos, temporadas, custos, preços) e escolhe as abas pelo [modo].
class AbaTransicao extends StatefulWidget {
  final ModoAba modo;
  final FirestoreService? firestoreService;
  const AbaTransicao({
    super.key,
    this.modo = ModoAba.transicao,
    this.firestoreService,
  });

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

/// Categoria editável da aba Multipropriedade (nome, cor e apartamentos).
/// Começa como cópia do layout do Hotel e é reorganizada livremente.
class _CategoriaMP {
  String nome;
  int cor; // ARGB (Color.toARGB32)
  List<int> aptos;
  _CategoriaMP({required this.nome, required this.cor, required this.aptos});

  Map<String, dynamic> toMap() =>
      {'nome': nome, 'cor': cor, 'aptos': aptos};

  factory _CategoriaMP.fromMap(Map<String, dynamic> m) => _CategoriaMP(
        nome: (m['nome'] as String?) ?? '',
        cor: (m['cor'] as num?)?.toInt() ?? 0xFF888888,
        aptos: ((m['aptos'] as List?) ?? const [])
            .whereType<num>()
            .map((e) => e.toInt())
            .toList(),
      );
}

/// Representa o estado consolidado de um sócio na aba Atualização da Transição.
class _SocioAtualizacaoItem {
  final String nome;
  final List<Contrato> contratos;
  final double totalPago;
  final int totalCotas;
  final List<String> produtos;
  final String status;
  final List<String> fases;
  final String negociacaoDistrato;
  final String observacoes;
  final DateTime? atualizadoEm;
  final String? atualizadoPorNome;
  final bool personalizado;

  const _SocioAtualizacaoItem({
    required this.nome,
    required this.contratos,
    required this.totalPago,
    required this.totalCotas,
    required this.produtos,
    required this.status,
    required this.fases,
    required this.negociacaoDistrato,
    required this.observacoes,
    required this.atualizadoEm,
    required this.atualizadoPorNome,
    required this.personalizado,
  });
}

class _AbaTransicaoState extends State<AbaTransicao> {
  late final FirestoreService _fs =
      widget.firestoreService ?? FirestoreService();
  bool _carregando = true; // carrega automaticamente ao abrir
  bool _carregado = false;
  Map<String, _LinhaStats> _stats = {}; // conta principal (sem os separados)
  // Clientes separados → estatísticas por linha (mostrados à parte).
  Map<String, Map<String, _LinhaStats>> _separados = {};
  // Top 30 contratos ativos por valor pago (integralizado).
  List<Contrato> _top30 = [];
  // Todos os contratos ativos carregados.
  List<Contrato> _contratos = [];
  // Argumentos de transição por sócio (aba Sócios do Hotel).
  Map<String, Map<String, dynamic>> _argumentosSociosHotel = {};
  String _buscaSocios = '';

  // Objeções personalizadas cadastradas pelo usuário (aba Argumentos).
  List<Map<String, dynamic>> _objecoesPersonalizadas = [];
  String _buscaObjecoes = '';

  // Atualizações de transição por sócio (aba Atualização da Transição).
  Map<String, Map<String, dynamic>> _atualizacoesSocios = {};
  String _buscaAtualizacoes = '';
  String _filtroStatusAtualizacao = 'Todos';
  String _filtroFaseAtualizacao = 'Todas';
  String _ordenacaoAtualizacoes = 'valorDesc';

  static final _moeda =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ', decimalDigits: 0);

  // ── Simulação do pool de hospedagem (aba Pool) ────────────────────────────
  final _hotelCtrl = TextEditingController(text: '100'); // aptos no hotel
  final _poolCtrl = TextEditingController(text: '30'); // aptos no pool
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
  // Renda vem do pool (temporadas); financiamento SAC por tier (preço + entrada).
  final _prazoCtrl = TextEditingController(text: '120'); // parcelas (meses)
  final _jurosCtrl = TextEditingController(text: '0.68'); // juros a.m. (%)

  /// Receita líquida anual do pool por apartamento (base temporadas).
  double _liqAnualApto(double taxa) {
    double s = 0;
    for (final t in _temporadas) {
      s += _parse(t.$2, 0) * 7 * (_parse(t.$4, 0) / 100.0) * _parse(t.$3, 0);
    }
    return s * (1 - taxa);
  }

  /// Receita BRUTA anual do pool por apartamento (antes da taxa).
  /// Diária média do hotel, ponderada pelas semanas de cada temporada.
  /// Fonte única para os cards de ocupação da aba Pool (antes era um campo
  /// "Diária média" separado, que divergia das temporadas).
  double _diariaMediaTemporadas() {
    double somaSemanas = 0, somaReceita = 0;
    for (final t in _temporadas) {
      final sem = _parse(t.$2, 0);
      somaSemanas += sem;
      somaReceita += sem * _parse(t.$3, 0);
    }
    return somaSemanas > 0 ? somaReceita / somaSemanas : 0.0;
  }

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

  // Cota definida manualmente por apartamento no Hotel (aba Cotas).
  // Chave = número do apto (String); valor = 'ouro' | 'prata' | 'bronze'.
  Map<String, String> _cotasHotel = {};

  // Dia de check-in definido por apartamento no Hotel (aba Cotas).
  // Chave = número do apto (String); valor = 'quinta' | 'sexta' | 'sabado' | 'domingo' | 'segunda'.
  Map<String, String> _checkinHotel = {};

  // Versões da tabela de preços do Hotel (aba Tabela de preços).
  List<VersaoPrecoHotel> _versoesPreco = [];
  String? _versaoSelecionadaId;

  VersaoPrecoHotel? get _versaoAtual {
    if (_versoesPreco.isEmpty) return null;
    return _versoesPreco.where((v) => v.id == _versaoSelecionadaId).firstOrNull ??
        _versoesPreco.where((v) => v.isPadrao).firstOrNull ??
        _versoesPreco.first;
  }

  bool get _podeEditarVersaoAtual {
    final v = _versaoAtual;
    if (v == null) return true;
    final userId = _fs.currentUserId;
    final userName = _fs.currentUserName.toLowerCase();
    // O criador pode alterar, ou se o usuário for Jeff / admin
    if (v.criadoPorId.isNotEmpty && v.criadoPorId == userId) return true;
    if (v.criadoPorNome.toLowerCase() == userName) return true;
    if (userName.contains('jeff') || userId.isEmpty || userId == 'sistema') return true;
    return false;
  }

  bool _recontando = false;

  // Tabela de preços do Hotel (aba Tabela de preços). Preço de venda por
  // combinação categoria × cota. Chave = "<categoria>|<cotaKey>".
  Map<String, double> _precosHotel = {};
  final Map<String, TextEditingController> _precoCtrls = {};
  bool _salvandoPrecos = false;

  /// Chave da tabela de preços para uma combinação categoria × cota.
  String _chavePreco(String categoria, String cotaKey) =>
      '$categoria|$cotaKey';

  /// Categorias (nome + cor) usadas na tabela de preços. Fonte = categorias da
  /// Multipropriedade (`_mp`), que já incluem as extras como SUÍTE PRESIDENCIAL
  /// e VILLAMOR 300. Cai para o layout do Hotel se a Multipropriedade ainda não
  /// foi carregada.
  List<(String, Color)> get _categoriasPreco => _mp.isNotEmpty
      ? [for (final c in _mp) (c.nome, Color(c.cor))]
      : [for (final c in _categoriasHotel) (c.$1, c.$2)];

  /// Controlador de uma célula, criado sob demanda (seed = preço salvo). Garante
  /// que categorias criadas na Multipropriedade em runtime tenham um campo,
  /// sem apagar edições já em andamento das demais.
  TextEditingController _precoCtrl(String key) =>
      _precoCtrls.putIfAbsent(key, () {
        final v = _precosHotel[key];
        return TextEditingController(
            text: (v != null && v > 0) ? v.toStringAsFixed(0) : '');
      });

  /// Garante um controlador por célula (categoria × cota) e sincroniza o texto
  /// com os preços carregados. Preço 0/ausente vira campo vazio.
  void _sincronizarPrecoCtrls() {
    for (final cat in _categoriasPreco) {
      for (final cota in _cotasOpcoes) {
        final k = _chavePreco(cat.$1, cota.$2);
        final v = _precosHotel[k];
        final txt = (v != null && v > 0) ? v.toStringAsFixed(0) : '';
        _precoCtrls.putIfAbsent(k, () => TextEditingController()).text = txt;
      }
    }
  }

  // Cotas selecionáveis na aba (rótulo exibido, chave salva, cor), da mais
  // premium (Integral = apto inteiro) à mais simples.
  static final List<(String, String, Color)> _cotasOpcoes = [
    ('Integral', 'integral', Color(0xFF4A6FA5)),
    ('Ouro', 'ouro', Color(0xFFC9A227)),
    ('Titânio', 'titanio', Color(0xFF546E7A)),
    ('Prata', 'prata', Color(0xFF7A8390)),
    ('Bronze', 'bronze', Color(0xFF9E6B3F)),
  ];

  // Apartamentos com cota bloqueada para alteração manual, em lote ou auto-distribuição.
  static const Set<int> _aptosBloqueadosCota = {141};

  // Ordem de prestígio das categorias (mais premium → mais simples). Usada
  // pela auto-distribuição de cotas: os aptos mais valorizados recebem Ouro,
  // depois Prata, e os mais simples Bronze — nas quantidades que refletem as
  // vendas reais (em apto-equivalente).
  static const List<String> _prestigioCategorias = [
    'SUÍTE VILLAMOR',
    'SUÍTE DUPLEX',
    'MASTER',
    'DUPLEX',
    'LUXO',
    'TRIPLO',
    'COMFORT 2° ANDAR',
    'COMFORT 1° ANDAR',
    'COMFORT TÉRREO',
    'STUDIO ROOM',
  ];

  // Categorias da Multipropriedade (editáveis pelo usuário). Carregadas de
  // config/multipropriedade; se vazio, seed a partir do layout do Hotel.
  List<_CategoriaMP> _mp = [];

  // Paleta para escolher/gerar cor de categoria na Multipropriedade.
  static const List<int> _paletaMP = [
    0xFF29ABE2, 0xFFCB5A1A, 0xFFF2DD1A, 0xFF1E7A3D, 0xFF8A8A2B,
    0xFF3B2E5A, 0xFF4CD137, 0xFF2E2E3A, 0xFFC2185B, 0xFF7B2FBE,
    0xFF00897B, 0xFFD84315, 0xFF5D4037, 0xFF455A64, 0xFF6A1B9A,
    0xFF0277BD,
  ];

  // Mix de vendas usado pela AUTO-DISTRIBUIÇÃO de cotas (aba Cotas), por tier:
  // (bronze, prata, ouro, integral). Regras de negócio aplicadas ao contar:
  //  • exclui Matheus Camelo e Reynaldo Fabbri (tratados à parte);
  //  • S & S Administradora de Bens conta como 1 integral (tem vários).
  // Calculado em _carregar a partir dos contratos ativos.
  (int, int, int, int) _mixDistribuicao = (0, 0, 0, 0);

  // Mix de vendas por LINHA de produto do resort, usado pela auto-distribuição
  // de CATEGORIAS na aba Multipropriedade: (villamor, luxo, bangalô).
  // Exclui Matheus Camelo e Reynaldo Fabbri (tratados à parte). Calculado em
  // _carregar. Regra de negócio (Jeff): Villamor→categoria VILLAMOR; Luxo→
  // MASTER ou COMFORT (sorteado); Bangalô→1 apto vira SUÍTE PRESIDENCIAL.
  (int, int, int) _mixLinhas = (0, 0, 0);

  /// Linha de produto do resort a partir do texto do produto do contrato.
  /// LUXO* → 'LUXO'; VILLAMOR* → 'VILLAMOR'; BANGALO* → 'BANGALÔ'; resto null.
  static String? _linhaContrato(String produto) {
    final t = produto.toUpperCase().trim();
    if (t.startsWith('LUXO')) return 'LUXO';
    if (t.startsWith('VILLAMOR')) return 'VILLAMOR';
    if (t.startsWith('BANGAL')) return 'BANGALÔ';
    return null;
  }

  /// S & S Administradora de Bens Ltda — colapsada para 1 integral.
  static bool _ehSS(String nome) {
    final u = nome.toUpperCase();
    return u.contains('S & S') && u.contains('ADMINISTRADORA');
  }

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
  final _reyCustosCtrl =
      TextEditingController(text: '60000'); // outras contas mensais do resort
  final _reyAporteCtrl = TextEditingController(text: '2000000'); // aporte Reynaldo
  final _reyPoolMesCtrl = TextEditingController(text: '50000'); // 15% pool/mês
  final _reyPoolInicioCtrl = TextEditingController(text: '12'); // mês início pool
  final _reyShareVendasCtrl =
      TextEditingController(text: '30'); // % do caixa de vendas p/ Reynaldo
  final _reyCrescVendasCtrl =
      TextEditingController(text: '10'); // crescimento das vendas (% a.m.)
  final _reyIgpmCtrl = TextEditingController(text: '4'); // IGPM (% a.a.) nas 60x
  final _reyJuros60Ctrl =
      TextEditingController(text: '0.5'); // juros das 60x (% a.m.)
  final _reyAluguelCtrl =
      TextEditingController(text: '50000'); // aluguel/mês (aptos não vendidos)
  final _reyAluguelAteCtrl =
      TextEditingController(text: '24'); // mês em que vende 100% (fim do aluguel)
  // Início da projeção = inauguração da multipropriedade (jan/2028).
  final _reyMesIniCtrl = TextEditingController(text: '1');
  final _reyAnoIniCtrl = TextEditingController(text: '2028');

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
    _prazoCtrl.dispose();
    _jurosCtrl.dispose();
    _reyDesistCtrl.dispose();
    _reyDistPrazoCtrl.dispose();
    _reyVendaMesCtrl.dispose();
    _reyEntradaCtrl.dispose();
    _reyVendaPrazoCtrl.dispose();
    _reyResortCtrl.dispose();
    _reyCustosCtrl.dispose();
    _reyAporteCtrl.dispose();
    _reyPoolMesCtrl.dispose();
    _reyPoolInicioCtrl.dispose();
    _reyShareVendasCtrl.dispose();
    _reyCrescVendasCtrl.dispose();
    _reyIgpmCtrl.dispose();
    _reyJuros60Ctrl.dispose();
    _reyAluguelCtrl.dispose();
    _reyAluguelAteCtrl.dispose();
    _reyMesIniCtrl.dispose();
    _reyAnoIniCtrl.dispose();
    for (final c in _precoCtrls.values) {
      c.dispose();
    }
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

  Future<void> _carregar({bool forcarContratos = false}) async {
    setState(() => _carregando = true);
    try {
      final imoveis = await _fs.getImoveis();
      // contratosEfetivos já mantém SOMENTE contratos com status Ativo.
      final todosContratos =
          await _fs.getContratos(forcarRecarga: forcarContratos);
      final contratos = contratosEfetivos(todosContratos);
      final outros = contratos
          .where((c) => _clienteSeparado(c.nomeComprador) == null)
          .toList();
      // Mix de vendas por tier para a auto-distribuição de cotas: exclui
      // Matheus/Reynaldo e conta S & S como 1 integral só.
      var mixB = 0, mixP = 0, mixO = 0, mixI = 0, ssInt = 0;
      for (final c in outros) {
        switch (tierDoProduto(c.produto, c.cota)) {
          case TierCota.bronze:
            mixB++;
            break;
          case TierCota.prata:
            mixP++;
            break;
          case TierCota.ouro:
            mixO++;
            break;
          case TierCota.integral:
          case TierCota.diamante:
            if (_ehSS(c.nomeComprador)) {
              ssInt++;
            } else {
              mixI++;
            }
            break;
          case null:
            break;
        }
      }
      if (ssInt > 0) mixI++; // S & S inteira vale 1 integral
      final mix = (mixB, mixP, mixO, mixI);
      // Mix por LINHA de produto (aba Multipropriedade): Villamor/Luxo/Bangalô,
      // também sem Matheus/Reynaldo.
      var linhaV = 0, linhaL = 0, linhaB = 0;
      for (final c in outros) {
        switch (_linhaContrato(c.produto)) {
          case 'VILLAMOR':
            linhaV++;
            break;
          case 'LUXO':
            linhaL++;
            break;
          case 'BANGALÔ':
            linhaB++;
            break;
          default:
            break;
        }
      }
      final mixLin = (linhaV, linhaL, linhaB);
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
      // Cotas por apartamento (só relevante no modo Hotel; barato ler sempre).
      final cotas = widget.modo == ModoAba.hotel
          ? await _fs.getCotasHotel()
          : <String, String>{};
      // Dia de check-in por apartamento (só modo Hotel).
      final checkin = widget.modo == ModoAba.hotel
          ? await _fs.getCheckinHotel()
          : <String, String>{};
      // Versões da tabela de preços (só modo Hotel).
      final versoes = widget.modo == ModoAba.hotel
          ? await _fs.getVersoesPrecosHotel()
          : <VersaoPrecoHotel>[];
      // Tabela de preços categoria × cota (só modo Hotel).
      final precos = widget.modo == ModoAba.hotel
          ? await _fs.getPrecosHotel()
          : <String, double>{};
      // Argumentos por sócio (só modo Hotel).
      final argumentosSocios = widget.modo == ModoAba.hotel
          ? await _fs.getArgumentosSociosHotel()
          : <String, Map<String, dynamic>>{};
      // Atualizações de transição por sócio (status de aceite, fases e distrato).
      final atualizacoesSocios = await _fs.getAtualizacoesSociosTransicao();
      // Objeções personalizadas cadastradas pela equipe (aba Argumentos).
      final objecoesPersonalizadas = await _fs.getObjecoesTransicao();
      // Categorias da Multipropriedade (modo Hotel): carrega ou faz o seed.
      var mp = <_CategoriaMP>[];
      if (widget.modo == ModoAba.hotel) {
        final raw = await _fs.getMultipropriedade();
        if (raw != null && raw.isNotEmpty) {
          mp = raw.map(_CategoriaMP.fromMap).toList();
        } else {
          mp = [
            for (final c in _categoriasHotel)
              _CategoriaMP(
                  nome: c.$1,
                  cor: c.$2.toARGB32(),
                  aptos: List<int>.from(c.$4)),
          ];
        }
      }
      if (!mounted) return;
      setState(() {
        _stats = _montarStats(imoveis, outros);
        _separados = separados;
        _top30 = top.take(30).toList();
        _contratos = contratos;
        _argumentosSociosHotel = argumentosSocios;
        _atualizacoesSocios = atualizacoesSocios;
        _objecoesPersonalizadas = objecoesPersonalizadas;
        _exposicaoDevolucao = exposicao;
        _baseDistrato = baseDist;
        _ativosCount = contratos.length;
        _pctPagos = pctPagos;
        _cotasHotel = cotas;
        _checkinHotel = checkin;
        _versoesPreco = versoes;
        if (_versaoSelecionadaId == null && versoes.isNotEmpty) {
          _versaoSelecionadaId =
              versoes.where((v) => v.isPadrao).firstOrNull?.id ??
                  versoes.first.id;
        }
        if (_versaoAtual != null && _versaoAtual!.precos.isNotEmpty) {
          _precosHotel = Map<String, double>.of(_versaoAtual!.precos);
        } else {
          _precosHotel = precos;
        }
        _mp = mp;
        _sincronizarPrecoCtrls();
        _mixDistribuicao = mix;
        _mixLinhas = mixLin;
        _carregado = true;
        _carregando = false;
      });
    } catch (e, stack) {
      debugPrint('AbaTransicao._carregar: $e\n$stack');
      if (!mounted) return;
      setState(() => _carregando = false);
      if (forcarContratos) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar a transição: $e')),
        );
      }
    }
  }

  /// Força a recontagem de todos os contratos a partir do Firestore (sem cache),
  /// atualizando as projeções, mix de cotas e métricas do sistema.
  Future<void> _recontarContratos({bool feedbackVisual = true}) async {
    if (_recontando) return;
    setState(() => _recontando = true);
    try {
      _fs.invalidarCacheContratos();
      final todos = await _fs.getContratos(forcarRecarga: true);
      final ativos = contratosEfetivos(todos);
      final cancelados = todos.length - ativos.length;

      await _carregar(forcarContratos: true);

      if (!mounted) return;
      setState(() => _recontando = false);

      if (feedbackVisual) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.check_circle_outline,
                color: Colors.green, size: 44),
            title: const Text('Contratos Sincronizados!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total de contratos na base: ${todos.length}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  Text('Contratos Ativos (vigentes): ${ativos.length}'),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.cancel_outlined,
                      size: 16, color: Colors.orange),
                  const SizedBox(width: 6),
                  Text('Cancelados / Distratados desconsiderados: $cancelados'),
                ]),
                const Divider(height: 20),
                const Text('Mix de vendas recalculado:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('• ${_mixDistribuicao.$1} cotas Bronze'),
                Text('• ${_mixDistribuicao.$2} cotas Prata'),
                Text('• ${_mixDistribuicao.$3} cotas Ouro'),
                Text('• ${_mixDistribuicao.$4} aptos Integral'),
                const SizedBox(height: 10),
                Text(
                  'Todos os cálculos, projeções, apartamentos e cotas foram sincronizados com sucesso.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('_recontarContratos: $e');
      if (!mounted) return;
      setState(() => _recontando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao sincronizar contratos: $e')),
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

    final hotel = widget.modo == ModoAba.hotel;

    // (Tab, builder) por modo — mesma lógica/estado, abas diferentes.
    final abas = hotel
        ? <(Tab, Widget)>[
            (
              const Tab(
                  text: 'Apartamentos', icon: Icon(Icons.apartment_outlined)),
              _tabApartamentosHotel(cs)
            ),
            (
              const Tab(
                  text: 'Cotas', icon: Icon(Icons.workspace_premium_outlined)),
              _tabCotas(cs)
            ),
            (
              const Tab(
                  text: 'Categorias',
                  icon: Icon(Icons.category_outlined)),
              _tabMultipropriedade(cs)
            ),
            (
              const Tab(text: 'Áreas', icon: Icon(Icons.pool_rounded)),
              _tabAreas(cs)
            ),
            (
              const Tab(text: 'Pool', icon: Icon(Icons.attach_money_rounded)),
              _tabPool(cs)
            ),
            (
              const Tab(
                  text: 'Condomínio',
                  icon: Icon(Icons.receipt_long_outlined)),
              _tabCondominio(cs)
            ),
            (
              const Tab(text: 'Ganhos', icon: Icon(Icons.savings_outlined)),
              _tabGanhos(cs)
            ),
            (
              const Tab(
                  text: 'Tabela de preços',
                  icon: Icon(Icons.sell_outlined)),
              _tabPrecos(cs)
            ),
            (
              const Tab(
                  text: 'Sócios',
                  icon: Icon(Icons.people_alt_outlined)),
              _tabSocios(cs)
            ),
          ]
        : <(Tab, Widget)>[
            (
              const Tab(
                  text: 'Apartamentos', icon: Icon(Icons.apartment_outlined)),
              _tabApartamentos(cs)
            ),
            (
              const Tab(
                  text: 'Prioridade',
                  icon: Icon(Icons.priority_high_rounded)),
              _tabPrioridade(cs)
            ),
            (
              const Tab(
                  text: 'Atualização',
                  icon: Icon(Icons.sync_alt_rounded)),
              _tabAtualizacao(cs)
            ),
            (
              const Tab(text: 'Argumentos', icon: Icon(Icons.forum_outlined)),
              _tabArgumentos(cs)
            ),
            (
              const Tab(
                  text: 'Comprador', icon: Icon(Icons.handshake_outlined)),
              _tabComprador(cs)
            ),
            (
              const Tab(
                  text: 'Devoluções', icon: Icon(Icons.money_off_outlined)),
              _tabDevolucoes(cs)
            ),
            (
              const Tab(
                  text: 'Reynaldo',
                  icon: Icon(Icons.account_balance_outlined)),
              _tabReynaldo(cs)
            ),
            (
              const Tab(text: 'Plano', icon: Icon(Icons.checklist_rounded)),
              _tabPlano(cs)
            ),
          ];

    return DefaultTabController(
      length: abas.length,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: cs.primary,
                  unselectedLabelColor: cs.onSurfaceVariant,
                  indicatorColor: cs.primary,
                  tabs: [for (final a in abas) a.$1],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Tooltip(
                  message: 'Recontar contratos e sincronizar projeções',
                  child: FilledButton.tonalIcon(
                    onPressed: _recontando ? null : () => _recontarContratos(),
                    icon: _recontando
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded, size: 16),
                    label: const Text('Recontar contratos',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(children: [for (final a in abas) a.$2]),
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

  // ── Aba: Apartamentos (Hotel) — categorias e unidades do mapa ─────────────
  // (nome, cor, descrição curta, unidades). Numeração baseada no mapa do hotel.
  static const List<(String, Color, String, List<int>)> _categoriasHotel = [
    (
      'LUXO',
      Color(0xFF29ABE2),
      'Apto com frigobar, TV, cama box queen, ar-condicionado, roupeiro.',
      [51, 52, 53, 54, 55, 56, 57, 58, 59, 102, 103, 104, 106, 107, 108, 109,
          110, 111, 112, 114, 115, 116, 117]
    ),
    (
      'STUDIO ROOM',
      Color(0xFFCB5A1A),
      'Quarto compacto tipo studio.',
      [71, 72, 73]
    ),
    (
      'DUPLEX',
      Color(0xFFF2DD1A),
      'Apartamento em dois níveis.',
      [128, 130]
    ),
    (
      'TRIPLO',
      Color(0xFF1E7A3D),
      'Acomodação para três hóspedes.',
      [101, 105]
    ),
    (
      'MASTER',
      Color(0xFF8A8A2B),
      'Frente para as piscinas, varanda com cadeiras de balanço e rede.',
      [201, 202, 203, 204, 205, 206, 207, 208, 209, 210]
    ),
    (
      'COMFORT TÉRREO',
      Color(0xFF3B2E5A),
      'Apto próximo ao Jardim do Éden, térreo, varanda.',
      [121, 122, 123, 124, 125, 126, 127, 129, 141, 142, 144, 145, 146, 147,
          148, 149]
    ),
    (
      'COMFORT 1° ANDAR',
      Color(0xFF4CD137),
      'Comfort no 1° andar, linda vista para o mar.',
      [131, 132, 133, 134, 136, 137, 138, 139, 140, 153, 154, 155, 156, 157,
          158, 159, 160, 161]
    ),
    (
      'COMFORT 2° ANDAR',
      Color(0xFF2E2E3A),
      'Comfort no 2° andar, com elevador.',
      [162, 163, 164, 165, 166, 167, 168, 169, 170]
    ),
    (
      'SUÍTE VILLAMOR',
      Color(0xFFC2185B),
      'Suíte ampla, acomodações diferenciadas.',
      [135, 143]
    ),
    (
      'SUÍTE DUPLEX',
      Color(0xFF7B2FBE),
      'Suíte em dois níveis.',
      [150, 151, 152]
    ),
  ];

  Widget _tabApartamentosHotel(ColorScheme cs) {
    final totalUnid =
        _categoriasHotel.fold<int>(0, (s, c) => s + c.$4.length);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Icon(Icons.hotel_rounded, color: cs.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Categorias de apartamentos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 4),
        Text('Hotel Villamor — $totalUnid unidades em '
            '${_categoriasHotel.length} categorias.',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        const SizedBox(height: 12),
        for (final c in _categoriasHotel) ...[
          _cardCategoria(cs, c),
          const SizedBox(height: 10),
        ],
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '⚠ Numeração das unidades transcrita do mapa do hotel — confira e me '
            'avise as correções. As cores seguem a legenda do mapa.',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _cardCategoria(
      ColorScheme cs, (String, Color, String, List<int>) c) {
    final (nome, cor, desc, unidades) = c;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                  color: cor, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(nome,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: cor,
                      letterSpacing: 0.3)),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${unidades.length} un.',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cor)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(desc,
              style: TextStyle(
                  fontSize: 12, color: cs.onSurfaceVariant, height: 1.3)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final n in unidades)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: cor.withValues(alpha: 0.4)),
                  ),
                  child: Text('$n',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Aba: Tabela de preços (preço de venda por categoria × cota) ───────────
  void _selecionarVersaoPreco(String id) {
    final v = _versoesPreco.where((ver) => ver.id == id).firstOrNull;
    if (v == null) return;
    setState(() {
      _versaoSelecionadaId = id;
      _precosHotel = Map<String, double>.of(v.precos);
      _sincronizarPrecoCtrls();
    });
  }

  Future<void> _dialogNovaVersao() async {
    final ctrl = TextEditingController();
    var copiarDaAtual = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Nova versão da tabela de preços'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Crie uma nova versão para simular valores de venda sem alterar a tabela de outros usuários.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nome da versão',
                  hintText: 'Ex: Tabela Verão 2026, Minha versão...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Copiar preços da versão atual',
                    style: TextStyle(fontSize: 13)),
                value: copiarDaAtual,
                onChanged: (v) => setDState(() => copiarDaAtual = v ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (ctrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Criar versão'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && ctrl.text.trim().isNotEmpty) {
      final nome = ctrl.text.trim();
      final precosBase = copiarDaAtual
          ? Map<String, double>.of(_precosHotel)
          : <String, double>{};
      final nova = VersaoPrecoHotel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nome: nome,
        criadoPorId: _fs.currentUserId,
        criadoPorNome: _fs.currentUserName,
        criadoEm: DateTime.now(),
        atualizadoEm: DateTime.now(),
        precos: precosBase,
        isPadrao: _versoesPreco.isEmpty,
      );
      try {
        await _fs.salvarVersaoPrecoHotel(nova);
        if (!mounted) return;
        setState(() {
          _versoesPreco.add(nova);
          _versaoSelecionadaId = nova.id;
          _precosHotel = Map<String, double>.of(nova.precos);
          _sincronizarPrecoCtrls();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Versão "$nome" criada com sucesso.')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar versão: $e')),
        );
      }
    }
  }

  Future<void> _dialogDuplicarVersao() async {
    final atual = _versaoAtual;
    if (atual == null) return;
    final ctrl = TextEditingController(
        text: '${atual.nome} (Cópia de ${_fs.currentUserName})');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duplicar versão da tabela'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Você criará uma cópia editável de "${atual.nome}". Você será o proprietário desta nova versão e poderá editar todos os valores.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nome da sua cópia',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Duplicar'),
          ),
        ],
      ),
    );

    if (ok == true && ctrl.text.trim().isNotEmpty) {
      final nome = ctrl.text.trim();
      final nova = VersaoPrecoHotel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nome: nome,
        criadoPorId: _fs.currentUserId,
        criadoPorNome: _fs.currentUserName,
        criadoEm: DateTime.now(),
        atualizadoEm: DateTime.now(),
        precos: Map<String, double>.of(_precosHotel),
        isPadrao: false,
      );
      try {
        await _fs.salvarVersaoPrecoHotel(nova);
        if (!mounted) return;
        setState(() {
          _versoesPreco.add(nova);
          _versaoSelecionadaId = nova.id;
          _precosHotel = Map<String, double>.of(nova.precos);
          _sincronizarPrecoCtrls();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Versão "$nome" criada. Você já pode editá-la!')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao duplicar versão: $e')),
        );
      }
    }
  }

  Future<void> _tornarVersaoPadrao() async {
    final v = _versaoAtual;
    if (v == null || v.isPadrao) return;
    try {
      for (var i = 0; i < _versoesPreco.length; i++) {
        final item = _versoesPreco[i];
        final deveSerPadrao = (item.id == v.id);
        if (item.isPadrao != deveSerPadrao) {
          final atualizada = item.copyWith(isPadrao: deveSerPadrao);
          _versoesPreco[i] = atualizada;
          await _fs.salvarVersaoPrecoHotel(atualizada);
        }
      }
      await _fs.salvarPrecosHotel(v.precos);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('"${v.nome}" definida como versão padrão do sistema.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao definir versão padrão: $e')),
      );
    }
  }

  Future<void> _confirmarExcluirVersao() async {
    final v = _versaoAtual;
    if (v == null) return;
    if (_versoesPreco.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Não é possível excluir a única versão da tabela.')),
      );
      return;
    }
    if (!_podeEditarVersaoAtual) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Você não tem permissão para excluir esta versão.')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir versão?'),
        content: Text(
            'Deseja excluir a versão "${v.nome}" criada por ${v.criadoPorNome}? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await _fs.deletarVersaoPrecoHotel(v.id);
        if (!mounted) return;
        setState(() {
          _versoesPreco.removeWhere((item) => item.id == v.id);
          final proxima = _versoesPreco.first;
          _versaoSelecionadaId = proxima.id;
          _precosHotel = Map<String, double>.of(proxima.precos);
          _sincronizarPrecoCtrls();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Versão "${v.nome}" excluída.')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir versão: $e')),
        );
      }
    }
  }

  /// True se algum campo de preço difere do que está salvo.
  bool get _precosAlterados {
    for (final cat in _categoriasPreco) {
      for (final cota in _cotasOpcoes) {
        final k = _chavePreco(cat.$1, cota.$2);
        final atual = _precosHotel[k] ?? 0;
        final digitado = double.tryParse(_precoCtrl(k).text.trim()) ?? 0;
        if (digitado != atual) return true;
      }
    }
    return false;
  }

  /// Persiste a tabela de preços na versão selecionada.
  Future<void> _salvarPrecos() async {
    final v = _versaoAtual;
    if (v == null) return;
    if (!_podeEditarVersaoAtual) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Você não pode alterar a versão de ${v.criadoPorNome}. '
            'Duplique esta versão para fazer suas alterações.',
          ),
        ),
      );
      return;
    }

    final novo = <String, double>{};
    for (final cat in _categoriasPreco) {
      for (final cota in _cotasOpcoes) {
        final k = _chavePreco(cat.$1, cota.$2);
        final val = double.tryParse(_precoCtrl(k).text.trim()) ?? 0;
        if (val > 0) novo[k] = val;
      }
    }
    final backup = Map<String, double>.of(_precosHotel);
    setState(() => _salvandoPrecos = true);
    try {
      final versaoAtualizada = v.copyWith(
        precos: novo,
        atualizadoEm: DateTime.now(),
      );
      await _fs.salvarVersaoPrecoHotel(versaoAtualizada);

      if (!mounted) return;
      setState(() {
        _precosHotel = novo;
        final idx = _versoesPreco.indexWhere((item) => item.id == v.id);
        if (idx >= 0) {
          _versoesPreco[idx] = versaoAtualizada;
        }
        _salvandoPrecos = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Versão "${versaoAtualizada.nome}" salva com sucesso.')),
      );
    } catch (e) {
      debugPrint('_salvarPrecos: $e');
      if (!mounted) return;
      setState(() {
        _precosHotel = backup;
        _salvandoPrecos = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Não consegui salvar a tabela. Tente de novo.')),
      );
    }
  }

  Widget _tabPrecos(ColorScheme cs) {
    const larguraCat = 150.0;
    const larguraCel = 120.0;
    final alterados = _precosAlterados;
    final podeEditar = _podeEditarVersaoAtual;
    final versao = _versaoAtual;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                Icon(Icons.sell_outlined, color: cs.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Tabela de preços',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                'Preço de venda por categoria de apartamento e cota. '
                'Salve versões personalizadas ou consulte versões da equipe.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 12),

              // ── Seletor de versões e permissões ──
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.history_edu_outlined,
                            size: 20, color: cs.primary),
                        const SizedBox(width: 8),
                        const Text('Versão:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isDense: true,
                              isExpanded: true,
                              value: versao?.id,
                              items: [
                                for (final v in _versoesPreco)
                                  DropdownMenuItem(
                                    value: v.id,
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            v.nome,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '(${v.criadoPorNome})',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: cs.onSurfaceVariant),
                                        ),
                                        if (v.isPadrao) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: cs.primary
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              'Padrão',
                                              style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: cs.primary),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                              ],
                              onChanged: (id) {
                                if (id != null) _selecionarVersaoPreco(id);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _dialogNovaVersao,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Nova versão',
                              style: TextStyle(fontSize: 12)),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _dialogDuplicarVersao,
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Duplicar versão',
                              style: TextStyle(fontSize: 12)),
                        ),
                        if (versao != null &&
                            !versao.isPadrao &&
                            podeEditar)
                          OutlinedButton.icon(
                            onPressed: _tornarVersaoPadrao,
                            icon: const Icon(Icons.star_outline_rounded,
                                size: 16),
                            label: const Text('Tornar padrão',
                                style: TextStyle(fontSize: 12)),
                          ),
                        if (versao != null &&
                            _versoesPreco.length > 1 &&
                            podeEditar)
                          IconButton(
                            tooltip: 'Excluir versão atual',
                            onPressed: _confirmarExcluirVersao,
                            icon: Icon(Icons.delete_outline,
                                size: 18, color: cs.error),
                          ),
                      ],
                    ),
                    if (!podeEditar && versao != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline,
                                size: 18, color: Colors.amber.shade900),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Você está visualizando a versão de ${versao.criadoPorNome}. '
                                'Não é permitido alterar versões de outros usuários. '
                                'Clique em "Duplicar versão" para criar a sua cópia editável.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.amber.shade900,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cabeçalho: uma coluna por cota.
                    Row(children: [
                      const SizedBox(width: larguraCat),
                      for (final cota in _cotasOpcoes)
                        SizedBox(
                          width: larguraCel,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                      color: cota.$3,
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Text(cota.$1,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                    ]),
                    const Divider(height: 8),
                    for (final cat in _categoriasPreco) ...[
                      Row(
                        children: [
                          SizedBox(
                            width: larguraCat,
                            child: Row(children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: cat.$2, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(cat.$1,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                              ),
                            ]),
                          ),
                          for (final cota in _cotasOpcoes)
                            SizedBox(
                              width: larguraCel,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 4),
                                child: TextField(
                                  controller:
                                      _precoCtrl(_chavePreco(cat.$1, cota.$2)),
                                  readOnly: !podeEditar,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    filled: !podeEditar,
                                    fillColor: podeEditar
                                        ? null
                                        : cs.surfaceContainerHighest
                                            .withValues(alpha: 0.35),
                                    prefixText: 'R\$ ',
                                    hintText: '—',
                                    border: const OutlineInputBorder(),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 10),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Divider(height: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        // Barra inferior: estado + salvar ou duplicar.
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outlineVariant)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    !podeEditar
                        ? 'Modo somente leitura (${versao?.criadoPorNome ?? ''})'
                        : (alterados
                            ? 'Alterações não salvas'
                            : 'Tudo salvo'),
                    style: TextStyle(
                        color: !podeEditar
                            ? cs.onSurfaceVariant
                            : (alterados ? cs.error : cs.onSurfaceVariant),
                        fontStyle: !podeEditar ? FontStyle.italic : null,
                        fontSize: 13),
                  ),
                ),
                if (podeEditar)
                  FilledButton.icon(
                    onPressed: (alterados && !_salvandoPrecos)
                        ? _salvarPrecos
                        : null,
                    icon: _salvandoPrecos
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined),
                    label: const Text('Salvar tabela'),
                  )
                else
                  FilledButton.tonalIcon(
                    onPressed: _dialogDuplicarVersao,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Duplicar para editar'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Aba: Sócios (argumentos de transição por sócio) ────────────────────────
  /// Agrupa os contratos ativos por comprador / sócio, excluindo clientes tratados à parte (Matheus/Reynaldo).
  Map<String, List<Contrato>> get _sociosAgrupados {
    final mapa = <String, List<Contrato>>{};
    for (final c in _contratos) {
      final n = c.nomeComprador.trim();
      if (n.isNotEmpty && _clienteSeparado(n) == null) {
        mapa.putIfAbsent(n, () => []).add(c);
      }
    }
    return mapa;
  }

  /// Retorna a lista de nomes dos sócios que possuem argumentos cadastrados,
  /// com filtro de busca se houver.
  List<String> get _sociosComArgumentos {
    final socios = _argumentosSociosHotel.entries
        .where((e) {
          final arg = (e.value['argumentos'] as String?)?.trim() ?? '';
          return arg.isNotEmpty;
        })
        .map((e) => e.key)
        .toList();
    socios.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (_buscaSocios.trim().isEmpty) return socios;
    final termo = _buscaSocios.trim().toLowerCase();
    return socios.where((s) => s.toLowerCase().contains(termo)).toList();
  }

  Widget _tabSocios(ColorScheme cs) {
    final lista = _sociosComArgumentos;
    final agrupados = _sociosAgrupados;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Cabeçalho da aba com ação de adicionar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.people_alt_outlined, color: cs.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sócios — Argumentos de Transição',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Registre e consulte argumentos personalizados de transição para cada sócio. '
                      'Apenas sócios que possuem argumentos cadastrados aparecem nesta lista.',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _abrirDialogSelecionarSocio(cs),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Adicionar sócio'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (lista.isEmpty && _buscaSocios.isEmpty) ...[
          // Começa zerado: empty state amigável
          Container(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_search_outlined,
                  size: 56,
                  color: cs.primary.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nenhum sócio com argumentos cadastrados',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Text(
                    'Clique no botão abaixo para escolher um sócio existente dos contratos e definir seus argumentos de transição para o hotel.',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.tonalIcon(
                  onPressed: () => _abrirDialogSelecionarSocio(cs),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Selecionar sócio dos contratos'),
                ),
              ],
            ),
          ),
        ] else ...[
          // Barra de pesquisa e total
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar sócio na lista...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (v) => setState(() => _buscaSocios = v),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${lista.length} sócio(s)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (lista.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Nenhum sócio encontrado para "$_buscaSocios".',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            ),
          ] else ...[
            for (final nome in lista)
              _cardSocioArgumento(cs, nome, agrupados[nome] ?? const []),
          ],
        ],
      ],
    );
  }

  Widget _cardSocioArgumento(
      ColorScheme cs, String nome, List<Contrato> contratosDoSocio) {
    final dados = _argumentosSociosHotel[nome] ?? const {};
    final textoArg = (dados['argumentos'] as String?)?.trim() ?? '';
    final atualizadoEm = (dados['atualizadoEm'] as Timestamp?)?.toDate();
    final autorNome = dados['atualizadoPorNome'] as String?;

    final totalPago = contratosDoSocio.fold<double>(
        0, (s, c) => s + c.valorIntegralizado);
    final totalCotas = contratosDoSocio.length;

    // Resumo dos produtos/imóveis
    final produtosSet = contratosDoSocio
        .map((c) => c.produto.trim())
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _abrirDialogArgumentosSocio(cs, nome),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nome,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (totalCotas > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.secondaryContainer.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$totalCotas cota(s)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: cs.onSecondaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _moeda.format(totalPago),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (produtosSet.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        produtosSet.join(' · '),
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.format_quote_rounded, size: 16, color: cs.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              textoArg,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurface,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (atualizadoEm != null || autorNome != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Atualizado${atualizadoEm != null ? ' em ${DateFormat('dd/MM/yyyy HH:mm').format(atualizadoEm)}' : ''}${autorNome != null ? ' por $autorNome' : ''}',
                        style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_note_rounded),
                    tooltip: 'Editar argumentos',
                    color: cs.primary,
                    onPressed: () => _abrirDialogArgumentosSocio(cs, nome),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remover argumentos',
                    color: cs.error,
                    onPressed: () => _confirmarRemoverArgumentosSocio(cs, nome),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _abrirDialogSelecionarSocio(ColorScheme cs) {
    final agrupados = _sociosAgrupados;
    final todosSocios = agrupados.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    showDialog<void>(
      context: context,
      builder: (ctx) {
        String filtro = '';
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final filtrados = todosSocios.where((nome) {
              if (filtro.isEmpty) return true;
              if (nome.toLowerCase().contains(filtro)) return true;
              final cts = agrupados[nome] ?? const [];
              for (final c in cts) {
                if (c.cpfComprador.contains(filtro)) return true;
                if (c.imovel.toLowerCase().contains(filtro)) return true;
                if (c.bloco.toLowerCase().contains(filtro)) return true;
                if (c.produto.toLowerCase().contains(filtro)) return true;
              }
              return false;
            }).toList();

            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600, maxHeight: 650),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_search_rounded, color: cs.primary),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Selecionar sócio dos contratos',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Escolha o sócio para cadastrar ou editar argumentos de transição.',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Buscar por nome, CPF ou cota...',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onChanged: (v) =>
                            setDialogState(() => filtro = v.trim().toLowerCase()),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${filtrados.length} sócio(s) encontrado(s)',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: filtrados.isEmpty
                            ? Center(
                                child: Text(
                                  'Nenhum sócio encontrado.',
                                  style: TextStyle(color: cs.onSurfaceVariant),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtrados.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (itemCtx, i) {
                                  final nome = filtrados[i];
                                  final cts = agrupados[nome] ?? const [];
                                  final totalPago = cts.fold<double>(
                                      0, (s, c) => s + c.valorIntegralizado);
                                  final jaTem = _argumentosSociosHotel
                                      .containsKey(nome) &&
                                      ((_argumentosSociosHotel[nome]?['argumentos']
                                                  as String?)
                                              ?.trim()
                                              .isNotEmpty ??
                                          false);

                                  return ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                    leading: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: jaTem
                                          ? Colors.teal.withValues(alpha: 0.2)
                                          : cs.surfaceContainerHighest,
                                      child: Icon(
                                        jaTem
                                            ? Icons.check
                                            : Icons.person_outline,
                                        size: 18,
                                        color: jaTem ? Colors.teal : cs.onSurfaceVariant,
                                      ),
                                    ),
                                    title: Text(
                                      nome,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${cts.length} cota(s) · ${_moeda.format(totalPago)} pago',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant),
                                    ),
                                    trailing: jaTem
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.teal.withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'Já cadastrado',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.teal,
                                              ),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.chevron_right_rounded,
                                            size: 20),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      _abrirDialogArgumentosSocio(cs, nome);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _abrirDialogArgumentosSocio(ColorScheme cs, String nomeSocio) {
    final agrupados = _sociosAgrupados;
    final cts = agrupados[nomeSocio] ?? const [];
    final totalPago =
        cts.fold<double>(0, (s, c) => s + c.valorIntegralizado);
    final dados = _argumentosSociosHotel[nomeSocio] ?? const {};
    final argAtual = (dados['argumentos'] as String?)?.trim() ?? '';
    final atualizadoEm = (dados['atualizadoEm'] as Timestamp?)?.toDate();
    final autorNome = dados['atualizadoPorNome'] as String?;

    final ctrl = TextEditingController(text: argAtual);
    final messenger = ScaffoldMessenger.of(context);
    bool salvando = false;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabeçalho
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: cs.primaryContainer,
                            child: Icon(Icons.handshake_outlined,
                                color: cs.onPrimaryContainer),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nomeSocio,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Argumentos de transição para o hotel',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(dialogCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Card resumo dos contratos do sócio
                      if (cts.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: cs.outlineVariant.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  size: 18, color: cs.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${cts.length} cota(s) · ${_moeda.format(totalPago)} pago · ${cts.map((c) => '${c.bloco} ${c.imovel}'.trim()).where((s) => s.isNotEmpty).toSet().join(', ')}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Campo de texto grande
                      Text(
                        'Argumentos de Venda / Abordagem:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: ctrl,
                        minLines: 8,
                        maxLines: 15,
                        decoration: InputDecoration(
                          hintText:
                              'Escreva aqui os argumentos personalizados para este sócio: '
                              'perfil, histórico, dores, expectativas, objeções previstas, '
                              'contraproposta ideal, categoria equivalente no hotel...',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: cs.surface,
                        ),
                      ),
                      if (atualizadoEm != null || autorNome != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Última alteração${atualizadoEm != null ? ' em ${DateFormat('dd/MM/yyyy HH:mm').format(atualizadoEm)}' : ''}${autorNome != null ? ' por $autorNome' : ''}',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Botões de ação
                      Row(
                        children: [
                          if (argAtual.isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: salvando
                                  ? null
                                  : () async {
                                      Navigator.pop(dialogCtx);
                                      await _confirmarRemoverArgumentosSocio(
                                          cs, nomeSocio);
                                    },
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Excluir'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: cs.error,
                                side: BorderSide(color: cs.error),
                              ),
                            ),
                          const Spacer(),
                          TextButton(
                            onPressed:
                                salvando ? null : () => Navigator.pop(dialogCtx),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: salvando
                                ? null
                                : () async {
                                    final texto = ctrl.text.trim();
                                    setDialogState(() => salvando = true);
                                    try {
                                      if (texto.isEmpty) {
                                        await _fs.removerArgumentoSocioHotel(
                                            nomeSocio);
                                        setState(() {
                                          _argumentosSociosHotel
                                              .remove(nomeSocio);
                                        });
                                      } else {
                                        await _fs.salvarArgumentoSocioHotel(
                                            nomeSocio, texto);
                                        setState(() {
                                          _argumentosSociosHotel[nomeSocio] = {
                                            'nome': nomeSocio,
                                            'argumentos': texto,
                                            'atualizadoEm': Timestamp.now(),
                                          };
                                        });
                                      }
                                      if (dialogCtx.mounted) {
                                        Navigator.pop(dialogCtx);
                                      }
                                      if (mounted) {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              texto.isEmpty
                                                  ? 'Argumentos de $nomeSocio removidos.'
                                                  : 'Argumentos de $nomeSocio salvos com sucesso!',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setDialogState(() => salvando = false);
                                      if (mounted) {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Erro ao salvar argumentos: $e'),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            icon: salvando
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined, size: 18),
                            label: const Text('Salvar argumentos'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmarRemoverArgumentosSocio(
      ColorScheme cs, String nomeSocio) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover argumentos?'),
        content: Text(
          'Deseja remover os argumentos de transição de "$nomeSocio"? '
          'Ele deixará de aparecer na aba Sócios.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirma == true) {
      try {
        await _fs.removerArgumentoSocioHotel(nomeSocio);
        setState(() {
          _argumentosSociosHotel.remove(nomeSocio);
        });
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Argumentos de $nomeSocio removidos.')),
          );
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Erro ao remover argumentos: $e')),
          );
        }
      }
    }
  }

  // ── Aba: Atualização (status de transição, fases e distrato dos sócios) ────

  static const List<String> _fasesTransicao = [
    'Não informado',
    'Informado',
    'Aguardando aceite do cliente',
    'Aguardando contrato',
    'Pagamento congelado',
    'Solicitou distrato',
    'Contrato Hotel Villamor assinado',
  ];

  static const List<String> _statusTransicao = [
    'Aguardando Resposta',
    'Aceitar',
    'Recusar',
  ];

  DateTime? _parseDataAtualizacao(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  String _formatarDataHora(DateTime dt) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }

  Map<String, dynamic> _getDadosAtualizacaoSocio(String nomeSocio) {
    final dados = _atualizacoesSocios[nomeSocio];
    if (dados != null) {
      final fasesRaw =
          (dados['fases'] as List?)?.whereType<String>().toList() ?? [];
      return {
        'status': (dados['status'] as String?)?.trim().isNotEmpty == true
            ? dados['status'] as String
            : 'Aguardando Resposta',
        'fases': fasesRaw.isNotEmpty ? fasesRaw : const ['Não informado'],
        'negociacaoDistrato': (dados['negociacaoDistrato'] as String?) ?? '',
        'observacoes': (dados['observacoes'] as String?) ?? '',
        'atualizadoEm': _parseDataAtualizacao(dados['atualizadoEm']),
        'atualizadoPorNome': dados['atualizadoPorNome'] as String?,
        'personalizado': true,
      };
    }
    return {
      'status': 'Aguardando Resposta',
      'fases': const ['Não informado'],
      'negociacaoDistrato': '',
      'observacoes': '',
      'atualizadoEm': null,
      'atualizadoPorNome': null,
      'personalizado': false,
    };
  }

  List<_SocioAtualizacaoItem> get _listaTodosSociosAtualizacao {
    final agrupados = _sociosAgrupados;
    final itens = <_SocioAtualizacaoItem>[];

    agrupados.forEach((nome, cts) {
      if (_clienteSeparado(nome) != null) return;
      final totalPago =
          cts.fold<double>(0, (s, c) => s + c.valorIntegralizado);
      final produtosSet = cts
          .map((c) => c.produto.trim())
          .where((p) => p.isNotEmpty)
          .toSet()
          .toList();
      final dados = _getDadosAtualizacaoSocio(nome);

      itens.add(_SocioAtualizacaoItem(
        nome: nome,
        contratos: cts,
        totalPago: totalPago,
        totalCotas: cts.length,
        produtos: produtosSet,
        status: (dados['status'] as String?) ?? 'Aguardando Resposta',
        fases: ((dados['fases'] as List?)?.whereType<String>().toList() ??
            const ['Não informado']),
        negociacaoDistrato: (dados['negociacaoDistrato'] as String?) ?? '',
        observacoes: (dados['observacoes'] as String?) ?? '',
        atualizadoEm: dados['atualizadoEm'] as DateTime?,
        atualizadoPorNome: dados['atualizadoPorNome'] as String?,
        personalizado: (dados['personalizado'] as bool?) ?? false,
      ));
    });

    return itens;
  }

  List<_SocioAtualizacaoItem> get _sociosAtualizacaoFiltrados {
    var itens = _listaTodosSociosAtualizacao;

    // Busca textual
    final busca = _buscaAtualizacoes.trim().toLowerCase();
    if (busca.isNotEmpty) {
      itens = itens.where((s) {
        if (s.nome.toLowerCase().contains(busca)) return true;
        for (final c in s.contratos) {
          if (c.cpfComprador.contains(busca)) return true;
          if (c.imovel.toLowerCase().contains(busca)) return true;
          if (c.bloco.toLowerCase().contains(busca)) return true;
          if (c.produto.toLowerCase().contains(busca)) return true;
        }
        return false;
      }).toList();
    }

    // Filtro por status
    if (_filtroStatusAtualizacao != 'Todos') {
      itens = itens.where((s) => s.status == _filtroStatusAtualizacao).toList();
    }

    // Filtro por fase
    if (_filtroFaseAtualizacao != 'Todas') {
      itens =
          itens.where((s) => s.fases.contains(_filtroFaseAtualizacao)).toList();
    }

    // Ordenação
    switch (_ordenacaoAtualizacoes) {
      case 'valorDesc':
        itens.sort((a, b) => b.totalPago.compareTo(a.totalPago));
        break;
      case 'valorAsc':
        itens.sort((a, b) => a.totalPago.compareTo(b.totalPago));
        break;
      case 'nomeAsc':
        itens.sort(
            (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
        break;
      case 'cotasDesc':
        itens.sort((a, b) => b.totalCotas.compareTo(a.totalCotas));
        break;
      case 'status':
        const ordem = {'Aceitar': 0, 'Aguardando Resposta': 1, 'Recusar': 2};
        itens.sort((a, b) =>
            (ordem[a.status] ?? 3).compareTo(ordem[b.status] ?? 3));
        break;
    }

    return itens;
  }

  Widget _tabAtualizacao(ColorScheme cs) {
    final todos = _listaTodosSociosAtualizacao;
    final filtrados = _sociosAtualizacaoFiltrados;

    final totalSocios = todos.length;
    final totalValorPago = todos.fold<double>(0, (s, i) => s + i.totalPago);

    final aceitaram = todos.where((s) => s.status == 'Aceitar').toList();
    final recusaram = todos.where((s) => s.status == 'Recusar').toList();
    final aguardando =
        todos.where((s) => s.status == 'Aguardando Resposta').toList();
    final distratos =
        todos.where((s) => s.fases.contains('Solicitou distrato')).toList();
    final assinados = todos
        .where((s) => s.fases.contains('Contrato Hotel Villamor assinado'))
        .toList();

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Cabeçalho explicativo ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.sync_alt_rounded,
                      color: cs.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Atualização de Sócios — Transição Hotel Villamor',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Acompanhe e registre a decisão de transição de cada sócio (Aceitar, Recusar ou Aguardando Resposta) '
                        'e as fases em que ele se encontra. Todos os sócios iniciam em "Não informado".',
                        style:
                            TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Cards de Indicadores / Resumo Executivo ──
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _cardKpiAtualizacao(
                cs: cs,
                titulo: 'Total de Sócios',
                valor: '$totalSocios',
                subtitulo: _moeda.format(totalValorPago),
                icone: Icons.people_outline,
                cor: cs.primary,
                ativo: _filtroStatusAtualizacao == 'Todos' &&
                    _filtroFaseAtualizacao == 'Todas',
                onTap: () {
                  setState(() {
                    _filtroStatusAtualizacao = 'Todos';
                    _filtroFaseAtualizacao = 'Todas';
                  });
                },
              ),
              _cardKpiAtualizacao(
                cs: cs,
                titulo: 'Aceitaram',
                valor: '${aceitaram.length}',
                subtitulo: totalSocios > 0
                    ? '${(aceitaram.length / totalSocios * 100).toStringAsFixed(1)}% do total'
                    : '0%',
                icone: Icons.check_circle_rounded,
                cor: Colors.green.shade700,
                ativo: _filtroStatusAtualizacao == 'Aceitar',
                onTap: () {
                  setState(() {
                    _filtroStatusAtualizacao =
                        _filtroStatusAtualizacao == 'Aceitar'
                            ? 'Todos'
                            : 'Aceitar';
                  });
                },
              ),
              _cardKpiAtualizacao(
                cs: cs,
                titulo: 'Aguardando Resposta',
                valor: '${aguardando.length}',
                subtitulo: totalSocios > 0
                    ? '${(aguardando.length / totalSocios * 100).toStringAsFixed(1)}% do total'
                    : '0%',
                icone: Icons.hourglass_top_rounded,
                cor: Colors.orange.shade800,
                ativo: _filtroStatusAtualizacao == 'Aguardando Resposta',
                onTap: () {
                  setState(() {
                    _filtroStatusAtualizacao =
                        _filtroStatusAtualizacao == 'Aguardando Resposta'
                            ? 'Todos'
                            : 'Aguardando Resposta';
                  });
                },
              ),
              _cardKpiAtualizacao(
                cs: cs,
                titulo: 'Recusaram',
                valor: '${recusaram.length}',
                subtitulo: totalSocios > 0
                    ? '${(recusaram.length / totalSocios * 100).toStringAsFixed(1)}% do total'
                    : '0%',
                icone: Icons.cancel_rounded,
                cor: Colors.red.shade700,
                ativo: _filtroStatusAtualizacao == 'Recusar',
                onTap: () {
                  setState(() {
                    _filtroStatusAtualizacao =
                        _filtroStatusAtualizacao == 'Recusar'
                            ? 'Todos'
                            : 'Recusar';
                  });
                },
              ),
              _cardKpiAtualizacao(
                cs: cs,
                titulo: 'Solicitou Distrato',
                valor: '${distratos.length}',
                subtitulo: 'Negociação requerida',
                icone: Icons.assignment_return_outlined,
                cor: Colors.deepOrange.shade800,
                ativo: _filtroFaseAtualizacao == 'Solicitou distrato',
                onTap: () {
                  setState(() {
                    _filtroFaseAtualizacao =
                        _filtroFaseAtualizacao == 'Solicitou distrato'
                            ? 'Todas'
                            : 'Solicitou distrato';
                  });
                },
              ),
              _cardKpiAtualizacao(
                cs: cs,
                titulo: 'Contrato Assinado',
                valor: '${assinados.length}',
                subtitulo: 'Hotel Villamor',
                icone: Icons.verified_rounded,
                cor: Colors.teal.shade800,
                ativo:
                    _filtroFaseAtualizacao == 'Contrato Hotel Villamor assinado',
                onTap: () {
                  setState(() {
                    _filtroFaseAtualizacao = _filtroFaseAtualizacao ==
                            'Contrato Hotel Villamor assinado'
                        ? 'Todas'
                        : 'Contrato Hotel Villamor assinado';
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Barra de Busca e Filtros ──
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText:
                          'Buscar sócio por nome, CPF, imóvel, bloco ou cota...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      suffixIcon: _buscaAtualizacoes.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () =>
                                  setState(() => _buscaAtualizacoes = ''),
                            )
                          : null,
                    ),
                    onChanged: (v) => setState(() => _buscaAtualizacoes = v),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Filtro por Status
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Decisão:',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurfaceVariant)),
                          const SizedBox(width: 6),
                          DropdownButton<String>(
                            value: _filtroStatusAtualizacao,
                            isDense: true,
                            underline: const SizedBox(),
                            style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurface,
                                fontWeight: FontWeight.w600),
                            items: [
                              DropdownMenuItem(
                                value: 'Todos',
                                child: Text('Todos os status ($totalSocios)'),
                              ),
                              for (final st in _statusTransicao)
                                DropdownMenuItem(
                                  value: st,
                                  child: Text(
                                    '$st (${todos.where((s) => s.status == st).length})',
                                  ),
                                ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _filtroStatusAtualizacao = val);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),

                      // Filtro por Fase
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Fase:',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurfaceVariant)),
                          const SizedBox(width: 6),
                          DropdownButton<String>(
                            value: _filtroFaseAtualizacao,
                            isDense: true,
                            underline: const SizedBox(),
                            style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurface,
                                fontWeight: FontWeight.w600),
                            items: [
                              const DropdownMenuItem(
                                value: 'Todas',
                                child: Text('Todas as fases'),
                              ),
                              for (final f in _fasesTransicao)
                                DropdownMenuItem(
                                  value: f,
                                  child: Text(f),
                                ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _filtroFaseAtualizacao = val);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),

                      // Ordenação
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Ordenar por:',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurfaceVariant)),
                          const SizedBox(width: 6),
                          DropdownButton<String>(
                            value: _ordenacaoAtualizacoes,
                            isDense: true,
                            underline: const SizedBox(),
                            style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurface,
                                fontWeight: FontWeight.w600),
                            items: const [
                              DropdownMenuItem(
                                value: 'valorDesc',
                                child: Text('Maior valor pago'),
                              ),
                              DropdownMenuItem(
                                value: 'valorAsc',
                                child: Text('Menor valor pago'),
                              ),
                              DropdownMenuItem(
                                value: 'nomeAsc',
                                child: Text('Nome (A-Z)'),
                              ),
                              DropdownMenuItem(
                                value: 'cotasDesc',
                                child: Text('Mais cotas'),
                              ),
                              DropdownMenuItem(
                                value: 'status',
                                child: Text('Status de aceite'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _ordenacaoAtualizacoes = val);
                              }
                            },
                          ),
                        ],
                      ),

                      // Indicador de contagem
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${filtrados.length} de $totalSocios sócio(s)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Lista de Sócios ──
          if (filtrados.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_off_rounded,
                        size: 48, color: cs.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text(
                      'Nenhum sócio encontrado com os filtros aplicados.',
                      style:
                          TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _buscaAtualizacoes = '';
                          _filtroStatusAtualizacao = 'Todos';
                          _filtroFaseAtualizacao = 'Todas';
                        });
                      },
                      child: const Text('Limpar filtros'),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            for (final socio in filtrados)
              Builder(
                key: ValueKey('socio_${socio.nome}'),
                builder: (context) {
                  try {
                    return _cardSocioAtualizacao(cs, socio);
                  } catch (e, stack) {
                    debugPrint('Erro ao renderizar sócio ${socio.nome}: $e\n$stack');
                    return const SizedBox.shrink();
                  }
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _cardKpiAtualizacao({
    required ColorScheme cs,
    required String titulo,
    required String valor,
    required String subtitulo,
    required IconData icone,
    required Color cor,
    required bool ativo,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 170,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: ativo
              ? cor.withValues(alpha: 0.12)
              : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ativo ? cor : cs.outlineVariant.withValues(alpha: 0.5),
            width: ativo ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, size: 18, color: cor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              valor,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitulo,
              style: TextStyle(
                fontSize: 10.5,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardSocioAtualizacao(ColorScheme cs, _SocioAtualizacaoItem s) {
    final statusCor = _corStatusTransicao(s.status);
    final statusFundo = _fundoStatusTransicao(s.status);
    final statusIcone = _iconeStatusTransicao(s.status);
    final statusRotulo = _rotuloStatusTransicao(s.status);

    final temDistrato = s.fases.contains('Solicitou distrato');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: temDistrato
              ? Colors.deepOrange.withValues(alpha: 0.4)
              : cs.outlineVariant.withValues(alpha: 0.6),
          width: temDistrato ? 1.4 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _abrirDialogAtualizacaoSocio(cs, s),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Linha Superior: Avatar, Nome, Cotas, Valor e Botão Atualizar
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: statusCor.withValues(alpha: 0.15),
                    child: Text(
                      s.nome.trim().isNotEmpty
                          ? s.nome.trim()[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statusCor,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.nome,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    cs.secondaryContainer.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${s.totalCotas} cota(s)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSecondaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _moeda.format(s.totalPago),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (s.produtos.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            s.produtos.join(' · '),
                            style: TextStyle(
                                fontSize: 11, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => _abrirDialogAtualizacaoSocio(cs, s),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Atualizar'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Linha de Status de Aceite e Fases
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Badge de Decisão / Status
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusFundo,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: statusCor.withValues(alpha: 0.4), width: 1.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcone, size: 14, color: statusCor),
                        const SizedBox(width: 5),
                        Text(
                          statusRotulo,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: statusCor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Chips das Fases de Transição
                  for (final fase in s.fases) _chipFaseTransicao(fase),
                ],
              ),

              // Alerta de Negociação de Distrato se solicitou distrato
              if (temDistrato) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.deepOrange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.assignment_return_outlined,
                          size: 18, color: Colors.deepOrange.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Negociação de Distrato Realizada:',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange.shade900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.negociacaoDistrato.isNotEmpty
                                  ? s.negociacaoDistrato
                                  : '(Nenhum detalhe da negociação foi informado ainda)',
                              style: TextStyle(
                                fontSize: 12,
                                color: s.negociacaoDistrato.isNotEmpty
                                    ? Colors.black87
                                    : Colors.deepOrange.shade700,
                                fontStyle: s.negociacaoDistrato.isNotEmpty
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Observações adicionais se houver
              if (s.observacoes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes_rounded,
                        size: 15, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        s.observacoes,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Rodapé do card: Metadata de atualização
              const SizedBox(height: 8),
              Text(
                s.personalizado
                    ? 'Atualizado${s.atualizadoEm != null ? ' em ${_formatarDataHora(s.atualizadoEm!)}' : ''}${s.atualizadoPorNome != null && s.atualizadoPorNome!.isNotEmpty ? ' por ${s.atualizadoPorNome}' : ''}'
                    : 'Pendente de atualização (padrão inicial "Não informado")',
                style: TextStyle(
                  fontSize: 10,
                  color: s.personalizado
                      ? cs.onSurfaceVariant
                      : cs.onSurfaceVariant.withValues(alpha: 0.7),
                  fontStyle:
                      s.personalizado ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipFaseTransicao(String fase) {
    Color cor;
    Color fundo;
    IconData icone;

    switch (fase) {
      case 'Informado':
        cor = Colors.blue.shade800;
        fundo = Colors.blue.withValues(alpha: 0.12);
        icone = Icons.campaign_outlined;
        break;
      case 'Aguardando aceite do cliente':
        cor = Colors.amber.shade900;
        fundo = Colors.amber.withValues(alpha: 0.12);
        icone = Icons.hourglass_top_rounded;
        break;
      case 'Aguardando contrato':
        cor = Colors.purple.shade800;
        fundo = Colors.purple.withValues(alpha: 0.12);
        icone = Icons.description_outlined;
        break;
      case 'Pagamento congelado':
        cor = Colors.cyan.shade900;
        fundo = Colors.cyan.withValues(alpha: 0.12);
        icone = Icons.pause_circle_outline_rounded;
        break;
      case 'Solicitou distrato':
        cor = Colors.deepOrange.shade800;
        fundo = Colors.deepOrange.withValues(alpha: 0.15);
        icone = Icons.assignment_return_outlined;
        break;
      case 'Contrato Hotel Villamor assinado':
        cor = Colors.teal.shade800;
        fundo = Colors.teal.withValues(alpha: 0.15);
        icone = Icons.verified_rounded;
        break;
      case 'Não informado':
      default:
        cor = Colors.grey.shade700;
        fundo = Colors.grey.withValues(alpha: 0.15);
        icone = Icons.help_outline_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 12, color: cor),
          const SizedBox(width: 4),
          Text(
            fase,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }

  Color _corStatusTransicao(String status) {
    switch (status) {
      case 'Aceitar':
        return Colors.green.shade800;
      case 'Recusar':
        return Colors.red.shade800;
      case 'Aguardando Resposta':
      default:
        return Colors.orange.shade800;
    }
  }

  Color _fundoStatusTransicao(String status) {
    switch (status) {
      case 'Aceitar':
        return Colors.green.withValues(alpha: 0.12);
      case 'Recusar':
        return Colors.red.withValues(alpha: 0.12);
      case 'Aguardando Resposta':
      default:
        return Colors.orange.withValues(alpha: 0.12);
    }
  }

  IconData _iconeStatusTransicao(String status) {
    switch (status) {
      case 'Aceitar':
        return Icons.check_circle_rounded;
      case 'Recusar':
        return Icons.cancel_rounded;
      case 'Aguardando Resposta':
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  String _rotuloStatusTransicao(String status) {
    switch (status) {
      case 'Aceitar':
        return 'Aceitou a transição';
      case 'Recusar':
        return 'Recusou a transição';
      case 'Aguardando Resposta':
      default:
        return 'Aguardando Resposta';
    }
  }

  void _abrirDialogAtualizacaoSocio(ColorScheme cs, _SocioAtualizacaoItem s) {
    String statusTemp = s.status;
    List<String> fasesTemp = List<String>.from(s.fases);
    if (fasesTemp.isEmpty) fasesTemp.add('Não informado');

    final distratoCtrl = TextEditingController(text: s.negociacaoDistrato);
    final obsCtrl = TextEditingController(text: s.observacoes);
    final messenger = ScaffoldMessenger.of(context);
    bool salvando = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final temDistrato = fasesTemp.contains('Solicitou distrato');

            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 680, maxHeight: 750),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabeçalho do Dialog
                      Row(
                        children: [
                          Icon(Icons.sync_alt_rounded, color: cs.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.nome,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${s.totalCotas} cota(s) • Total pago: ${_moeda.format(s.totalPago)}${s.produtos.isNotEmpty ? ' • ${s.produtos.join(', ')}' : ''}',
                                  style: TextStyle(
                                      fontSize: 12, color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: salvando
                                ? null
                                : () => Navigator.pop(dialogCtx),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Conteúdo rolável
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Decisão do Cliente (Status de Aceite)
                              Text(
                                'Decisão do Sócio (Aceite da Transição):',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                    value: 'Aguardando Resposta',
                                    label: Text('Aguardando'),
                                    icon: Icon(Icons.hourglass_top_rounded,
                                        size: 16),
                                  ),
                                  ButtonSegment(
                                    value: 'Aceitar',
                                    label: Text('Aceitar'),
                                    icon: Icon(Icons.check_circle_rounded,
                                        size: 16),
                                  ),
                                  ButtonSegment(
                                    value: 'Recusar',
                                    label: Text('Recusar'),
                                    icon: Icon(Icons.cancel_rounded, size: 16),
                                  ),
                                ],
                                selected: {statusTemp},
                                onSelectionChanged: (val) {
                                  setDialogState(
                                      () => statusTemp = val.first);
                                },
                              ),
                              const SizedBox(height: 20),

                              // 2. Fases de Transição (Multi-seleção)
                              Row(
                                children: [
                                  Text(
                                    'Fases de Transição:',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(Pode marcar uma ou mais fases)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: cs.outlineVariant
                                          .withValues(alpha: 0.6)),
                                ),
                                child: Column(
                                  children: [
                                    for (final fase in _fasesTransicao)
                                      CheckboxListTile(
                                        dense: true,
                                        visualDensity: VisualDensity.compact,
                                        title: Text(
                                          fase,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight:
                                                fasesTemp.contains(fase)
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                            color: fase == 'Solicitou distrato'
                                                ? Colors.deepOrange.shade900
                                                : null,
                                          ),
                                        ),
                                        subtitle: fase == 'Não informado'
                                            ? const Text(
                                                'Fase inicial padrão (desmarca as demais se selecionada)',
                                                style: TextStyle(fontSize: 10.5))
                                            : fase == 'Solicitou distrato'
                                                ? const Text(
                                                    'Obrigatório detalhar a negociação de distrato realizada',
                                                    style: TextStyle(
                                                        fontSize: 10.5,
                                                        color: Colors.deepOrange))
                                                : null,
                                        value: fasesTemp.contains(fase),
                                        onChanged: salvando
                                            ? null
                                            : (bool? val) {
                                                setDialogState(() {
                                                  if (val == true) {
                                                    if (fase ==
                                                        'Não informado') {
                                                      fasesTemp = [
                                                        'Não informado'
                                                      ];
                                                    } else {
                                                      fasesTemp.remove(
                                                          'Não informado');
                                                      if (!fasesTemp
                                                          .contains(fase)) {
                                                        fasesTemp.add(fase);
                                                      }
                                                    }
                                                  } else {
                                                    fasesTemp.remove(fase);
                                                    if (fasesTemp.isEmpty) {
                                                      fasesTemp
                                                          .add('Não informado');
                                                    }
                                                  }
                                                });
                                              },
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 3. Campo Obrigatório de Negociação de Distrato
                              if (temDistrato) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.deepOrange
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.deepOrange
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                              Icons.assignment_return_outlined,
                                              size: 18,
                                              color:
                                                  Colors.deepOrange.shade800),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Negociação de distrato feita *',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.deepOrange.shade900,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Como o sócio solicitou distrato, informe detalhadamente qual negociação foi feita (valores, parcelas, retenções, prazos e condições):',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Colors.deepOrange.shade900,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: distratoCtrl,
                                        minLines: 3,
                                        maxLines: 6,
                                        decoration: InputDecoration(
                                          hintText:
                                              'Ex: Acordada devolução de R\$ 50.000 em 10 parcelas de R\$ 5.000 com retenção de 20% conforme contrato...',
                                          filled: true,
                                          fillColor: cs.surface,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // 4. Observações gerais
                              Text(
                                'Observações do Consultor (Opcional):',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: obsCtrl,
                                minLines: 2,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText:
                                      'Anotações de conversas, próximos passos, histórico de contato...',
                                  filled: true,
                                  fillColor: cs.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Rodapé com Ações
                      Row(
                        children: [
                          if (s.personalizado)
                            OutlinedButton.icon(
                              onPressed: salvando
                                  ? null
                                  : () async {
                                      Navigator.pop(dialogCtx);
                                      await _confirmarResetarAtualizacaoSocio(
                                          cs, s.nome);
                                    },
                              icon: const Icon(Icons.restore, size: 16),
                              label: const Text('Redefinir padrão'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: cs.error,
                                side: BorderSide(color: cs.error),
                              ),
                            ),
                          const Spacer(),
                          TextButton(
                            onPressed: salvando
                                ? null
                                : () => Navigator.pop(dialogCtx),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: salvando
                                ? null
                                : () async {
                                    final distratoTexto =
                                        distratoCtrl.text.trim();
                                    if (temDistrato && distratoTexto.isEmpty) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          backgroundColor: Colors.deepOrange,
                                          content: Text(
                                              'Atenção: Ao marcar "Solicitou distrato", é obrigatório detalhar a negociação de distrato feita.'),
                                        ),
                                      );
                                      return;
                                    }

                                    setDialogState(() => salvando = true);
                                    try {
                                      await _fs.salvarAtualizacaoSocioTransicao(
                                        nomeSocio: s.nome,
                                        status: statusTemp,
                                        fases: fasesTemp,
                                        negociacaoDistrato: distratoTexto,
                                        observacoes: obsCtrl.text.trim(),
                                      );

                                      setState(() {
                                        _atualizacoesSocios[s.nome] = {
                                          'nome': s.nome,
                                          'status': statusTemp,
                                          'fases': fasesTemp,
                                          'negociacaoDistrato': distratoTexto,
                                          'observacoes': obsCtrl.text.trim(),
                                          'atualizadoEm': Timestamp.now(),
                                        };
                                      });

                                      if (dialogCtx.mounted) {
                                        Navigator.pop(dialogCtx);
                                      }
                                      if (mounted) {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Atualização de ${s.nome} salva com sucesso!'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setDialogState(() => salvando = false);
                                      if (mounted) {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Erro ao salvar atualização: $e'),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            icon: salvando
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined, size: 18),
                            label: const Text('Salvar atualização'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmarResetarAtualizacaoSocio(
      ColorScheme cs, String nomeSocio) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Redefinir para o padrão?'),
        content: Text(
          'Deseja redefinir os dados de transição de "$nomeSocio"? '
          'Ele voltará para o status "Aguardando Resposta" e fase "Não informado".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Redefinir'),
          ),
        ],
      ),
    );

    if (confirma == true) {
      try {
        await _fs.removerAtualizacaoSocioTransicao(nomeSocio);
        setState(() {
          _atualizacoesSocios.remove(nomeSocio);
        });
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Dados de $nomeSocio redefinidos.')),
          );
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Erro ao redefinir dados: $e')),
          );
        }
      }
    }
  }

  // ── Aba: Cotas (define a cota de cada apartamento do Hotel) ───────────────
  /// Cor da cota (Ouro/Prata/Bronze) ou null se o apto não tem cota definida.
  Color? _corCota(String? cota) {
    for (final o in _cotasOpcoes) {
      if (o.$2 == cota) return o.$3;
    }
    return null;
  }

  /// Rótulo de exibição da cota ('Ouro'…) ou null.
  String? _rotuloCota(String? cota) {
    for (final o in _cotasOpcoes) {
      if (o.$2 == cota) return o.$1;
    }
    return null;
  }

  /// Define (ou limpa, com [cota] == null) a cota de um apartamento, salvando
  /// no Firestore. Atualização otimista: reverte se a gravação falhar.
  Future<void> _setCota(String apto, String? cota) async {
    final numApto = int.tryParse(apto);
    if (numApto != null && _aptosBloqueadosCota.contains(numApto)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'O apartamento $apto está com a cota bloqueada para alteração.'),
            backgroundColor: Colors.amber.shade900,
          ),
        );
      }
      return;
    }
    final anterior = _cotasHotel[apto];
    setState(() {
      if (cota == null) {
        _cotasHotel.remove(apto);
      } else {
        _cotasHotel[apto] = cota;
      }
    });
    try {
      await _fs.setCotaHotel(apto, cota);
    } catch (e) {
      debugPrint('AbaTransicao._setCota: $e');
      if (!mounted) return;
      setState(() {
        if (anterior == null) {
          _cotasHotel.remove(apto);
        } else {
          _cotasHotel[apto] = anterior;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não consegui salvar a cota. Tente de novo.')),
      );
    }
  }

  /// Aplica (ou limpa) uma cota a todos os apartamentos de uma categoria.
  Future<void> _setCotaLote(List<int> aptos, String? cota) async {
    final permitidos =
        aptos.where((n) => !_aptosBloqueadosCota.contains(n)).toList();
    if (permitidos.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Todos os apartamentos selecionados estão com a cota bloqueada.'),
        ),
      );
      return;
    }
    final anterior = {for (final n in permitidos) '$n': _cotasHotel['$n']};
    setState(() {
      for (final n in permitidos) {
        if (cota == null) {
          _cotasHotel.remove('$n');
        } else {
          _cotasHotel['$n'] = cota;
        }
      }
    });
    try {
      await _fs.setCotasHotelEmLote([for (final n in permitidos) '$n'], cota);
    } catch (e) {
      debugPrint('AbaTransicao._setCotaLote: $e');
      if (!mounted) return;
      setState(() {
        anterior.forEach((k, v) {
          if (v == null) {
            _cotasHotel.remove(k);
          } else {
            _cotasHotel[k] = v;
          }
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não consegui salvar as cotas. Tente de novo.')),
      );
    }
  }

  // ── Dias de Check-in (Quinta, Sexta, Sábado, Domingo, Segunda) ───────────
  static const List<(String, String, Color, String)> _checkinOpcoes = [
    ('Quinta', 'quinta', Color(0xFF8E24AA), 'Qui'),
    ('Sexta', 'sexta', Color(0xFF1E88E5), 'Sex'),
    ('Sábado', 'sabado', Color(0xFF00897B), 'Sáb'),
    ('Domingo', 'domingo', Color(0xFFE53935), 'Dom'),
    ('Segunda', 'segunda', Color(0xFFFB8C00), 'Seg'),
  ];

  String? _rotuloCheckin(String? dia) {
    for (final o in _checkinOpcoes) {
      if (o.$2 == dia) return o.$1;
    }
    return null;
  }

  String? _abrevCheckin(String? dia) {
    for (final o in _checkinOpcoes) {
      if (o.$2 == dia) return o.$4;
    }
    return null;
  }

  Color? _corCheckin(String? dia) {
    for (final o in _checkinOpcoes) {
      if (o.$2 == dia) return o.$3;
    }
    return null;
  }

  Future<void> _setCheckin(String apto, String? dia) async {
    final anterior = _checkinHotel[apto];
    setState(() {
      if (dia == null) {
        _checkinHotel.remove(apto);
      } else {
        _checkinHotel[apto] = dia;
      }
    });
    try {
      await _fs.setCheckinHotel(apto, dia);
    } catch (e) {
      debugPrint('AbaTransicao._setCheckin: $e');
      if (!mounted) return;
      setState(() {
        if (anterior == null) {
          _checkinHotel.remove(apto);
        } else {
          _checkinHotel[apto] = anterior;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Não consegui salvar o dia de check-in. Tente de novo.')),
      );
    }
  }

  Future<void> _setCheckinLote(List<int> aptos, String? dia) async {
    final anterior = {for (final n in aptos) '$n': _checkinHotel['$n']};
    setState(() {
      for (final n in aptos) {
        if (dia == null) {
          _checkinHotel.remove('$n');
        } else {
          _checkinHotel['$n'] = dia;
        }
      }
    });
    try {
      await _fs.setCheckinHotelEmLote([for (final n in aptos) '$n'], dia);
    } catch (e) {
      debugPrint('AbaTransicao._setCheckinLote: $e');
      if (!mounted) return;
      setState(() {
        anterior.forEach((k, v) {
          if (v == null) {
            _checkinHotel.remove(k);
          } else {
            _checkinHotel[k] = v;
          }
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Não consegui salvar os check-ins. Tente de novo.')),
      );
    }
  }

  /// Apartamentos do Hotel em ordem de prestígio (categoria premium → simples,
  /// e dentro da categoria por número crescente). Base da auto-distribuição.
  List<int> _aptosPorPrestigio() {
    final out = <int>[];
    for (final nome in _prestigioCategorias) {
      final cat = _categoriasHotel.where((c) => c.$1 == nome);
      if (cat.isEmpty) continue;
      out.addAll([...cat.first.$4]..sort());
    }
    // Qualquer categoria fora da lista de prestígio entra ao final.
    for (final c in _categoriasHotel) {
      if (!_prestigioCategorias.contains(c.$1)) {
        out.addAll([...c.$4]..sort());
      }
    }
    return out;
  }

  /// Reparte [n] apartamentos entre os tiers na proporção de [pesos]
  /// (apto-equivalente), fechando a soma com maior-resto (Hare). Devolve a
  /// contagem por tier na mesma ordem dos pesos.
  List<int> _repartir(int n, List<double> pesos) {
    final total = pesos.fold(0.0, (s, v) => s + v);
    if (total <= 0 || n <= 0) return List.filled(pesos.length, 0);
    final raw = [for (final p in pesos) n * p / total];
    final base = raw.map((v) => v.floor()).toList();
    final resto = n - base.reduce((a, b) => a + b);
    final frac = [
      for (var i = 0; i < raw.length; i++) (i, raw[i] - base[i])
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    for (var i = 0; i < resto; i++) {
      base[frac[i % frac.length].$1]++;
    }
    return base;
  }

  /// Auto-distribui as cotas pelos apartamentos conforme as vendas reais do
  /// resort (mix em apto-equivalente), premium → simples. Pede confirmação.
  /// Tiers, do mais premium ao mais simples: Integral, Ouro, Prata, Bronze.
  Future<void> _autoDistribuirCotas() async {
    // Mix já calculado em _carregar: exclui Matheus/Reynaldo e conta S & S
    // como 1 integral.
    final (b, p, o, d) = _mixDistribuicao;
    if (b + p + o + d == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Sem vendas para basear a distribuição.')),
      );
      return;
    }
    final todosAptos = _aptosPorPrestigio();
    // Exclui apartamentos com cota bloqueada da auto-distribuição
    final aptos =
        todosAptos.where((n) => !_aptosBloqueadosCota.contains(n)).toList();
    final n = aptos.length;
    // Integral é FIXO = total de integrais que temos + 6. O restante dos
    // apartamentos é repartido entre Ouro/Prata/Bronze em apto-equivalente
    // (cada apto rende 13 Ouro / 26 Prata / 52 Bronze cotas).
    final nIntegral = (d + 6).clamp(0, n);
    final resto = n - nIntegral;
    final q3 = _repartir(resto, [o / 13.0, p / 26.0, b / 52.0]);
    final q = [nIntegral, q3[0], q3[1], q3[2]];
    final tiers = ['integral', 'ouro', 'prata', 'bronze'];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Auto-distribuir cotas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Integral = $d (que temos) + 6 = $nIntegral apartamentos. '
                'Os outros $resto são repartidos entre Ouro/Prata/Bronze '
                'conforme as vendas ($o Ouro, $p Prata, $b Bronze em cotas; '
                'sem Matheus/Reynaldo, S & S = 1). Total desbloqueados $n '
                '(${_aptosBloqueadosCota.length} bloqueado mantido):'),
            const SizedBox(height: 10),
            _linhaAlvo(const Color(0xFF4A6FA5), 'Integral', q[0], n),
            _linhaAlvo(const Color(0xFFC9A227), 'Ouro', q[1], n),
            _linhaAlvo(const Color(0xFF7A8390), 'Prata', q[2], n),
            _linhaAlvo(const Color(0xFF9E6B3F), 'Bronze', q[3], n),
            const SizedBox(height: 10),
            const Text(
                'Os apartamentos mais valorizados recebem Integral/Ouro; os '
                'mais simples, Bronze. Apartamentos bloqueados não são alterados.',
                style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Distribuir')),
        ],
      ),
    );
    if (ok != true) return;

    // Inicia preservando apartamentos bloqueados
    final mapa = Map<String, String>.fromEntries(
      _cotasHotel.entries
          .where((e) => _aptosBloqueadosCota.contains(int.tryParse(e.key))),
    );
    var idx = 0;
    for (var t = 0; t < tiers.length; t++) {
      for (var k = 0; k < q[t] && idx < n; k++, idx++) {
        mapa['${aptos[idx]}'] = tiers[t];
      }
    }
    final backup = Map<String, String>.of(_cotasHotel);
    setState(() => _cotasHotel = mapa);
    try {
      await _fs.substituirCotasHotel(mapa);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Distribuído: ${q[0]} Integral, ${q[1]} Ouro, '
                '${q[2]} Prata, ${q[3]} Bronze.')),
      );
    } catch (e) {
      debugPrint('AbaTransicao._autoDistribuirCotas: $e');
      if (!mounted) return;
      setState(() => _cotasHotel = backup);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não consegui salvar. Tente de novo.')),
      );
    }
  }

  /// Apaga TODAS as cotas desbloqueadas (voltando a "Sem cota"). Pede
  /// confirmação e oferece "Desfazer" logo em seguida.
  Future<void> _limparCotas() async {
    final cotasModificaveis = _cotasHotel.entries
        .where((e) => !_aptosBloqueadosCota.contains(int.tryParse(e.key)))
        .toList();
    if (cotasModificaveis.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não há cotas desbloqueadas para apagar.')),
      );
      return;
    }
    final qtd = cotasModificaveis.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar cotas desbloqueadas?'),
        content: Text('Os $qtd apartamentos desbloqueados voltam a ficar '
            '"Sem cota". Apartamentos bloqueados (${_aptosBloqueadosCota.join(', ')}) serão preservados.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apagar')),
        ],
      ),
    );
    if (ok != true) return;

    final backup = Map<String, String>.of(_cotasHotel);
    final preservados = Map<String, String>.fromEntries(
      _cotasHotel.entries
          .where((e) => _aptosBloqueadosCota.contains(int.tryParse(e.key))),
    );
    setState(() => _cotasHotel = preservados);
    try {
      await _fs.substituirCotasHotel(preservados);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cotas desbloqueadas apagadas.'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () async {
              setState(() => _cotasHotel = backup);
              try {
                await _fs.substituirCotasHotel(backup);
              } catch (e) {
                debugPrint('AbaTransicao._limparCotas (desfazer): $e');
              }
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('AbaTransicao._limparCotas: $e');
      if (!mounted) return;
      setState(() => _cotasHotel = backup);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não consegui apagar. Tente de novo.')),
      );
    }
  }

  Widget _linhaAlvo(Color cor, String rotulo, int n, int total) {
    final pct = total > 0 ? (100 * n / total).round() : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text('$rotulo: ',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        Text('$n aptos ($pct%)'),
      ]),
    );
  }

  Widget _tabCotas(ColorScheme cs) {
    final todos = [for (final c in _categoriasHotel) ...c.$4];
    // Conta por cota de forma genérica (inclui novas cotas como Titânio).
    final contagem = {for (final o in _cotasOpcoes) o.$2: 0};
    for (final n in todos) {
      final k = _cotasHotel['$n'];
      if (k != null && contagem.containsKey(k)) {
        contagem[k] = contagem[k]! + 1;
      }
    }
    final atribuidos = contagem.values.fold<int>(0, (s, v) => s + v);
    final sem = todos.length - atribuidos;

    // Contagem por dia de check-in (Quinta, Sexta, Sábado, Domingo, Segunda)
    final contagemCheckin = {for (final o in _checkinOpcoes) o.$2: 0};
    for (final n in todos) {
      final d = _checkinHotel['$n'] ?? (n == 141 ? 'sexta' : null);
      if (d != null && contagemCheckin.containsKey(d)) {
        contagemCheckin[d] = contagemCheckin[d]! + 1;
      }
    }
    final comCheckin =
        contagemCheckin.values.fold<int>(0, (s, v) => s + v);
    final semCheckin = todos.length - comCheckin;

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Icon(Icons.workspace_premium_outlined, color: cs.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Cotas e check-in por apartamento',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            'Toque em um apartamento para definir a cota (Integral, '
            'Ouro, Titânio, Prata ou Bronze) e o dia de check-in (Quinta a Segunda). '
            'Use os menus na categoria para definir em lote.',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _autoDistribuirCotas,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Auto-distribuir conforme vendas'),
              ),
              OutlinedButton.icon(
                onPressed: _limparCotas,
                style: OutlinedButton.styleFrom(foregroundColor: cs.error),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Limpar cotas'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in _cotasOpcoes)
                _pilulaResumo(o.$1, contagem[o.$2] ?? 0, o.$3),
              _pilulaResumo('Sem cota', sem, cs.onSurfaceVariant),
              _pilulaResumo(
                'Bloqueado (${_aptosBloqueadosCota.join(', ')})',
                _aptosBloqueadosCota.length,
                Colors.amber.shade800,
                icon: Icons.lock_rounded,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.calendar_month_outlined,
                  size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                'Dias de check-in:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in _checkinOpcoes)
                _pilulaResumo(
                  o.$1,
                  contagemCheckin[o.$2] ?? 0,
                  o.$3,
                  icon: Icons.calendar_today_rounded,
                ),
              if (semCheckin > 0)
                _pilulaResumo(
                  'Sem check-in',
                  semCheckin,
                  cs.outlineVariant,
                  icon: Icons.event_busy_rounded,
                ),
            ],
          ),
          const SizedBox(height: 16),
          for (final c in _categoriasHotel) ...[
            _cardCotasCategoria(cs, c),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _pilulaResumo(String rotulo, int n, Color cor, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: cor),
        ] else ...[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
          ),
        ],
        const SizedBox(width: 6),
        Text('$n $rotulo',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: cor)),
      ]),
    );
  }

  Widget _cardCotasCategoria(
      ColorScheme cs, (String, Color, String, List<int>) c) {
    final (nome, cor, _, unidades) = c;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                  color: cor, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(nome,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: cor,
                      letterSpacing: 0.3)),
            ),
            PopupMenuButton<String>(
              tooltip: 'Definir dia de check-in para todos os ${unidades.length} aptos',
              onSelected: (v) =>
                  _setCheckinLote(unidades, v == 'limpar' ? null : v),
              itemBuilder: (_) => [
                for (final o in _checkinOpcoes)
                  PopupMenuItem(
                    value: o.$2,
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: o.$3.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(o.$4,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: o.$3)),
                      ),
                      const SizedBox(width: 8),
                      Text('Todos → ${o.$1}'),
                    ]),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                    value: 'limpar', child: Text('Limpar check-in')),
              ],
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.calendar_today_outlined,
                    size: 15, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('check-in',
                    style:
                        TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                Icon(Icons.arrow_drop_down, color: cs.onSurfaceVariant),
              ]),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Aplicar uma cota a todos os ${unidades.length} aptos',
              onSelected: (v) =>
                  _setCotaLote(unidades, v == 'limpar' ? null : v),
              itemBuilder: (_) => [
                for (final o in _cotasOpcoes)
                  PopupMenuItem(
                    value: o.$2,
                    child: Row(children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                            color: o.$3, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text('Todos → ${o.$1}'),
                    ]),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                    value: 'limpar', child: Text('Limpar todos')),
              ],
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.layers_outlined,
                    size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('cota',
                    style:
                        TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                Icon(Icons.arrow_drop_down, color: cs.onSurfaceVariant),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final n in unidades) _chipCotaApto(cs, n)],
          ),
        ],
      ),
    );
  }

  Widget _chipCotaApto(ColorScheme cs, int n) {
    final cota = _cotasHotel['$n'];
    final corCota = _corCota(cota);
    final cotaDefinida = corCota != null;
    final checkin = _checkinHotel['$n'] ?? (n == 141 ? 'sexta' : null);
    final corCheckin = _corCheckin(checkin);
    final abrevCheckin = _abrevCheckin(checkin);
    final bloqueadoCota = _aptosBloqueadosCota.contains(n);

    final chipContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: cotaDefinida
            ? corCota
            : (bloqueadoCota ? Colors.amber.shade50 : cs.surface),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: bloqueadoCota
              ? Colors.amber.shade700
              : (cotaDefinida
                  ? corCota
                  : cs.outlineVariant.withValues(alpha: 0.8)),
          width: bloqueadoCota ? 2 : 1,
        ),
        boxShadow: bloqueadoCota
            ? [
                BoxShadow(
                  color: Colors.amber.shade700.withValues(alpha: 0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (bloqueadoCota) ...[
            Icon(Icons.lock_rounded,
                size: 13,
                color: cotaDefinida ? Colors.white : Colors.amber.shade900),
            const SizedBox(width: 4),
          ],
          Text(
            '$n',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: cotaDefinida
                  ? Colors.white
                  : (bloqueadoCota ? Colors.amber.shade900 : cs.onSurface),
            ),
          ),
          if (cotaDefinida) ...[
            const SizedBox(width: 4),
            Text(
              _rotuloCota(cota)![0],
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
          if (checkin != null &&
              corCheckin != null &&
              abrevCheckin != null) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: cotaDefinida
                    ? Colors.black.withValues(alpha: 0.28)
                    : corCheckin.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: cotaDefinida
                      ? Colors.white.withValues(alpha: 0.6)
                      : corCheckin,
                  width: 0.8,
                ),
              ),
              child: Text(
                abrevCheckin,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: cotaDefinida ? Colors.white : corCheckin,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return PopupMenuButton<String>(
      tooltip: 'Apto $n'
          '${cotaDefinida ? ' — ${_rotuloCota(cota)}' : ''}'
          '${checkin != null ? ' (Check-in: ${_rotuloCheckin(checkin)})' : ''}',
      onSelected: (v) {
        if (v.startsWith('cota:')) {
          final val = v.substring(5);
          _setCota('$n', val == 'limpar' ? null : val);
        } else if (v.startsWith('checkin:')) {
          final val = v.substring(8);
          _setCheckin('$n', val == 'limpar' ? null : val);
        }
      },
      itemBuilder: (_) => [
        // Seção Cota
        const PopupMenuItem<String>(
          enabled: false,
          height: 28,
          child: Text(
            'COTA DO APARTAMENTO',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Colors.grey,
            ),
          ),
        ),
        if (bloqueadoCota)
          PopupMenuItem<String>(
            enabled: false,
            child: Row(
              children: [
                const Icon(Icons.lock_rounded, size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Cota bloqueada (${_rotuloCota(cota) ?? 'Integral'})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )
        else ...[
          for (final o in _cotasOpcoes)
            PopupMenuItem<String>(
              value: 'cota:${o.$2}',
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration:
                        BoxDecoration(color: o.$3, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(o.$1),
                  if (o.$2 == cota) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.check, size: 16),
                  ],
                ],
              ),
            ),
          if (cotaDefinida) ...[
            const PopupMenuItem<String>(
              value: 'cota:limpar',
              child: Text('Sem cota (limpar)'),
            ),
          ],
        ],
        const PopupMenuDivider(),
        // Seção Check-in
        const PopupMenuItem<String>(
          enabled: false,
          height: 28,
          child: Text(
            'DIA DE CHECK-IN',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Colors.grey,
            ),
          ),
        ),
        for (final o in _checkinOpcoes)
          PopupMenuItem<String>(
            value: 'checkin:${o.$2}',
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: o.$3.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    o.$4,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: o.$3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(o.$1),
                if (o.$2 == checkin) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.check, size: 16),
                ],
              ],
            ),
          ),
        if (checkin != null) ...[
          const PopupMenuItem<String>(
            value: 'checkin:limpar',
            child: Text('Limpar check-in'),
          ),
        ],
      ],
      child: chipContent,
    );
  }

  // ── Aba: Multipropriedade (categorias editáveis pelo usuário) ─────────────
  /// Aplica uma mutação em [_mp] de forma otimista e salva no Firestore.
  /// Se a gravação falhar, desfaz a mudança e avisa.
  Future<void> _mutarMP(void Function() fn) async {
    final backup = _mp
        .map((c) => _CategoriaMP(
            nome: c.nome, cor: c.cor, aptos: List<int>.of(c.aptos)))
        .toList();
    setState(fn);
    try {
      await _fs.salvarMultipropriedade(_mp.map((c) => c.toMap()).toList());
    } catch (e) {
      debugPrint('AbaTransicao._mutarMP: $e');
      if (!mounted) return;
      setState(() => _mp = backup);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Não consegui salvar. Tente de novo.')),
      );
    }
  }

  /// Apartamentos da Multipropriedade em ordem de prestígio (categoria
  /// premium → simples, aptos crescentes dentro da categoria). Base da
  /// auto-distribuição por categoria.
  List<int> _aptosMPPorPrestigio() {
    final usados = <int>{};
    final out = <int>[];
    void add(List<int> xs) {
      final ordenados = [...xs]..sort();
      for (final a in ordenados) {
        if (usados.add(a)) out.add(a);
      }
    }

    for (final nome in _prestigioCategorias) {
      for (final c in _mp.where((c) => c.nome.toUpperCase() == nome)) {
        add(c.aptos);
      }
    }
    // Categorias fora da lista de prestígio (ex.: VILLAMOR 300-310 criada à
    // mão) entram ao final, na ordem em que aparecem.
    for (final c in _mp) {
      if (!_prestigioCategorias.contains(c.nome.toUpperCase())) {
        add(c.aptos);
      }
    }
    return out;
  }

  /// Auto-distribui os apartamentos da Multipropriedade em CATEGORIAS conforme
  /// as vendas reais do resort (proporção por linha de produto). Regra (Jeff):
  ///  • Villamor no resort  → categoria VILLAMOR;
  ///  • Luxo no resort      → MASTER ou COMFORT (sorteado);
  ///  • Bangalô             → 1 apto vira SUÍTE PRESIDENCIAL (o mais premium);
  ///    os demais contratos bangalô ficam sem mapear por ora.
  /// Substitui o layout atual da aba. Pede confirmação.
  Future<void> _autoDistribuirMP() async {
    final (v, l, b) = _mixLinhas;
    if (v + l + b == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Sem vendas para basear a distribuição.')),
      );
      return;
    }
    final aptos = _aptosMPPorPrestigio();
    final n = aptos.length;
    if (n == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Não há apartamentos na multipropriedade.')),
      );
      return;
    }

    // Bangalô: reserva 1 apto (o mais premium) para a SUÍTE PRESIDENCIAL.
    final nPres = (b > 0) ? 1 : 0;
    final resto = n - nPres;
    // Villamor × Luxo nos aptos restantes, proporcional às vendas (Hare).
    final vl = _repartir(resto, [v.toDouble(), l.toDouble()]);
    final nVillamor = vl[0];
    final nLuxo = vl[1];

    const presidencial = 'SUÍTE PRESIDENCIAL';
    const villamor = 'VILLAMOR';
    const master = 'MASTER';
    const comfort = 'COMFORT';
    const cores = {
      presidencial: 0xFF6A1B9A,
      villamor: 0xFFC2185B,
      master: 0xFF8A8A2B,
      comfort: 0xFF1E7A3D,
    };
    final buckets = <String, List<int>>{
      presidencial: [],
      villamor: [],
      master: [],
      comfort: [],
    };

    final rng = math.Random();
    var idx = 0;
    for (var k = 0; k < nPres && idx < n; k++, idx++) {
      buckets[presidencial]!.add(aptos[idx]);
    }
    for (var k = 0; k < nVillamor && idx < n; k++, idx++) {
      buckets[villamor]!.add(aptos[idx]);
    }
    for (var k = 0; k < nLuxo && idx < n; k++, idx++) {
      buckets[rng.nextBool() ? master : comfort]!.add(aptos[idx]);
    }
    for (final e in buckets.values) {
      e.sort();
    }

    final ordem = [presidencial, villamor, master, comfort];
    final novo = [
      for (final c in ordem)
        if (buckets[c]!.isNotEmpty)
          _CategoriaMP(nome: c, cor: cores[c]!, aptos: buckets[c]!),
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Auto-distribuir categorias'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Baseado nas vendas do resort ($v Villamor, $l Luxo, '
                '$b Bangalô; sem Matheus/Reynaldo). Distribui os $n '
                'apartamentos assim:'),
            const SizedBox(height: 10),
            for (final c in ordem)
              if (buckets[c]!.isNotEmpty)
                _linhaAlvo(Color(cores[c]!), c, buckets[c]!.length, n),
            const SizedBox(height: 10),
            Text(
                'Luxo é sorteado entre Master e Comfort. '
                '${b > 1 ? 'Os outros ${b - 1} contratos Bangalô ficam sem mapear por ora. ' : ''}'
                'Isso SUBSTITUI as categorias atuais da Multipropriedade.',
                style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Distribuir')),
        ],
      ),
    );
    if (ok != true) return;
    await _mutarMP(() => _mp = novo);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Distribuído: '
              '${buckets[villamor]!.length} Villamor, '
              '${buckets[master]!.length} Master, '
              '${buckets[comfort]!.length} Comfort'
              '${nPres > 0 ? ', 1 Suíte Presidencial' : ''}.')),
    );
  }

  /// Caixa de texto simples (nome de categoria ou número de apto).
  Future<String?> _pedirTexto(String titulo,
      {String inicial = '', String hint = '', bool numero = false}) async {
    final ctrl = TextEditingController(text: inicial);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: numero ? TextInputType.number : null,
          textCapitalization: numero
              ? TextCapitalization.none
              : TextCapitalization.characters,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('OK')),
        ],
      ),
    );
    ctrl.dispose();
    return (r == null || r.isEmpty) ? null : r;
  }

  Future<void> _novaCategoriaMP() async {
    final nome = await _pedirTexto('Nova categoria', hint: 'Ex.: PREMIUM');
    if (nome == null) return;
    final cor = _paletaMP[_mp.length % _paletaMP.length];
    _mutarMP(() => _mp.add(_CategoriaMP(nome: nome, cor: cor, aptos: [])));
  }

  Future<void> _renomearCategoriaMP(int i) async {
    final nome =
        await _pedirTexto('Renomear categoria', inicial: _mp[i].nome);
    if (nome == null) return;
    _mutarMP(() => _mp[i].nome = nome);
  }

  Future<void> _escolherCorMP(int i) async {
    final escolha = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cor de "${_mp[i].nome}"',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final cor in _paletaMP)
                    InkWell(
                      onTap: () => Navigator.pop(ctx, cor),
                      borderRadius: BorderRadius.circular(40),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Color(cor),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _mp[i].cor == cor
                                ? Theme.of(ctx).colorScheme.onSurface
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (escolha != null) _mutarMP(() => _mp[i].cor = escolha);
  }

  Future<void> _adicionarAptoMP(int i) async {
    final txt = await _pedirTexto('Adicionar apartamento',
        hint: 'Número do apto', numero: true);
    if (txt == null) return;
    final n = int.tryParse(txt);
    if (n == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Número de apto inválido.')),
      );
      return;
    }
    _mutarMP(() {
      for (final c in _mp) {
        c.aptos.remove(n); // garante que não fique duplicado
      }
      _mp[i].aptos
        ..add(n)
        ..sort();
    });
  }

  Future<void> _excluirCategoriaMP(int i) async {
    final c = _mp[i];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir "${c.nome}"?'),
        content: Text(c.aptos.isEmpty
            ? 'A categoria será removida.'
            : 'Os ${c.aptos.length} apartamentos sairão da multipropriedade '
                '(você pode readicioná-los depois).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (ok == true) _mutarMP(() => _mp.removeAt(i));
  }

  Future<void> _restaurarLayoutHotelMP() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar layout do Hotel?'),
        content: const Text(
            'As categorias da multipropriedade voltam a ser iguais às do '
            'Hotel. Suas alterações aqui serão perdidas.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restaurar')),
        ],
      ),
    );
    if (ok == true) {
      _mutarMP(() {
        _mp = [
          for (final c in _categoriasHotel)
            _CategoriaMP(
                nome: c.$1, cor: c.$2.toARGB32(), aptos: List<int>.from(c.$4)),
        ];
      });
    }
  }

  Future<void> _abrirMoverApto(int fromIndex, int apto) async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Apartamento $apto',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            for (var j = 0; j < _mp.length; j++)
              ListTile(
                leading: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                      color: Color(_mp[j].cor),
                      borderRadius: BorderRadius.circular(4)),
                ),
                title: Text(_mp[j].nome),
                trailing: j == fromIndex
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  if (j != fromIndex) {
                    _mutarMP(() {
                      _mp[fromIndex].aptos.remove(apto);
                      _mp[j].aptos
                        ..add(apto)
                        ..sort();
                    });
                  }
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Remover da multipropriedade',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _mutarMP(() => _mp[fromIndex].aptos.remove(apto));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _tabMultipropriedade(ColorScheme cs) {
    final totalAptos = _mp.fold<int>(0, (s, c) => s + c.aptos.length);
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Icon(Icons.holiday_village_outlined, color: cs.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Categorias',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              tooltip: 'Restaurar layout do Hotel',
              onPressed: _restaurarLayoutHotelMP,
              icon: const Icon(Icons.restore),
            ),
          ]),
          const SizedBox(height: 4),
          Text('$totalAptos apartamentos em ${_mp.length} categorias. '
              'Começa igual ao Hotel — reorganize as categorias e os aptos '
              'aqui como quiser.',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _novaCategoriaMP,
                icon: const Icon(Icons.add),
                label: const Text('Nova categoria'),
              ),
              FilledButton.tonalIcon(
                onPressed: _autoDistribuirMP,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Auto-distribuir por vendas'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _mp.length; i++) _cardMP(cs, i),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'As mudanças salvam automaticamente. Toque num apartamento para '
              'movê-lo de categoria ou removê-lo; um apto fica em uma única '
              'categoria.',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardMP(ColorScheme cs, int i) {
    final c = _mp[i];
    final cor = Color(c.cor);
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            InkWell(
              onTap: () => _escolherCorMP(i),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                    color: cor, borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.edit, size: 13, color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => _renomearCategoriaMP(i),
                child: Text(c.nome,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: cor,
                        letterSpacing: 0.3)),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${c.aptos.length} un.',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cor)),
            ),
            PopupMenuButton<String>(
              tooltip: 'Opções da categoria',
              onSelected: (v) {
                switch (v) {
                  case 'renomear':
                    _renomearCategoriaMP(i);
                    break;
                  case 'cor':
                    _escolherCorMP(i);
                    break;
                  case 'apto':
                    _adicionarAptoMP(i);
                    break;
                  case 'excluir':
                    _excluirCategoriaMP(i);
                    break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'renomear', child: Text('Renomear')),
                PopupMenuItem(value: 'cor', child: Text('Mudar cor')),
                PopupMenuItem(value: 'apto', child: Text('Adicionar apto')),
                PopupMenuDivider(),
                PopupMenuItem(
                    value: 'excluir', child: Text('Excluir categoria')),
              ],
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final n in c.aptos)
                InkWell(
                  onTap: () => _abrirMoverApto(i, n),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: cor.withValues(alpha: 0.4)),
                    ),
                    child: Text('$n',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              InkWell(
                onTap: () => _adicionarAptoMP(i),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: cor.withValues(alpha: 0.6)),
                  ),
                  child: Icon(Icons.add, size: 16, color: cor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Aba: Áreas (comodidades do hotel) ─────────────────────────────────────
  // (nome, ícone, éAreaDoSocio). As marcadas pelo Jeff como "NÃO É ÁREA DO
  // SÓCIO" ficam com o 3º campo = false (uso comercial/terceiros).
  static const List<(String, IconData, bool)> _areasHotel = [
    ('Piscina Principal', Icons.pool, true),
    ('Piscina (rooftop)', Icons.pool_outlined, true),
    ('Rooftop', Icons.deck, true),
    ('Ôfuro', Icons.hot_tub, true),
    ('Templo de Afrodite', Icons.account_balance, true),
    ('Jardim do Éden', Icons.park, true),
    ('Showroom Villamor Tambaba Resort', Icons.tv, true),
    ('Banho Romano', Icons.bathtub, true),
    ('Massagem', Icons.spa, true),
    ('Sauna', Icons.hot_tub_outlined, true),
    ('Recepção', Icons.meeting_room, true),
    ('Estacionamento', Icons.local_parking, true),
    // Áreas de uso comercial / exploração — NÃO são áreas do sócio.
    ('Loja de Conveniência', Icons.local_convenience_store, false),
    ('SPA', Icons.spa_outlined, false),
    ('Restaurante', Icons.restaurant, false),
    ('Academia', Icons.fitness_center, false),
    ('Bar Piscina', Icons.local_bar, false),
    ('Bar Jardim do Éden', Icons.local_bar, false),
    ('Bar Rooftop', Icons.local_bar, false),
    ('Bar Templo de Afrodite', Icons.local_bar, false),
    ('Boate', Icons.nightlife, false),
    ('Avião Boate', Icons.flight, false),
  ];

  Widget _tabAreas(ColorScheme cs) {
    final socio = _areasHotel.where((a) => a.$3).toList();
    final naoSocio = _areasHotel.where((a) => !a.$3).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Icon(Icons.map_outlined, color: cs.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Áreas e comodidades',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 4),
        Text('${_areasHotel.length} áreas do Hotel Villamor — '
            '${socio.length} do sócio e ${naoSocio.length} de uso comercial.',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        const SizedBox(height: 16),
        _tituloGrupoArea(cs, 'Áreas do sócio', socio.length,
            const Color(0xFF1E7A3D)),
        const SizedBox(height: 8),
        for (final a in socio) _cardArea(cs, a),
        const SizedBox(height: 16),
        _tituloGrupoArea(cs, 'Não são áreas do sócio', naoSocio.length,
            const Color(0xFFCB5A1A)),
        const SizedBox(height: 4),
        Text('Uso comercial / exploração (lojas, bares, restaurante, etc).',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        for (final a in naoSocio) _cardArea(cs, a),
      ],
    );
  }

  Widget _tituloGrupoArea(ColorScheme cs, String titulo, int n, Color cor) {
    return Row(children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Text(titulo,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800, color: cor)),
      const SizedBox(width: 6),
      Text('($n)',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
    ]);
  }

  Widget _cardArea(ColorScheme cs, (String, IconData, bool) a) {
    final cor = a.$3 ? const Color(0xFF1E7A3D) : const Color(0xFFCB5A1A);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(a.$2, color: cor),
        const SizedBox(width: 12),
        Expanded(
          child: Text(a.$1,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        if (!a.$3)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('não é do sócio',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: cor)),
          ),
      ]),
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
    [
      'Não terá a Sex Lagoon como no resort.',
      'Com transparência: o hotel tem o próprio conjunto de lazer, que pode '
          'não repetir atração por atração. O que você contratou — cota, valor '
          'e direito de uso — segue 100% preservado, e passa a ser usufruído '
          'AGORA. Convide o cliente a conhecer a estrutura pronta antes de '
          'comparar no papel.',
    ],
    [
      'Não terá a Festa na Floresta.',
      'O hotel tem a própria agenda de experiências e eventos. O essencial do '
          'seu contrato — fração, valor e uso — não muda. Confirme a '
          'programação atual com a administração e foque no benefício maior: '
          'usar já, sem esperar a obra.',
    ],
    [
      'O Jardim do Éden é muito menor e não é espelhado.',
      'Reconheça a diferença sem rodeios. O ganho da troca não é área X ou Y, '
          'e sim poder usar AGORA, com estrutura pronta e testada, sem risco de '
          'prazo de obra. Mostre o Jardim do Éden do hotel pessoalmente — a '
          'experiência real costuma pesar mais que a comparação de tamanho.',
    ],
    [
      'O hotel terá menos apartamentos que o resort.',
      'Menos unidades não reduz o seu direito: sua cota/semana e a categoria '
          'são preservadas, e já há apartamento equivalente reservado ao seu '
          'perfil (ver abas Prioridade e Multipropriedade). Menos unidades '
          'pode significar, inclusive, uma operação mais exclusiva.',
    ],
    [
      'Como vão internacionalizar o hotel?',
      '(Confirme a estratégia oficial com a administração.) Em linhas gerais, '
          'destaque posicionamento, canais de reserva e parcerias. Evite '
          'prometer o que ainda não está definido; foque no que já está pronto '
          'e operando hoje.',
    ],
    [
      'O hotel terá ambulatório?',
      '(Fato a confirmar com a administração.) Reforce que a segurança e o '
          'bem-estar do hóspede são prioridade e que o hotel já opera '
          'atendendo hóspedes. Não prometa estrutura médica sem confirmação.',
    ],
    [
      'Terá centro de convenções?',
      '(A confirmar com a administração.) Se houver espaço para eventos, '
          'apresente-o como diferencial; caso contrário, foque nos atrativos já '
          'existentes. Não prometa o que não estiver definido.',
    ],
    [
      'As lojas serão em parceria com os sócios?',
      '(Política a confirmar com a administração.) Havendo previsão de parceria '
          'ou preferência para sócios, apresente como vantagem; sem definição, '
          'não crie expectativa.',
    ],
    [
      'Haverá restaurante com piano bar?',
      '(A confirmar com a administração.) Destaque a gastronomia e o ambiente '
          'do hotel. Confirme a existência do piano bar antes de prometer.',
    ],
    [
      'O rooftop será exclusivo para sócios?',
      '(Política de acesso a confirmar com a administração.) Quando confirmada, '
          'posicione a exclusividade como benefício de ser sócio; não garanta '
          'exclusividade sem definição oficial.',
    ],
    [
      'Qual a vantagem de ser sócio?',
      'Uso garantido do seu período todo ano sem pagar diária, com o valor '
          'investido preservado e proteção contra o reajuste de hospedagem. '
          'Além do uso: possíveis descontos em consumo e em noites extras e '
          'acessos exclusivos (itens a confirmar com a administração).',
    ],
    [
      'O sócio terá desconto em consumo (bar, restaurante)?',
      '(Benefício a confirmar com a administração.) Havendo, apresente como '
          'vantagem concreta do sócio; não prometa percentual sem definição.',
    ],
    [
      'O sócio terá desconto em hospedagem em outras datas?',
      '(A confirmar com a administração.) Em geral o sócio tem condição '
          'diferenciada para noites extras ou fora da sua semana; confirme a '
          'regra antes de oferecer.',
    ],
    [
      'Como será a escolha dos apartamentos?',
      'Por equivalência de categoria e por prioridade — maior valor pago '
          'primeiro (ver abas Prioridade e Multipropriedade). Critério '
          'transparente, definido antes de negociar, que evita disputa.',
    ],
    [
      'Como será a escolha das datas?',
      'Pelo mesmo direito de semana/cota que você já possui, com um sistema de '
          'reserva/rodízio transparente. (Confirme o calendário e as regras de '
          'rodízio com a administração.)',
    ],
    [
      'O hotel tem toda a documentação regularizada?',
      '(Fato jurídico a confirmar com a administração/jurídico.) Transmita '
          'segurança: a troca é formalizada por aditivo que preserva seus '
          'direitos, com a documentação apresentada antes da assinatura. Não '
          'afirme regularização sem checar.',
    ],
    [
      'Há algum plano de economia de custo, como energia solar?',
      '(A confirmar com a administração.) Eficiência e sustentabilidade '
          '(energia solar, reuso de água, etc.) reduzem o custo de operação e, '
          'com isso, a taxa de condomínio do sócio. Havendo projeto definido, '
          'apresente como ganho direto no bolso; não prometa o que ainda não '
          'estiver confirmado.',
    ],
  ];

  /// Retorna a lista unificada de objeções (personalizadas da equipe + padrão),
  /// aplicando o filtro de busca `_buscaObjecoes`.
  List<Map<String, dynamic>> get _todasObjecoes {
    final List<Map<String, dynamic>> lista = [];

    // Objeções personalizadas cadastradas pela equipe (aparecem no topo)
    for (final op in _objecoesPersonalizadas) {
      lista.add({
        'id': op['id'] as String?,
        'pergunta': (op['pergunta'] as String?) ?? '',
        'resposta': (op['resposta'] as String?) ?? '',
        'criadoPorNome': op['criadoPorNome'] as String?,
        'personalizada': true,
      });
    }

    // Objeções padrão pré-definidas
    for (final qr in _objeoesRespostas) {
      lista.add({
        'id': null,
        'pergunta': qr[0],
        'resposta': qr[1],
        'criadoPorNome': null,
        'personalizada': false,
      });
    }

    final termo = _buscaObjecoes.trim().toLowerCase();
    if (termo.isEmpty) return lista;

    return lista.where((item) {
      final p = (item['pergunta'] as String).toLowerCase();
      final r = (item['resposta'] as String).toLowerCase();
      return p.contains(termo) || r.contains(termo);
    }).toList();
  }

  /// Gera e abre o visualizador de impressão/PDF com todos os argumentos e objeções.
  Future<void> _imprimirArgumentos() async {
    final List<(String, String)> listaPdf = [];

    // Objeções personalizadas primeiro
    for (final op in _objecoesPersonalizadas) {
      final p = (op['pergunta'] as String?)?.trim() ?? '';
      final r = (op['resposta'] as String?)?.trim() ?? '';
      if (p.isNotEmpty) listaPdf.add((p, r));
    }

    // Objeções padrão
    for (final qr in _objeoesRespostas) {
      listaPdf.add((qr[0], qr[1]));
    }

    try {
      await ArgumentosPdf.gerar(
        porqueTrocar: _porqueTrocar,
        porqueMesmoValor: _porqueMesmoValor,
        objecoes: listaPdf,
      );
    } catch (e) {
      debugPrint('Erro ao imprimir argumentos: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar PDF: $e')),
      );
    }
  }

  /// Abre diálogo para cadastrar nova objeção ou editar uma personalizada existente.
  void _abrirDialogObjecao(ColorScheme cs, {Map<String, dynamic>? item}) {
    final bool editando = item != null;
    final perguntaCtrl = TextEditingController(text: item?['pergunta'] ?? '');
    final respostaCtrl = TextEditingController(text: item?['resposta'] ?? '');
    final messenger = ScaffoldMessenger.of(context);
    bool salvando = false;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabeçalho
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.orange.shade100,
                            child: Icon(Icons.question_answer_outlined,
                                color: Colors.orange.shade900),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  editando
                                      ? 'Editar Objeção / Pergunta'
                                      : 'Nova Objeção / Pergunta',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ficará disponível para toda a equipe na aba Argumentos e incluída na impressão do PDF.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(dialogCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Campo: Pergunta / Objeção
                      Text(
                        'Pergunta / Objeção do cliente *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: perguntaCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Ex.: E se as obras do resort atrasarem ainda mais?',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: cs.surface,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Campo: Resposta sugerida
                      Text(
                        'Resposta sugerida / Argumento da equipe *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: respostaCtrl,
                        minLines: 4,
                        maxLines: 8,
                        decoration: InputDecoration(
                          hintText:
                              'Explique a resposta recomendada, pontos práticos e orientações para o vendedor...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: cs.surface,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Botões de ação
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed:
                                salvando ? null : () => Navigator.pop(dialogCtx),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: salvando
                                ? null
                                : () async {
                                    final p = perguntaCtrl.text.trim();
                                    final r = respostaCtrl.text.trim();
                                    if (p.isEmpty || r.isEmpty) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Preencha a pergunta e a resposta.'),
                                        ),
                                      );
                                      return;
                                    }
                                    setDialogState(() => salvando = true);
                                    try {
                                      await _fs.salvarObjecaoTransicao(
                                        id: item?['id'] as String?,
                                        pergunta: p,
                                        resposta: r,
                                      );
                                      final novas =
                                          await _fs.getObjecoesTransicao();
                                      if (mounted) {
                                        setState(() {
                                          _objecoesPersonalizadas = novas;
                                        });
                                      }
                                      if (dialogCtx.mounted) {
                                        Navigator.pop(dialogCtx);
                                      }
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(editando
                                              ? 'Objeção atualizada com sucesso!'
                                              : 'Nova objeção adicionada com sucesso!'),
                                        ),
                                      );
                                    } catch (e) {
                                      setDialogState(() => salvando = false);
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content:
                                              Text('Erro ao salvar objeção: $e'),
                                        ),
                                      );
                                    }
                                  },
                            icon: salvando
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check, size: 18),
                            label: Text(
                                salvando ? 'Salvando...' : 'Salvar Objeção'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Confirma e remove uma objeção personalizada da equipe.
  Future<void> _confirmarRemoverObjecao(
    ColorScheme cs,
    Map<String, dynamic> item,
  ) async {
    final id = item['id'] as String?;
    if (id == null) return;
    final pergunta = (item['pergunta'] as String?) ?? '';
    final messenger = ScaffoldMessenger.of(context);

    final confirma = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Excluir Objeção'),
        content: Text(
          'Deseja excluir a pergunta "$pergunta"?\n\n'
          'Ela será removida do roteiro da equipe e não sairá mais no PDF.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirma != true) return;

    try {
      await _fs.removerObjecaoTransicao(id);
      final novas = await _fs.getObjecoesTransicao();
      if (mounted) {
        setState(() {
          _objecoesPersonalizadas = novas;
        });
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Objeção excluída com sucesso.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Erro ao excluir: $e')),
      );
    }
  }

  Widget _tabArgumentos(ColorScheme cs) {
    final listaObjecoes = _todasObjecoes;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.forum_outlined, color: cs.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Roteiro de Abordagem e Objeções da Transição',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Do resort (em obras) para o hotel (em operação). Use este guia como apoio comercial, adicione novas objeções mapeadas pela equipe e imprima em PDF para reuniões ou atendimentos.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _imprimirArgumentos,
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('Imprimir / Salvar PDF'),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _abrirDialogObjecao(cs),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Adicionar Objeção'),
                  ),
                ],
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
        const SizedBox(height: 20),
        // Barra de busca e título da seção de objeções
        Row(
          children: [
            Icon(Icons.question_answer_outlined, color: Colors.orange.shade800),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  const Text(
                    'Objeções dos clientes e como responder',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${listaObjecoes.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                  if (_objecoesPersonalizadas.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_objecoesPersonalizadas.length} equipe',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          decoration: InputDecoration(
            hintText: 'Filtrar perguntas ou respostas por palavra-chave...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _buscaObjecoes.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() => _buscaObjecoes = ''),
                  )
                : null,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: cs.surface,
          ),
          onChanged: (v) => setState(() => _buscaObjecoes = v),
        ),
        const SizedBox(height: 10),
        if (listaObjecoes.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  _buscaObjecoes.isNotEmpty
                      ? 'Nenhuma objeção encontrada para "$_buscaObjecoes".'
                      : 'Nenhuma objeção cadastrada.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            ),
          )
        else
          for (final o in listaObjecoes)
            _objecaoTile(
              cs,
              o['pergunta'] as String,
              o['resposta'] as String,
              id: o['id'] as String?,
              personalizada: (o['personalizada'] as bool?) ?? false,
              autor: o['criadoPorNome'] as String?,
              onEditar: o['personalizada'] == true
                  ? () => _abrirDialogObjecao(cs, item: o)
                  : null,
              onExcluir: o['personalizada'] == true
                  ? () => _confirmarRemoverObjecao(cs, o)
                  : null,
            ),
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

  // (nº da etapa, tarefa, prazo/observação) — cronograma da transição.
  static const List<(String, String, String)> _tarefasTransicao = [
    ('02', 'Reunião on-line com todos os sócios proprietários e propor a '
        'transição', '10/2026'),
    ('03', 'Abrir aos sócios a utilização das cotas (com 30% pago)',
        'a partir de 31/12/2027'),
    ('03', 'Execução do novo calendário das cotas', ''),
    ('04', 'Cancelamento e contrato novo', ''),
    ('05', 'Definir nova tabela de preço', ''),
  ];

  // (nº, melhoria) — ampliações / pontos positivos do empreendimento.
  static const List<(String, String)> _ampliacoes = [
    ('01', 'Ampliação do restaurante'),
    ('02', 'Reformar os aptos e deixá-los próximos ao modelo Resort'),
    ('03', 'Construção de 8 aptos com banheiras de imersão (aptos Villamor '
        'vendidos)'),
    ('04', 'Construção de 9 aptos, 1º andar, sobre os luxos 52 a 59'),
    ('05', 'Construção de apto presidencial na antiga academia (suprir venda '
        'de um bangalô)'),
    ('06', 'Reforma e ampliação da recepção com loja de conveniência'),
    ('07', 'Construção de nova academia'),
    ('08', 'Construção de 1 apto substituindo o ôfuro'),
    ('09', 'Uso do apto modelo na grade de reservas'),
    ('10', 'Construção de Spa (terreno agregado)'),
    ('14', 'Execução de Cinema na área da boate'),
    ('15', 'Execução de Sexy Cassino na área da boate'),
  ];

  // ── Aba: Reynaldo (distratos + vendas + payback do aporte de R$ 2M) ───────
  /// Calcula toda a projeção do Reynaldo (usada pela aba e pelo PDF).
  DadosReynaldo _dadosReynaldo() {
    final base = _baseDistrato;
    final desist = _parse(_reyDesistCtrl, 40) / 100;
    final distPrazo = _parse(_reyDistPrazoCtrl, 48);
    final vendaMes = _parse(_reyVendaMesCtrl, 400000);
    final entradaPct = _parse(_reyEntradaCtrl, 10) / 100;
    final vendaPrazo = _parse(_reyVendaPrazoCtrl, 60);
    final resortBase = _parse(_reyResortCtrl, 300000);
    final custos = _parse(_reyCustosCtrl, 60000);
    final aporte = _parse(_reyAporteCtrl, 2000000);
    final poolMes = _parse(_reyPoolMesCtrl, 50000);
    final poolInicio = _parse(_reyPoolInicioCtrl, 12);
    final share = _parse(_reyShareVendasCtrl, 30) / 100;
    final cresc = _parse(_reyCrescVendasCtrl, 10) / 100; // vendas +% a.m.
    final igpm = _parse(_reyIgpmCtrl, 4) / 100; // a.a.
    final juros60 = _parse(_reyJuros60Ctrl, 0.5) / 100; // a.m.
    final corrMes = igpm / 12 + juros60; // correção mensal das 60x
    final aluguelMes = _parse(_reyAluguelCtrl, 50000);
    final aluguelAte = _parse(_reyAluguelAteCtrl, 24).toInt();

    final totalDistrato = base * desist;
    final distParcela =
        distPrazo > 0 ? totalDistrato / distPrazo : totalDistrato;
    // Com a desistência, o recebimento atual cai; volta a crescer com vendas.
    final resortLiq = resortBase * (1 - desist);
    // Referência (mês 1) para exibição.
    final entradaMes = vendaMes * entradaPct;
    final parcelaSafra =
        vendaPrazo > 0 ? vendaMes * (1 - entradaPct) / vendaPrazo : 0.0;
    final prazoInt = vendaPrazo.toInt();

    // Venda do mês s: crescimento LINEAR (+cresc da venda inicial por mês)
    // — 400k, 440k, 480k… (não composto).
    double vendaDoMes(int s) => vendaMes * (1 + cresc * (s - 1));
    double parcelaBaseSafra(int s) =>
        prazoInt > 0 ? vendaDoMes(s) * (1 - entradaPct) / prazoInt : 0.0;

    // Caixa das vendas no mês m: entrada da safra do mês + parcelas corrigidas
    // (IGPM + juros) das safras anteriores ainda dentro do prazo.
    double vendasCashMes(int m) {
      var total = vendaDoMes(m) * entradaPct;
      for (int s = 1; s < m; s++) {
        final idade = m - s;
        if (idade <= prazoInt) {
          total += parcelaBaseSafra(s) * math.pow(1 + corrMes, idade);
        }
      }
      return total;
    }

    const horizonte = 24;
    double acum = 0;
    final fluxo = <(int, double, double, double, double)>[];
    for (int m = 1; m <= horizonte; m++) {
      final vendasCash = vendasCashMes(m);
      final pool = m >= poolInicio ? poolMes : 0.0;
      final aluguel = m <= aluguelAte ? aluguelMes : 0.0;
      final retorno = vendasCash * share + pool + aluguel;
      final recebimento = resortLiq + vendasCash; // recuperação c/ vendas
      final sobra = recebimento - distParcela - custos; // após distrato+custos
      acum += retorno;
      fluxo.add((m, recebimento, retorno, acum, sobra));
    }
    final acumHorizonte = acum;

    // Referência (não é o foco): mês em que o acumulado igualaria o aporte.
    double c = 0;
    int? payback;
    for (int m = 1; m <= 240; m++) {
      final pool = m >= poolInicio ? poolMes : 0.0;
      final aluguel = m <= aluguelAte ? aluguelMes : 0.0;
      c += vendasCashMes(m) * share + pool + aluguel;
      if (c >= aporte) {
        payback = m;
        break;
      }
    }

    return DadosReynaldo(
      aporte: aporte,
      base: base,
      desistPct: desist,
      distPrazo: distPrazo,
      totalDistrato: totalDistrato,
      distParcela: distParcela,
      resort: resortBase,
      resortLiq: resortLiq,
      custosMensais: custos,
      vendaMes: vendaMes,
      entradaPct: entradaPct,
      vendaPrazo: vendaPrazo,
      entradaMes: entradaMes,
      parcelaSafra: parcelaSafra,
      poolMes: poolMes,
      poolInicio: poolInicio,
      sharePct: share,
      crescVendasPct: cresc,
      corrMes60: corrMes,
      aluguelMes: aluguelMes,
      aluguelAte: aluguelAte,
      anoInicio: _parse(_reyAnoIniCtrl, 2028).toInt(),
      mesInicio: _parse(_reyMesIniCtrl, 1).toInt().clamp(1, 12),
      horizonte: horizonte,
      paybackMes: payback,
      acumHorizonte: acumHorizonte,
      fluxo: fluxo,
    );
  }

  Widget _tabReynaldo(ColorScheme cs) {
    final d = _dadosReynaldo();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Proposta de investimento — Reynaldo',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: cs.primary)),
        const SizedBox(height: 4),
        Text(
          'Aporte de ${_moeda.format(d.aporte)} para finalizar as obras e os '
          'novos apartamentos, começando em ${d.dataDoMes(1)} (inauguração). '
          'O foco é mostrar, mês a mês, quanto volta para o Reynaldo — pelas '
          'vendas, aluguel e 15% do pool.',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: () => ReynaldoPdf.gerar(_dadosReynaldo()),
            icon: const Icon(Icons.print_outlined),
            label: const Text('Imprimir proposta (P&B)'),
          ),
        ),
        const SizedBox(height: 16),

        // ── Distratos e recebimento ──
        Text('Distratos e recebimento',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _campoNum('% desistência', _reyDesistCtrl, sufixo: '%'),
          _campoNum('Parcelas distrato', _reyDistPrazoCtrl, sufixo: ''),
          _campoNum('Recebimento hoje', _reyResortCtrl, sufixo: 'R\$'),
          _campoNum('Custos mensais resort', _reyCustosCtrl, sufixo: 'R\$'),
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
                  _moeda.format(d.base), cs),
              _linhaInfo(
                  'Total a devolver (${(d.desistPct * 100).toStringAsFixed(0)}%)',
                  _moeda.format(d.totalDistrato),
                  cs),
              const Divider(height: 18),
              _linhaInfo('Recebimento hoje', '${_moeda.format(d.resort)}/mês',
                  cs),
              _linhaInfo(
                  'Após ${(d.desistPct * 100).toStringAsFixed(0)}% de '
                  'desistência',
                  '${_moeda.format(d.resortLiq)}/mês',
                  cs),
              _linhaInfo(
                  'Parcela do distrato (${d.distPrazo.toStringAsFixed(0)}×)',
                  '− ${_moeda.format(d.distParcela)}/mês',
                  cs),
              _linhaInfo('Custos mensais do resort',
                  '− ${_moeda.format(d.custosMensais)}/mês', cs),
              const Divider(height: 18),
              _linhaInfo(
                  'Sobra da base (antes das vendas)',
                  '${_moeda.format(d.resortLiq - d.distParcela - d.custosMensais)}/mês',
                  cs),
              const SizedBox(height: 4),
              Text('Essa é a sobra só do recebimento base (180k). Com as vendas '
                  'entrando, a sobra cresce mês a mês (coluna "Sobra" na '
                  'tabela).',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Vendas ──
        Text('Vendas',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _campoNum('Venda / mês (inicial)', _reyVendaMesCtrl, sufixo: 'R\$'),
          _campoNum('Crescimento vendas', _reyCrescVendasCtrl, sufixo: '%'),
          _campoNum('Entrada', _reyEntradaCtrl, sufixo: '%'),
          _campoNum('Parcelas venda', _reyVendaPrazoCtrl, sufixo: ''),
          _campoNum('IGPM (a.a.)', _reyIgpmCtrl, sufixo: '%'),
          _campoNum('Juros 60x (a.m.)', _reyJuros60Ctrl, sufixo: '%'),
        ]),
        const SizedBox(height: 16),

        // ── Retorno ao Reynaldo (parâmetros) ──
        Text('Retorno ao Reynaldo',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _campoNum('Aporte Reynaldo', _reyAporteCtrl, sufixo: 'R\$'),
          _campoNum('% vendas p/ ele', _reyShareVendasCtrl, sufixo: '%'),
          _campoNum('Pool 15% / mês', _reyPoolMesCtrl, sufixo: 'R\$'),
          _campoNum('Mês início do pool', _reyPoolInicioCtrl, sufixo: ''),
          _campoNum('Aluguel / mês', _reyAluguelCtrl, sufixo: 'R\$'),
          _campoNum('Aluguel até o mês', _reyAluguelAteCtrl, sufixo: ''),
          _campoNum('Mês início (1-12)', _reyMesIniCtrl, sufixo: ''),
          _campoNum('Ano início', _reyAnoIniCtrl, sufixo: ''),
        ]),
        const SizedBox(height: 12),
        Text('Mês a mês — quanto volta para o Reynaldo',
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
            columnWidths: const {0: FlexColumnWidth(1.0)},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: BoxDecoration(color: cs.surfaceContainerHighest),
                children: [
                  _celReynaldo(cs, 'Mês', cabecalho: true),
                  _celReynaldo(cs, 'Recebimento', cabecalho: true),
                  _celReynaldo(cs, 'Sobra', cabecalho: true),
                  _celReynaldo(cs, 'Retorno', cabecalho: true),
                  _celReynaldo(cs, 'Acumulado', cabecalho: true),
                ],
              ),
              for (final f in d.fluxo)
                TableRow(children: [
                  _celReynaldo(cs, d.dataDoMes(f.$1)),
                  _celReynaldo(cs, _moeda.format(f.$2)),
                  _celReynaldo(cs, _moeda.format(f.$5),
                      cor: f.$5 < 0 ? Colors.red.shade700 : null),
                  _celReynaldo(cs, _moeda.format(f.$3),
                      destaque: true, cor: cs.primary),
                  _celReynaldo(cs, _moeda.format(f.$4)),
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
            'Como ler: as vendas crescem +'
            '${(d.crescVendasPct * 100).toStringAsFixed(0)}%/mês (linear) e as 60x são '
            'corrigidas por IGPM + juros (${(d.corrMes60 * 100).toStringAsFixed(2)}%/mês). '
            '"Recebimento" = após a desistência (${_moeda.format(d.resortLiq)}) '
            '+ caixa das vendas do mês. "Sobra" = recebimento − distrato '
            '(${_moeda.format(d.distParcela)}) − custos '
            '(${_moeda.format(d.custosMensais)}); vermelho quando não cobre. '
            '"Retorno" = ${(d.sharePct * 100).toStringAsFixed(0)}% das vendas + '
            '15% do pool (mês ${d.poolInicio.toStringAsFixed(0)}) + aluguel '
            '${_moeda.format(d.aluguelMes)}/mês até o mês ${d.aluguelAte} '
            '(100% vendido). Ajuste com os números reais.',
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
          Icon(Icons.checklist_rtl_rounded, color: Colors.indigo.shade600),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Tarefas a fazer (cronograma)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 8),
        for (final t in _tarefasTransicao)
          _tarefaNumerada(cs, t.$1, t.$2, Colors.indigo.shade600, prazo: t.$3),
        const SizedBox(height: 20),
        Row(children: [
          Icon(Icons.auto_awesome_outlined, color: Colors.green.shade700),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Ampliação (pontos positivos)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 8),
        for (final a in _ampliacoes)
          _tarefaNumerada(cs, a.$1, a.$2, Colors.green.shade700),
        const SizedBox(height: 20),
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

  /// Item numerado (etapa/tarefa) com badge do número e prazo opcional.
  Widget _tarefaNumerada(ColorScheme cs, String numero, String texto, Color cor,
      {String prazo = ''}) {
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
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(numero,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: cor)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(texto,
                    style: const TextStyle(
                        fontSize: 13, height: 1.3, fontWeight: FontWeight.w600)),
                if (prazo.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(Icons.event_outlined, size: 13, color: cor),
                    const SizedBox(width: 4),
                    Text(prazo,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: cor)),
                  ]),
                ],
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
    // Diária média PONDERADA pelas semanas das temporadas (fonte única — a
    // mesma usada em "Ganho por cota", Ganhos e Comprador). Sem campo solto.
    final diaria = _diariaMediaTemporadas();
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
            _campoNum('Taxa administração', _taxaCtrl, sufixo: '%'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '$pool de ${hotel.toStringAsFixed(0)} apartamentos no pool · '
          'diária média ${_moeda.format(diaria)} (ponderada das temporadas) · '
          'administração ${(taxa * 100).toStringAsFixed(0)}%',
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
            'diária × (1 − taxa). A diária é a média ponderada das temporadas '
            '(editável em "Ganho por cota, por temporada" logo abaixo) — fonte '
            'única usada também em Ganhos e Comprador.',
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
          _linhaInfo('Diárias ocupadas / mês (por apto)',
              (diasMes * occ).toStringAsFixed(0), cs),
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Visão do comprador (cota financiada)',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: cs.primary)),
        const SizedBox(height: 4),
        Text(
          'Para quem compra a cota financiada: o apartamento rende pelo pool '
          '(as mesmas temporadas, taxa e condomínio das outras abas) e a dívida '
          'cobra a parcela (SAC). Abaixo, o retorno por tier e o fluxo de caixa '
          'real — tudo na mesma fonte de números.',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
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
            _campoNum('Prazo (meses)', _prazoCtrl, sufixo: ''),
            _campoNum('Juros a.m.', _jurosCtrl, sufixo: '%'),
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
            'Como calcula: o repasse do pool vem das temporadas (líquido da '
            'taxa), a parcela é SAC (preço × (1 − entrada), com o prazo e os '
            'juros acima) e o condomínio é o rateio do custo do hotel. '
            'Fluxo/mês = repasse − parcela (mês 1) − condomínio. No SAC a '
            'parcela diminui, então o fluxo melhora com o tempo.',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ),
      ],
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
    // Condomínio por apartamento/ano no cenário MP = 50% do hotel (cenário
    // negativo: só metade dos aptos é multipropriedade e absorve o custo, por
    // isso o rateio por apto dobra). Fração 50% vem de _cenariosMP.
    final fracaoMP = _cenariosMP.first.$2; // 0.5 = MP é 50% do hotel
    final aptosMP = _parse(_hotelCtrl, 100) * fracaoMP;
    final condoAptoAno = aptosMP > 0 ? (_custoMensal / aptosMP) * 12 : 0.0;
    // Diamante/Integral = apto inteiro, desconta o condomínio cheio.
    final aposCondoTotal = liqTotal - condoAptoAno;
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
          _tabelaCotaTemporada(cs, valorSemana, condoAptoAno),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${_moeda.format(liqTotal)} / ano',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A6FA5))),
                    Text('${_moeda.format(aposCondoTotal)} / ano − condomínio',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E7A3D))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bronze reveza (1 semana): num ano recebe a parte alta, no outro a '
            'parte média — "Recebe/ano" é a média do ciclo. Prata e Ouro têm '
            'composição fixa (alta + média) e recebem as duas todo ano. '
            'Diamante/Integral possui o apartamento inteiro. "− Condomínio" é o '
            'recebimento já descontado o rateio do condomínio por cota no '
            'cenário MP = 50% do hotel (custo do hotel ÷ 50% dos aptos, dividido '
            'por cota: Bronze 1/52, Prata 1/26, Ouro 1/13, Diamante o apto '
            'inteiro). Ajuste custo/aptos na aba Condomínio.',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _tabelaCotaTemporada(
      ColorScheme cs, List<double> valorSemana, double condoAptoAno) {
    final valAlta = valorSemana.isNotEmpty ? valorSemana[0] : 0.0;
    final valMedia = valorSemana.length > 1 ? valorSemana[1] : 0.0;
    const corAposCondo = Color(0xFF1E7A3D); // verde — líquido após condomínio

    // (rótulo, composição, semanas de alta, semanas de média, reveza?, divisor condo)
    final cotas = <(String, String, int, int, bool, int)>[
      ('Bronze', '1 sem · reveza', 1, 1, true, 52),
      ('Prata', '1 alta + 1 média', 1, 1, false, 26),
      ('Ouro', '2 alta + 2 média', 2, 2, false, 13),
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
        bool reveza, int divisorCondo) {
      final parteAlta = semA * valAlta;
      final parteMedia = semM * valMedia;
      final recebeAno =
          reveza ? (parteAlta + parteMedia) / 2 : parteAlta + parteMedia;
      final aposCondo = recebeAno - condoAptoAno / divisorCondo;
      return TableRow(children: [
        cel(rotulo, destaque: true),
        cel(comp),
        cel(_moeda.format(parteAlta)),
        cel(_moeda.format(parteMedia)),
        cel(_moeda.format(recebeAno), destaque: true, cor: cs.primary),
        cel(_moeda.format(aposCondo), destaque: true, cor: corAposCondo),
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
          0: FlexColumnWidth(0.8),
          1: FlexColumnWidth(1.25),
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
              cel('− Condomínio', cabecalho: true),
            ],
          ),
          for (final c in cotas) linhaCota(c.$1, c.$2, c.$3, c.$4, c.$5, c.$6),
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

  Widget _objecaoTile(
    ColorScheme cs,
    String objecao,
    String resposta, {
    String? id,
    bool personalizada = false,
    String? autor,
    VoidCallback? onEditar,
    VoidCallback? onExcluir,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: personalizada ? 1.5 : 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: personalizada
              ? cs.primary.withValues(alpha: 0.4)
              : cs.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: ExpansionTile(
        leading: Icon(
          Icons.chat_bubble_outline,
          color: personalizada ? cs.primary : Colors.orange.shade800,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '"$objecao"',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (personalizada) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Personalizada',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
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
                child: Text(
                  resposta,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (personalizada) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 6),
            Row(
              children: [
                if (autor != null && autor.isNotEmpty)
                  Expanded(
                    child: Text(
                      'Cadastrado por $autor',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (onEditar != null)
                  TextButton.icon(
                    onPressed: onEditar,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Editar', style: TextStyle(fontSize: 12)),
                  ),
                if (onExcluir != null)
                  TextButton.icon(
                    onPressed: onExcluir,
                    icon: Icon(Icons.delete_outline, size: 16, color: cs.error),
                    label: Text(
                      'Excluir',
                      style: TextStyle(fontSize: 12, color: cs.error),
                    ),
                  ),
              ],
            ),
          ],
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
            const Expanded(
              child: Text('Transição para o Hotel Villamor',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Projeção da migração dos contratos do resort para o novo hotel. '
          'Base atual: $_ativosCount contratos ativos considerados (cancelados e distratados desconsiderados).',
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
