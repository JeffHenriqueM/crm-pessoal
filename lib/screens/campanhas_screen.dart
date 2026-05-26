import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/campanha_model.dart';
import '../services/firestore_service.dart';

// ── Tela de Condições Especiais (apenas admin) ────────────────────────────────
class CampanhasScreen extends StatelessWidget {
  const CampanhasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Icon(Icons.campaign_outlined, color: cs.primary, size: 22),
            const SizedBox(width: 10),
            const Text('Condições Especiais'),
          ],
        ),
      ),
      body: StreamBuilder<List<Campanha>>(
        stream: service.getCampanhasStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final campanhas = snapshot.data ?? [];
          if (campanhas.isEmpty) {
            return _buildVazio(context, cs);
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            itemCount: campanhas.length,
            itemBuilder: (context, i) => _CampanhaCard(
              campanha: campanhas[i],
              service: service,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(context, service, null),
        icon: const Icon(Icons.add),
        label: const Text('Nova Condição'),
      ),
    );
  }

  Widget _buildVazio(BuildContext context, ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined,
                size: 56, color: cs.outline.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('Nenhuma condição especial ainda.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.outline, fontSize: 15)),
            const SizedBox(height: 8),
            Text(
              'Crie campanhas de desconto ou condições especiais\nque ficam visíveis para toda a equipe.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirFormulario(
      BuildContext context, FirestoreService service, Campanha? editando) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _FormularioCampanha(
        service: service,
        editando: editando,
      ),
    );
  }
}

// ── Card de campanha ──────────────────────────────────────────────────────────
class _CampanhaCard extends StatelessWidget {
  final Campanha campanha;
  final FirestoreService service;

  const _CampanhaCard({required this.campanha, required this.service});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('dd/MM/yyyy');
    final vigente = campanha.vigente;
    final ativa = campanha.ativa;

    final Color corStatus = vigente
        ? Colors.green.shade700
        : ativa
            ? Colors.orange.shade700
            : cs.onSurfaceVariant;

