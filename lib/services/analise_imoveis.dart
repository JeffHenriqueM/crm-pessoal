// Lógica pura da Análise de Imóveis (aba Pós-Venda → Análise).
//
// Sem dependência de Firestore/UI: recebe o inventário de imóveis e a lista de
// contratos e produz a ligação contrato→cota, as situações de disponibilidade
// e as agregações (por bloco, por tier). Portável para Cloud Functions e
// totalmente testável.
//
// Regras de negócio:
// - Cada imóvel tem um tier fixo (bronze/prata/ouro/diamante/integral) assim
//   que a 1ª cota é vendida; todos os contratos do imóvel compartilham o tier.
// - Cada cota pertence a no máximo um contrato (id da cota = rótulo no contrato).
// - Contratos que não casam com Bloco B/C/Bangalô ficam "avulsos" (sem ligação).

import '../models/contrato_model.dart';
import '../models/cota_model.dart';
import '../models/imovel_model.dart';

// ── Metragens por tipo de planta ────────────────────────────────────────────
const double _mLuxo = 46.20;
const double _mLuxoPremium = 53.96;
const double _mLuxoMaster = 59.81;
const double _mLuxoExtra = 46.20;
const double _mLuxoPrime = 53.96;
const double _mVillamor = 52.42;
const double _mVillamorPremium = 53.96;
const double _mVillamorSuperMaster = 53.96;

/// Letras dos 20 bangalôs (A–T). Todos duplex. Os contratos referenciam o
/// bangalô pela letra (vendidos hoje: D, I, J, M).
const List<String> kLetrasBangalos = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
  'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
];

// ── Geração do inventário (530 unidades) ────────────────────────────────────
// Blocos A/B/D/E têm Térreo + 4 andares (98 cada); o Bloco C tem Térreo + 5
// andares (118). Mais 20 bangalôs. Total = 530.

/// Sobrescritas de tipo do Bloco B (HERA). Base = LUXO.
const Map<int, String> _tiposEspeciaisB = {
  1: 'LUXO MASTER', 20: 'LUXO PREMIUM', // térreo
  101: 'LUXO MASTER', 120: 'LUXO MASTER',
  201: 'LUXO MASTER', 220: 'LUXO MASTER',
  301: 'LUXO MASTER', 320: 'LUXO MASTER',
  401: 'LUXO MASTER', 420: 'LUXO PREMIUM',
};

/// Sobrescritas de tipo do Bloco A (ZEUS). Base = LUXO.
const Map<int, String> _tiposEspeciaisA = {
  1: 'LUXO PRIME', // térreo
  2: 'LUXO EXTRA', 3: 'LUXO EXTRA', 4: 'LUXO EXTRA', 5: 'LUXO EXTRA',
  20: 'LUXO PREMIUM',
  101: 'LUXO MASTER', 120: 'LUXO PREMIUM',
  201: 'LUXO MASTER', 220: 'LUXO PREMIUM',
  301: 'LUXO MASTER', 320: 'LUXO PREMIUM',
  401: 'LUXO MASTER', 420: 'LUXO PREMIUM',
};

/// Sobrescritas de tipo do Bloco D (ATENA). Base = LUXO.
const Map<int, String> _tiposEspeciaisD = {
  1: 'LUXO PREMIUM', 20: 'LUXO MASTER', // térreo
  101: 'LUXO PREMIUM', 120: 'LUXO MASTER',
  201: 'LUXO PREMIUM', 220: 'LUXO MASTER',
  301: 'LUXO PREMIUM', 320: 'LUXO MASTER',
  401: 'LUXO PREMIUM', 420: 'LUXO MASTER',
};

