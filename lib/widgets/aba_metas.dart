import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../models/usuario_model.dart';

/// Aba "Meta" do dashboard admin (somente leitura).
///
/// Mostra, por perfil, a meta mensal definida por cada usuário e o respectivo
/// progresso, além de indicadores de inatividade (há quanto tempo cada vendedor
/// e cada pós-venda não atualiza nenhum cliente).
class AbaMetas extends StatelessWidget {
  final List<Cliente> todosClientes;
  final List<Usuario> todosUsuarios;

  const AbaMetas({
    super.key,
    required this.todosClientes,
    required this.todosUsuarios,
  });

  static const _meses = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril',
    'Maio', 'Junho', 'Julho', 'Agosto',
    'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  bool _ehCaptacao(String perfil) {
    final p = perfil.toLowerCase();
    return p == 'captador' || p == 'recepcao' || p == 'recepção';
  }

  bool _ehVendedor(String perfil) => perfil.toLowerCase() == 'vendedor';

  bool _ehPosVenda(String perfil) {
    final p = perfil.toLowerCase();
    return p == 'pós-venda' || p == 'pos-venda';
  }

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

    for (final c in todosClientes) {
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

    final vendedores =
        todosUsuarios.where((u) => _ehVendedor(u.perfil) && u.ativo).toList()
          ..sort((a, b) => a.nome.compareTo(b.nome));
    final captadores =
        todosUsuarios.where((u) => _ehCaptacao(u.perfil) && u.ativo).toList()
          ..sort((a, b) => a.nome.compareTo(b.nome));
    final posVenda =
        todosUsuarios.where((u) => _ehPosVenda(u.perfil) && u.ativo).toList()
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

  /// Retorna (rótulo do tipo, alvo, progresso, monetário) ou null se sem meta.
  ({String tipo, double alvo, double progresso, bool monetario})? _meta(
    Usuario u,
    List<Cliente> seusLeads,
    List<Cliente> captados,
  ) {
    final tipoKey =
        u.tipoMeta ?? (u.metaMensal != null ? 'fechamentos' : null);
    final alvo = u.valorMeta ?? u.metaMensal?.toDouble();
    if (tipoKey == null || alvo == null) return null;

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

  // ── Card de meta por usuário ──────────────────────────────────────────────
  Widget _cardMeta(
    BuildContext context,
    Usuario u,
    List<Cliente> seusLeads,
    List<Cliente> captados,
  ) {
    final cs = Theme.of(context).colorScheme;
    final moeda = NumberFormat.compactCurrency(
        locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);
    final meta = _meta(u, seusLeads, captados);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
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
                  if (meta == null)
                    Text('Sem meta definida',
                        style: TextStyle(fontSize: 12, color: cs.outline))
                  else ...[
                    Builder(builder: (_) {
                      final pct = (meta.alvo == 0
                              ? 0.0
                              : meta.progresso / meta.alvo)
                          .clamp(0.0, 1.0);
                      final atingiu = meta.progresso >= meta.alvo;
                      final cor = atingiu
                          ? Colors.green.shade600
                          : pct >= 0.7
                              ? Colors.orange.shade600
                              : cs.primary;
                      String fmt(double v) => meta.monetario
                          ? moeda.format(v)
                          : v.toInt().toString();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(meta.tipo,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant)),
                              Text('${fmt(meta.progresso)} / ${fmt(meta.alvo)}',
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
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(cor),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ),
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
            final dias = ultima == null ? null : agora.difference(ultima).inDays;

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
