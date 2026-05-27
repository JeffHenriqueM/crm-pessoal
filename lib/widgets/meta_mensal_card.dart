import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../services/firestore_service.dart';

class MetaMensalCard extends StatefulWidget {
  final String userId;

  /// Lista de clientes do vendedor — usada para calcular fechamentos do mês.
  final List<Cliente> clientes;

  const MetaMensalCard({
    super.key,
    required this.userId,
    required this.clientes,
  });

  @override
  State<MetaMensalCard> createState() => _MetaMensalCardState();
}

class _MetaMensalCardState extends State<MetaMensalCard> {
  final _service = FirestoreService();
  int? _meta;
  bool _carregando = true;

  static const _meses = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril',
    'Maio', 'Junho', 'Julho', 'Agosto',
    'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  @override
  void initState() {
    super.initState();
    _carregarMeta();
  }

  Future<void> _carregarMeta() async {
    final meta = await _service.getMetaMensal(widget.userId);
    if (mounted) setState(() { _meta = meta; _carregando = false; });
  }

  int get _fechadosMes {
    final agora = DateTime.now();
    final inicioMes = DateTime(agora.year, agora.month, 1);
    return widget.clientes
        .where((c) =>
            c.fase == FaseCliente.fechado &&
            !c.dataAtualizacao.isBefore(inicioMes))
        .length;
  }

  Future<void> _editarMeta(BuildContext context) async {
    final ctrl = TextEditingController(text: _meta?.toString() ?? '');

    final resultado = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.flag_outlined),
            SizedBox(width: 10),
            Text('Meta do Mês'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quantos fechamentos você quer atingir este mês?',
              style: TextStyle(
                  fontSize: 14, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Número de fechamentos',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.emoji_events_outlined),
              ),
            ),
          ],
        ),
        actions: [
          if (_meta != null)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(0), // 0 = remover
              child: Text('Remover meta',
                  style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error,
                      fontSize: 13)),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text.trim());
              if (v != null && v > 0) Navigator.of(ctx).pop(v);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    ctrl.dispose();
    if (!mounted || resultado == null) return;

    final novaMeta = resultado == 0 ? null : resultado;
    await _service.atualizarMetaMensal(widget.userId, novaMeta);
    if (mounted) setState(() => _meta = novaMeta);
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) return const SizedBox(height: 4);

    final cs = Theme.of(context).colorScheme;
    final agora = DateTime.now();
    final nomeMes = _meses[agora.month - 1];
    final fechados = _fechadosMes;

    // ── Sem meta definida ─────────────────────────────────────────────────────
    if (_meta == null) {
      return Card(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _editarMeta(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.flag_outlined, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Meta do Mês',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(
                        'Toque para definir sua meta de fechamentos de $nomeMes.',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () => _editarMeta(context),
                  child: const Text('Definir'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Com meta definida ─────────────────────────────────────────────────────
    final pct = (_meta! == 0 ? 0.0 : fechados / _meta!).clamp(0.0, 1.0);
    final faltam = (_meta! - fechados).clamp(0, _meta!);
    final atingiu = fechados >= _meta!;
    final excedeu = fechados > _meta!;

    final corProgresso = atingiu
        ? Colors.green.shade600
        : pct >= 0.7
            ? Colors.orange.shade600
            : cs.primary;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // ── Anel de progresso ─────────────────────────────────────────
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: pct,
                    strokeWidth: 7,
                    backgroundColor:
                        corProgresso.withValues(alpha: 0.12),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(corProgresso),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$fechados',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: corProgresso,
                            height: 1,
                          ),
                        ),
                        Text(
                          '/ $_meta',
                          style: TextStyle(
                              fontSize: 11, color: cs.outline, height: 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // ── Texto de progresso ────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Meta de $nomeMes',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      if (atingiu)
                        Icon(Icons.check_circle,
                            size: 18, color: Colors.green.shade600),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor:
                          corProgresso.withValues(alpha: 0.12),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(corProgresso),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    atingiu
                        ? excedeu
                            ? '🎉 Meta atingida! ${fechados - _meta!} além do esperado.'
                            : '🎉 Parabéns! Meta atingida este mês.'
                        : '$faltam fechamento${faltam != 1 ? 's' : ''} para atingir a meta',
                    style: TextStyle(
                      fontSize: 12,
                      color: atingiu
                          ? Colors.green.shade700
                          : cs.onSurfaceVariant,
                      fontWeight: atingiu
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            // ── Botão editar ──────────────────────────────────────────────
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 18, color: cs.outline),
              onPressed: () => _editarMeta(context),
              tooltip: 'Editar meta',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
