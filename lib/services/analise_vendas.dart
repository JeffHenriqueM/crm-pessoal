// Lógica pura de análise financeira/temporal dos contratos da pós-venda.
// Sem dependência de Firestore/UI — recebe a lista de contratos e agrega.

import '../models/contrato_model.dart';

/// Venda agregada de um mês/ano.
class VendaMes {
  final int ano;
  final int mes;
  double valor; // soma de valorTotalReajustado (inclui ganhos de upgrade)
  int cotas; // contratos de cota fracionada
  int inteiros; // contratos de apartamento inteiro (Integral)
  int upgrades; // ganhos de upgrade lançados neste mês (não é unidade nova)
  double ganhoUpgrade; // soma do valor incremental dos upgrades deste mês
  final List<Contrato> contratos = [];
  VendaMes(this.ano, this.mes,
      {this.valor = 0,
      this.cotas = 0,
      this.inteiros = 0,
      this.upgrades = 0,
      this.ganhoUpgrade = 0});

  int get total => cotas + inteiros;
}

bool _ehIntegral(Contrato c) => c.cota.trim().toLowerCase() == 'integral';

/// Agrupa contratos por ano/mês da `dataContrato`. Contratos sem data são
/// ignorados. Ordenado do mais recente para o mais antigo.
List<VendaMes> vendasPorMes(List<Contrato> contratos) {
  final mapa = <String, VendaMes>{};
  for (final c in contratos) {
    final d = c.dataContrato;
    if (d == null) continue;
    final vm = mapa.putIfAbsent('${d.year}-${d.month}', () => VendaMes(d.year, d.month));
    vm.valor += c.valorTotalReajustado;
    vm.contratos.add(c);
    if (_ehIntegral(c)) {
      vm.inteiros++;
    } else {
      vm.cotas++;
    }
  }
  final lista = mapa.values.toList()
    ..sort((a, b) =>
        a.ano != b.ano ? b.ano.compareTo(a.ano) : b.mes.compareTo(a.mes));
  return lista;
}

/// Agrupa as vendas mensais por ano (cada ano com seus meses, recente primeiro).
Map<int, List<VendaMes>> vendasPorAno(List<Contrato> contratos) {
  final out = <int, List<VendaMes>>{};
  for (final vm in vendasPorMes(contratos)) {
    (out[vm.ano] ??= []).add(vm);
  }
  return out;
}

// ── Reversão: re-datação da venda ────────────────────────────────────────────
//
// Um contrato refeito no projeto atual (com ORIGEM REVERSÃO) não é uma venda
// nova: ele substitui um contrato anterior. A venda real aconteceu na data do
// contrato ORIGINAL (raiz da cadeia de reversão), não na data do refazimento.
//
//  • Reversão pura (mesmo produto) ou downgrade  → venda inteira vai p/ a data
//    da raiz (não conta como venda nova no mês do refazimento).
//  • Upgrade (subiu de tier/linha)               → conta nos DOIS: a base na
//    data da raiz e o GANHO incremental na data nova.

String _semAcentoMin(String s) => _semAcento(s);

/// Ordem das LINHAS de produto (menor → maior), conforme regra de negócio.
/// Substrings checadas da mais específica para a mais genérica.
const List<(String, int)> _ordemLinha = [
  ('bangalo', 7),
  ('villamor super master', 6),
  ('villamor premium', 5),
  ('villamor', 4),
  ('luxo premium', 3),
  ('luxo master', 2),
  ('luxo', 1),
];

/// Ordem dos METAIS (menor → maior). Integral = apartamento inteiro (topo).
int _rankMetal(String produto, String cota) {
  if (cota.trim().toLowerCase() == 'integral') return 5;
  final p = _semAcentoMin(produto);
  if (p.contains('diamante')) return 4;
  if (p.contains('ouro')) return 3;
  if (p.contains('prata')) return 2;
  if (p.contains('bronze')) return 1;
  return 0;
}

int _rankLinha(String produto) {
  final p = _semAcentoMin(produto);
  for (final (sub, rank) in _ordemLinha) {
    if (p.contains(sub)) return rank;
  }
  return 0;
}

