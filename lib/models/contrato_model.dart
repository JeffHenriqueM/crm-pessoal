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

  const Contrato({
    required this.localizador,
    required this.localizadorAtendimento,
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
  });

  bool get temAtrasos => valorAtrasado > 0;
  bool get estaQuitado => statusFinanceiro.toLowerCase() == 'quitado';
  String get nomeExibicao => nomeComprador;

  factory Contrato.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Contrato(
      localizador: doc.id,
      localizadorAtendimento: d['localizadorAtendimento'] as String? ?? '',
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
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'localizador': localizador,
      'localizadorAtendimento': localizadorAtendimento,
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
      'statusAssinatura': statusAssinatura.value,
      'atualizadoEm': FieldValue.serverTimestamp(),
    };
  }

  Contrato copyWith({
    StatusAssinatura? statusAssinatura,
  }) {
    return Contrato(
      localizador: localizador,
      localizadorAtendimento: localizadorAtendimento,
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
