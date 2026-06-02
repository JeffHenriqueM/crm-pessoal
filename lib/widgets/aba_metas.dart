import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../models/usuario_model.dart';
import '../services/firestore_service.dart';

/// Meta padrão de contatos do pós-venda (% dos contratos no mês).
const double _kMetaPadraoPosVenda = 80.0;

/// Aba "Meta" do dashboard admin.
///
/// Mostra, por perfil, as metas mensais definidas por cada usuário e o
/// progresso, indicadores de inatividade (vendedor e pós-venda) e a meta de
/// contatos do pós-venda — esta editável pelo admin.
class AbaMetas extends StatefulWidget {
  final List<Cliente> todosClientes;
  final List<Usuario> todosUsuarios;

  const AbaMetas({
    super.key,
    required this.todosClientes,
    required this.todosUsuarios,
  });

  @override
  State<AbaMetas> createState() => _AbaMetasState();
}

class _AbaMetasState extends State<AbaMetas> {
  final _service = FirestoreService();

  // Contratos do pós-venda (para a meta de % contatados no mês).
  int _contratosTotal = 0;
  int _contratosContatados = 0;
  bool _carregandoContratos = true;

  // Override local das metas de pós-venda por usuário (após edição do admin):
  // userId → {tipoMeta: alvo}.
  final Map<String, Map<String, double>> _alvoPosVenda = {};

  static const _meses = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril',
    'Maio', 'Junho', 'Julho', 'Agosto',
    'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  @override
  void initState() {
    super.initState();
    _carregarContratos();
  }

  Future<void> _carregarContratos() async {
    final contratos = await _service.getContratos();
    if (!mounted) return;
    setState(() {
      _contratosTotal = contratos.length;
      _contratosContatados = contratos.where((c) => c.contatadoEsteMes).length;
      _carregandoContratos = false;
    });
  }

  bool _ehCaptacao(String perfil) {
    final p = perfil.toLowerCase();
    return p == 'captador' || p == 'recepcao' || p == 'recepção';
  }

  bool _ehVendedor(String perfil) => perfil.toLowerCase() == 'vendedor';

  bool _ehPosVenda(String perfil) {
    final p = perfil.toLowerCase();
    return p == 'pós-venda' || p == 'pos-venda';
  }

  double get _pctPosVenda =>
      _contratosTotal == 0 ? 0.0 : _contratosContatados / _contratosTotal * 100;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final agora = DateTime.now();
    final nomeMes = _meses[agora.month - 1];

    // Índices por usuário: leads onde é vendedor e leads que captou.
    final porVendedor = <String, List<Cliente>>{};
    final porCaptador = <String, List<Cliente>>{};
    // Última atualização feita por cada usuário (atualizadoPorId).
    final ultimaAtualizacaoPorUsuario = <String, DateTime>{};

    for (final c in widget.todosClientes) {
      if (c.vendedorId != null) {
        porVendedor.putIfAbsent(c.vendedorId!, () => []).add(c);
      }
      if (c.captadorId != null) {
        porCaptador.putIfAbsent(c.captadorId!, () => []).add(c);
      }
      final autor = c.atualizadoPorId;
      if (autor != null) {
        final atual = ultimaAtualizacaoPorUsuario[autor];
        if (atual == null || c.dataAtualizacao.isAfter(atual)) {
          ultimaAtualizacaoPorUsuario[autor] = c.dataAtualizacao;
        }
      }
    }

