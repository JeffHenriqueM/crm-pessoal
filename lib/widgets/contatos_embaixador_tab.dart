import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/contato_embaixador_model.dart';
import '../models/interacao_model.dart' show Canal, CanalExt;
import '../services/firestore_service.dart';
import '../utils/match_contrato.dart' show telefoneValido;
import '../utils/url_launcher_service.dart';
import '../utils/whatsapp_modelos.dart';

/// Aba "Contatos" da Recepção: lista de contatos que o embaixador trabalha,
/// registrando tentativas (WhatsApp/Ligação) e o "houve resposta?" do dia
/// seguinte.
class ContatosEmbaixadorTab extends StatefulWidget {
  const ContatosEmbaixadorTab({super.key});

  @override
  State<ContatosEmbaixadorTab> createState() => _ContatosEmbaixadorTabState();
}

class _ContatosEmbaixadorTabState extends State<ContatosEmbaixadorTab> {
  final _fs = FirestoreService();
  final _busca = TextEditingController();
  String _filtro = '';

  /// Filtro por responsável: null = todos; '' = sem responsável; senão o nome.
  String? _respFiltro;
  FiltroMensagens _msgFiltro = FiltroMensagens.todas;

  bool get _temFiltro =>
      _filtro.isNotEmpty ||
      _respFiltro != null ||
      _msgFiltro != FiltroMensagens.todas;

