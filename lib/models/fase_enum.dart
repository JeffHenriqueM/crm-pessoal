// lib/models/fase_enum.dart
enum FaseCliente {
  prospeccao, // Cliente foi adicionado, mas ainda não houve contato efetivo.
  contato,    // Primeiro contato realizado.
  negociacao, // Proposta enviada ou em discussão.
  visita,
  fechado,    // Venda concluída (ou objetivo pessoal atingido).
  perdido,    // Cliente não avançou.
}

extension FaseClienteExtension on FaseCliente {
  // Converte a enum para uma string legível na UI
  String get nomeDisplay {
    switch (this) {
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