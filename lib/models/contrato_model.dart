import 'package:cloud_firestore/cloud_firestore.dart';

enum StatusAssinatura {
  naoAssinado,
  emAndamento,
  assinado;

  String get label {
    switch (this) {
      case StatusAssinatura.naoAssinado:
        return 'Não assinado';
      case StatusAssinatura.emAndamento:
        return 'Em andamento';
      case StatusAssinatura.assinado:
        return 'Assinado';
    }
  }

  static StatusAssinatura fromString(String? v) {
    switch (v) {
      case 'em_andamento':
        return StatusAssinatura.emAndamento;
      case 'assinado':
        return StatusAssinatura.assinado;
      default:
        return StatusAssinatura.naoAssinado;
    }
  }

  // Converte o texto legível do CSV ("Assinado", "Em andamento", etc.)
  static StatusAssinatura fromCsvLabel(String v) {
    final s = v.toLowerCase().trim();
    if (s == 'assinado') return StatusAssinatura.assinado;
    if (s.contains('andamento')) return StatusAssinatura.emAndamento;
    return StatusAssinatura.naoAssinado;
  }

  String get value {
    switch (this) {
      case StatusAssinatura.naoAssinado:
        return 'nao_assinado';
      case StatusAssinatura.emAndamento:
        return 'em_andamento';
      case StatusAssinatura.assinado:
        return 'assinado';
    }
  }
}

class Contrato {
  final String localizador;
  final String localizadorAtendimento;

  /// Número/código do contrato (ex.: "LMP-1590-320/Cota-15"). Vem da coluna
  /// CÓDIGO da Central de Contratos e é a chave que casa com o PDF no Drive.
  final String? codigoContrato;

  final DateTime? dataContrato;

  // Comprador principal
  final String nomeComprador;
  final String cpfComprador;
  final String emailComprador;
  final String telefoneComprador;
  final DateTime? dataNascimentoComprador;
  final int? diaNascimentoComprador;
  final int? mesNascimentoComprador;

  // Comprador secundário (cônjuge/sócio)
  final String? nomeComprador2;
  final String? cpfComprador2;
  final String? emailComprador2;
  final String? telefoneComprador2;
  final DateTime? dataNascimentoComprador2;
  final int? diaNascimentoComprador2;
  final int? mesNascimentoComprador2;

  // Endereço
  final String logradouro;
  final String numero;
  final String complemento;
  final String bairro;
  final String cidade;
  final String estado;
  final String pais;

  // Produto
  final String sala;
  final String bloco;
  final String imovel;
  final String produto;
  final String cota;
  final String status;

  /// Reversão de projeto antigo → atual. `origemReversao` é o localizador do
  /// contrato anterior que este substituiu (vazio/"0" quando não houve). Vêm da
  /// Central de Contratos (colunas REVERTIDO e ORIGEM REVERSÃO).
  final bool revertido;
  final String? origemReversao;

  // Financeiro
  final String statusFinanceiro;
  final DateTime? dataQuitacao;
  final double entrada;
  final double saldoRestante;
  final double valorFinanciado;
  final double valorIntegralizado;
  final double valorAtrasado;
  final double percentualIntegralizado;
  final double valorTotalReajustado;
  final DateTime? dataProximoVencimento;

  // Equipe comercial
  final String vendedorCloser;
  final String captador;
  final String vendedorLiner;
  final String pontoCapatcao;

  // Pós-venda
  final StatusAssinatura statusAssinatura;

  // Auditoria
  final DateTime? criadoEm;
  final DateTime? atualizadoEm;

  /// Contador de interações por mês {'AAAA-M': qtd}. Mantido pelo
  /// FirestoreService (não é serializado no toFirestore para que o re-import
  /// por merge não zere o contador). Usado na meta de pós-venda.
  final Map<String, int> interacoesPorMes;

  /// Marcos de upgrade (meta de captação de upgrade do pós-venda). Não são
  /// serializados no toFirestore para sobreviver ao re-import por merge.
  final DateTime? upgradeOferecidoEm;
  final DateTime? upgradeRealizadoEm;