  void _limparFiltros() {
    setState(() {
      _busca.clear();
      _filtro = '';
      _respFiltro = null;
      _msgFiltro = FiltroMensagens.todas;
    });
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<ContatoEmbaixador>>(
        stream: _fs.getContatosEmbaixadorStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Erro: ${snap.error}'));
          }
          final todos = snap.data ?? [];
          final hoje = DateTime.now();
          final contatos = filtrarContatosEmbaixador(
            todos,
            texto: _filtro,
            responsavel: _respFiltro,
            mensagens: _msgFiltro,
          );
          final pendentes =
              contatos.where((c) => c.temRespostaPendente(hoje)).length;

          return Column(
            children: [
              _filtrosBar(context, todos, contatos.length),
              Expanded(
                child: contatos.isEmpty
                    ? _vazio(context)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 88),
                        children: [
                          if (pendentes > 0)
                            Card(
                              color: Colors.orange.shade50,
                              child: ListTile(
                                leading: const Icon(
                                    Icons.assignment_late_outlined,
                                    color: Colors.orange),
                                title: Text(
                                    '$pendentes contato(s) aguardando "houve resposta?"'),
                                subtitle: const Text(
                                    'Preencha a resposta das tentativas do dia anterior.'),
                              ),
                            ),
                          for (final c in contatos)
                            _CardContato(contato: c, hoje: hoje, fs: _fs),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _menuAdicionar,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Adicionar'),
      ),
    );
  }

  // ── Barra de busca + filtros (Responsável / Qtd de mensagens) ───────────────
  Widget _filtrosBar(
      BuildContext context, List<ContatoEmbaixador> todos, int total) {
    // Responsáveis distintos (não vazios) presentes nos dados carregados.
    final comResp = <String>{};
    var temSemResp = false;
    for (final c in todos) {
      final r = (c.responsavel ?? '').trim();
      if (r.isEmpty) {
        temSemResp = true;
      } else {
        comResp.add(r);
      }
    }
    final responsaveis = comResp.toList()..sort();

    // Evita assert do Dropdown se o filtro guardado sumiu dos dados.
    final respValido = _respFiltro == null ||
        (_respFiltro!.isEmpty && temSemResp) ||
        responsaveis.contains(_respFiltro);
    final respValue = respValido ? _respFiltro : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        children: [
          TextField(
            controller: _busca,
            decoration: InputDecoration(
              hintText: 'Buscar por nome ou telefone…',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (v) => setState(() => _filtro = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: respValue,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Responsável',
                    prefixIcon: Icon(Icons.person_pin_outlined),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Todos')),
                    if (temSemResp)
                      const DropdownMenuItem(
                          value: '', child: Text('Sem responsável')),
                    for (final r in responsaveis)
                      DropdownMenuItem(value: r, child: Text(r)),
                  ],
                  onChanged: (v) => setState(() => _respFiltro = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<FiltroMensagens>(
                  initialValue: _msgFiltro,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Mensagens',
                    prefixIcon: Icon(Icons.forum_outlined),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: FiltroMensagens.todas, child: Text('Todas')),
                    DropdownMenuItem(
                        value: FiltroMensagens.nenhuma,
                        child: Text('Sem mensagem')),
                    DropdownMenuItem(
                        value: FiltroMensagens.ate2, child: Text('1 a 2')),
                    DropdownMenuItem(
                        value: FiltroMensagens.tresOuMais, child: Text('3 ou +')),
                  ],
                  onChanged: (v) => setState(
                      () => _msgFiltro = v ?? FiltroMensagens.todas),
                ),
              ),
              if (_temFiltro)
                IconButton(
                  tooltip: 'Limpar filtros',
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  onPressed: _limparFiltros,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$total contato(s)${_temFiltro ? ' (filtrado)' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vazio(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.contacts_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_temFiltro ? 'Nada encontrado' : 'Nenhum contato ainda',
                style: tt.titleMedium),
            const SizedBox(height: 6),
            Text(
              _temFiltro
                  ? 'Ajuste a busca ou os filtros de responsável/mensagens.'
                  : 'Use o botão "Adicionar" para incluir um contato ou vários de uma vez.',
              textAlign: TextAlign.center,
              style: tt.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  void _menuAdicionar() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_alt_1),
              title: const Text('Adicionar um contato'),
              onTap: () {
                Navigator.pop(context);
                _formContato();
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Adicionar vários (colar da planilha)'),
              subtitle: const Text(
                  'Um por linha (TAB): nº · embaixador · cliente · telefone'),
              onTap: () {
                Navigator.pop(context);
                _formVarios();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _formContato({ContatoEmbaixador? existente}) async {
    final salvo = await showDialog<bool>(
      context: context,
      builder: (_) => _FormContatoDialog(fs: _fs, existente: existente),
    );
    if (salvo == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contato salvo.')),
      );
    }
  }

  Future<void> _formVarios() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar vários contatos'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cole direto da planilha (colunas separadas por TAB), um por '
                'linha:\nnº · embaixador · nome do cliente · telefone\n'
                'O nº inicial é ignorado. Linhas sem telefone válido são '
                'descartadas.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                minLines: 5,
                maxLines: 12,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '801\tJefferson\tFRANCISCO NASCIMENTO\t61982731384\n'
                      '802\tJefferson\tVICTOR HUGO MONTEIRO\t31998553080',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Importar')),
        ],
      ),
    );
    if (ok != true) return;
    final contatos = parsearContatosColados(ctrl.text);
    if (contatos.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum contato válido na lista.')),
        );
      }
      return;
    }
    await _fs.criarContatosEmbaixadorLote(contatos);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${contatos.length} contato(s) importado(s).')),
      );
    }
  }
}

/// Faixas de quantidade de mensagens/tentativas para o filtro da aba Contatos.
enum FiltroMensagens { todas, nenhuma, ate2, tresOuMais }