    final vendedores = widget.todosUsuarios
        .where((u) => _ehVendedor(u.perfil) && u.ativo)
        .toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));
    final captadores = widget.todosUsuarios
        .where((u) => _ehCaptacao(u.perfil) && u.ativo)
        .toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));
    final posVenda = widget.todosUsuarios
        .where((u) => _ehPosVenda(u.perfil) && u.ativo)
        .toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Metas de $nomeMes',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Meta mensal definida por cada usuário e progresso no mês.',
            style: TextStyle(fontSize: 12, color: cs.outline),
          ),
          const SizedBox(height: 20),

          // ── Metas dos vendedores ───────────────────────────────────────
          _sectionTitle(context, 'Vendedores', Icons.badge_outlined),
          const SizedBox(height: 8),
          if (vendedores.isEmpty)
            _vazio(cs, 'Nenhum vendedor ativo.')
          else
            ...vendedores.map((u) => _cardMeta(
                  context,
                  u,
                  porVendedor[u.id] ?? const [],
                  porCaptador[u.id] ?? const [],
                )),

          const SizedBox(height: 24),

          // ── Metas de captação ──────────────────────────────────────────
          _sectionTitle(context, 'Captação / Recepção', Icons.favorite_outline),
          const SizedBox(height: 8),
          if (captadores.isEmpty)
            _vazio(cs, 'Nenhum captador/recepção ativo.')
          else
            ...captadores.map((u) => _cardMeta(
                  context,
                  u,
                  porVendedor[u.id] ?? const [],
                  porCaptador[u.id] ?? const [],
                )),

          const SizedBox(height: 24),

          // ── Metas do pós-venda (editável pelo admin) ───────────────────
          _sectionTitle(
              context, 'Pós-venda', Icons.mark_chat_read_outlined),
          const SizedBox(height: 4),
          Text(
            'Meta: contatar uma % dos contratos da tela de pós-venda no mês. '
            'Toque no lápis para definir.',
            style: TextStyle(fontSize: 12, color: cs.outline),
          ),
          const SizedBox(height: 8),
          if (posVenda.isEmpty)
            _vazio(cs, 'Nenhum usuário de pós-venda ativo.')
          else
            ...posVenda.map((u) => _cardPosVenda(context, u)),

          const SizedBox(height: 24),

          // ── Inatividade dos vendedores ─────────────────────────────────
          _sectionTitle(
              context, 'Inatividade — Vendedores', Icons.timelapse_outlined),
          const SizedBox(height: 4),
          Text(
            'Há quanto tempo cada vendedor não atualiza nenhum cliente.',
            style: TextStyle(fontSize: 12, color: cs.outline),
          ),
          const SizedBox(height: 8),
          if (vendedores.isEmpty)
            _vazio(cs, 'Nenhum vendedor ativo.')
          else
            _cardInatividade(context, vendedores, ultimaAtualizacaoPorUsuario),

          const SizedBox(height: 24),

          // ── Inatividade do pós-venda ───────────────────────────────────
          _sectionTitle(
              context, 'Inatividade — Pós-venda', Icons.support_agent_outlined),
          const SizedBox(height: 4),
          Text(
            'Há quanto tempo o pós-venda não atualiza nenhum cliente.',
            style: TextStyle(fontSize: 12, color: cs.outline),
          ),
          const SizedBox(height: 8),
          if (posVenda.isEmpty)
            _vazio(cs, 'Nenhum usuário de pós-venda ativo.')
          else
            _cardInatividade(context, posVenda, ultimaAtualizacaoPorUsuario),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Cálculo de progresso de meta ──────────────────────────────────────────
  bool _esteMs(DateTime? dt) {
    if (dt == null) return false;
    final agora = DateTime.now();
    return !dt.isBefore(DateTime(agora.year, agora.month, 1));
  }

  /// Calcula (rótulo, alvo, progresso, monetário) de uma meta específica.
  ({String tipo, double alvo, double progresso, bool monetario}) _progresso(
    String tipoKey,
    double alvo,
    Usuario u,
    List<Cliente> seusLeads,
    List<Cliente> captados,
  ) {
    double progresso;
    bool monetario = false;
    String rotulo;

    int fechadosMes(List<Cliente> ls) => ls
        .where((c) =>
            c.fase == FaseCliente.fechado &&
            _esteMs(c.dataFechamento ?? c.dataAtualizacao))
        .length;
    double valorMes(List<Cliente> ls) => ls
        .where((c) =>
            c.fase == FaseCliente.fechado &&
            _esteMs(c.dataFechamento ?? c.dataAtualizacao))
        .fold(0.0, (s, c) => s + (c.valorVendido ?? 0.0));

    switch (tipoKey) {
      case 'valorVendido':
        rotulo = 'Valor vendido';
        monetario = true;
        progresso = valorMes(seusLeads);
      case 'mensagensEnviadas':
        rotulo = 'Mensagens';
        progresso = u.interacoesMesAtual.toDouble();
      case 'casaisCaptados':
        rotulo = 'Casais captados';
        progresso = captados
            .where((c) => _esteMs(c.dataCadastro))
            .length
            .toDouble();
      case 'vendasCaptadas':
        rotulo = 'Vendas captadas';
        progresso = fechadosMes(captados).toDouble();
      case 'valorCaptado':
        rotulo = 'Valor captado';
        monetario = true;
        progresso = valorMes(captados);
      case 'novosLeads':
        rotulo = 'Novos leads';
        progresso =
            seusLeads.where((c) => _esteMs(c.dataCadastro)).length.toDouble();
      case 'fechamentos':
      default:
        rotulo = 'Fechamentos';
        progresso = fechadosMes(seusLeads).toDouble();
    }
    return (tipo: rotulo, alvo: alvo, progresso: progresso, monetario: monetario);
  }

  // ── Card de meta por usuário (vendedor/captação) ──────────────────────────
  Widget _cardMeta(
    BuildContext context,
    Usuario u,
    List<Cliente> seusLeads,
    List<Cliente> captados,
  ) {
    final cs = Theme.of(context).colorScheme;
    final moeda = NumberFormat.compactCurrency(
        locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);
    final metas = u.metas; // {tipoKey: alvo}

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(u.nome, cs),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.nome,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  if (metas.isEmpty)
                    Text('Sem meta definida',
                        style: TextStyle(fontSize: 12, color: cs.outline))
                  else
                    ...metas.entries.map((e) {
                      final m =
                          _progresso(e.key, e.value, u, seusLeads, captados);
                      return _linhaProgresso(
                        cs,
                        rotulo: m.tipo,
                        progresso: m.progresso,
                        alvo: m.alvo,
                        fmt: (v) =>
                            m.monetario ? moeda.format(v) : v.toInt().toString(),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card de metas do pós-venda (editável pelo admin) ──────────────────────
  /// Metas efetivas do pós-venda (com override local após edição e default 80%
  /// para contatos).
  Map<String, double> _metasPosVenda(Usuario u) {
    final base = _alvoPosVenda[u.id] ?? Map<String, double>.from(u.metas);
    return {
      'mensagensPosVenda':
          base['mensagensPosVenda'] ?? _kMetaPadraoPosVenda,
      if (base['assinaturas'] != null) 'assinaturas': base['assinaturas']!,
      if (base['upgrades'] != null) 'upgrades': base['upgrades']!,
    };
  }

  Widget _cardPosVenda(BuildContext context, Usuario u) {
    final cs = Theme.of(context).colorScheme;
    final metas = _metasPosVenda(u);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(u.nome, cs),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.nome,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  if (_carregandoContratos)
                    Text('Calculando contatos…',
                        style: TextStyle(fontSize: 12, color: cs.outline))
                  else ...[
                    _linhaProgresso(
                      cs,
                      rotulo:
                          'Contatos pós-venda ($_contratosContatados/$_contratosTotal)',
                      progresso: _pctPosVenda,
                      alvo: metas['mensagensPosVenda']!,
                      fmt: (v) => '${v.round()}%',
                    ),
                    if (metas['assinaturas'] != null)
                      _linhaProgresso(
                        cs,
                        rotulo: 'Assinaturas · ${u.assinaturasTotal} no total',
                        progresso: u.assinaturasMesAtual.toDouble(),
                        alvo: metas['assinaturas']!,
                        fmt: (v) => v.toInt().toString(),
                      ),
                    if (metas['upgrades'] != null)
                      _linhaProgresso(
                        cs,
                        rotulo: 'Upgrades · ${u.upgradesTotal} no total',
                        progresso: u.upgradesMesAtual.toDouble(),
                        alvo: metas['upgrades']!,
                        fmt: (v) => v.toInt().toString(),
                      ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 18, color: cs.outline),
              tooltip: 'Definir metas do pós-venda',
              visualDensity: VisualDensity.compact,
              onPressed: () => _editarMetasPosVenda(context, u, metas),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editarMetasPosVenda(
      BuildContext context, Usuario u, Map<String, double> atuais) async {
    final messenger = ScaffoldMessenger.of(context);
    final corErro = Theme.of(context).colorScheme.error;

    final ctrlContatos = TextEditingController(
        text: (atuais['mensagensPosVenda'] ?? _kMetaPadraoPosVenda)
            .round()
            .toString());
    final ctrlAssin = TextEditingController(
        text: atuais['assinaturas']?.toInt().toString() ?? '');
    final ctrlUpg = TextEditingController(
        text: atuais['upgrades']?.toInt().toString() ?? '');

    Widget campo(String label, TextEditingController c, String hint) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        );

    final salvar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Metas do Pós-venda — ${u.nome}'),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Deixe em branco para não usar. Contatos é em %; '
                  'assinaturas e upgrades são quantidades no mês.',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              campo('Contatos (%)', ctrlContatos, '80'),
              campo('Assinaturas (qtd/mês)', ctrlAssin, 'ex.: 10'),
              campo('Upgrades (qtd/mês)', ctrlUpg, 'ex.: 5'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    final contatos = double.tryParse(ctrlContatos.text.trim());
    final assin = double.tryParse(ctrlAssin.text.trim());
    final upg = double.tryParse(ctrlUpg.text.trim());
    ctrlContatos.dispose();
    ctrlAssin.dispose();
    ctrlUpg.dispose();
    if (salvar != true) return;

    final novo = <String, double>{};
    if (contatos != null && contatos > 0 && contatos <= 100) {
      novo['mensagensPosVenda'] = contatos;
    }
    if (assin != null && assin > 0) novo['assinaturas'] = assin;
    if (upg != null && upg > 0) novo['upgrades'] = upg;

    try {
      await _service.definirMetas(u.id, novo);
      if (mounted) setState(() => _alvoPosVenda[u.id] = novo);
      messenger.showSnackBar(
        const SnackBar(content: Text('Metas do pós-venda atualizadas.')),
      );
    } catch (e) {
      debugPrint('[AbaMetas] Erro ao salvar metas do pós-venda: $e');
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Não foi possível salvar as metas.'),
          backgroundColor: corErro,
        ),
      );
    }
  }

  // ── Linha de progresso (rótulo + valores + barra) ─────────────────────────
  Widget _linhaProgresso(
    ColorScheme cs, {
    required String rotulo,
    required double progresso,
    required double alvo,
    required String Function(double) fmt,
  }) {
    final pct = (alvo == 0 ? 0.0 : progresso / alvo).clamp(0.0, 1.0);
    final atingiu = progresso >= alvo;
    final cor = atingiu
        ? Colors.green.shade600
        : pct >= 0.7
            ? Colors.orange.shade600
            : cs.primary;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(rotulo,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis),
              ),
              Text('${fmt(progresso)} / ${fmt(alvo)}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: cor)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: cor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(cor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // ── Card de inatividade ───────────────────────────────────────────────────
  Widget _cardInatividade(
    BuildContext context,
    List<Usuario> usuarios,
    Map<String, DateTime> ultimaAtualizacao,
  ) {
    final cs = Theme.of(context).colorScheme;
    final agora = DateTime.now();
    final fmt = DateFormat('dd/MM/yy');

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          children: usuarios.map((u) {
            final ultima = ultimaAtualizacao[u.id];
            final dias =
                ultima == null ? null : agora.difference(ultima).inDays;

            String texto;
            Color cor;
            if (dias == null) {
              texto = 'Nunca atualizou';
              cor = cs.error;
            } else if (dias == 0) {
              texto = 'Hoje';
              cor = Colors.green.shade600;
            } else {
              texto = '$dias dia${dias != 1 ? 's' : ''} atrás';
              cor = dias >= 7
                  ? cs.error
                  : dias >= 3
                      ? Colors.orange.shade700
                      : Colors.green.shade600;
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  _avatar(u.nome, cs, raio: 14),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.nome,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        if (ultima != null)
                          Text('Última: ${fmt.format(ultima)}',
                              style: TextStyle(
                                  fontSize: 11, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      texto,
                      style: TextStyle(
                          color: cor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────
  Widget _sectionTitle(BuildContext context, String title, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _vazio(ColorScheme cs, String texto) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(texto, style: TextStyle(fontSize: 13, color: cs.outline)),
      );

  Widget _avatar(String nome, ColorScheme cs, {double raio = 18}) {
    final inicial = nome.isNotEmpty ? nome[0].toUpperCase() : '?';
    final cores = [
      Colors.blue.shade700,
      Colors.teal.shade600,
      Colors.indigo.shade600,
      Colors.orange.shade700,
      Colors.green.shade700,
      Colors.cyan.shade700,
    ];
    final cor = cores[nome.isEmpty ? 0 : nome.codeUnits.first % cores.length];
    return CircleAvatar(
      radius: raio,
      backgroundColor: cor.withValues(alpha: 0.15),
      child: Text(inicial,
          style: TextStyle(
              color: cor, fontWeight: FontWeight.bold, fontSize: raio * 0.9)),
    );
  }
}
