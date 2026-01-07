// lib/models/fase_enum.dart
enum FaseCliente {
  prospeccao, // Cliente foi adicionado, mas ainda não houve contato efetivo.
  contato,    // Primeiro contato realizado.
  qualificacao, // Fase de Qualificar cliente
  negociacao, // Proposta enviada ou em discussão.
  visita,
  objecoes,
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
      case FaseCliente.qualificacao:
        return 'Qualificando Cliente';
      case FaseCliente.negociacao:
        return 'Negociação';
      case FaseCliente.visita:
        return 'Visita';
      case FaseCliente.objecoes:
        return 'Objeções';
      case FaseCliente.fechado:
        return 'Fechado';
      case FaseCliente.perdido:
        return 'Perdido';
    }
  }
}