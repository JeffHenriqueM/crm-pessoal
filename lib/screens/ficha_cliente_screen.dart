import 'dart:async';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../models/cliente_model.dart';
import '../models/fase_enum.dart';
import '../models/interacao_model.dart';
import '../models/negociacao_model.dart';
import '../models/usuario_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/url_launcher_service.dart';
import '../widgets/aba_negociacoes.dart';
import '../widgets/ficha/ficha_dados_tab.dart';
import '../widgets/ficha/ficha_timeline_tab.dart';

final _moedaCompacta =
    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);

/// Tela unificada: criação + edição + interações + negociações.
/// Estado, lógica e dialogs ficam aqui; UI das abas em widgets separados.
class FichaClienteScreen extends StatefulWidget {
  final Cliente? cliente;
  final String userProfile;

  const FichaClienteScreen({
    super.key,
    this.cliente,
    this.userProfile = 'vendedor',
  });

  @override
  State<FichaClienteScreen> createState() => _FichaClienteScreenState();
}

class _FichaClienteScreenState extends State<FichaClienteScreen>
    with TickerProviderStateMixin {
  // ── Controllers ───────────────────────────────────────────────────────────────
  late final TabController _tabController;
  final _service = FirestoreService();
  final _authService = AuthService();

  // ── Identidade do cliente ─────────────────────────────────────────────────────
  String? _clienteId;
  bool get _isNovo => _clienteId == null;

  // ── Streams de dados (só para clientes existentes) ────────────────────────────
  List<Interacao> _interacoes = [];
  List<Negociacao> _negociacoes = [];
  StreamSubscription<List<Interacao>>? _intSub;
  StreamSubscription<List<Negociacao>>? _negSub;

  // ── Form ──────────────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _nomeParceiroCtrl;
  late final TextEditingController _telefone1Ctrl;
  late final TextEditingController _telefone2Ctrl;
  late final TextEditingController _motivoPerdaDescCtrl;

  String _tipo = 'Casal';
  FaseCliente _fase = FaseCliente.prospeccao;
  String? _origem;
  String? _motivoPerdaDropdown;
  DateTime? _dataCaptacao;
  DateTime? _proximoContato;
  DateTime? _dataVisita;
  bool _tentouSalvar = false;

  List<Usuario> _usuarios = [];
  Usuario? _captador;
  Usuario? _vendedor;
  bool _carregandoUsuarios = true;
  bool _salvandoDados = false;

  // ── Init / Dispose ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _clienteId = widget.cliente?.id;
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    final c = widget.cliente;
    _nomeCtrl = TextEditingController(text: c?.nome ?? '');
    _nomeParceiroCtrl = TextEditingController(text: c?.nomeEsposa ?? '');
    _telefone1Ctrl = TextEditingController(text: c?.telefoneContato ?? '');
    _telefone2Ctrl = TextEditingController(text: c?.telefone2 ?? '');
    _motivoPerdaDescCtrl = TextEditingController(text: c?.motivoNaoVenda ?? '');
    _tipo = c?.tipo ?? 'Casal';
    _fase = c?.fase ?? FaseCliente.prospeccao;
    _origem =
        const ['Presencial', 'WhatsApp', 'Instagram'].contains(c?.origem)
            ? c?.origem
            : null;
    _motivoPerdaDropdown = c?.motivoNaoVendaDropdown;
    _dataCaptacao = c?.dataEntradaSala;
    _proximoContato = c?.proximoContato;
    _dataVisita = c?.dataVisita;

    _carregarUsuarios();
    if (!_isNovo) _iniciarStreams();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nomeCtrl.dispose();
    _nomeParceiroCtrl.dispose();
    _telefone1Ctrl.dispose();
    _telefone2Ctrl.dispose();
    _motivoPerdaDescCtrl.dispose();
    _intSub?.cancel();
    _negSub?.cancel();
    super.dispose();
  }

  // ── Streams ───────────────────────────────────────────────────────────────────
  void _iniciarStreams() {
    _intSub?.cancel();
    _negSub?.cancel();
    _intSub = _service.getInteracoesStream(_clienteId!).listen((lista) {
      if (mounted) setState(() => _interacoes = lista);
    });
    _negSub = _service.getNegociacoesStream(_clienteId!).listen((lista) {
      if (mounted) setState(() => _negociacoes = lista);
    });
  }

  // ── Carregamento de usuários ──────────────────────────────────────────────────
  Future<void> _carregarUsuarios() async {
    try {
      final lista = await _service.getTodosUsuarios(apenasAtivos: true);
      if (!mounted) return;
      setState(() {
        _usuarios = lista;
        _carregandoUsuarios = false;
        if (widget.cliente?.captadorId != null) {
          try {
            _captador =
                _usuarios.firstWhere((u) => u.id == widget.cliente!.captadorId);
          } catch (_) {}
        }
        if (widget.cliente?.vendedorId != null) {
          try {
            _vendedor =
                _usuarios.firstWhere((u) => u.id == widget.cliente!.vendedorId);
          } catch (_) {}
        }
      });
    } catch (_) {
      if (mounted) setState(() => _carregandoUsuarios = false);
    }
  }

  // ── Origem → fase automática (só na criação) ──────────────────────────────────
  void _atualizarFasePorOrigem(String? origem) {
    setState(() {
      _origem = origem;
      if (_isNovo) {
        if (origem == 'Presencial') {
          _fase = FaseCliente.visita;
        } else if (origem == 'WhatsApp' || origem == 'Instagram') {
          _fase = FaseCliente.contato;
        }
      }
    });
  }

  // ── Seletores de data ─────────────────────────────────────────────────────────
  Future<void> _selecionarData(
      void Function(DateTime?) onSet, DateTime? atual) async {
    final data = await showDatePicker(
      context: context,
      initialDate: atual ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (mounted) setState(() => onSet(data));
  }

  Future<void> _selecionarProximoContato() async {
    final dataAnterior = _proximoContato;
    await _selecionarData((d) => _proximoContato = d, _proximoContato);
    if (!mounted) return;

    final novaData = _proximoContato;
    final mudou = novaData != null &&
        !_isNovo &&
        _clienteId != null &&
        dataAnterior != null &&
        (novaData.year != dataAnterior.year ||
            novaData.month != dataAnterior.month ||
            novaData.day != dataAnterior.day);

    if (mudou) await _mostrarModalRastreamento(dataAnterior);
  }

  // ── Modal de rastreamento de mensagem (#16) ───────────────────────────────────
  Future<void> _mostrarModalRastreamento(DateTime dataAnterior) async {
    if (_clienteId == null) return;
    final dataStr = DateFormat('dd/MM/yyyy').format(dataAnterior);
    int etapa = 0;
    final motivoCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          Widget buildContent() {
            if (etapa == 0) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A mensagem agendada para $dataStr foi enviada ao cliente?',
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              );
            }
            if (etapa == 1) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ótimo! O cliente respondeu?',
                      style: TextStyle(fontSize: 15)),
                ],
              );
            }
            // etapa == 2
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Qual o motivo de não ter enviado?',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                TextField(
                  controller: motivoCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Ex: cliente pediu para aguardar...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            );
          }

          List<Widget> buildActions() {
            final cs = Theme.of(ctx).colorScheme;
            if (etapa == 0) {
              return [
                TextButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _service.registrarRastreamentoMensagem(
                      clienteId: _clienteId!,
                      status: 'nao_enviada',
                      motivo: 'Não informado',
                    );
                  },
                  child: const Text('Fechar'),
                ),
                OutlinedButton(
                  onPressed: () => setD(() => etapa = 2),
                  child: const Text('Não'),
                ),
                FilledButton(
                  onPressed: () => setD(() => etapa = 1),
                  child: const Text('Sim'),
                ),
              ];
            }
            if (etapa == 1) {
              return [
                OutlinedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _service.registrarRastreamentoMensagem(
                      clienteId: _clienteId!,
                      status: 'enviada_sem_resposta',
                    );
                  },
                  child: const Text('Ainda não'),
                ),
                FilledButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _service.registrarRastreamentoMensagem(
                      clienteId: _clienteId!,
                      status: 'enviada_com_resposta',
                    );
                    await _service.limparStatusMensagem(_clienteId!);
                  },
                  child: const Text('Sim, respondeu!'),
                ),
              ];
            }
            // etapa == 2
            return [
              TextButton(
                onPressed: () => setD(() => etapa = 0),
                child: const Text('Voltar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: cs.error),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _service.registrarRastreamentoMensagem(
                    clienteId: _clienteId!,
                    status: 'nao_enviada',
                    motivo: motivoCtrl.text.trim(),
                  );
                },
                child: const Text('Confirmar'),
              ),
            ];
          }

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.message_outlined, size: 20),
                const SizedBox(width: 8),
                const Expanded(child: Text('Rastreamento de Mensagem')),
                if (etapa == 0)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Fechar (registra como não enviada)',
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await _service.registrarRastreamentoMensagem(
                        clienteId: _clienteId!,
                        status: 'nao_enviada',
                        motivo: 'Não informado',
                      );
                    },
                  ),
              ],
            ),
            content: buildContent(),
            actions: buildActions(),
          );
        },
      ),
    );
    motivoCtrl.dispose();
  }

  // ── Salvar dados ──────────────────────────────────────────────────────────────
  Future<void> _salvarDados() async {
    setState(() => _tentouSalvar = true);
    if (!_formKey.currentState!.validate()) return;
    if (_dataCaptacao == null) return;

    setState(() => _salvandoDados = true);
    try {
      if (_isNovo) {
        final novoCliente = Cliente(
          nome: _nomeCtrl.text.trim(),
          tipo: _tipo,
          nomeEsposa:
              _tipo == 'Casal' ? _nomeParceiroCtrl.text.trim() : null,
          telefoneContato: _telefone1Ctrl.text.trim(),
          telefone2: _telefone2Ctrl.text.trim().isEmpty
              ? null
              : _telefone2Ctrl.text.trim(),
          origem: _origem,
          fase: _fase,
          dataCadastro: DateTime.now(),
          dataAtualizacao: DateTime.now(),
          proximoContato: _proximoContato,
          dataVisita: _dataVisita,
          captadorId: _captador?.id,
          captadorNome: _captador?.nome,
          vendedorId: _vendedor?.id,
          vendedorNome: _vendedor?.nome,
          dataEntradaSala: _dataCaptacao,
          motivoNaoVendaDropdown:
              _fase == FaseCliente.perdido ? _motivoPerdaDropdown : null,
          motivoNaoVenda: _fase == FaseCliente.perdido
              ? _motivoPerdaDescCtrl.text.trim()
              : null,
        );
        final id = await _service.adicionarCliente(novoCliente);
        for (final i in _interacoes) {
          await _service.adicionarInteracao(id, i);
        }
        for (final n in _negociacoes) {
          await _service.adicionarNegociacao(n.copyWith(clienteId: id));
        }
        if (!mounted) return;
        setState(() {
          _clienteId = id;
          _interacoes = [];
          _negociacoes = [];
          _iniciarStreams();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente criado! Interações e negociações salvas.'),
            backgroundColor: Colors.green,
          ),
        );
        _tabController.animateTo(1);
      } else {
        final user = _authService.getCurrentUser();
        final dados = <String, dynamic>{
          'nome': _nomeCtrl.text.trim(),
          'tipo': _tipo,
          'nomeEsposa':
              _tipo == 'Casal' ? _nomeParceiroCtrl.text.trim() : null,
          'telefoneContato': _telefone1Ctrl.text.trim(),
          'telefone2': _telefone2Ctrl.text.trim().isEmpty
              ? null
              : _telefone2Ctrl.text.trim(),
          'origem': _origem,
          'fase': _fase.toString().split('.').last,
          'proximoContato': _proximoContato != null
              ? Timestamp.fromDate(_proximoContato!)
              : null,
          'dataVisita':
              _dataVisita != null ? Timestamp.fromDate(_dataVisita!) : null,
          'captadorId': _captador?.id,
          'captadorNome': _captador?.nome,
          'vendedorId': _vendedor?.id,
          'vendedorNome': _vendedor?.nome,
          'dataEntradaSala': Timestamp.fromDate(_dataCaptacao!),
          'motivoNaoVenda': _fase == FaseCliente.perdido
              ? _motivoPerdaDescCtrl.text.trim()
              : null,
          'motivoNaoVendaDropdown':
              _fase == FaseCliente.perdido ? _motivoPerdaDropdown : null,
          'atualizadoPorId': user?.uid,
        };
        await _service.atualizarClienteDetalhes(_clienteId!, dados);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_nomeCtrl.text.trim()} atualizado!'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvandoDados = false);
    }
  }

  // ── Ações rápidas (AppBar menu) ───────────────────────────────────────────────
  void _mudarFaseDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mudar Fase'),
        content: DropdownButton<FaseCliente>(
          value: _fase,
          isExpanded: true,
          onChanged: (novaFase) async {
            if (novaFase == null) return;
            Navigator.of(ctx).pop();
            if (novaFase == FaseCliente.perdido) {
              _pedirMotivoPerda(novaFase);
            } else {
              await _service.atualizarFaseCliente(_clienteId!, novaFase);
              if (mounted) setState(() => _fase = novaFase);
            }
          },
          items: FaseCliente.values
              .map((f) =>
                  DropdownMenuItem(value: f, child: Text(f.nomeDisplay)))
              .toList(),
        ),
      ),
    );
  }

  void _pedirMotivoPerda(FaseCliente novaFase) {
    final motivoCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Perda'),
        content: TextField(
          controller: motivoCtrl,
          decoration:
              const InputDecoration(hintText: 'Qual o motivo da perda?'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              await _service.atualizarFaseCliente(_clienteId!, novaFase,
                  motivo: motivoCtrl.text.trim());
              if (mounted) setState(() => _fase = novaFase);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirWhatsApp(String tel) async {
    try {
      await UrlLauncherService().abrirWhatsApp(tel);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _adicionarAgenda() {
    if (_proximoContato == null) return;
    Add2Calendar.addEvent2Cal(Event(
      title: 'Contato: ${_nomeCtrl.text}',
      description: 'Ligar para ${_nomeCtrl.text}.',
      location: 'CRM Villamor',
      startDate: _proximoContato!,
      endDate: _proximoContato!.add(const Duration(minutes: 30)),
    ));
  }

  void _apagarClienteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Apagar permanentemente "${_nomeCtrl.text}"?'),
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
              final nav = Navigator.of(context);
              await _service.deletarCliente(_clienteId!);
              if (ctx.mounted) Navigator.of(ctx).pop();
              nav.pop();
            },
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
  }

  // ── Dialogs de interação ──────────────────────────────────────────────────────
  void _mostrarDialogoInteracao(Interacao? interacao) {
    final isEditing = interacao != null;
    final tituloCtrl = TextEditingController(text: interacao?.titulo);
    final notaCtrl = TextEditingController(text: interacao?.nota);
    final proximoPassoCtrl =
        TextEditingController(text: interacao?.proximoPasso ?? '');
    var tipoSelecionado = interacao?.tipo ?? TipoInteracao.ligacao;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(isEditing ? 'Editar Interação' : 'Nova Interação'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tipo',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(ctx).colorScheme.primary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: TipoInteracao.values.map((t) {
                        final selecionado = tipoSelecionado == t;
                        return ChoiceChip(
                          avatar: Icon(t.icone,
                              size: 14,
                              color: selecionado
                                  ? Theme.of(ctx)
                                      .colorScheme
                                      .onPrimaryContainer
                                  : t.cor),
                          label: Text(t.nome,
                              style: const TextStyle(fontSize: 12)),
                          selected: selecionado,
                          onSelected: (_) =>
                              setStateDialog(() => tipoSelecionado = t),
                          selectedColor: t.cor.withValues(alpha: 0.18),
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: tituloCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Título',
                          prefixIcon: Icon(Icons.title)),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Insira um título.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nota',
                        prefixIcon: Icon(Icons.notes),
                        alignLabelWithHint: true,
                      ),
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 4,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Insira uma nota.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: proximoPassoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'O que combinamos? (opcional)',
                        prefixIcon: Icon(Icons.check_circle_outline),
                        alignLabelWithHint: true,
                        hintText: 'Ex: Ligar na sexta às 14h...',
                      ),
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final passo = proximoPassoCtrl.text.trim();
                final nova = Interacao(
                  id: interacao?.id ??
                      'local_${DateTime.now().millisecondsSinceEpoch}',
                  titulo: tituloCtrl.text.trim(),
                  nota: notaCtrl.text.trim(),
                  dataInteracao: interacao?.dataInteracao ?? DateTime.now(),
                  tipo: tipoSelecionado,
                  proximoPasso: passo.isEmpty ? null : passo,
                );
                if (_isNovo) {
                  setState(() {
                    if (isEditing) {
                      final idx =
                          _interacoes.indexWhere((i) => i.id == interacao.id);
                      if (idx >= 0) _interacoes[idx] = nova;
                    } else {
                      _interacoes.insert(0, nova);
                    }
                  });
                  if (ctx.mounted) Navigator.of(ctx).pop();
                } else {
                  if (isEditing) {
                    await _service.atualizarInteracao(_clienteId!, nova);
                  } else {
                    await _service.adicionarInteracao(_clienteId!, nova);
                  }
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text(
                          'Interação ${isEditing ? 'atualizada' : 'registrada'}!'),
                      backgroundColor: Colors.green.shade700,
                    ));
                  }
                }
              },
              child: Text(isEditing ? 'Salvar' : 'Registrar'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarOpcoesInteracao(Interacao interacao) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.edit_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('Editar'),
            onTap: () {
              Navigator.of(ctx).pop();
              _mostrarDialogoInteracao(interacao);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline,
                color: Theme.of(ctx).colorScheme.error),
            title: const Text('Excluir'),
            onTap: () async {
              Navigator.of(ctx).pop();
              if (_isNovo) {
                setState(() =>
                    _interacoes.removeWhere((i) => i.id == interacao.id));
                return;
              }
              final confirm = await showDialog<bool>(
                context: context,
                builder: (dctx) => AlertDialog(
                  title: const Text('Excluir interação?'),
                  content: const Text('Esta ação não pode ser desfeita.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(dctx).pop(false),
                        child: const Text('Não')),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            Theme.of(dctx).colorScheme.error,
                        foregroundColor:
                            Theme.of(dctx).colorScheme.onError,
                      ),
                      onPressed: () => Navigator.of(dctx).pop(true),
                      child: const Text('Excluir'),
                    ),
                  ],
                ),
              );
              if (confirm == true && mounted) {
                await _service.excluirInteracao(_clienteId!, interacao.id!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Interação excluída.')));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // ── FAB dinâmico por aba ──────────────────────────────────────────────────────
  Widget? _buildFab() {
    if (_tabController.index == 0) return null;
    if (_tabController.index == 1) {
      return FloatingActionButton.extended(
        key: const ValueKey('fab_interacao'),
        onPressed: () => _mostrarDialogoInteracao(null),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Nova Interação'),
      );
    }
    return FloatingActionButton.extended(
      key: const ValueKey('fab_negociacao'),
      onPressed: () => abrirFormularioNegociacao(
        context,
        clienteId: _isNovo ? null : _clienteId,
        service: _isNovo ? null : _service,
        proximoNumero: _negociacoes.length + 1,
        onSaveLocal:
            _isNovo ? (neg) => setState(() => _negociacoes.add(neg)) : null,
        currentUserId: _authService.getCurrentUser()?.uid,
        currentUserName: _authService.getCurrentUser()?.displayName,
        userProfile: widget.userProfile,
      ),
      icon: const Icon(Icons.add),
      label: const Text('Nova Proposta'),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final titulo = _isNovo ? 'Novo Cliente' : _nomeCtrl.text;

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        actions: [
          if (!_isNovo)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Mais ações',
              onSelected: (action) {
                switch (action) {
                  case 'whatsapp1':
                    _abrirWhatsApp(_telefone1Ctrl.text.trim());
                  case 'whatsapp2':
                    _abrirWhatsApp(_telefone2Ctrl.text.trim());
                  case 'fase':
                    _mudarFaseDialog();
                  case 'agenda':
                    _adicionarAgenda();
                  case 'apagar':
                    _apagarClienteDialog();
                }
              },
              itemBuilder: (ctx) => [
                if (_telefone1Ctrl.text.trim().isNotEmpty)
                  PopupMenuItem(
                    value: 'whatsapp1',
                    child: ListTile(
                      leading: const Icon(FontAwesomeIcons.whatsapp,
                          color: Color(0xFF25D366)),
                      title:
                          Text('WhatsApp — ${_telefone1Ctrl.text.trim()}'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                if (_telefone2Ctrl.text.trim().isNotEmpty)
                  PopupMenuItem(
                    value: 'whatsapp2',
                    child: ListTile(
                      leading: const Icon(FontAwesomeIcons.whatsapp,
                          color: Color(0xFF25D366)),
                      title:
                          Text('WhatsApp 2 — ${_telefone2Ctrl.text.trim()}'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                const PopupMenuItem(
                  value: 'fase',
                  child: ListTile(
                    leading: Icon(Icons.swap_horiz_outlined),
                    title: Text('Mudar Fase'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                if (_proximoContato != null)
                  const PopupMenuItem(
                    value: 'agenda',
                    child: ListTile(
                      leading: Icon(Icons.event_outlined),
                      title: Text('Adicionar à Agenda'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'apagar',
                  child: ListTile(
                    leading:
                        Icon(Icons.delete_outline, color: cs.error),
                    title: Text('Apagar Cliente',
                        style: TextStyle(color: cs.error)),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(icon: Icon(Icons.person_outlined), text: 'Dados'),
            Tab(
              icon: const Icon(Icons.chat_bubble_outline),
              child: _buildTabLabel('Interações', _interacoes.length),
            ),
            Tab(
              icon: const Icon(Icons.handshake_outlined),
              child: _buildTabLabel('Negociações', _negociacoes.length),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Aba 0: Dados ────────────────────────────────────────────────────
          FichaDadosTab(
            formKey: _formKey,
            nomeCtrl: _nomeCtrl,
            nomeParceiroCtrl: _nomeParceiroCtrl,
            telefone1Ctrl: _telefone1Ctrl,
            telefone2Ctrl: _telefone2Ctrl,
            motivoPerdaDescCtrl: _motivoPerdaDescCtrl,
            tipo: _tipo,
            fase: _fase,
            origem: _origem,
            motivoPerdaDropdown: _motivoPerdaDropdown,
            dataCaptacao: _dataCaptacao,
            proximoContato: _proximoContato,
            dataVisita: _dataVisita,
            tentouSalvar: _tentouSalvar,
            salvandoDados: _salvandoDados,
            carregandoUsuarios: _carregandoUsuarios,
            isNovo: _isNovo,
            usuarios: _usuarios,
            captador: _captador,
            vendedor: _vendedor,
            onTipoChanged: (v) => setState(() {
              _tipo = v;
              if (v == 'Individual') _nomeParceiroCtrl.clear();
            }),
            onOrigemChanged: _atualizarFasePorOrigem,
            onFaseChanged: (v) {
              if (v != null) {
                setState(() {
                  _fase = v;
                  if (v != FaseCliente.perdido) {
                    _motivoPerdaDropdown = null;
                    _motivoPerdaDescCtrl.clear();
                  }
                });
              }
            },
            onMotivoPerdaDropdownChanged: (v) =>
                setState(() => _motivoPerdaDropdown = v),
            onCaptadorChanged: (v) => setState(() => _captador = v),
            onVendedorChanged: (v) => setState(() => _vendedor = v),
            onSelectDataCaptacao: () =>
                _selecionarData((d) => _dataCaptacao = d, _dataCaptacao),
            onClearDataCaptacao: () =>
                setState(() => _dataCaptacao = null),
            onSelectProximoContato: _selecionarProximoContato,
            onClearProximoContato: () =>
                setState(() => _proximoContato = null),
            onSelectDataVisita: () =>
                _selecionarData((d) => _dataVisita = d, _dataVisita),
            onClearDataVisita: () => setState(() => _dataVisita = null),
            onSalvar: _salvarDados,
            onNomeChanged: () => setState(() {}),
          ),

          // ── Aba 1: Timeline de Interações ───────────────────────────────────
          FichaTimelineTab(
            interacoes: _interacoes,
            isNovo: _isNovo,
            onItemTap: _mostrarOpcoesInteracao,
          ),

          // ── Aba 2: Negociações ──────────────────────────────────────────────
          _buildNegociacoesTab(),
        ],
      ),
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _buildFab(),
      ),
    );
  }

  Widget _buildTabLabel(String label, int count) {
    if (count == 0) return Text(label);
    return Badge.count(
      count: count,
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Text(label),
      ),
    );
  }

  // ── Aba: Negociações ──────────────────────────────────────────────────────────
  Widget _buildNegociacoesTab() {
    if (!_isNovo) {
      return AbaNegociacoes(
        clienteId: _clienteId!,
        proximoNumero: _negociacoes.length + 1,
        currentUserId: _authService.getCurrentUser()?.uid,
        currentUserName: _authService.getCurrentUser()?.displayName,
        userProfile: widget.userProfile,
      );
    }

    final cs = Theme.of(context).colorScheme;
    if (_negociacoes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.handshake_outlined,
                  size: 56, color: cs.outline.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text(
                'Adicione propostas antes de salvar\no cliente — serão enviadas junto.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.outline, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      itemCount: _negociacoes.length,
      itemBuilder: (context, i) =>
          _buildNegociacaoPendenteCard(_negociacoes[i], i),
    );
  }

  Widget _buildNegociacaoPendenteCard(Negociacao neg, int idx) {
    final cs = Theme.of(context).colorScheme;
    const cores = {
      StatusNegociacao.ativa: Color(0xFF1565C0),
      StatusNegociacao.aceita: Color(0xFF2E7D32),
      StatusNegociacao.recusada: Color(0xFFC62828),
    };
    final cor = cores[neg.status]!;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(neg.titulo,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    _moedaCompacta.format(neg.valorFinal),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: cs.primary),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cor.withValues(alpha: 0.3)),
              ),
              child: Text(
                neg.status.nomeDisplay,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cor),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 18, color: cs.primary),
              onPressed: () => abrirFormularioNegociacao(
                context,
                proximoNumero: _negociacoes.length + 1,
                editando: neg,
                onSaveLocal: (updated) =>
                    setState(() => _negociacoes[idx] = updated),
                currentUserId: _authService.getCurrentUser()?.uid,
                currentUserName: _authService.getCurrentUser()?.displayName,
                userProfile: widget.userProfile,
              ),
              visualDensity: VisualDensity.compact,
              tooltip: 'Editar',
            ),
            IconButton(
              icon:
                  Icon(Icons.delete_outline, size: 18, color: cs.error),
              onPressed: () =>
                  setState(() => _negociacoes.removeAt(idx)),
              visualDensity: VisualDensity.compact,
              tooltip: 'Remover',
            ),
          ],
        ),
      ),
    );
  }
}
