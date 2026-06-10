// lib/utils/datas_uteis.dart

/// Soma [dias] dias ÚTEIS a [base], pulando sábados e domingos.
///
/// Usada para sugerir o `proximoContato` ao registrar uma interação:
/// um contato feito hoje agenda o próximo follow-up alguns dias à frente,
/// tirando o lead do estado "em atraso" sem cair num fim de semana.
///
/// O horário de [base] é descartado — o resultado é sempre à meia-noite local
/// do dia útil alvo (o "em atraso" compara apenas a data).
DateTime adicionarDiasUteis(DateTime base, int dias) {
  var data = DateTime(base.year, base.month, base.day);
  if (dias <= 0) return data;
  var adicionados = 0;
  while (adicionados < dias) {
    data = data.add(const Duration(days: 1));
    final ehFimDeSemana =
        data.weekday == DateTime.saturday || data.weekday == DateTime.sunday;
    if (!ehFimDeSemana) adicionados++;
  }
  return data;
}
