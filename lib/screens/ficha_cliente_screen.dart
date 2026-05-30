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
  late final TextEditingController _brindeCtrl;

  String _tipo = 'Casal';
  FaseCliente _fase = FaseCliente.prospeccao;
  String? _origem;
  String? _motivoPerdaDropdown;
  DateTime? _dataCaptacao;
  DateTime? _proximoContato;
  DateTime? _dataVisita;
  DateTime? _dataFechamento;
  double? _valorVendido;
  bool _tentouSalvar = false;
  bool _dadosAlterados = false; // true quando formulário foi modificado mas não salvo

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
    _tabController.addListener(_onTabChanged);

    final c = widget.cliente;
    _nomeCtrl = TextEditingController(text: c?.nome ?? '');
    _nomeParceiroCtrl = TextEditingController(text: c?.nomeEsposa ?? '');
    _telefone1Ctrl = TextEditingController(text: c?.telefoneContato ?? '');
    _telefone2Ctrl = TextEditingController(text: c?.telefone2 ?? '');
    _motivoPerdaDescCtrl = TextEditingController(text: c?.motivoNaoVenda ?? '');
    _brindeCtrl = TextEditingController(text: c?.brinde ?? '');
    _tipo = c?.tipo ?? 'Casal';
    _fase = c?.fase ?? FaseCliente.prospeccao;
    _origem =
        const ['Presencial', 'WhatsApp', 'Instagram'].contains(c?.origem)
            ? c?.origem
            : null;
    _motivoPerdaDropdown = c?.motivoNaoVendaDropdown;
    _dataCaptacao = c?.dataEntradaSala ?? (c == null ? DateTime.now() : null);
    _proximoContato = c?.proximoContato;
    _dataVisita = c?.dataVisita;
    _dataFechamento = c?.dataFechamento;
    _valorVendido = c?.valorVendido;

    // Detectar alterações não salvas na aba Dados
    for (final c in [_nomeCtrl, _nomeParceiroCtrl, _telefone1Ctrl,
                     _telefone2Ctrl, _motivoPerdaDescCtrl, _brindeCtrl]) {
      c.addListener(_marcarAlterado);
    }

    _carregarUsuarios();
    if (!_isNovo) _iniciarStreams();
  }

  void _marcarAlterado() {
    if (!_dadosAlterados && mounted) setState(() => _dadosAlterados = true);
  }

  /// Chamado ao trocar de aba. Se houver alterações não salvas na aba Dados,
  /// pergunta se o usuário quer salvar antes.
  void _onTabChanged() {
    if (!mounted) return;
    setState(() {});
    // Só pergunta quando SAI da aba Dados (índice 0) com mudanças pendentes
    if (!_tabController.indexIsChanging) return;
    if (_tabController.previousIndex != 0) return;
    if (!_dadosAlterados) return;

    // Adia para depois do frame (evita conflito com animação do TabController)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Salvar alterações?'),
          content: const Text(
            'Você alterou dados do lead mas não salvou.\n'
            'Deseja salvar antes de continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Ignorar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ).then((salvar) {
        if (salvar == true && mounted) _salvarDados();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nomeCtrl.dispose();
    _nomeParceiroCtrl.dispose();
    _telefone1Ctrl.dispose();
    _telefone2Ctrl.dispose();
    _motivoPerdaDescCtrl.dispose();
    _brindeCtrl.dispose();
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
      // Carrega TODOS os usuários (incluindo inativos) para garantir que o
      // captador/vendedor atual seja sempre encontrado no dropdown, mesmo que
      // tenha sido desativado após o cadastro.
      final lista = await _service.getTodosUsuarios();
      if (!mounted) return;

      final currentUid = _authService.getCurrentUser()?.uid;
      final isAdmin = widget.userProfile == 'admin' ||
          widget.userProfile == 'super admin';

      setState(() {
        _usuarios = lista;
        _carregandoUsuarios = false;

        if (widget.cliente?.captadorId != null) {
          try {
            _captador = _usuarios
                .firstWhere((u) => u.id == widget.cliente!.captadorId);
          } catch (_) {}
        }

        if (widget.cliente?.vendedorId != null) {
          // Editando: restaura o vendedor salvo
          try {
            _vendedor = _usuarios
                .firstWhere((u) => u.id == widget.cliente!.vendedorId);
          } catch (_) {}
        } else if (_isNovo && !isAdmin && currentUid != null) {
          // Novo cliente criado por um vendedor/captador:
          // auto-preenche o vendedor com o próprio usuário logado
          // para que o cliente apareça no funil dele imediatamente.
          try {
            _vendedor = _usuarios.firstWhere((u) => u.id == currentUid);
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

  // ── Diálogo de fechamento ─────────────────────────────────────────────────────
  Future<void> _mostrarDialogoFechamento(FaseCliente novaFase) async {
    DateTime? dataEscolhida = _dataFechamento ?? DateTime.now();
    final valorCtrl = TextEditingController(
      text: _valorVendido != null ? _valorVendido!.toStringAsFixed(0) : '',
    );

    final confirmado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green),
              SizedBox(width: 10),
              Text('Fechamento'),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registre a data e o valor do fechamento.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),

                // Data de fechamento
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: dataEscolhida ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (d != null) setD(() => dataEscolhida = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Theme.of(ctx).colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 18,
                            color: dataEscolhida != null
                                ? Theme.of(ctx).colorScheme.primary
                                : Theme.of(ctx).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 10),
                        Text(
                          dataEscolhida != null
                              ? 'Data: ${DateFormat('dd/MM/yyyy').format(dataEscolhida!)}'
                              : 'Selecionar data do fechamento',
                          style: TextStyle(
                            fontSize: 14,
                            color: dataEscolhida != null
                                ? Theme.of(ctx).colorScheme.onSurface
                                : Theme.of(ctx).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Valor vendido
                TextField(
                  controller: valorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Valor vendido (opcional)',
                    prefixIcon: Icon(Icons.attach_money),
                    prefixText: 'R\$ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: dataEscolhida == null
                  ? null
                  : () => Navigator.of(ctx).pop(true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );

    if (confirmado == true && mounted) {
      final valorDigitado = double.tryParse(
          valorCtrl.text.replaceAll(',', '.'));
      setState(() {
        _fase = novaFase;
        _dataFechamento = dataEscolhida;
        _valorVendido = valorDigitado;
        _motivoPerdaDropdown = null;
        _motivoPerdaDescCtrl.clear();
      });
    }
    valorCtrl.dispose();
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
    if (_fase == FaseCliente.perdido &&
        (_motivoPerdaDropdown == null || _motivoPerdaDropdown!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o motivo da perda antes de salvar.')),
      );
      return;
    }

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
          dataFechamento: _dataFechamento,
          valorVendido: _valorVendido,
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
          _dadosAlterados = false;
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
          'dataFechamento': _dataFechamento != null
              ? Timestamp.fromDate(_dataFechamento!)
              : null,
          'valorVendido': _valorVendido,
          'brinde': _brindeCtrl.text.trim().isEmpty ? null : _brindeCtrl.text.trim(),
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
          Navigator.of(context).pop(true);
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
      if (mounted) {
        setState(() {
          _salvandoDados = false;
          _dadosAlterados = false;
        });
      }
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
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Perda'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: motivoCtrl,
            decoration: const InputDecoration(
              hintText: 'Qual o motivo da perda?',
              labelText: 'Motivo *',
            ),
            maxLines: 3,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Informe o motivo da perda.' : null,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
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
    final tituloCtrl = TextEditingController(text: interacao?.titulo ?? '');
    final notaCtrl = TextEditingController(text: interacao?.nota ?? '');
    final oQueCombinamos =
        TextEditingController(text: interacao?.oQueCombinamos ?? '');
    var canalSelecionado = interacao?.canal ?? Canal.whatsapp;
    var modalidadeSelecionada = interacao?.modalidade ?? Modalidade.online;
    var houveResposta = interacao?.houveResposta ?? false;
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
                    // ── Canal ──────────────────────────────────────────────
                    Text('Canal',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(ctx).colorScheme.primary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: Canal.values
                          .where((c) => c != Canal.sistema)
                          .map((c) {
                        final sel = canalSelecionado == c;
                        final cs = Theme.of(ctx).colorScheme;
                        return ChoiceChip(
                          avatar: Icon(c.icone, size: 14, color: c.cor),
                          label: Text(c.nome,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: sel ? c.cor : cs.onSurfaceVariant)),
                          selected: sel,
                          onSelected: (_) =>
                              setStateDialog(() => canalSelecionado = c),
                          selectedColor: c.cor.withValues(alpha: 0.18),
                          backgroundColor: cs.surfaceContainerHighest,
                          side: BorderSide(
                              color: sel
                                  ? c.cor.withValues(alpha: 0.5)
                                  : cs.outlineVariant),
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // ── Modalidade + Houve resposta ────────────────────────
                    Row(
                      children: [
                        // Modalidade toggle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Modalidade',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          Theme.of(ctx).colorScheme.primary)),
                              const SizedBox(height: 6),
                              SegmentedButton<Modalidade>(
                                segments: const [
                                  ButtonSegment(
                                      value: Modalidade.online,
                                      label: Text('Online'),
                                      icon: Icon(Icons.public_outlined,
                                          size: 14)),
                                  ButtonSegment(
                                      value: Modalidade.presencial,
                                      label: Text('Presencial'),
                                      icon: Icon(Icons.store_outlined,
                                          size: 14)),
                                ],
                                selected: {modalidadeSelecionada},
                                onSelectionChanged: (s) => setStateDialog(
                                    () => modalidadeSelecionada = s.first),
                                style: const ButtonStyle(
                                    visualDensity: VisualDensity.compact),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Houve resposta toggle
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Houve resposta?',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        Theme.of(ctx).colorScheme.primary)),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () => setStateDialog(
                                  () => houveResposta = !houveResposta),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 44,
                                height: 24,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: houveResposta
                                      ? Colors.green.shade600
                                      : Theme.of(ctx)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                ),
                                child: AnimatedAlign(
                                  duration: const Duration(milliseconds: 200),
                                  alignment: houveResposta
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.all(3),
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Título (opcional) ──────────────────────────────────
                    TextFormField(
                      controller: tituloCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Título (opcional)',
                          prefixIcon: Icon(Icons.title)),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 12),

                    // ── Nota ──────────────────────────────────────────────
                    TextFormField(
                      controller: notaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nota *',
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

                    // ── O que combinamos ──────────────────────────────────
                    TextFormField(
                      controller: oQueCombinamos,
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
                final combinamos = oQueCombinamos.text.trim();
                final nova = Interacao(
                  id: interacao?.id ??
                      'local_${DateTime.now().millisecondsSinceEpoch}',
                  titulo: tituloCtrl.text.trim().isEmpty
                      ? null
                      : tituloCtrl.text.trim(),
                  nota: notaCtrl.text.trim(),
                  dataInteracao: interacao?.dataInteracao ?? DateTime.now(),
                  canal: canalSelecionado,
                  modalidade: modalidadeSelecionada,
                  houveResposta: houveResposta,
                  oQueCombinamos: combinamos.isEmpty ? null : combinamos,
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
          // ── Salvar sempre visível (qualquer aba) ──────────────────────
          _salvandoDados
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Badge(
                  isLabelVisible: _dadosAlterados,
                  smallSize: 8,
                  child: IconButton(
                    icon: const Icon(Icons.save_outlined),
                    tooltip: _isNovo ? 'Criar Cliente' : 'Salvar Alterações',
                    onPressed: _salvarDados,
                  ),
                ),
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
                if (widget.userProfile == 'admin' || widget.userProfile == 'super admin') ...[
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
                ], // fim if (isAdmin)
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
            brindeCtrl: _brindeCtrl,
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
              _dadosAlterados = true;
              if (v == 'Individual') _nomeParceiroCtrl.clear();
            }),
            onOrigemChanged: (v) {
              _dadosAlterados = true;
              _atualizarFasePorOrigem(v);
            },
            onFaseChanged: (v) {
              if (v != null) {
                _dadosAlterados = true;
                if (v == FaseCliente.fechado && _fase != FaseCliente.fechado) {
                  _mostrarDialogoFechamento(v);
                  return;
                }
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
                setState(() { _motivoPerdaDropdown = v; _dadosAlterados = true; }),
            onCaptadorChanged: (v) => setState(() { _captador = v; _dadosAlterados = true; }),
            onVendedorChanged: (v) => setState(() { _vendedor = v; _dadosAlterados = true; }),
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
