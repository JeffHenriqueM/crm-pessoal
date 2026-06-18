import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../services/firestore_service.dart';
import '../services/tempo_sem_contato.dart';
import 'chip_tempo_sem_contato.dart';

class ClienteListFiltered extends StatelessWidget {
  final List<Cliente> clientes;
  final Function(Cliente) onTileTap;
  final String filtroNome;

  const ClienteListFiltered({
    super.key,
    required this.clientes,
    required this.onTileTap,
    required this.filtroNome,
  });

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    if (clientes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline,
                  size: 56,
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text(
                filtroNome.isEmpty
                    ? 'Nenhum cliente nesta fase.'
                    : 'Nenhum resultado para "$filtroNome".',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: clientes.length,
      padding: const EdgeInsets.only(bottom: 80, top: 4),
      itemBuilder: (context, index) {
        final cliente = clientes[index];
        final contatoAtrasado = cliente.proximoContato != null &&
            cliente.proximoContato!.isBefore(DateTime.now());

        return Dismissible(
          key: Key(cliente.id!),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => _confirmarExclusao(context, cliente),
          onDismissed: (_) {
            firestoreService.deletarCliente(cliente.id!);
            final cs = Theme.of(context).colorScheme;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('"${cliente.nome}" foi removido.'),
                backgroundColor: cs.error,
              ),
            );
          },
          background: Builder(builder: (context) {
            final cs = Theme.of(context).colorScheme;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: cs.error,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: Icon(Icons.delete_forever_outlined,
                  color: cs.onError, size: 28),
            );
          }),
          child: _buildClienteCard(context, cliente, firestoreService, contatoAtrasado),
        );
      },
    );
  }

  Future<bool?> _confirmarExclusao(BuildContext context, Cliente cliente) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Deseja apagar permanentemente "${cliente.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
  }

  Widget _buildClienteCard(
    BuildContext context,
    Cliente cliente,
    FirestoreService service,
    bool contatoAtrasado,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tempoContato =
        avaliarTempoSemContatoCliente(cliente, agora: DateTime.now());

    return Card(
      shape: RoundedRectangleBorder(
        side: contatoAtrasado
            ? BorderSide(color: cs.error, width: 1.5)
            : BorderSide.none,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onTileTap(cliente),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: contatoAtrasado ? cs.error : cs.primaryContainer,
                child: Text(
                  cliente.nome.isNotEmpty ? cliente.nome[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: contatoAtrasado ? cs.onError : cs.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Informações
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome
                    Text(
                      (cliente.nomeEsposa?.isNotEmpty == true)
                          ? '${cliente.nome} e ${cliente.nomeEsposa}'
                          : cliente.nome,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Chips de informações
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (filtroNome.isNotEmpty)
                          _badge(
                            context,
                            cliente.fase.nomeDisplay.toUpperCase(),
                            cs.primaryContainer,
                            cs.onPrimaryContainer,
                          ),
                        if (cliente.origem?.isNotEmpty == true)
                          _badge(
                            context,
                            cliente.origem!,
                            cs.surfaceContainerHighest,
                            cs.onSurfaceVariant,
                          ),
                        if (contatoAtrasado)
                          _badge(
                            context,
                            'CONTATO ATRASADO',
                            cs.errorContainer,
                            cs.onErrorContainer,
                          ),
                        if (tempoContato.temAlerta)
                          ChipTempoSemContato(tempoContato),
                      ],
                    ),

                    if (cliente.proximoContato != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 12,
                            color: contatoAtrasado ? cs.error : cs.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Contato: ${DateFormat('dd/MM/yy').format(cliente.proximoContato!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: contatoAtrasado ? cs.error : cs.outline,
                              fontWeight: contatoAtrasado
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (cliente.fase == FaseCliente.perdido &&
                        cliente.motivoNaoVenda?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Motivo: ${cliente.motivoNaoVenda}',
                        style: TextStyle(
                          color: cs.error,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // ── Badge rastreamento de mensagem (#16) ──────────
                    if (cliente.statusMensagem == 'nao_enviada' ||
                        cliente.statusMensagem == 'enviada_sem_resposta') ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: cliente.statusMensagem == 'nao_enviada'
                                  ? cs.errorContainer
                                  : Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  cliente.statusMensagem == 'nao_enviada'
                                      ? Icons.message_outlined
                                      : Icons.schedule_outlined,
                                  size: 11,
                                  color: cliente.statusMensagem == 'nao_enviada'
                                      ? cs.onErrorContainer
                                      : Colors.amber.shade900,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  cliente.statusMensagem == 'nao_enviada'
                                      ? 'Mensagem não enviada'
                                      : 'Aguardando resposta',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        cliente.statusMensagem == 'nao_enviada'
                                            ? cs.onErrorContainer
                                            : Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(BuildContext context, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