/// Sobrescritas de tipo do Bloco E (APOLO). Base = LUXO.
const Map<int, String> _tiposEspeciaisE = {
  1: 'LUXO PREMIUM', // térreo
  16: 'LUXO EXTRA', 17: 'LUXO EXTRA', 18: 'LUXO EXTRA', 19: 'LUXO EXTRA', 20: 'LUXO EXTRA',
  101: 'LUXO PREMIUM', 120: 'LUXO MASTER',
  201: 'LUXO PREMIUM', 220: 'LUXO MASTER',
  301: 'LUXO PREMIUM', 320: 'LUXO MASTER',
  401: 'LUXO PREMIUM', 420: 'LUXO MASTER',
};

/// Sobrescritas de tipo do Bloco C (AFRODITE). Base = VILLAMOR.
const Map<int, String> _tiposEspeciaisC = {
  1: 'VILLAMOR SUPER MASTER', 20: 'VILLAMOR SUPER MASTER', // térreo
  101: 'VILLAMOR SUPER MASTER', 120: 'VILLAMOR SUPER MASTER',
  201: 'VILLAMOR SUPER MASTER', 220: 'VILLAMOR SUPER MASTER',
  301: 'VILLAMOR PREMIUM', 320: 'VILLAMOR SUPER MASTER',
  401: 'VILLAMOR SUPER MASTER', 420: 'VILLAMOR SUPER MASTER',
  501: 'VILLAMOR SUPER MASTER', 520: 'VILLAMOR PREMIUM',
};

double? _metragemDoTipo(String tipo) {
  switch (tipo) {
    case 'LUXO':
      return _mLuxo;
    case 'LUXO PREMIUM':
      return _mLuxoPremium;
    case 'LUXO MASTER':
      return _mLuxoMaster;
    case 'LUXO EXTRA':
      return _mLuxoExtra;
    case 'LUXO PRIME':
      return _mLuxoPrime;
    case 'VILLAMOR':
      return _mVillamor;
    case 'VILLAMOR PREMIUM':
      return _mVillamorPremium;
    case 'VILLAMOR SUPER MASTER':
      return _mVillamorSuperMaster;
    default:
      return null;
  }
}

/// Números de apartamento de um pavimento: 01–20, exceto 06 e 15 no térreo
/// (acessos/escada). Andares superiores têm os 20.
List<int> _numerosDoPavimento(int base, {required bool terreo}) {
  final out = <int>[];
  for (var i = 1; i <= 20; i++) {
    if (terreo && (i == 6 || i == 15)) continue;
    out.add(base + i);
  }
  return out;
}

String _pavimentoLabel(int nivel) => nivel == 0 ? 'terreo' : '$nivel';

/// Gera um bloco de apartamentos com Térreo + [andares] pavimentos, base [base]
/// e as sobrescritas de [especiais] (mesmo padrão de numeração do Bloco B).
void _gerarBlocoApto(
  List<Imovel> out, {
  required String bloco,
  required String blocoNome,
  required String base,
  required Map<int, String> especiais,
  int andares = 4,
}) {
  for (var nivel = 0; nivel <= andares; nivel++) {
    final centena = nivel == 0 ? 0 : nivel * 100;
    for (final n in _numerosDoPavimento(centena, terreo: nivel == 0)) {
      final tipo = especiais[n] ?? base;
      out.add(Imovel(
        id: '$bloco-$n',
        bloco: bloco,
        blocoNome: blocoNome,
        pavimento: _pavimentoLabel(nivel),
        numero: '$n',
        tipo: tipo,
        metragem: _metragemDoTipo(tipo),
        etapa: 1,
      ));
    }
  }
}

