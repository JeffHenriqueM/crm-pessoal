import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoCampanha { desconto, condicao }

extension TipoCampanhaExt on TipoCampanha {
  String get nomeDisplay =>
      this == TipoCampanha.desconto ? 'Desconto %' : 'Condição Especial';
  String get nome => name;
}

class Campanha {
  final String? id;
  final String nome;
  final TipoCampanha tipo;
  final double? valorDesconto; // só quando tipo == desconto
  final String? condicao;      // só quando tipo == condicao
  final DateTime dataInicio;
  final DateTime dataFim;
  final bool ativa;
  final String? criadoPorId;
  final String? criadoPorNome;
  final DateTime? criadoEm;

  const Campanha({
    this.id,
    required this.nome,
    required this.tipo,
    this.valorDesconto,
    this.condicao,
    required this.dataInicio,
    required this.dataFim,
    this.ativa = false,
    this.criadoPorId,
    this.criadoPorNome,
    this.criadoEm,
  });

  bool get vigente {
    final agora = DateTime.now();
    return ativa &&
        !agora.isBefore(dataInicio) &&
        agora.isBefore(dataFim.add(const Duration(days: 1)));
  }

  String get resumo {
    if (tipo == TipoCampanha.desconto && valorDesconto != null) {
      return '${valorDesconto!.toStringAsFixed(valorDesconto! == valorDesconto!.truncateToDouble() ? 0 : 1)}% de desconto';
    }
    return condicao ?? '';
  }

  factory Campanha.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Campanha(
      id: doc.id,
      nome: d['nome'] ?? '',
      tipo: d['tipo'] == 'desconto' ? TipoCampanha.desconto : TipoCampanha.condicao,
      valorDesconto: (d['valorDesconto'] as num?)?.toDouble(),
      condicao: d['condicao'],
      dataInicio: (d['dataInicio'] as Timestamp).toDate(),
      dataFim: (d['dataFim'] as Timestamp).toDate(),
      ativa: d['ativa'] ?? false,
      criadoPorId: d['criadoPorId'],
      criadoPorNome: d['criadoPorNome'],
      criadoEm: (d['criadoEm'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'nome': nome,
        'tipo': tipo.nome,
        'valorDesconto': valorDesconto,
        'condicao': condicao,
        'dataInicio': Timestamp.fromDate(dataInicio),
        'dataFim': Timestamp.fromDate(dataFim),
        'ativa': ativa,
        'criadoPorId': criadoPorId,
        'criadoPorNome': criadoPorNome,
      };
}