/// Rank comparável de um produto: linha (primária) e metal (secundária).
/// Maior = melhor. Usado para detectar upgrade/downgrade na reversão.
int rankProduto(String produto, String cota) =>
    _rankLinha(produto) * 10 + _rankMetal(produto, cota);

/// Segue a cadeia de [origemReversao] até a raiz (contrato original). Retorna
/// null se o contrato não é uma reversão (sem origem) ou se a origem não está
/// no mapa. Protegido contra ciclos.
Contrato? raizReversao(Contrato c, Map<String, Contrato> porId) {
  final visitados = <String>{c.localizador};
  Contrato atual = c;
  while (true) {
    final o = (atual.origemReversao ?? '').trim();
    if (o.isEmpty || o == '0') break;
    final pai = porId[o];
    if (pai == null || !visitados.add(o)) break;
    atual = pai;
  }
  return identical(atual, c) ? null : atual;
}

enum TipoReversao { nenhuma, pura, downgrade, upgrade }

class ClassificacaoReversao {
  final TipoReversao tipo;
  final Contrato? raiz;
  final double ganho; // só p/ upgrade: valorNovo - valorRaiz (>= 0)
  const ClassificacaoReversao(this.tipo, {this.raiz, this.ganho = 0});
}

/// Classifica um contrato quanto à reversão, comparando com a raiz da cadeia.
ClassificacaoReversao classificarReversao(
    Contrato c, Map<String, Contrato> porId) {
  final raiz = raizReversao(c, porId);
  if (raiz == null) return const ClassificacaoReversao(TipoReversao.nenhuma);
  final rc = rankProduto(c.produto, c.cota);
  final rr = rankProduto(raiz.produto, raiz.cota);
  if (rc > rr) {
    final ganho = c.valorTotalReajustado - raiz.valorTotalReajustado;
    return ClassificacaoReversao(TipoReversao.upgrade,
        raiz: raiz, ganho: ganho > 0 ? ganho : 0);
  }
  if (rc < rr) {
    return ClassificacaoReversao(TipoReversao.downgrade, raiz: raiz);
  }
  return ClassificacaoReversao(TipoReversao.pura, raiz: raiz);
}

/// Igual a [vendasPorMes], mas re-data as reversões: a venda de um contrato
/// revertido é contabilizada na data do contrato ORIGINAL (raiz). Upgrades
/// lançam a base na data antiga e o ganho incremental na data nova.
///
/// [efetivos] são os contratos vigentes (Ativo); [todosPorId] é a carteira
/// COMPLETA indexada por localizador (para resolver as raízes, que estão como
/// Revertido e não entram em [efetivos]).
List<VendaMes> vendasPorMesAjustado(
  List<Contrato> efetivos,
  Map<String, Contrato> todosPorId,
) {
  final mapa = <String, VendaMes>{};
  VendaMes mes(DateTime d) =>
      mapa.putIfAbsent('${d.year}-${d.month}', () => VendaMes(d.year, d.month));

  for (final c in efetivos) {
    final cls = classificarReversao(c, todosPorId);
    final dataNova = c.dataContrato;
    final dataRaiz = cls.raiz?.dataContrato ?? dataNova;

    switch (cls.tipo) {
      case TipoReversao.nenhuma:
        if (dataNova == null) continue;
        final vm = mes(dataNova);
        vm.valor += c.valorTotalReajustado;
        vm.contratos.add(c);
        _ehIntegral(c) ? vm.inteiros++ : vm.cotas++;
        break;
      case TipoReversao.pura:
      case TipoReversao.downgrade:
        // Venda inteira vai para a data da raiz (não é venda nova).
        if (dataRaiz == null) continue;
        final vm = mes(dataRaiz);
        vm.valor += c.valorTotalReajustado;
        vm.contratos.add(c);
        _ehIntegral(c) ? vm.inteiros++ : vm.cotas++;
        break;
      case TipoReversao.upgrade:
        // Base na data da raiz (unidade) + ganho na data nova.
        if (dataRaiz != null) {
          final base = mes(dataRaiz);
          base.valor += cls.raiz!.valorTotalReajustado;
          base.contratos.add(cls.raiz!);
          _ehIntegral(c) ? base.inteiros++ : base.cotas++;
        }
        if (dataNova != null && cls.ganho > 0) {
          final novo = mes(dataNova);
          novo.valor += cls.ganho;
          novo.ganhoUpgrade += cls.ganho;
          novo.upgrades++;
          novo.contratos.add(c);
        }
        break;
    }
  }

  final lista = mapa.values.toList()
    ..sort((a, b) =>
        a.ano != b.ano ? b.ano.compareTo(a.ano) : b.mes.compareTo(a.mes));
  return lista;
}