/// Filtra a lista de contatos por texto livre (nome/esposa/telefone/responsável),
/// por responsável e por faixa de quantidade de tentativas.
///
/// [responsavel]: `null` = todos; `''` = apenas sem responsável; senão o nome
/// exato. Lógica pura, sem UI, para ser testável.
List<ContatoEmbaixador> filtrarContatosEmbaixador(
  List<ContatoEmbaixador> todos, {
  String texto = '',
  String? responsavel,
  FiltroMensagens mensagens = FiltroMensagens.todas,
}) {
  final t = texto.trim().toLowerCase();

  bool matchTexto(ContatoEmbaixador c) {
    if (t.isEmpty) return true;
    final alvo =
        '${c.nome} ${c.nomeEsposa ?? ''} ${c.telefone} ${c.responsavel ?? ''}'
            .toLowerCase();
    return alvo.contains(t);
  }

  bool matchResponsavel(ContatoEmbaixador c) {
    if (responsavel == null) return true;
    final r = (c.responsavel ?? '').trim();
    return responsavel.isEmpty ? r.isEmpty : r == responsavel;
  }

  bool matchMensagens(ContatoEmbaixador c) {
    final n = c.totalTentativas;
    switch (mensagens) {
      case FiltroMensagens.todas:
        return true;
      case FiltroMensagens.nenhuma:
        return n == 0;
      case FiltroMensagens.ate2:
        return n >= 1 && n <= 2;
      case FiltroMensagens.tresOuMais:
        return n >= 3;
    }
  }

  return todos
      .where((c) =>
          matchTexto(c) && matchResponsavel(c) && matchMensagens(c))
      .toList();
}

/// Faz o parse de uma lista colada direto da planilha (um contato por linha,
/// colunas separadas por TAB):
///
///     nº ⇥ embaixador ⇥ nome do cliente ⇥ telefone
///
/// A coluna do nº inicial é ignorada. Também aceita linhas sem o nº (3 colunas)
/// e sem telefone (campo vazio). Linhas sem nome do cliente são ignoradas.
/// Lógica pura para ser testável.
List<ContatoEmbaixador> parsearContatosColados(String texto) {
  final out = <ContatoEmbaixador>[];
  for (final linhaRaw in texto.split('\n')) {
    // Preserva TABs (inclusive um TAB final = telefone vazio); remove só o \r.
    final linha = linhaRaw.replaceAll('\r', '');
    if (linha.trim().isEmpty) continue;

    // Quebra por TAB; se não houver TAB, tenta ";" (formato manual antigo).
    var cols = (linha.contains('\t') ? linha.split('\t') : linha.split(';'))
        .map((e) => e.trim())
        .toList();

    // Remove a coluna do índice numérico inicial (ex.: "801"), se houver.
    if (cols.length > 3 && RegExp(r'^\d+$').hasMatch(cols.first)) {
      cols = cols.sublist(1);
    }

    String responsavel = '';
    String nome = '';
    String telefone = '';
    if (cols.length >= 3) {
      responsavel = cols[0];
      nome = cols[1];
      telefone = cols[2];
    } else if (cols.length == 2) {
      nome = cols[0];
      telefone = cols[1];
    } else if (cols.length == 1) {
      nome = cols[0];
    }

    nome = nome.trim();
    // Ignora linhas sem nome ou sem telefone válido (DDD + 8/9 dígitos).
    if (nome.isEmpty || !telefoneValido(telefone)) continue;
    out.add(ContatoEmbaixador(
      nome: nome,
      telefone: telefone.trim(),
      responsavel: responsavel.trim().isEmpty ? null : responsavel.trim(),
    ));
  }
  return out;
}

// ── Card de um contato ───────────────────────────────────────────────────────
class _CardContato extends StatelessWidget {
  final ContatoEmbaixador contato;
  final DateTime hoje;
  final FirestoreService fs;
  const _CardContato(
      {required this.contato, required this.hoje, required this.fs});

