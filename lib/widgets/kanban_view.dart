import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../services/firestore_service.dart';
import '../services/tempo_sem_contato.dart';
import 'chip_tempo_sem_contato.dart';
import 'vincular_contrato_dialog.dart';

// ── Kanban com drag-and-drop ──────────────────────────────────────────────────
class KanbanView extends StatelessWidget {
  final List<Cliente> clientes;
  final bool isAdmin;
  final Function(Cliente) onCardTap;

  const KanbanView({
    super.key,
    required this.clientes,
    required this.isAdmin,
    required this.onCardTap,
  });

  static const double _columnWidth = 276.0;
  static const double _columnGap = 10.0;

  static Color corDaFase(FaseCliente fase) {
    switch (fase) {
      case FaseCliente.atendimento:
        return const Color(0xFF546E7A); // cinza-azulado
      case FaseCliente.prospeccao:
        return const Color(0xFF1565C0);
      case FaseCliente.contato:
        return const Color(0xFF00695C);
      case FaseCliente.negociacao:
        return const Color(0xFFB45309);
      case FaseCliente.visita:
        return const Color(0xFF6A1B9A);
      case FaseCliente.fechado:
        return const Color(0xFF2E7D32);
      case FaseCliente.perdido:
        return const Color(0xFFC62828);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: SizedBox(
            // Altura fixa para que as colunas possam usar Expanded internamente
            height: constraints.maxHeight - 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: FaseCliente.values
                  .where((f) => f != FaseCliente.atendimento)
                  .map((fase) {
                final clientesDaFase =
                    clientes.where((c) => c.fase == fase).toList();
                return Padding(
                  padding: const EdgeInsets.only(right: _columnGap),
                  child: SizedBox(
                    width: _columnWidth,
                    child: _KanbanColumn(
                      fase: fase,
                      clientes: clientesDaFase,
                      cor: corDaFase(fase),
                      isAdmin: isAdmin,
                      onCardTap: onCardTap,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

// ── Coluna (DragTarget) ───────────────────────────────────────────────────────
class _KanbanColumn extends StatefulWidget {
  final FaseCliente fase;
  final List<Cliente> clientes;
  final Color cor;
  final bool isAdmin;
  final Function(Cliente) onCardTap;

  const _KanbanColumn({
    required this.fase,
    required this.clientes,
    required this.cor,
    required this.isAdmin,
    required this.onCardTap,
  });

  @override
  State<_KanbanColumn> createState() => _KanbanColumnState();
}

class _KanbanColumnState extends State<_KanbanColumn> {
  bool _isDragOver = false;
  final _service = FirestoreService();

  Future<void> _handleDrop(Cliente cliente) async {
    if (cliente.fase == widget.fase) return;

    if (widget.fase == FaseCliente.perdido) {
      await _mostrarDialogoPerdido(cliente);
    } else {
      await _service.atualizarFaseCliente(cliente.id!, widget.fase);
      // Ao fechar o lead, oferece vincular ao contrato correspondente.
      if (widget.fase == FaseCliente.fechado && mounted) {
        await _vincularContratoAoFechar(cliente);
      }
    }
  }

  Future<void> _vincularContratoAoFechar(Cliente cliente) async {
    final contrato = await VincularContratoDialog.mostrar(
      context,
      nome: cliente.nome,
      telefone: cliente.telefoneContato ?? cliente.telefone2 ?? '',
      fs: _service,
    );
    if (contrato == null) return;
    await _service.vincularContratoACliente(
        cliente.id!, contrato.localizador, contrato.nomeComprador);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lead vinculado ao contrato de '
            '${contrato.nomeComprador}.')),
      );
    }
  }

  Future<void> _mostrarDialogoPerdido(Cliente cliente) async {
    final motivoCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sentiment_dissatisfied_outlined),
            SizedBox(width: 10),
            Text('Registrar Perda'),
          ],
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: motivoCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Motivo da perda *',
              hintText: 'Ex: preço, concorrência, sem interesse...',
            ),
            maxLines: 3,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Informe o motivo da perda.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _service.atualizarFaseCliente(
        cliente.id!,
        FaseCliente.perdido,
        motivo: motivoCtrl.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return DragTarget<Cliente>(
      onWillAcceptWithDetails: (d) {
        if (d.data.fase == widget.fase) return false;
        setState(() => _isDragOver = true);
        return true;
      },
      onLeave: (_) => setState(() => _isDragOver = false),
      onAcceptWithDetails: (d) {
        setState(() => _isDragOver = false);
        _handleDrop(d.data);
      },
      builder: (ctx, candidateData, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _isDragOver
                ? widget.cor.withValues(alpha: 0.08)
                : (isLight
                    ? const Color(0xFFF4F6F8)
                    : cs.surfaceContainerLow),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isDragOver
                  ? widget.cor
                  : cs.outlineVariant.withValues(alpha: 0.6),
              width: _isDragOver ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              Expanded(child: _buildCardList(context)),
            ],
          ),
        );
      },
    );
  }