/// Versão ajustada de [vendasPorAno] (ver [vendasPorMesAjustado]).
Map<int, List<VendaMes>> vendasPorAnoAjustado(
  List<Contrato> efetivos,
  Map<String, Contrato> todosPorId,
) {
  final out = <int, List<VendaMes>>{};
  for (final vm in vendasPorMesAjustado(efetivos, todosPorId)) {
    (out[vm.ano] ??= []).add(vm);
  }
  return out;
}

// ── Permuta ─────────────────────────────────────────────────────────────────
// Provisório: ainda não há marcação de permuta nos contratos, então
// identificamos pelos compradores conhecidos. Cada entrada é uma lista de
// tokens que precisam TODOS aparecer no nome (robusto a nome do meio/abreviação).
const List<List<String>> kCompradoresPermuta = [
  ['mateus', 'camilo'],
];

String _semAcento(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const para = 'aaaaaeeeeiiiiooooouuuuc';
  var r = s.toLowerCase();
  for (var i = 0; i < de.length; i++) {
    r = r.replaceAll(de[i], para[i]);
  }
  return r;
}

/// True se o contrato é venda por permuta (pelo comprador conhecido).
bool ehPermuta(Contrato c) {
  final nome = _semAcento(c.nomeComprador);
  return kCompradoresPermuta
      .any((tokens) => tokens.every((t) => nome.contains(_semAcento(t))));
}

/// Contratos vendidos por permuta.
List<Contrato> contratosPermuta(List<Contrato> contratos) =>
    contratos.where(ehPermuta).toList();

/// Total a receber: soma dos saldos restantes dos contratos não quitados.
double valorAReceber(List<Contrato> contratos) =>
    contratos.where((c) => !c.estaQuitado).fold(0.0, (s, c) => s + c.saldoRestante);

/// Total já vendido (valor de tabela reajustado de todos os contratos).
double valorVendidoTotal(List<Contrato> contratos) =>
    contratos.fold(0.0, (s, c) => s + c.valorTotalReajustado);

/// Data da última atualização dos dados (maior `atualizadoEm`) — reflete o
/// último arquivo Excel importado.
DateTime? dataAtualizacaoDados(List<Contrato> contratos) {
  DateTime? max;
  for (final c in contratos) {
    final a = c.atualizadoEm;
    if (a != null && (max == null || a.isAfter(max))) max = a;
  }
  return max;
}

/// Contratos há muito tempo sem pagamento: não quitados que estão em atraso
/// (valorAtrasado > 0) ou com próximo vencimento vencido há mais de [diasMin].
/// Ordenado do mais crítico (vencimento mais antigo) para o menos.
List<Contrato> contratosSemPagamento(
  List<Contrato> contratos, {
  required DateTime agora,
  int diasMin = 60,
}) {
  bool criterio(Contrato c) {
    if (c.estaQuitado) return false;
    if (c.valorAtrasado > 0) return true;
    final v = c.dataProximoVencimento;
    return v != null && agora.difference(v).inDays >= diasMin;
  }

  final lista = contratos.where(criterio).toList();
  lista.sort((a, b) {
    final va = a.dataProximoVencimento ?? DateTime(9999);
    final vb = b.dataProximoVencimento ?? DateTime(9999);
    return va.compareTo(vb);
  });
  return lista;
}
