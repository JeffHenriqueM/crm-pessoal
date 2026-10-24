import 'semana_mp.dart';

/// Resultado de resolver o calendário de rodízio de um contrato: ou as semanas
/// (ok) ou o motivo de não ter sido possível (tier/cota/bloco/dia ausentes).
class ResolucaoCalendarioMP {
  final bool ok;
  final String? motivo; // preenchido quando !ok
  final String? tier; // ouro | prata | bronze
  final String? dia; // domingo | segunda | quinta | sexta | sabado
  final int? cota; // número da cota
  final List<SemanaMP> semanas;

  const ResolucaoCalendarioMP({
    required this.ok,
    this.motivo,
    this.tier,
    this.dia,
    this.cota,
    this.semanas = const [],
  });

  factory ResolucaoCalendarioMP.erro(String motivo,
          {String? tier, String? dia, int? cota}) =>
      ResolucaoCalendarioMP(
          ok: false, motivo: motivo, tier: tier, dia: dia, cota: cota);
}