  // ── Cabeçalho da coluna ───────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: widget.cor.withValues(alpha: 0.10),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
        border: Border(
          bottom: BorderSide(
              color: widget.cor.withValues(alpha: 0.18), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration:
                BoxDecoration(color: widget.cor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.fase.nomeDisplay,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: widget.cor),
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: widget.cor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${widget.clientes.length}',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: widget.cor),
            ),
          ),
        ],
      ),
    );
  }

  // ── Lista de cards ────────────────────────────────────────────────────────
  Widget _buildCardList(BuildContext context) {
    if (widget.clientes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined,
                  size: 30,
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.35)),
              const SizedBox(height: 8),
              Text('Nenhum lead',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      itemCount: widget.clientes.length,
      itemBuilder: (context, i) {
        final cliente = widget.clientes[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _KanbanCard(
            cliente: cliente,
            cor: widget.cor,
            isAdmin: widget.isAdmin,
            onTap: () => widget.onCardTap(cliente),
          ),
        );
      },
    );
  }
}

// ── Card arrastável ───────────────────────────────────────────────────────────
class _KanbanCard extends StatelessWidget {
  final Cliente cliente;
  final Color cor;
  final bool isAdmin;
  final VoidCallback onTap;

  const _KanbanCard({
    required this.cliente,
    required this.cor,
    required this.isAdmin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = _buildCardWidget(context);
    return Draggable<Cliente>(
      data: cliente,
      feedback: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 258,
          child: _buildCardWidget(context, isDragging: true),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: card),
      child: card,
    );
  }

  Widget _buildCardWidget(BuildContext context, {bool isDragging = false}) {
    final cs = Theme.of(context).colorScheme;
    final hoje = DateTime.now();
    final inicioDoDia = DateTime(hoje.year, hoje.month, hoje.day);
    final contatoAtrasado = cliente.proximoContato != null &&
        cliente.proximoContato!.isBefore(inicioDoDia);
    final tempoContato = avaliarTempoSemContatoCliente(cliente, agora: hoje);

    return Card(
      elevation: isDragging ? 0 : 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: contatoAtrasado && !isDragging
            ? BorderSide(color: cs.error.withValues(alpha: 0.55), width: 1.5)
            : BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.4), width: 0.8),
      ),
      child: InkWell(
        onTap: isDragging ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Nome + Avatar ────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: cor.withValues(alpha: 0.12),
                    child: Text(
                      cliente.nome.isNotEmpty
                          ? cliente.nome[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          color: cor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cliente.nomeEsposa?.isNotEmpty == true
                          ? '${cliente.nome} e ${cliente.nomeEsposa}'
                          : cliente.nome,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // ── Tempo sem contato (ticket #48) ───────────────────
              if (tempoContato.temAlerta) ...[
                const SizedBox(height: 7),
                ChipTempoSemContato(tempoContato, compacto: true),
              ],

              // ── Origem ───────────────────────────────────────────
              if (cliente.origem?.isNotEmpty == true) ...[
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    cliente.origem!,
                    style: TextStyle(
                        fontSize: 10, color: cs.onSurfaceVariant),
                  ),
                ),
              ],

              // ── Próximo contato ──────────────────────────────────
              if (cliente.proximoContato != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.phone_outlined,
                        size: 11,
                        color:
                            contatoAtrasado ? cs.error : cs.outline),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd/MM/yy')
                          .format(cliente.proximoContato!),
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            contatoAtrasado ? cs.error : cs.outline,
                        fontWeight: contatoAtrasado
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    if (contatoAtrasado) ...[
                      const SizedBox(width: 4),
                      Text('· atrasado',
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.error,
                              fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ],

              // ── Vendedor (admin) ─────────────────────────────────
              if (isAdmin && cliente.vendedorNome?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.person_outline,
                        size: 11, color: cs.outline),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        cliente.vendedorNome!,
                        style: TextStyle(
                            fontSize: 11, color: cs.outline),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // ── Motivo de perda ──────────────────────────────────
              if (cliente.fase == FaseCliente.perdido &&
                  cliente.motivoNaoVenda?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text(
                  'Motivo: ${cliente.motivoNaoVenda}',
                  style: TextStyle(
                      fontSize: 10,
                      color: cs.error,
                      fontStyle: FontStyle.italic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // ── Badge rastreamento de mensagem (#16) ──────────────
              if (cliente.statusMensagem == 'nao_enviada' ||
                  cliente.statusMensagem == 'enviada_sem_resposta') ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: cliente.statusMensagem == 'nao_enviada'
                        ? cs.errorContainer
                        : Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cliente.statusMensagem == 'nao_enviada'
                            ? Icons.message_outlined
                            : Icons.schedule_outlined,
                        size: 10,
                        color: cliente.statusMensagem == 'nao_enviada'
                            ? cs.onErrorContainer
                            : Colors.amber.shade900,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        cliente.statusMensagem == 'nao_enviada'
                            ? 'Msg. não enviada'
                            : 'Aguardando resposta',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: cliente.statusMensagem == 'nao_enviada'
                              ? cs.onErrorContainer
                              : Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