/// Gera o inventário completo do empreendimento: blocos A (98), B (98),
/// C (118), D (98), E (98) e 20 bangalôs = 530 unidades.
List<Imovel> inventarioPrimeiraEtapa() {
  final imoveis = <Imovel>[];

  // ── Bloco A (ZEUS): térreo + 4 pavimentos ──
  _gerarBlocoApto(imoveis,
      bloco: 'A', blocoNome: 'ZEUS', base: 'LUXO', especiais: _tiposEspeciaisA);

  // ── Bloco B (HERA): térreo + 4 pavimentos ──
  for (var nivel = 0; nivel <= 4; nivel++) {
    final base = nivel == 0 ? 0 : nivel * 100;
    for (final n in _numerosDoPavimento(base, terreo: nivel == 0)) {
      final tipo = _tiposEspeciaisB[n] ?? 'LUXO';
      imoveis.add(Imovel(
        id: 'B-$n',
        bloco: 'B',
        blocoNome: 'HERA',
        pavimento: _pavimentoLabel(nivel),
        numero: '$n',
        tipo: tipo,
        metragem: _metragemDoTipo(tipo),
        etapa: 1,
      ));
    }
  }

  // ── Bloco C (AFRODITE): térreo + 5 pavimentos ──
  for (var nivel = 0; nivel <= 5; nivel++) {
    final base = nivel == 0 ? 0 : nivel * 100;
    for (final n in _numerosDoPavimento(base, terreo: nivel == 0)) {
      final tipo = _tiposEspeciaisC[n] ?? 'VILLAMOR';
      imoveis.add(Imovel(
        id: 'C-$n',
        bloco: 'C',
        blocoNome: 'AFRODITE',
        pavimento: _pavimentoLabel(nivel),
        numero: '$n',
        tipo: tipo,
        metragem: _metragemDoTipo(tipo),
        etapa: 1,
      ));
    }
  }

  // ── Bloco D (ATENA): térreo + 4 pavimentos ──
  _gerarBlocoApto(imoveis,
      bloco: 'D', blocoNome: 'ATENA', base: 'LUXO', especiais: _tiposEspeciaisD);

  // ── Bloco E (APOLO): térreo + 4 pavimentos ──
  _gerarBlocoApto(imoveis,
      bloco: 'E', blocoNome: 'APOLO', base: 'LUXO', especiais: _tiposEspeciaisE);

  // ── 20 bangalôs (A–T): tipo/metragem definidos por venda ──
  for (final letra in kLetrasBangalos) {
    imoveis.add(Imovel(
      id: 'BANG-$letra',
      bloco: 'BANGALO',
      blocoNome: 'Bangalôs',
      pavimento: 'unico',
      numero: letra,
      tipo: 'BANGALO',
      metragem: null,
      etapa: 1,
    ));
  }

  return imoveis;
}

// ── Normalização e ligação ──────────────────────────────────────────────────

/// Normaliza o campo `bloco` (sujo) do contrato para 'B' | 'C' | 'BANGALO',
/// ou null quando não pertence à 1ª etapa (projeto antigo, pavimento no campo,
/// outros blocos como D/ATENA).
String? normalizarBloco(String blocoRaw) {
  final b = blocoRaw.toUpperCase();
  if (b.contains('BANGAL')) return 'BANGALO';
  if (b.contains('HERA') || b == 'B') return 'B';
  if (b.contains('AFRODITE') || b == 'C') return 'C';
  if (b.contains('ZEUS') || b == 'A') return 'A';
  if (b.contains('ATENA') || b == 'D') return 'D';
  if (b.contains('APOLO') || b == 'E') return 'E';
  return null;
}

/// Verifica se o número do apartamento é válido para o bloco, conforme as
/// plantas (térreo 1–20 sem 06/15; andares 101–120 etc.).
bool _numeroAptoValido(String bloco, int n) {
  // Térreo (1–20 sem 06/15 — acessos/escada).
  if (n >= 1 && n <= 20) return n != 6 && n != 15;
  // Andares superiores têm os 20 aptos completos (inclusive 06 e 15).
  bool noAndar(int base) => n > base && n <= base + 20;
  // Blocos A/B/D/E: térreo + 4 andares (101–420).
  if (bloco == 'A' || bloco == 'B' || bloco == 'D' || bloco == 'E') {
    return noAndar(100) || noAndar(200) || noAndar(300) || noAndar(400);
  }
  // Bloco C: térreo + 5 andares (101–520).
  if (bloco == 'C') {
    return noAndar(100) || noAndar(200) || noAndar(300) || noAndar(400) || noAndar(500);
  }
  return false;
}