  /// Link do PDF do contrato no Google Drive. Definido manualmente; não é
  /// serializado no toFirestore para sobreviver ao re-import por merge.
  final String? linkContratoDrive;

  /// Alerta de que o contrato precisa de reajuste de dados (ex.: status/produto
  /// a corrigir, pendente de acerto no sistema de origem). Anotação interna do
  /// CRM; não é serializada no toFirestore (sobrevive ao re-import por merge).
  final bool precisaReajuste;
  final String? motivoReajuste;

  const Contrato({
    required this.localizador,
    required this.localizadorAtendimento,
    this.codigoContrato,
    this.dataContrato,
    required this.nomeComprador,
    this.cpfComprador = '',
    this.emailComprador = '',
    this.telefoneComprador = '',
    this.dataNascimentoComprador,
    this.diaNascimentoComprador,
    this.mesNascimentoComprador,
    this.nomeComprador2,
    this.cpfComprador2,
    this.emailComprador2,
    this.telefoneComprador2,
    this.dataNascimentoComprador2,
    this.diaNascimentoComprador2,
    this.mesNascimentoComprador2,
    this.logradouro = '',
    this.numero = '',
    this.complemento = '',
    this.bairro = '',
    this.cidade = '',
    this.estado = '',
    this.pais = 'Brasil',
    this.sala = '',
    this.bloco = '',
    this.imovel = '',
    this.produto = '',
    this.cota = '',
    this.status = 'Ativo',
    this.revertido = false,
    this.origemReversao,
    this.statusFinanceiro = 'Em andamento',
    this.dataQuitacao,
    this.entrada = 0,
    this.saldoRestante = 0,
    this.valorFinanciado = 0,
    this.valorIntegralizado = 0,
    this.valorAtrasado = 0,
    this.percentualIntegralizado = 0,
    this.valorTotalReajustado = 0,
    this.dataProximoVencimento,
    this.vendedorCloser = '',
    this.captador = '',
    this.vendedorLiner = '',
    this.pontoCapatcao = '',
    this.statusAssinatura = StatusAssinatura.naoAssinado,
    this.criadoEm,
    this.atualizadoEm,
    this.interacoesPorMes = const {},
    this.upgradeOferecidoEm,
    this.upgradeRealizadoEm,
    this.linkContratoDrive,
    this.precisaReajuste = false,
    this.motivoReajuste,
  });

  bool get temAtrasos => valorAtrasado > 0;
  bool get estaQuitado => statusFinanceiro.toLowerCase() == 'quitado';
  String get nomeExibicao => nomeComprador;

  /// True se o contrato teve ao menos uma interação no mês corrente.
  bool get contatadoEsteMes {
    final a = DateTime.now();
    return (interacoesPorMes['${a.year}-${a.month}'] ?? 0) > 0;
  }

  bool get upgradeOferecido => upgradeOferecidoEm != null;
  bool get upgradeRealizado => upgradeRealizadoEm != null;

