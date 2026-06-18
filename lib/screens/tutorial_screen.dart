import 'package:flutter/material.dart';

/// Tela de Tutoriais (ticket #33) — guias escritos passo a passo de uso do
/// sistema, acessível pela navegação (sidebar/drawer), sem poluir as telas de
/// trabalho. Conteúdo organizado em seções expansíveis por área.
class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  static const List<_Tutorial> _tutoriais = [
    _Tutorial(
      titulo: 'Recepção — registrar atendimento e agendamento',
      icone: Icons.meeting_room_outlined,
      passos: [
        'Abra "Recepção" no menu lateral e fique na aba "Registrar".',
        'Use o botão de alternância no topo para escolher entre Atendimento '
            '(cliente presente agora) ou Agendamento (compromisso futuro).',
        'Preencha os dados do titular (e do cônjuge, se houver), sala, origem '
            'e o embaixador responsável.',
        'No modo Agendamento, toque em data/hora para definir o compromisso.',
        'Toque em "Salvar". No atendimento, o sistema gera o número e a ficha; '
            'no agendamento, o registro vai para a aba "Agendamentos".',
      ],
    ),
    _Tutorial(
      titulo: 'Agendamentos — confirmar presença e remarcar',
      icone: Icons.event_outlined,
      passos: [
        'Na Recepção, abra a aba "Agendamentos" para ver os compromissos '
            'futuros, ordenados por data.',
        'Quando o cliente comparecer, use "Registrar atendimento" — o '
            'formulário abre pré-preenchido e ao salvar vira um atendimento.',
        'Para mudar a data, toque em "Remarcar", escolha a nova data/hora e '
            'informe o motivo (obrigatório).',
        'Cada agendamento pode ser remarcado até 2 vezes. Atingido o limite, '
            'um administrador precisa liberar uma remarcação extra.',
      ],
    ),
    _Tutorial(
      titulo: 'Pipeline e Kanban — mover leads entre fases',
      icone: Icons.view_kanban_outlined,
      passos: [
        'Abra "Clientes" para ver seus leads em lista ou no quadro Kanban.',
        'No Kanban, arraste o card do lead para a próxima fase.',
        'Ao mover para "Perdido", informe o motivo da perda (obrigatório).',
        'Toque em um card para abrir a ficha completa do lead.',
      ],
    ),
    _Tutorial(
      titulo: 'Ficha do lead — contatos, agenda e histórico',
      icone: Icons.badge_outlined,
      passos: [
        'Na ficha, registre cada interação (ligação, WhatsApp, visita) na '
            'timeline para manter o histórico.',
        'Defina o "próximo contato" para o lead aparecer na sua Agenda e nas '
            'notificações do dia.',
        'Acompanhe o indicador de tempo sem contato: o lead muda de cor '
            'conforme os dias sem interação (15 / 20 / 30 dias).',
      ],
    ),
    _Tutorial(
      titulo: 'Negociações — propostas e fechamento',
      icone: Icons.handshake_outlined,
      passos: [
        'Na ficha do lead, abra a aba "Negociações" para lançar uma proposta.',
        'Preencha valores, condições e o embaixador responsável.',
        'Use "Exportar PDF" para gerar a proposta comercial.',
        'Ao fechar, atualize a fase do lead para "Fechado".',
      ],
    ),
    _Tutorial(
      titulo: 'Agenda — sua rotina do dia',
      icone: Icons.calendar_month_outlined,
      passos: [
        'A tela inicial mostra contatos, visitas e agendamentos do dia.',
        'Os dias com compromissos ficam marcados no calendário.',
        'Toque em um evento para abrir a ficha do cliente correspondente.',
      ],
    ),
    _Tutorial(
      titulo: 'Notificações — pendências e lembretes',
      icone: Icons.notifications_outlined,
      passos: [
        'O sino mostra o total de pendências; toque para abrir o painel.',
        'As notificações são agrupadas (Lembretes, Tickets, Visitas, etc.) e '
            'ordenadas das mais recentes para as mais antigas.',
        'Toque no título de um grupo para recolher ou expandir aquela seção.',
        'Toque em um item para ir direto ao lead ou ticket relacionado.',
      ],
    ),
    _Tutorial(
      titulo: 'Linha de atendimento — fila da sala de vendas',
      icone: Icons.headset_mic_outlined,
      passos: [
        'Na sua tela inicial, ative "Disponível para atendimento" para entrar '
            'na fila da sala de vendas.',
        'A recepção vê a ordem da fila e quem é o próximo a atender.',
        'Ao atender (ou atrasar), o vendedor vai para o fim da fila.',
      ],
    ),
    _Tutorial(
      titulo: 'Tickets — suporte e melhorias',
      icone: Icons.confirmation_number_outlined,
      passos: [
        'Abra "Tickets" para registrar um bug, melhoria ou nova ideia.',
        'Descreva o problema/sugestão com o máximo de detalhes.',
        'Acompanhe o status: aberto → em validação → resolvido.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutoriais'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: Text(
              'Guias rápidos de uso do sistema. Toque em uma seção para ver o '
              'passo a passo.',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ),
          ..._tutoriais.map((t) => _TutorialCard(tutorial: t)),
        ],
      ),
    );
  }
}

class _Tutorial {
  final String titulo;
  final IconData icone;
  final List<String> passos;
  const _Tutorial({
    required this.titulo,
    required this.icone,
    required this.passos,
  });
}

class _TutorialCard extends StatelessWidget {
  final _Tutorial tutorial;
  const _TutorialCard({required this.tutorial});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(tutorial.icone, color: cs.primary),
        title: Text(
          tutorial.titulo,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < tutorial.passos.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tutorial.passos[i],
                      style: TextStyle(fontSize: 13, color: cs.onSurface),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