/// Retorna o id do imóvel ao qual o contrato se liga ('B-101', 'BANG-F'), ou
/// null quando o contrato não casa com nenhum imóvel da 1ª etapa (avulso).
String? imovelIdDoContrato(Contrato c) {
  final bloco = normalizarBloco(c.bloco);
  if (bloco == null) return null;

  if (bloco == 'BANGALO') {
    final letra = c.imovel.trim().toUpperCase();
    return kLetrasBangalos.contains(letra) ? 'BANG-$letra' : null;
  }

  final n = int.tryParse(c.imovel.trim());
  if (n == null) return null;
  if (!_numeroAptoValido(bloco, n)) return null;
  return '$bloco-$n';
}

/// Um contrato só representa uma venda vigente quando o STATUS é "Ativo".
/// Cancelado, Revertido, Não efetivado, Pendente etc. NÃO contam para estoque
/// (cotas/espelho), vendas ou metas — entram no banco, mas ficam de fora da
/// análise. A lista de contratos (aba Contratos) ainda mostra todos via filtro.
bool contratoEfetivo(Contrato c) => c.status.trim().toLowerCase() == 'ativo';

/// Filtra apenas os contratos vigentes (ver [contratoEfetivo]).
List<Contrato> contratosEfetivos(List<Contrato> contratos) =>
    contratos.where(contratoEfetivo).toList();

/// Deriva o tier da cota a partir do nome do produto e do campo `cota`.
/// 'Integral' tem prioridade; senão lê BRONZE/PRATA/OURO/DIAMANTE do produto.
TierCota? tierDoProduto(String produto, String cota) {
  if (cota.trim().toLowerCase() == 'integral') return TierCota.integral;
  final p = produto.toUpperCase();
  if (p.contains('DIAMANTE')) return TierCota.diamante;
  if (p.contains('OURO')) return TierCota.ouro;
  if (p.contains('PRATA')) return TierCota.prata;
  if (p.contains('BRONZE')) return TierCota.bronze;
  return null;
}

/// Converte um contrato linkável em uma Cota (projeção para a subcoleção).
/// O rótulo da cota (`numero`) é o campo `cota` do contrato.
Cota cotaDoContrato(Contrato c) {
  return Cota(
    numero: c.cota.trim().isEmpty ? 'Integral' : c.cota.trim(),
    tier: tierDoProduto(c.produto, c.cota),
    clienteNome: c.nomeComprador,
    cpfComprador: c.cpfComprador,
    contratoId: c.localizador,
    produto: c.produto,
    valor: c.valorTotalReajustado,
    statusFinanceiro: c.statusFinanceiro,
    dataContrato: c.dataContrato,
  );
}

/// Projeta os contratos linkáveis em cotas, agrupadas por id de imóvel.
/// Usada pela sincronização (gravar cotas) e pela análise.
Map<String, List<Cota>> projetarCotas(List<Contrato> contratos) {
  final out = <String, List<Cota>>{};
  for (final c in contratos) {
    final id = imovelIdDoContrato(c);
    if (id == null) continue;
    (out[id] ??= []).add(cotaDoContrato(c));
  }
  return out;
}

/// Contratos que não casam com nenhum imóvel da 1ª etapa.
List<Contrato> contratosAvulsos(List<Contrato> contratos) =>
    contratos.where((c) => imovelIdDoContrato(c) == null).toList();

/// Explica por que um contrato avulso não casa com Bloco B/C/Bangalô.
String motivoAvulso(Contrato c) {
  final bloco = normalizarBloco(c.bloco);
  if (bloco == null) {
    return 'Bloco fora da 1ª etapa: "${c.bloco.isEmpty ? '—' : c.bloco}"';
  }
  if (bloco == 'BANGALO') {
    return 'Bangalô sem letra válida (F–Q): "${c.imovel}"';
  }
  return 'Imóvel fora do range do Bloco $bloco: "${c.imovel}"';
}