    final String labelStatus = vigente
        ? 'Vigente'
        : ativa
            ? 'Fora do período'
            : 'Inativa';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: vigente ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: vigente
              ? Colors.green.shade700.withValues(alpha: 0.4)
              : cs.outlineVariant.withValues(alpha: 0.4),
          width: vigente ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabeçalho ──────────────────────────────────────
            Row(
              children: [
                Icon(
                  campanha.tipo == TipoCampanha.desconto
                      ? Icons.percent_outlined
                      : Icons.star_outlined,
                  size: 18,
                  color: cs.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    campanha.nome,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                // Badge status
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: corStatus.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: corStatus.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    labelStatus,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: corStatus),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Condição / Desconto ─────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                campanha.resumo,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.primary),
              ),
            ),
            const SizedBox(height: 8),

            // ── Período ─────────────────────────────────────────
            Row(
              children: [
                Icon(Icons.date_range_outlined,
                    size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  '${fmt.format(campanha.dataInicio)} → ${fmt.format(campanha.dataFim)}',
                  style:
                      TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                if (campanha.criadoPorNome != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.person_outlined,
                      size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    campanha.criadoPorNome!,
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // ── Ações ───────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Toggle publicar/despublicar
                OutlinedButton.icon(
                  onPressed: () => service.publicarCampanha(
                      campanha.id!, !campanha.ativa),
                  icon: Icon(
                    ativa
                        ? Icons.visibility_off_outlined
                        : Icons.send_outlined,
                    size: 16,
                  ),
                  label: Text(ativa ? 'Despublicar' : 'Publicar',
                      style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor:
                        ativa ? cs.error : Colors.green.shade700,
                    side: BorderSide(
                      color: ativa
                          ? cs.error.withValues(alpha: 0.4)
                          : Colors.green.shade700.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.edit_outlined,
                      size: 18, color: cs.primary),
                  tooltip: 'Editar',
                  onPressed: () => showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => _FormularioCampanha(
                      service: service,
                      editando: campanha,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: cs.error),
                  tooltip: 'Excluir',
                  onPressed: () => _confirmarExclusao(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarExclusao(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir condição?'),
        content:
            Text('Deseja excluir "${campanha.nome}" permanentemente?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await service.deletarCampanha(campanha.id!);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

// ── Formulário de campanha ────────────────────────────────────────────────────
class _FormularioCampanha extends StatefulWidget {
  final FirestoreService service;
  final Campanha? editando;

  const _FormularioCampanha({required this.service, this.editando});

  @override
  State<_FormularioCampanha> createState() => _FormularioCampanhaState();
}

class _FormularioCampanhaState extends State<_FormularioCampanha> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _descontoCtrl;
  late final TextEditingController _condicaoCtrl;

  TipoCampanha _tipo = TipoCampanha.desconto;
  DateTime? _dataInicio;
  DateTime? _dataFim;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editando;
    _nomeCtrl = TextEditingController(text: e?.nome ?? '');
    _descontoCtrl = TextEditingController(
        text: e?.valorDesconto != null
            ? (e!.valorDesconto! == e.valorDesconto!.truncateToDouble()
                ? e.valorDesconto!.toInt().toString()
                : e.valorDesconto!.toStringAsFixed(1))
            : '');
    _condicaoCtrl = TextEditingController(text: e?.condicao ?? '');
    _tipo = e?.tipo ?? TipoCampanha.desconto;
    _dataInicio = e?.dataInicio;
    _dataFim = e?.dataFim;
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _descontoCtrl.dispose();
    _condicaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _selecionarData(bool isInicio) async {
    final hoje = DateTime.now();
    final inicial = isInicio
        ? (_dataInicio ?? hoje)
        : (_dataFim ?? (_dataInicio?.add(const Duration(days: 1)) ?? hoje));
    final data = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: isInicio ? DateTime(2020) : (_dataInicio ?? hoje),
      lastDate: DateTime(2030),
    );
    if (data != null && mounted) {
      setState(() {
        if (isInicio) {
          _dataInicio = data;
          if (_dataFim != null && _dataFim!.isBefore(data)) _dataFim = null;
        } else {
          _dataFim = data;
        }
      });
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dataInicio == null || _dataFim == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione as datas de início e fim.')),
      );
      return;
    }
    setState(() => _salvando = true);
    try {
      final nova = Campanha(
        id: widget.editando?.id,
        nome: _nomeCtrl.text.trim(),
        tipo: _tipo,
        valorDesconto: _tipo == TipoCampanha.desconto
            ? double.tryParse(_descontoCtrl.text.replaceAll(',', '.'))
            : null,
        condicao: _tipo == TipoCampanha.condicao
            ? _condicaoCtrl.text.trim()
            : null,
        dataInicio: _dataInicio!,
        dataFim: _dataFim!,
        ativa: widget.editando?.ativa ?? false,
        criadoPorId: widget.editando?.criadoPorId,
        criadoPorNome: widget.editando?.criadoPorNome,
      );
      if (widget.editando != null) {
        await widget.service.atualizarCampanha(nova);
      } else {
        await widget.service.criarCampanha(nova);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro: $e'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('dd/MM/yyyy');
    final isEditing = widget.editando != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.campaign_outlined, color: cs.primary),
          const SizedBox(width: 10),
          Text(isEditing ? 'Editar Condição' : 'Nova Condição Especial'),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tipo
                SegmentedButton<TipoCampanha>(
                  segments: const [
                    ButtonSegment(
                      value: TipoCampanha.desconto,
                      icon: Icon(Icons.percent_outlined, size: 16),
                      label: Text('Desconto %'),
                    ),
                    ButtonSegment(
                      value: TipoCampanha.condicao,
                      icon: Icon(Icons.star_outlined, size: 16),
                      label: Text('Condição Especial'),
                    ),
                  ],
                  selected: {_tipo},
                  onSelectionChanged: (s) =>
                      setState(() => _tipo = s.first),
                  style: const ButtonStyle(
                      visualDensity: VisualDensity.compact),
                ),
                const SizedBox(height: 14),

                // Nome
                TextFormField(
                  controller: _nomeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nome da campanha *',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) =>
                      v?.trim().isEmpty == true ? 'Informe um nome' : null,
                ),
                const SizedBox(height: 14),

                // Desconto ou condição
                if (_tipo == TipoCampanha.desconto)
                  TextFormField(
                    controller: _descontoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Desconto (%) *',
                      prefixIcon: Icon(Icons.percent_outlined),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Informe o desconto';
                      }
                      final d =
                          double.tryParse(v.replaceAll(',', '.'));
                      if (d == null || d <= 0 || d > 100) {
                        return 'Valor entre 0 e 100';
                      }
                      return null;
                    },
                  )
                else
                  TextFormField(
                    controller: _condicaoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Condição especial *',
                      prefixIcon: Icon(Icons.star_outlined),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => v?.trim().isEmpty == true
                        ? 'Descreva a condição'
                        : null,
                  ),
                const SizedBox(height: 14),

                // Datas
                Row(
                  children: [
                    Expanded(
                      child: _dataTile(
                        context, cs,
                        label: 'Início *',
                        data: _dataInicio,
                        icon: Icons.play_arrow_outlined,
                        onTap: () => _selecionarData(true),
                        fmt: fmt,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _dataTile(
                        context, cs,
                        label: 'Fim *',
                        data: _dataFim,
                        icon: Icons.stop_outlined,
                        onTap: () => _selecionarData(false),
                        fmt: fmt,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _salvando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          icon: _salvando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(isEditing
                  ? Icons.save_outlined
                  : Icons.add_circle_outline),
          label: Text(isEditing ? 'Salvar' : 'Criar'),
          onPressed: _salvando ? null : _salvar,
        ),
      ],
    );
  }

  Widget _dataTile(
    BuildContext context,
    ColorScheme cs, {
    required String label,
    required DateTime? data,
    required IconData icon,
    required VoidCallback onTap,
    required DateFormat fmt,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: data != null ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                data != null ? fmt.format(data) : label,
                style: TextStyle(
                  fontSize: 13,
                  color: data != null ? cs.onSurface : cs.onSurfaceVariant,
                  fontWeight: data != null
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
