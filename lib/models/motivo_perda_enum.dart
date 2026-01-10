// lib/models/motivo_perda_enum.dart

enum MotivoPerda {
  preco('Preço/Valor'),concorrencia('Concorrência ganhou'),
  prazo('Prazo de entrega/execução'),
  semFit('Não era o perfil ideal'),
  semResposta('Cliente parou de responder'),
  outro('Outro');

  const MotivoPerda(this.nomeDisplay);
  final String nomeDisplay;
}