  factory Contrato.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Contrato(
      localizador: doc.id,
      localizadorAtendimento: d['localizadorAtendimento'] as String? ?? '',
      codigoContrato: d['codigoContrato'] as String?,
      dataContrato: (d['dataContrato'] as Timestamp?)?.toDate(),
      nomeComprador: d['nomeComprador'] as String? ?? '',
      cpfComprador: d['cpfComprador'] as String? ?? '',
      emailComprador: d['emailComprador'] as String? ?? '',
      telefoneComprador: d['telefoneComprador'] as String? ?? '',
      dataNascimentoComprador:
          (d['dataNascimentoComprador'] as Timestamp?)?.toDate(),
      diaNascimentoComprador: d['diaNascimentoComprador'] as int?,
      mesNascimentoComprador: d['mesNascimentoComprador'] as int?,
      nomeComprador2: d['nomeComprador2'] as String?,
      cpfComprador2: d['cpfComprador2'] as String?,
      emailComprador2: d['emailComprador2'] as String?,
      telefoneComprador2: d['telefoneComprador2'] as String?,
      dataNascimentoComprador2:
          (d['dataNascimentoComprador2'] as Timestamp?)?.toDate(),
      diaNascimentoComprador2: d['diaNascimentoComprador2'] as int?,
      mesNascimentoComprador2: d['mesNascimentoComprador2'] as int?,
      logradouro: d['logradouro'] as String? ?? '',
      numero: d['numero'] as String? ?? '',
      complemento: d['complemento'] as String? ?? '',
      bairro: d['bairro'] as String? ?? '',
      cidade: d['cidade'] as String? ?? '',
      estado: d['estado'] as String? ?? '',
      pais: d['pais'] as String? ?? 'Brasil',
      sala: d['sala'] as String? ?? '',
      bloco: d['bloco'] as String? ?? '',
      imovel: d['imovel'] as String? ?? '',
      produto: d['produto'] as String? ?? '',
      cota: d['cota'] as String? ?? '',
      status: d['status'] as String? ?? 'Ativo',
      revertido: d['revertido'] as bool? ?? false,
      origemReversao: d['origemReversao'] as String?,
      statusFinanceiro: d['statusFinanceiro'] as String? ?? 'Em andamento',
      dataQuitacao: (d['dataQuitacao'] as Timestamp?)?.toDate(),
      entrada: _toDouble(d['entrada']),
      saldoRestante: _toDouble(d['saldoRestante']),
      valorFinanciado: _toDouble(d['valorFinanciado']),
      valorIntegralizado: _toDouble(d['valorIntegralizado']),
      valorAtrasado: _toDouble(d['valorAtrasado']),
      percentualIntegralizado: _toDouble(d['percentualIntegralizado']),
      valorTotalReajustado: _toDouble(d['valorTotalReajustado']),
      dataProximoVencimento:
          (d['dataProximoVencimento'] as Timestamp?)?.toDate(),
      vendedorCloser: d['vendedorCloser'] as String? ?? '',
      captador: d['captador'] as String? ?? '',
      vendedorLiner: d['vendedorLiner'] as String? ?? '',
      pontoCapatcao: d['pontoCapatcao'] as String? ?? '',
      statusAssinatura:
          StatusAssinatura.fromString(d['statusAssinatura'] as String?),
      criadoEm: (d['criadoEm'] as Timestamp?)?.toDate(),
      atualizadoEm: (d['atualizadoEm'] as Timestamp?)?.toDate(),
      interacoesPorMes: (d['interacoesPorMes'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0)) ??
          const {},
      upgradeOferecidoEm: (d['upgradeOferecidoEm'] as Timestamp?)?.toDate(),
      upgradeRealizadoEm: (d['upgradeRealizadoEm'] as Timestamp?)?.toDate(),
      linkContratoDrive: d['linkContratoDrive'] as String?,
      precisaReajuste: d['precisaReajuste'] as bool? ?? false,
      motivoReajuste: d['motivoReajuste'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'localizador': localizador,
      'localizadorAtendimento': localizadorAtendimento,
      if (codigoContrato != null) 'codigoContrato': codigoContrato,
      if (dataContrato != null)
        'dataContrato': Timestamp.fromDate(dataContrato!),
      'nomeComprador': nomeComprador,
      'cpfComprador': cpfComprador,
      'emailComprador': emailComprador,
      'telefoneComprador': telefoneComprador,
      if (dataNascimentoComprador != null)
        'dataNascimentoComprador': Timestamp.fromDate(dataNascimentoComprador!),
      if (diaNascimentoComprador != null)
        'diaNascimentoComprador': diaNascimentoComprador,
      if (mesNascimentoComprador != null)
        'mesNascimentoComprador': mesNascimentoComprador,
      if (nomeComprador2 != null) 'nomeComprador2': nomeComprador2,
      if (cpfComprador2 != null) 'cpfComprador2': cpfComprador2,
      if (emailComprador2 != null) 'emailComprador2': emailComprador2,
      if (telefoneComprador2 != null) 'telefoneComprador2': telefoneComprador2,
      if (dataNascimentoComprador2 != null)
        'dataNascimentoComprador2':
            Timestamp.fromDate(dataNascimentoComprador2!),
      if (diaNascimentoComprador2 != null)
        'diaNascimentoComprador2': diaNascimentoComprador2,
      if (mesNascimentoComprador2 != null)
        'mesNascimentoComprador2': mesNascimentoComprador2,
      'logradouro': logradouro,
      'numero': numero,
      'complemento': complemento,
      'bairro': bairro,
      'cidade': cidade,
      'estado': estado,
      'pais': pais,
      'sala': sala,
      'bloco': bloco,
      'imovel': imovel,
      'produto': produto,
      'cota': cota,
      'status': status,
      'revertido': revertido,
      if (origemReversao != null) 'origemReversao': origemReversao,
      'statusFinanceiro': statusFinanceiro,
      if (dataQuitacao != null)
        'dataQuitacao': Timestamp.fromDate(dataQuitacao!),
      'entrada': entrada,
      'saldoRestante': saldoRestante,
      'valorFinanciado': valorFinanciado,
      'valorIntegralizado': valorIntegralizado,
      'valorAtrasado': valorAtrasado,
      'percentualIntegralizado': percentualIntegralizado,
      'valorTotalReajustado': valorTotalReajustado,
      if (dataProximoVencimento != null)
        'dataProximoVencimento': Timestamp.fromDate(dataProximoVencimento!),
      'vendedorCloser': vendedorCloser,
      'captador': captador,
      'vendedorLiner': vendedorLiner,
      'pontoCapatcao': pontoCapatcao,
      // statusAssinatura NÃO é serializado aqui: é mantido apenas via
      // atualizarStatusAssinatura(), para sobreviver ao re-import por merge.
      'atualizadoEm': FieldValue.serverTimestamp(),
    };
  }

