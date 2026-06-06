// Lógica pura de análise financeira/temporal dos contratos da pós-venda.
// Sem dependência de Firestore/UI — recebe a lista de contratos e agrega.

import '../models/contrato_model.dart';

/// Venda agregada de um mês/ano.
class VendaMes {
  final int ano;
  final int mes;
  double valor; // soma de valorTotalReajustado
  int cotas; // contratos de cota fracionada
  int inteiros; // contratos de apartamento inteiro (Integral)
  VendaMes(this.ano, this.mes,
      {this.valor = 0, this.cotas = 0, this.inteiros = 0});

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