  @override
  Widget build(BuildContext context) {
    final c = contato;
    final tt = Theme.of(context).textTheme;
    final pendente = c.temRespostaPendente(hoje);
    final ult = c.ultimaTentativa;

    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          child: Text(c.nome.isEmpty ? '?' : c.nome[0].toUpperCase()),
        ),
        title: Text(c.nome,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text([
          c.telefone,
          if (c.responsavel != null && c.responsavel!.isNotEmpty)
            'Resp.: ${c.responsavel}',
          '${c.totalTentativas} tentativa(s)',
        ].join(' · ')),
        trailing: pendente
            ? const Icon(Icons.assignment_late, color: Colors.orange)
            : (ult != null
                ? Icon(ult.canal.icone, size: 18, color: ult.canal.cor)
                : null),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          if (c.responsavel != null && c.responsavel!.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('Responsável pelo próximo contato: ${c.responsavel}',
                    style: tt.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ),
          if (c.nomeEsposa != null && c.nomeEsposa!.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('Esposa: ${c.nomeEsposa}',
                    style: tt.bodySmall?.copyWith(color: Colors.grey)),
              ),
            ),
          if (c.observacao != null && c.observacao!.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Obs.: ${c.observacao}',
                    style: tt.bodySmall?.copyWith(color: Colors.grey)),
              ),
            ),
          // Ações
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _novoContato(context),
                  icon: const Icon(Icons.add_comment_outlined, size: 18),
                  label: const Text('Novo contato'),
                ),
              ),
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => _FormContatoDialog(fs: fs, existente: c),
                ),
              ),
              IconButton(
                tooltip: 'Excluir',
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmarExcluir(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (c.tentativas.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Nenhuma tentativa ainda.',
                  style: tt.bodySmall?.copyWith(color: Colors.grey)),
            )
          else
            for (final entry in _tentativasOrdenadas())
              _LinhaTentativa(
                tentativa: entry.value,
                hoje: hoje,
                onResposta: (houve) =>
                    _responder(context, entry.key, houve),
              ),
        ],
      ),
    );
  }

  /// Tentativas com índice original (para edição), ordenadas recente primeiro.
  List<MapEntry<int, Tentativa>> _tentativasOrdenadas() {
    final lista = [
      for (var i = 0; i < contato.tentativas.length; i++)
        MapEntry(i, contato.tentativas[i])
    ];
    lista.sort((a, b) => b.value.data.compareTo(a.value.data));
    return lista;
  }

  Future<void> _novoContato(BuildContext context) async {
    final canal = await showModalBottomSheet<Canal>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Novo contato por…',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            for (final canal in Tentativa.canaisDisponiveis)
              ListTile(
                leading: Icon(canal.icone, color: canal.cor),
                title: Text(canal.nome),
                onTap: () => Navigator.pop(context, canal),
              ),
          ],
        ),
      ),
    );
    if (canal == null) return;

    // WhatsApp: pergunta com/sem mensagem e abre o chat. Ligação: só registra.
    if (canal == Canal.whatsapp) {
      if (!context.mounted) return;
      final escolha = await escolherMensagemWhatsApp(
        context,
        nome: contato.nome,
        esposa: contato.nomeEsposa,
        responsavel: contato.responsavel,
        fs: fs,
      );
      if (escolha == null) return; // cancelou
      try {
        await UrlLauncherService().abrirWhatsApp(contato.telefone,
            mensagem: escolha.texto.isEmpty ? null : escolha.texto);
      } catch (_) {/* registra mesmo assim */}
    }

    final novas = [
      ...contato.tentativas,
      Tentativa(data: DateTime.now(), canal: canal),
    ];
    await fs.salvarTentativasContato(contato.id, novas);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Tentativa por ${canal.nome} registrada. '
                'Preencha "houve resposta?" amanhã.')),
      );
    }
  }

  Future<void> _responder(
      BuildContext context, int indice, bool houve) async {
    final novas = [...contato.tentativas];
    novas[indice] = novas[indice].copyWith(houveResposta: houve);
    await fs.salvarTentativasContato(contato.id, novas);
  }

  Future<void> _confirmarExcluir(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir contato'),
        content: Text('Excluir "${contato.nome}" e suas tentativas?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok == true) await fs.deletarContatoEmbaixador(contato.id);
  }
}


// ── Linha de uma tentativa ───────────────────────────────────────────────────
class _LinhaTentativa extends StatelessWidget {
  final Tentativa tentativa;
  final DateTime hoje;
  final ValueChanged<bool> onResposta;
  const _LinhaTentativa(
      {required this.tentativa, required this.hoje, required this.onResposta});

