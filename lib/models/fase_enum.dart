// lib/models/fase_enum.dart
enum FaseCliente {
  atendimento, // Cadastrado pela recepção — aguarda vendedor completar para virar lead
  prospeccao,  // Lead adicionado, ainda sem contato efetivo
  contato,     // Primeiro contato realizado
  negociacao,  // Proposta enviada ou em discussão
  visita,
  fechado,     // Venda concluída
  perdido,     // Cliente não avançou
}

extension FaseClienteExtension on FaseCliente {
  String get nomeDisplay {
    switch (this) {
      case FaseCliente.atendimento:
        return 'Atendimento';
      case FaseCliente.prospeccao:
        return 'Prospecção';
      case FaseCliente.contato:
        return 'Primeiro Contato';
      case FaseCliente.negociacao:
        return 'Negociação';
      case FaseCliente.visita:
        return 'Visita';
      case FaseCliente.fechado:
        return 'Fechado';
      case FaseCliente.perdido:
        return 'Perdido';
    }
  }
}