// ── Resultado da análise ────────────────────────────────────────────────────

enum SituacaoImovel { indefinido, parcial, esgotado }

/// Análise de um único imóvel: tier derivado, cotas vendidas/disponíveis,
/// situação e flags de saúde de dados.
class AnaliseImovel {
  final Imovel imovel;
  final TierCota? tier;
  final List<Cota> cotas;
  final int cotasVendidas;
  final int? cotasTotal;
  final int? disponiveis;
  final double ocupacaoPct;
  final SituacaoImovel situacao;

  /// Contratos do imóvel com tiers diferentes entre si (viola a regra de tier
  /// único). Não deveria acontecer.
  final bool conflitoTier;

  /// Rótulos de cota vendidos mais de uma vez no mesmo imóvel (dois contratos
  /// para a mesma cota).
  final List<String> cotasDuplicadas;

  const AnaliseImovel({
    required this.imovel,
    required this.tier,
    required this.cotas,
    required this.cotasVendidas,
    required this.cotasTotal,
    required this.disponiveis,
    required this.ocupacaoPct,
    required this.situacao,
    required this.conflitoTier,
    required this.cotasDuplicadas,
  });

  double get receita => cotas.fold(0.0, (s, c) => s + c.valor);
  bool get temAlerta => conflitoTier || cotasDuplicadas.isNotEmpty;
}

/// Agregação por tier (alimenta as barras de cotas).
class ResumoTier {
  final TierCota tier;
  int imoveis = 0;
  int cotasVendidas = 0;
  int cotasTotal = 0;
  ResumoTier(this.tier);
  int get disponiveis => (cotasTotal - cotasVendidas).clamp(0, cotasTotal);
}

/// Agregação por bloco.
class ResumoBloco {
  final String bloco;
  int unidades = 0;
  int comVenda = 0;
  int esgotados = 0;
  int indefinidos = 0;
  int cotasVendidas = 0;
  double receita = 0;
  ResumoBloco(this.bloco);
}

/// Resultado completo da análise do empreendimento.
class ResumoAnalise {
  final List<AnaliseImovel> imoveis;
  final List<Contrato> avulsos;
  final Map<TierCota, ResumoTier> porTier;
  final Map<String, ResumoBloco> porBloco;

  const ResumoAnalise({
    required this.imoveis,
    required this.avulsos,
    required this.porTier,
    required this.porBloco,
  });

  int get totalUnidades => imoveis.length;
  int get totalComVenda =>
      imoveis.where((i) => i.situacao != SituacaoImovel.indefinido).length;
  int get totalEsgotados =>
      imoveis.where((i) => i.situacao == SituacaoImovel.esgotado).length;
  int get totalCotasVendidas =>
      imoveis.fold(0, (s, i) => s + i.cotasVendidas);
  double get receitaTotal => imoveis.fold(0.0, (s, i) => s + i.receita);

  /// Imóveis com algum problema de dados (conflito de tier ou cota duplicada).
  List<AnaliseImovel> get comAlerta =>
      imoveis.where((i) => i.temAlerta).toList();
}

// ── Função principal ────────────────────────────────────────────────────────