  @override
  Widget build(BuildContext context) {
    final t = tentativa;
    final tt = Theme.of(context).textTheme;
    final fmt = DateFormat('dd/MM/yyyy');
    final pendente = t.respostaPendente(hoje);

    Widget resposta;
    if (t.houveResposta != null) {
      resposta = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(t.houveResposta! ? Icons.check_circle : Icons.cancel,
              size: 16,
              color: t.houveResposta! ? Colors.green : Colors.red),
          const SizedBox(width: 4),
          Text(t.houveResposta! ? 'Respondeu' : 'Sem resposta',
              style: tt.labelSmall),
        ],
      );
    } else if (pendente) {
      resposta = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Houve resposta?', style: TextStyle(fontSize: 12)),
          TextButton(
              onPressed: () => onResposta(true), child: const Text('Sim')),
          TextButton(
              onPressed: () => onResposta(false), child: const Text('Não')),
        ],
      );
    } else {
      resposta = Text('Responder amanhã',
          style: tt.labelSmall?.copyWith(color: Colors.grey));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(t.canal.icone, size: 16, color: t.canal.cor),
          const SizedBox(width: 8),
          Expanded(child: Text('${t.canal.nome} · ${fmt.format(t.data)}')),
          resposta,
        ],
      ),
    );
  }
}

// ── Form de criar/editar contato ─────────────────────────────────────────────
class _FormContatoDialog extends StatefulWidget {
  final FirestoreService fs;
  final ContatoEmbaixador? existente;
  const _FormContatoDialog({required this.fs, this.existente});

  @override
  State<_FormContatoDialog> createState() => _FormContatoDialogState();
}

class _FormContatoDialogState extends State<_FormContatoDialog> {
  late final _nome = TextEditingController(text: widget.existente?.nome ?? '');
  late final _esposa =
      TextEditingController(text: widget.existente?.nomeEsposa ?? '');
  late final _tel =
      TextEditingController(text: widget.existente?.telefone ?? '');
  late final _obs =
      TextEditingController(text: widget.existente?.observacao ?? '');
  late final _responsavel =
      TextEditingController(text: widget.existente?.responsavel ?? '');
  bool _salvando = false;

  @override
  void dispose() {
    _nome.dispose();
    _esposa.dispose();
    _tel.dispose();
    _obs.dispose();
    _responsavel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existente == null ? 'Novo contato' : 'Editar contato'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nome,
              decoration: const InputDecoration(labelText: 'Nome *'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _esposa,
              decoration: const InputDecoration(labelText: 'Nome da esposa'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tel,
              decoration: const InputDecoration(labelText: 'Telefone'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _responsavel,
              decoration: const InputDecoration(
                  labelText: 'Responsável pelo próximo contato'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _obs,
              decoration: const InputDecoration(labelText: 'Observação'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: _salvando ? null : _salvar,
          child: _salvando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Salvar'),
        ),
      ],
    );
  }

  Future<void> _salvar() async {
    final nome = _nome.text.trim();
    final tel = _tel.text.trim();
    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O nome é obrigatório.')),
      );
      return;
    }
    if (!telefoneValido(tel)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Informe um telefone válido (DDD + número).')),
      );
      return;
    }
    setState(() => _salvando = true);
    final esposa = _esposa.text.trim();
    final obs = _obs.text.trim();
    final resp = _responsavel.text.trim();
    try {
      if (widget.existente == null) {
        await widget.fs.criarContatoEmbaixador(ContatoEmbaixador(
          nome: nome,
          nomeEsposa: esposa.isEmpty ? null : esposa,
          telefone: tel,
          observacao: obs.isEmpty ? null : obs,
          responsavel: resp.isEmpty ? null : resp,
        ));
      } else {
        await widget.fs.atualizarContatoEmbaixador(widget.existente!.copyWith(
          nome: nome,
          nomeEsposa: esposa.isEmpty ? null : esposa,
          telefone: tel,
          observacao: obs.isEmpty ? null : obs,
          responsavel: resp.isEmpty ? null : resp,
        ));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }
}
