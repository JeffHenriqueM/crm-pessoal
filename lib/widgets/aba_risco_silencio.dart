import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../models/usuario_model.dart';
import '../screens/ficha_cliente_screen.dart';
import '../services/risco_silencio.dart';
import '../utils/url_launcher_service.dart';

/// Aba "Risco de Silêncio" — lista os leads ativos que estão esfriando
/// (parando de responder / sem follow-up), priorizados por pontuação de risco.
///
/// A regra de risco vive em `services/risco_silencio.dart` (lógica pura,
/// testada). Aqui é só apresentação + filtro por vendedor.
class AbaRiscoSilencio extends StatefulWidget {
  final List<Cliente> clientes;
  final List<Usuario> todosVendedores;
  final String userProfile;

  const AbaRiscoSilencio({
    super.key,
    required this.clientes,
    this.todosVendedores = const [],
    this.userProfile = 'admin',
  });

  @override
  State<AbaRiscoSilencio> createState() => _AbaRiscoSilencioState();
}

class _RiscoItem {
  final Cliente cliente;
  final AvaliacaoRisco avaliacao;
  const _RiscoItem(this.cliente, this.avaliacao);
}

class _AbaRiscoSilencioState extends State<AbaRiscoSilencio> {
  String? _vendedorIdFiltro; // null = todos
  NivelRisco? _nivelFiltro; // null = todos os níveis

  Color _corNivel(NivelRisco n, ColorScheme cs) {
    switch (n) {
      case NivelRisco.critico:
        return cs.error;
      case NivelRisco.esfriando:
        return Colors.deepOrange.shade700;
      case NivelRisco.observar:
        return Colors.amber.shade800;
      case NivelRisco.nenhum:
        return Colors.green.shade700;
    }
  }