/// Cruza o inventário com os contratos e produz a análise completa.
ResumoAnalise analisarEmpreendimento(
  List<Imovel> imoveis,
  List<Contrato> contratos,
) {
  final cotasPorImovel = projetarCotas(contratos);
  final avulsos = contratosAvulsos(contratos);

  final analises = <AnaliseImovel>[];
  final porTier = <TierCota, ResumoTier>{};
  final porBloco = <String, ResumoBloco>{};

  for (final imovel in imoveis) {
    final cotas = cotasPorImovel[imovel.id] ?? const <Cota>[];

    // Tier dominante e detecção de conflito.
    final tiersPresentes = cotas.map((c) => c.tier).whereType<TierCota>().toSet();
    final conflitoTier = tiersPresentes.length > 1;
    TierCota? tier;
    if (tiersPresentes.isNotEmpty) {
      // Tier mais frequente (estável mesmo com conflito).
      final freq = <TierCota, int>{};
      for (final c in cotas) {
        if (c.tier != null) freq[c.tier!] = (freq[c.tier!] ?? 0) + 1;
      }
      tier = freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }

    // Cotas distintas e duplicatas (mesmo rótulo em >1 contrato).
    final contagem = <String, int>{};
    for (final c in cotas) {
      contagem[c.numero] = (contagem[c.numero] ?? 0) + 1;
    }
    final duplicadas = contagem.entries
        .where((e) => e.value > 1)
        .map((e) => e.key)
        .toList();
    final cotasVendidas = contagem.length; // distintas

    final cotasTotal = tier?.cotasTotal;
    final disponiveis =
        cotasTotal == null ? null : (cotasTotal - cotasVendidas).clamp(0, cotasTotal);
    final ocupacao = (cotasTotal != null && cotasTotal > 0)
        ? (cotasVendidas / cotasTotal * 100).clamp(0, 100).toDouble()
        : 0.0;

    final SituacaoImovel situacao;
    if (cotasVendidas == 0) {
      situacao = SituacaoImovel.indefinido;
    } else if (cotasTotal != null && cotasVendidas >= cotasTotal) {
      situacao = SituacaoImovel.esgotado;
    } else {
      situacao = SituacaoImovel.parcial;
    }

    final analise = AnaliseImovel(
      imovel: imovel,
      tier: tier,
      cotas: cotas,
      cotasVendidas: cotasVendidas,
      cotasTotal: cotasTotal,
      disponiveis: disponiveis,
      ocupacaoPct: ocupacao,
      situacao: situacao,
      conflitoTier: conflitoTier,
      cotasDuplicadas: duplicadas,
    );
    analises.add(analise);

    // Agregação por tier.
    if (tier != null) {
      final rt = porTier.putIfAbsent(tier, () => ResumoTier(tier!));
      rt.imoveis++;
      rt.cotasVendidas += cotasVendidas;
      rt.cotasTotal += cotasTotal ?? 0;
    }

    // Agregação por bloco.
    final rb = porBloco.putIfAbsent(imovel.bloco, () => ResumoBloco(imovel.bloco));
    rb.unidades++;
    rb.cotasVendidas += cotasVendidas;
    rb.receita += analise.receita;
    if (situacao != SituacaoImovel.indefinido) rb.comVenda++;
    if (situacao == SituacaoImovel.esgotado) rb.esgotados++;
    if (situacao == SituacaoImovel.indefinido) rb.indefinidos++;
  }

  return ResumoAnalise(
    imoveis: analises,
    avulsos: avulsos,
    porTier: porTier,
    porBloco: porBloco,
  );
}

// ════════════════════════════════════════════════════════════════════════════
// EXPORT — Espelho de Vendas (CSV)
// ════════════════════════════════════════════════════════════════════════════
//
// Gera o CSV do espelho a partir da análise do empreendimento: uma linha por
// imóvel COM venda (situação != indefinido), nas colunas TIPO DE IMÓVEL ·
// TIPO COTA · BLOCO · IMOVEL · TOTAL COTAS · Reservado · Disponivel · Vendida.
//
// "Reservado" é sempre 0 por enquanto (ainda não há fonte de dados de reserva);
// a coluna existe no layout para preenchimento futuro. Como Reservado = 0,
// Disponível = Total − Vendida. Quando Vendida > Total (erro de dado / venda
// acima da capacidade), Disponível fica negativo de propósito, para a linha
// denunciar o problema em vez de mascará-lo.