  Contrato copyWith({
    StatusAssinatura? statusAssinatura,
    String? linkContratoDrive,
    String? codigoContrato,
  }) {
    return Contrato(
      localizador: localizador,
      localizadorAtendimento: localizadorAtendimento,
      codigoContrato: codigoContrato ?? this.codigoContrato,
      dataContrato: dataContrato,
      nomeComprador: nomeComprador,
      cpfComprador: cpfComprador,
      emailComprador: emailComprador,
      telefoneComprador: telefoneComprador,
      dataNascimentoComprador: dataNascimentoComprador,
      diaNascimentoComprador: diaNascimentoComprador,
      mesNascimentoComprador: mesNascimentoComprador,
      nomeComprador2: nomeComprador2,
      cpfComprador2: cpfComprador2,
      emailComprador2: emailComprador2,
      telefoneComprador2: telefoneComprador2,
      dataNascimentoComprador2: dataNascimentoComprador2,
      diaNascimentoComprador2: diaNascimentoComprador2,
      mesNascimentoComprador2: mesNascimentoComprador2,
      logradouro: logradouro,
      numero: numero,
      complemento: complemento,
      bairro: bairro,
      cidade: cidade,
      estado: estado,
      pais: pais,
      sala: sala,
      bloco: bloco,
      imovel: imovel,
      produto: produto,
      cota: cota,
      status: status,
      revertido: revertido,
      origemReversao: origemReversao,
      statusFinanceiro: statusFinanceiro,
      dataQuitacao: dataQuitacao,
      entrada: entrada,
      saldoRestante: saldoRestante,
      valorFinanciado: valorFinanciado,
      valorIntegralizado: valorIntegralizado,
      valorAtrasado: valorAtrasado,
      percentualIntegralizado: percentualIntegralizado,
      valorTotalReajustado: valorTotalReajustado,
      dataProximoVencimento: dataProximoVencimento,
      vendedorCloser: vendedorCloser,
      captador: captador,
      vendedorLiner: vendedorLiner,
      pontoCapatcao: pontoCapatcao,
      statusAssinatura: statusAssinatura ?? this.statusAssinatura,
      criadoEm: criadoEm,
      atualizadoEm: atualizadoEm,
      linkContratoDrive: linkContratoDrive ?? this.linkContratoDrive,
      precisaReajuste: precisaReajuste,
      motivoReajuste: motivoReajuste,
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
    return 0.0;
  }
}
