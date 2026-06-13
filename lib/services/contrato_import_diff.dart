import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/contrato_model.dart';

/// Resultado da análise de uma importação de contratos: o que **realmente**
/// muda em relação aos dados atuais (comparando o que seria gravado pelo merge).
class DiffImportContratos {
  /// Contratos existentes cujo conteúdo a importar difere do atual.
  final List<ContratoAlterado> alterados;

  /// Contratos da planilha que ainda não existem na base.
  final List<Contrato> novos;

  /// Quantos já existem e ficariam idênticos (nenhuma gravação efetiva).
  final int inalterados;

  const DiffImportContratos({
    required this.alterados,
    required this.novos,
    required this.inalterados,
  });

  /// Contratos que serão de fato gravados (alterados + novos).
  List<Contrato> get paraGravar =>
      [...alterados.map((a) => a.contrato), ...novos];

  int get total => alterados.length + novos.length + inalterados;
}

/// Um contrato existente que mudou, com os rótulos dos campos alterados.
class ContratoAlterado {
  final Contrato contrato;
  final List<String> campos; // rótulos legíveis, sem repetição
  const ContratoAlterado(this.contrato, this.campos);
}

/// Compara os contratos da planilha [novos] com os [atuais] (por localizador) e
/// devolve apenas o que muda. "Mudou" = ao menos um campo que o merge gravaria
/// (`toFirestore()`) tem valor diferente do atual. Campos nossos (assinatura,
/// link, etc.) não entram no `toFirestore()`, então nunca contam como mudança.
DiffImportContratos analisarImportContratos(
  List<Contrato> novos,
  Map<String, Contrato> atuais,
) {
  final alterados = <ContratoAlterado>[];
  final criados = <Contrato>[];
  var inalterados = 0;

  for (final c in novos) {
    final atual = atuais[c.localizador];
    if (atual == null) {
      criados.add(c);
      continue;
    }
    final campos = _camposAlterados(c, atual);
    if (campos.isEmpty) {
      inalterados++;
    } else {
      alterados.add(ContratoAlterado(c, campos));
    }
  }

  return DiffImportContratos(
    alterados: alterados,
    novos: criados,
    inalterados: inalterados,
  );
}

/// Rótulos (sem repetição, em ordem) dos campos que o merge mudaria.
List<String> _camposAlterados(Contrato novo, Contrato atual) {
  final n = novo.toFirestore();
  final a = atual.toFirestore();
  final rotulos = <String>[];
  for (final entry in n.entries) {
    if (entry.key == 'localizador') continue; // é a própria chave
    if (!_iguais(entry.value, a[entry.key])) {
      final r = _rotulo(entry.key);
      if (!rotulos.contains(r)) rotulos.add(r);
    }
  }
  return rotulos;
}

/// Igualdade tolerante a tipos de valor de campo do Firestore.
///
/// Datas (campos `Timestamp`) são comparadas por **dia de calendário (UTC)**, e
/// não pelo instante exato: os campos do contrato são datas (sem hora) e o
/// horário gravado varia com o fuso de quem importa (a base foi escrita à
/// meia-noite de Brasília = `T03:00:00Z`). Comparar o instante marcaria quase
/// todo contrato como alterado por uma diferença de horas no mesmo dia.
/// `0 == 0.0` é verdadeiro em Dart, então num cruza tipo sem ajuste.
bool _iguais(Object? x, Object? y) {
  if (x is Timestamp && y is Timestamp) {
    final dx = x.toDate().toUtc();
    final dy = y.toDate().toUtc();
    return dx.year == dy.year && dx.month == dy.month && dx.day == dy.day;
  }
  return x == y;
}

/// Mapa de campo do `toFirestore()` → rótulo legível. Vários campos relacionados
/// (endereço, nascimento) colapsam num único rótulo para não poluir.
String _rotulo(String campo) {
  switch (campo) {
    case 'localizadorAtendimento':
      return 'loc. atendimento';
    case 'codigoContrato':
      return 'código';
    case 'dataContrato':
      return 'data do contrato';
    case 'nomeComprador':
      return 'nome';
    case 'cpfComprador':
      return 'CPF';
    case 'emailComprador':
      return 'e-mail';
    case 'telefoneComprador':
      return 'telefone';
    case 'dataNascimentoComprador':
    case 'diaNascimentoComprador':
    case 'mesNascimentoComprador':
      return 'nascimento';
    case 'nomeComprador2':
      return 'cônjuge';
    case 'cpfComprador2':
      return 'CPF cônjuge';
    case 'emailComprador2':
      return 'e-mail cônjuge';
    case 'telefoneComprador2':
      return 'telefone cônjuge';
    case 'dataNascimentoComprador2':
    case 'diaNascimentoComprador2':
    case 'mesNascimentoComprador2':
      return 'nascimento cônjuge';
    case 'logradouro':
    case 'numero':
    case 'complemento':
    case 'bairro':
    case 'cidade':
    case 'estado':
    case 'pais':
      return 'endereço';
    case 'sala':
      return 'sala';
    case 'bloco':
      return 'bloco';
    case 'imovel':
      return 'imóvel';
    case 'produto':
      return 'produto';
    case 'cota':
      return 'cota';
    case 'status':
      return 'status';
    case 'revertido':
    case 'origemReversao':
      return 'reversão';
    case 'statusFinanceiro':
      return 'status financeiro';
    case 'dataQuitacao':
      return 'data quitação';
    case 'entrada':
      return 'entrada';
    case 'saldoRestante':
      return 'saldo restante';
    case 'valorFinanciado':
      return 'valor financiado';
    case 'valorIntegralizado':
      return 'valor integralizado';
    case 'valorAtrasado':
      return 'valor atrasado';
    case 'percentualIntegralizado':
      return '% integralizado';
    case 'valorTotalReajustado':
      return 'valor reajustado';
    case 'dataProximoVencimento':
      return 'próx. vencimento';
    case 'vendedorCloser':
      return 'vendedor';
    case 'captador':
      return 'captador';
    case 'vendedorLiner':
      return 'liner';
    case 'pontoCapatcao':
      return 'ponto de captação';
    default:
      return campo;
  }
}