/// Rótulo legível do bloco no espelho: 'A (ZEUS)', 'B (HERA)', etc.
String _blocoLabelEspelho(Imovel i) {
  switch (i.bloco) {
    case 'A':
      return 'A (ZEUS)';
    case 'B':
      return 'B (HERA)';
    case 'C':
      return 'C (AFRODITE)';
    case 'D':
      return 'D (ATENA)';
    case 'E':
      return 'E (APOLO)';
    case 'BANGALO':
      return 'Bangalô';
    default:
      return i.bloco;
  }
}

/// Escapa um campo CSV conforme RFC 4180 (aspas quando há vírgula/aspas/quebra).
String _csvCampoEspelho(String v) {
  if (v.contains(',') || v.contains('"') || v.contains('\r') || v.contains('\n')) {
    return '"${v.replaceAll('"', '""')}"';
  }
  return v;
}

/// Ordem dos blocos no espelho (A → B → C → D → E → Bangalô).
const Map<String, int> _ordemBlocoEspelho = {
  'A': 0, 'B': 1, 'C': 2, 'D': 3, 'E': 4, 'BANGALO': 5,
};

/// Gera o CSV do espelho de vendas (uma linha por imóvel com venda).
/// Inclui BOM UTF-8 e EOL CRLF para abrir corretamente no Excel/Numbers.
String csvEspelhoVendas(ResumoAnalise resumo) {
  const eol = '\r\n';
  final buffer = StringBuffer();
  buffer.write('\u{FEFF}'); // BOM UTF-8 (acentos no Excel)

  buffer.write([
    'TIPO DE IMÓVEL',
    'TIPO COTA',
    'BLOCO',
    'IMOVEL',
    'TOTAL COTAS',
    'Reservado',
    'Disponivel',
    'Vendida',
  ].join(','));
  buffer.write(eol);

  // Só imóveis com venda (tier definido), ordenados por bloco e número.
  final linhas = resumo.imoveis
      .where((a) => a.situacao != SituacaoImovel.indefinido && a.tier != null)
      .toList()
    ..sort((a, b) {
      final ob = (_ordemBlocoEspelho[a.imovel.bloco] ?? 99)
          .compareTo(_ordemBlocoEspelho[b.imovel.bloco] ?? 99);
      if (ob != 0) return ob;
      final na = int.tryParse(a.imovel.numero);
      final nb = int.tryParse(b.imovel.numero);
      if (na != null && nb != null) return na.compareTo(nb);
      return a.imovel.numero.compareTo(b.imovel.numero);
    });

  for (final a in linhas) {
    final total = a.cotasTotal ?? 0;
    const reservado = 0;
    final vendida = a.cotasVendidas;
    final disponivel = total - vendida - reservado;
    buffer.write([
      _csvCampoEspelho(a.imovel.tipo),
      _csvCampoEspelho(a.tier!.label),
      _csvCampoEspelho(_blocoLabelEspelho(a.imovel)),
      _csvCampoEspelho(a.imovel.numero),
      '$total',
      '$reservado',
      '$disponivel',
      '$vendida',
    ].join(','));
    buffer.write(eol);
  }

  return buffer.toString();
}

// ════════════════════════════════════════════════════════════════════════════
// ANÁLISE DE REVERSÃO (projeto antigo → atual)
// ════════════════════════════════════════════════════════════════════════════
//
// Contexto: contratos do projeto antigo foram refeitos no projeto atual. O
// contrato novo recebe em ORIGEM REVERSÃO o localizador do contrato antigo que
// substituiu. Logo, todo localizador que aparece como origem de reversão já foi
// revertido — não deveria seguir "Ativo".
//
// Produto do projeto ANTIGO = nome NÃO em caixa-alta (ex.: "Luxo Prata 1/2/3").
// Projeto atual usa caixa-alta (ex.: "LUXO MASTER PRATA 1º / 2º / 3º").