  IconData _iconeNivel(NivelRisco n) {
    switch (n) {
      case NivelRisco.critico:
        return Icons.local_fire_department_rounded;
      case NivelRisco.esfriando:
        return Icons.ac_unit_rounded;
      case NivelRisco.observar:
        return Icons.visibility_outlined;
      case NivelRisco.nenhum:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final agora = DateTime.now();
    final mostrarFiltro =
        widget.todosVendedores.isNotEmpty && _temPerfilAdmin();

    // Aplica filtro de vendedor (closer ou liner) quando selecionado.
    final base = _vendedorIdFiltro == null
        ? widget.clientes
        : widget.clientes
            .where((c) =>
                c.vendedorId == _vendedorIdFiltro ||
                c.linerId == _vendedorIdFiltro)
            .toList();

    // Avalia e mantém só quem exige ação, ordenado por severidade e, dentro do
    // mesmo nível, pelos que estão há mais tempo sem contato.
    final itens = base
        .map((c) => _RiscoItem(c, avaliarRiscoCliente(c, agora: agora)))
        .where((i) => i.avaliacao.exigeAcao)
        .toList()
      ..sort((a, b) {
        final sev = b.avaliacao.nivel.severidade
            .compareTo(a.avaliacao.nivel.severidade);
        if (sev != 0) return sev;
        return b.avaliacao.diasSemContato
            .compareTo(a.avaliacao.diasSemContato);
      });

    final criticos =
        itens.where((i) => i.avaliacao.nivel == NivelRisco.critico).length;
    final esfriando =
        itens.where((i) => i.avaliacao.nivel == NivelRisco.esfriando).length;
    final observar =
        itens.where((i) => i.avaliacao.nivel == NivelRisco.observar).length;

    // Lista exibida — respeita o filtro de nível ativo (clicando num KPI).
    final visiveis = _nivelFiltro == null
        ? itens
        : itens.where((i) => i.avaliacao.nivel == _nivelFiltro).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Risco de Silêncio',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface)),
                    const SizedBox(height: 2),
                    Text(
                      'Leads ativos esfriando — priorize o resgate de cima para baixo',
                      style: TextStyle(fontSize: 12, color: cs.outline),
                    ),
                  ],
                ),
              ),
              if (mostrarFiltro) _filtroVendedor(cs),
            ],
          ),
          const SizedBox(height: 16),

          // ── KPIs por nível (clicáveis: filtram a lista) ───────────────
          Row(
            children: [
              Expanded(
                  child: _kpi(cs, 'Crítico', criticos, NivelRisco.critico)),
              const SizedBox(width: 8),
              Expanded(
                  child:
                      _kpi(cs, 'Esfriando', esfriando, NivelRisco.esfriando)),
              const SizedBox(width: 8),
              Expanded(
                  child: _kpi(cs, 'Observar', observar, NivelRisco.observar)),
            ],
          ),
          if (_nivelFiltro != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Mostrando: ${_nivelFiltro!.rotulo}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant)),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => setState(() => _nivelFiltro = null),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close, size: 14, color: cs.primary),
                        const SizedBox(width: 2),
                        Text('limpar',
                            style: TextStyle(
                                fontSize: 12, color: cs.primary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),

          if (itens.isEmpty)
            _estadoVazio(cs)
          else if (visiveis.isEmpty)
            _semNoNivel(cs)
          else
            ...visiveis.map((i) => _cardRisco(context, cs, i)),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  bool _temPerfilAdmin() =>
      widget.userProfile == 'admin' || widget.userProfile == 'super admin';

  Widget _filtroVendedor(ColorScheme cs) {
    final selecionado = _vendedorIdFiltro == null
        ? 'Todos'
        : widget.todosVendedores
            .firstWhere((u) => u.id == _vendedorIdFiltro,
                orElse: () => Usuario(
                    id: '', nome: 'Todos', email: '', perfil: ''))
            .nome;

    return PopupMenuButton<String?>(
      tooltip: 'Filtrar por vendedor',
      onSelected: (v) => setState(() => _vendedorIdFiltro = v),
      itemBuilder: (_) => [
        const PopupMenuItem<String?>(value: null, child: Text('Todos')),
        ...widget.todosVendedores
            .where((u) => u.perfil == 'vendedor' || u.perfil == 'captador')
            .map((u) =>
                PopupMenuItem<String?>(value: u.id, child: Text(u.nome))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(selecionado,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: cs.onSurface)),
            ),
            Icon(Icons.arrow_drop_down, size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _kpi(ColorScheme cs, String titulo, int valor, NivelRisco nivel) {
    final cor = _corNivel(nivel, cs);
    final icone = _iconeNivel(nivel);
    final selecionado = _nivelFiltro == nivel;

    return Card(
      margin: EdgeInsets.zero,
      // Realça o card selecionado.
      color: selecionado ? cor.withValues(alpha: 0.12) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selecionado
            ? BorderSide(color: cor, width: 1.6)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // Clicar filtra a lista por este nível; clicar de novo limpa.
        onTap: () => setState(
            () => _nivelFiltro = selecionado ? null : nivel),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            children: [
              Icon(icone, color: cor, size: 22),
              const SizedBox(height: 6),
              Text('$valor',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, color: cor)),
              Text(titulo,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _semNoNivel(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Center(
          child: Text(
            'Nenhum lead em "${_nivelFiltro?.rotulo}" no momento',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  Widget _estadoVazio(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.celebration_outlined,
                  size: 40, color: Colors.green.shade600),
              const SizedBox(height: 12),
              Text('Nenhum lead em risco de silêncio',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 4),
              Text('Carteira engajada — siga acompanhando os follow-ups.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: cs.outline)),
            ],
          ),
        ),
      ),
    );
  }

  // Ao tocar num lead: escolher entre ver a ficha ou enviar WhatsApp.
  void _aoTocarLead(Cliente c) {
    final cs = Theme.of(context).colorScheme;
    final temTelefone = (c.telefoneContato ?? '').trim().isNotEmpty;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(c.nome,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.person_outline, color: cs.primary),
              title: const Text('Ver lead'),
              subtitle: const Text('Abrir a ficha completa'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _abrirFicha(c);
              },
            ),
            ListTile(
              leading: Icon(Icons.chat_outlined,
                  color: temTelefone
                      ? const Color(0xFF25D366)
                      : cs.onSurfaceVariant),
              title: const Text('Enviar mensagem'),
              subtitle: Text(temTelefone
                  ? 'Abrir o WhatsApp deste lead'
                  : 'Lead sem telefone cadastrado'),
              enabled: temTelefone,
              onTap: temTelefone
                  ? () {
                      Navigator.pop(sheetCtx);
                      _enviarWhatsApp(c);
                    }
                  : null,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _abrirFicha(Cliente c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FichaClienteScreen(cliente: c, userProfile: widget.userProfile),
      ),
    );
  }

  Future<void> _enviarWhatsApp(Cliente c) async {
    final tel = (c.telefoneContato ?? '').trim();
    if (tel.isEmpty) return;
    try {
      await UrlLauncherService().abrirWhatsApp(tel);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
      );
    }
  }

  Widget _cardRisco(BuildContext context, ColorScheme cs, _RiscoItem item) {
    final c = item.cliente;
    final a = item.avaliacao;
    final cor = _corNivel(a.nivel, cs);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _aoTocarLead(c),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: cor.withValues(alpha: 0.14),
                    child: Icon(_iconeNivel(a.nivel), color: cor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.nome,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        Text(
                          '${c.fase.nomeDisplay}'
                          '${c.vendedorNome?.isNotEmpty == true ? ' · ${c.vendedorNome}' : ''}',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: cor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(a.nivel.rotulo,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: cor)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                          a.diasSemContato == 0
                              ? 'contato hoje'
                              : '${a.diasSemContato}d sem contato',
                          style:
                              TextStyle(fontSize: 10, color: cs.outline)),
                    ],
                  ),
                ],
              ),
              if (a.motivos.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: a.motivos
                      .map((m) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(m,
                                style: TextStyle(
                                    fontSize: 11, color: cs.onSurfaceVariant)),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