/// True se o produto é do projeto antigo (texto não totalmente em maiúsculo).
bool produtoProjetoAntigo(String produto) {
  final p = produto.trim();
  return p.isNotEmpty && p != p.toUpperCase();
}

/// Normaliza o valor de origem reversão: "0"/vazio → null.
String? _origemValida(Contrato c) {
  final o = (c.origemReversao ?? '').trim();
  if (o.isEmpty || o == '0') return null;
  return o;
}

/// Resultado da análise de reversão de uma carteira de contratos.
class AnaliseReversao {
  /// Ativos cujo localizador aparece como origem de reversão E o(s)
  /// substituto(s) NÃO está(ão) mais Ativo(s): reversão concluída, então o
  /// contrato deveria ter saído de Ativo. Caso crítico.
  final List<Contrato> statusErradoCritico;

  /// Ativos cujo localizador aparece como origem, mas algum substituto também
  /// está Ativo (cadeia de troca / duplicidade) — exige verificação manual.
  final List<Contrato> statusErradoVerificar;

  /// Produto antigo + Ativo + ainda NÃO revertido (não aparece como origem e
  /// REVERTIDO=Não): pendentes de reversão.
  final List<Contrato> pendentesNaoRevertidos;

  /// Produto antigo + Ativo + REVERTIDO=Sim, mas o rótulo do produto continua
  /// em minúsculo: provavelmente só falta atualizar o produto para caixa-alta.
  final List<Contrato> pendentesAmbiguos;

  /// Mapa localizador → contratos que o referenciam como origem (substitutos).
  final Map<String, List<Contrato>> substitutosPorLocalizador;

  const AnaliseReversao({
    required this.statusErradoCritico,
    required this.statusErradoVerificar,
    required this.pendentesNaoRevertidos,
    required this.pendentesAmbiguos,
    required this.substitutosPorLocalizador,
  });

  List<Contrato> get statusErrado =>
      [...statusErradoCritico, ...statusErradoVerificar];

  List<Contrato> get pendentes =>
      [...pendentesNaoRevertidos, ...pendentesAmbiguos];

  bool get temAlerta => statusErrado.isNotEmpty || pendentes.isNotEmpty;
}

/// Analisa reversões na carteira COMPLETA de contratos (precisa de todos os
/// status — Revertido/Cancelado entram no conjunto de origens). Ver
/// [AnaliseReversao].
AnaliseReversao analisarReversao(List<Contrato> todos) {
  // origem → substitutos que a referenciam
  final substitutos = <String, List<Contrato>>{};
  for (final c in todos) {
    final o = _origemValida(c);
    if (o != null) (substitutos[o] ??= []).add(c);
  }

  bool ativo(Contrato c) => contratoEfetivo(c);
  bool jaRevertido(Contrato c) => substitutos.containsKey(c.localizador);

  final critico = <Contrato>[];
  final verificar = <Contrato>[];
  final pendNao = <Contrato>[];
  final pendAmb = <Contrato>[];

  for (final c in todos) {
    if (!ativo(c)) continue;

    if (jaRevertido(c)) {
      // Já foi substituído: se algum substituto segue Ativo é cadeia/troca a
      // verificar; se todos saíram de Ativo, é status errado crítico.
      final subs = substitutos[c.localizador]!;
      if (subs.any(ativo)) {
        verificar.add(c);
      } else {
        critico.add(c);
      }
      continue;
    }

    // Não foi revertido ainda: só interessa quando o produto é do antigo.
    if (produtoProjetoAntigo(c.produto)) {
      if (c.revertido) {
        pendAmb.add(c);
      } else {
        pendNao.add(c);
      }
    }
  }

  return AnaliseReversao(
    statusErradoCritico: critico,
    statusErradoVerificar: verificar,
    pendentesNaoRevertidos: pendNao,
    pendentesAmbiguos: pendAmb,
    substitutosPorLocalizador: substitutos,
  );
}
