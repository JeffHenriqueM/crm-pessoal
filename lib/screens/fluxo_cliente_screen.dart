import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tela "Fluxo do Cliente" — diagrama VISUAL do processo comercial.
///
/// Layout em serpentina (esquerda→direita; ao chegar na borda, desce e segue
/// direita→esquerda). É apenas ilustrativo (não associa leads às etapas — isso
/// fica para uma fase futura).
///
/// Navegação passo a passo: a etapa atual fica em destaque e as futuras
/// esmaecidas. Avança com clique no card, seta → / botão Próximo; volta com
/// seta ← / botão Voltar. Há também um "play" lento que percorre sozinho.
class FluxoClienteScreen extends StatefulWidget {
  const FluxoClienteScreen({super.key});

  @override
  State<FluxoClienteScreen> createState() => _FluxoClienteScreenState();
}

enum _FluxoTipo { presencial, online }

class _FluxoClienteScreenState extends State<FluxoClienteScreen> {
  _FluxoTipo _tipo = _FluxoTipo.presencial;
  int _passo = 0;
  bool _mostrarTodos = false;
  Timer? _auto;
  final FocusNode _focus = FocusNode();

  bool get _tocando => _auto != null;

  // Velocidade do play automático.
  static const _passoAuto = Duration(milliseconds: 1700);

  // Paleta por seção
  static const _corPresencial = Color(0xFF00897B); // teal
  static const _corOnline = Color(0xFF1E88E5); // blue
  static const _corQualif = Color(0xFF6D4C41); // brown
  static const _corApresentacao = Color(0xFF3949AB); // indigo
  static const _corNutricao = Color(0xFF8E24AA); // purple

  // Dimensões dos cards (a serpentina calcula colunas a partir disto)
  static const double _cardW = 220;
  static const double _cardH = 150;
  static const double _arrowW = 30;

  @override
  void initState() {
    super.initState();
    // Garante que a tela receba os eventos de teclado (setas ← →) no web.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    _focus.dispose();
    super.dispose();
  }

  // ── Navegação ──────────────────────────────────────────────────────────────
  void _trocar(_FluxoTipo t) {
    if (t == _tipo) return;
    _pausar();
    setState(() {
      _tipo = t;
      _passo = 0;
      _mostrarTodos = false;
    });
  }

  void _irPara(int i, int total) {
    setState(() => _passo = i.clamp(0, total - 1));
  }

  void _proximo(int total) {
    if (_passo >= total - 1) {
      _pausar();
      return;
    }
    setState(() => _passo++);
  }

  void _anterior() {
    if (_passo <= 0) return;
    setState(() => _passo--);
  }

  void _tocarCard(int i, int total) {
    _focus.requestFocus(); // reativa o teclado após o clique
    _pausar();
    // Clicar no card atual avança; clicar em outro pula para ele.
    if (i == _passo) {
      _proximo(total);
    } else {
      _irPara(i, total);
    }
  }

  void _pausar() {
    _auto?.cancel();
    if (_auto != null) setState(() => _auto = null);
  }

  void _alternarPlay(int total) {
    if (_tocando) {
      _pausar();
      return;
    }
    if (_passo >= total - 1 || _mostrarTodos) _passo = 0; // recomeça do início
    setState(() {
      _mostrarTodos = false;
      _auto = Timer.periodic(_passoAuto, (_) {
        if (_passo >= total - 1) {
          _pausar();
        } else {
          setState(() => _passo++);
        }
      });
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nos = _nos(cs);
    final total = nos.length;
    if (_passo >= total) _passo = total - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fluxo do Cliente'),
        toolbarHeight: 50,
        actions: [
          IconButton(
            icon: Icon(_tocando ? Icons.pause_rounded : Icons.play_arrow_rounded),
            tooltip: _tocando ? 'Pausar' : 'Reproduzir (lento)',
            onPressed: () => _alternarPlay(total),
          ),
          IconButton(
            icon: const Icon(Icons.replay_rounded),
            tooltip: 'Recomeçar',
            onPressed: () {
              _pausar();
              setState(() {
                _passo = 0;
                _mostrarTodos = false;
              });
            },
          ),
        ],
      ),
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.arrowRight): () {
            _pausar();
            _proximo(total);
          },
          const SingleActivator(LogicalKeyboardKey.arrowDown): () {
            _pausar();
            _proximo(total);
          },
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
            _pausar();
            _anterior();
          },
          const SingleActivator(LogicalKeyboardKey.arrowUp): () {
            _pausar();
            _anterior();
          },
        },
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _focus.requestFocus(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Processo comercial',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface)),
              const SizedBox(height: 4),
              Text(
                'Diagrama ilustrativo. As etapas vão surgindo conforme você avança: clique, use as setas ← → do teclado, ou aperte ▶ para rodar sozinho.',
                style: TextStyle(fontSize: 12, color: cs.outline),
              ),
              const SizedBox(height: 16),

              Center(
                child: SegmentedButton<_FluxoTipo>(
                  segments: const [
                    ButtonSegment(
                        value: _FluxoTipo.presencial,
                        icon: Icon(Icons.hotel_outlined, size: 16),
                        label: Text('Presencial')),
                    ButtonSegment(
                        value: _FluxoTipo.online,
                        icon: Icon(Icons.public, size: 16),
                        label: Text('Online')),
                  ],
                  selected: {_tipo},
                  onSelectionChanged: (s) => _trocar(s.first),
                ),
              ),
              const SizedBox(height: 12),

              _controles(cs, nos, total),
              const SizedBox(height: 16),

              // Serpentina passo a passo
              _Serpentina(
                nos: nos,
                passo: _passo,
                mostrarTodos: _mostrarTodos,
                onTapCard: (i) => _tocarCard(i, total),
                cardW: _cardW,
                cardH: _cardH,
                arrowW: _arrowW,
                cs: cs,
              ),

              const SizedBox(height: 20),
              _legenda(cs),
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Barra de controle passo a passo ────────────────────────────────────────
  Widget _controles(ColorScheme cs, List<_No> nos, int total) {
    final atual = nos[_passo];
    return Center(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.tonalIcon(
            onPressed: _passo > 0
                ? () {
                    _pausar();
                    _anterior();
                  }
                : null,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Voltar'),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 220),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Passo ${_passo + 1} de $total',
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(atual.titulo,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface)),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: (!_mostrarTodos && _passo < total - 1)
                ? () {
                    _pausar();
                    _proximo(total);
                  }
                : null,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Próximo'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              _pausar();
              setState(() {
                _mostrarTodos = !_mostrarTodos;
                if (_mostrarTodos) {
                  _passo = total - 1;
                } else {
                  _passo = 0;
                }
              });
            },
            icon: Icon(
                _mostrarTodos
                    ? Icons.unfold_less_rounded
                    : Icons.unfold_more_rounded,
                size: 18),
            label: Text(_mostrarTodos ? 'Passo a passo' : 'Mostrar todos'),
          ),
        ],
      ),
    );
  }

  // ── Nós do fluxo selecionado (entrada + cauda compartilhada) ───────────────
  List<_No> _nos(ColorScheme cs) {
    final entrada = _tipo == _FluxoTipo.presencial
        ? _entradaPresencial()
        : _entradaOnline();
    return [...entrada, ..._caudaCompartilhada(cs)];
  }

  List<_No> _entradaPresencial() => const [
        _No('Reserva', 'Cliente reserva no resort.',
            Icons.event_available_outlined, _corPresencial),
        _No('Mensagem pré-chegada', 'Recebe mensagem sobre o resort.',
            Icons.sms_outlined, _corPresencial),
        _No('Check-in', 'Imagens e tablet na recepção.',
            Icons.meeting_room_outlined, _corPresencial),
        _No('No quarto', 'Panfleto; brinde se for conhecer.',
            Icons.hotel_outlined, _corPresencial),
        _No('Captadora', 'Aborda e convida a conhecer o projeto.',
            Icons.record_voice_over_outlined, _corPresencial),
        _No('Restaurante', 'Vídeos do projeto e tablet.',
            Icons.restaurant_outlined, _corPresencial),
        _No('Qualificação', 'Recepção/captadora avaliam o perfil.',
            Icons.fact_check_outlined, _corQualif),
        _No('Foi conhecer?', 'Sim → Apresentação · Não → Nutrição.',
            Icons.help_outline, _corQualif, tag: 'Decisão'),
      ];

  List<_No> _entradaOnline() => const [
        _No('Origem', 'Site, página, anúncio, rede social, indicação.',
            Icons.public, _corOnline),
        _No('Contato', 'Cliente entra em contato conosco.',
            Icons.chat_outlined, _corOnline),
        _No('Qualificação', 'Avaliação do perfil do casal.',
            Icons.fact_check_outlined, _corQualif),
        _No('Como avança?', 'Apresentação (voucher) ou Nutrição (WhatsApp).',
            Icons.help_outline, _corQualif, tag: 'Decisão'),
        _No('Voucher → Visita', 'Com voucher, hospeda-se e vira presencial.',
            Icons.card_giftcard_outlined, _corPresencial, tag: 'Ponte'),
      ];

  List<_No> _caudaCompartilhada(ColorScheme cs) => [
        const _No('Apresentação', 'Os dois fluxos convergem aqui.',
            Icons.slideshow_outlined, _corApresentacao),
        _No('Tornou-se sócio', 'Pós-venda + Indique e Ganhe ↻.',
            Icons.handshake_outlined, Colors.green.shade600,
            tag: 'Desfecho'),
        _No('Sem interesse', 'Entra na lista de atualizações.',
            Icons.bookmark_added_outlined, cs.primary, tag: 'Desfecho'),
        _No('Quer pensar', 'Follow-up — segue no funil ↻.',
            Icons.update_outlined, Colors.orange.shade700, tag: 'Desfecho'),
        const _No('Nutrição / Re-engajamento',
            'WhatsApp, e-mail e tráfego pago trazem o cliente de volta ↻.',
            Icons.autorenew, _corNutricao),
      ];

  // ── Legenda ────────────────────────────────────────────────────────────────
  Widget _legenda(ColorScheme cs) {
    final dark = cs.brightness == Brightness.dark;
    Color brilho(Color base) {
      if (!dark) return base;
      final hsl = HSLColor.fromColor(base);
      return hsl
          .withLightness((hsl.lightness + 0.30).clamp(0.0, 0.82))
          .toColor();
    }

    Widget item(Color c, String t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 11,
                height: 11,
                decoration:
                    BoxDecoration(color: brilho(c), shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(t, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        );
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        item(_corPresencial, 'Presencial'),
        item(_corOnline, 'Online'),
        item(_corQualif, 'Qualificação / decisão'),
        item(_corApresentacao, 'Apresentação'),
        item(Colors.green.shade600, 'Desfechos'),
        item(_corNutricao, 'Nutrição'),
      ],
    );
  }
}

// ── Modelo de nó ──────────────────────────────────────────────────────────────
class _No {
  final String titulo;
  final String subtitulo;
  final IconData icone;
  final Color cor;
  final String? tag;
  const _No(this.titulo, this.subtitulo, this.icone, this.cor, {this.tag});
}

// ── Layout serpentina passo a passo ───────────────────────────────────────────
class _Serpentina extends StatelessWidget {
  final List<_No> nos;
  final int passo;
  final bool mostrarTodos;
  final ValueChanged<int> onTapCard;
  final double cardW;
  final double cardH;
  final double arrowW;
  final ColorScheme cs;

  const _Serpentina({
    required this.nos,
    required this.passo,
    required this.mostrarTodos,
    required this.onTapCard,
    required this.cardW,
    required this.cardH,
    required this.arrowW,
    required this.cs,
  });

  bool _revelado(int i) => mostrarTodos || i <= passo;

  static const _animDur = Duration(milliseconds: 520);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final maxW = c.maxWidth;
        var cols = ((maxW + arrowW) / (cardW + arrowW)).floor();
        if (cols < 1) cols = 1;
        if (cols > nos.length) cols = nos.length;

        // Quebra os índices em linhas de `cols`.
        final linhas = <List<int>>[];
        for (var i = 0; i < nos.length; i += cols) {
          linhas.add([
            for (var j = i; j < i + cols && j < nos.length; j++) j,
          ]);
        }

        // Largura exata da grade (para alinhar as linhas entre si).
        final gridWidth = cols * cardW + (cols - 1) * arrowW;

        final filhos = <Widget>[];
        for (var r = 0; r < linhas.length; r++) {
          final par = r.isEven; // par = esquerda→direita
          filhos.add(SizedBox(width: gridWidth, child: _linha(linhas[r], par)));
          if (r < linhas.length - 1) {
            final proxPrimeiro = linhas[r + 1].first;
            filhos.add(SizedBox(
              width: gridWidth,
              child: _descida(
                  alinharDireita: par, vis: _revelado(proxPrimeiro)),
            ));
          }
        }
        return Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: filhos,
          ),
        );
      },
    );
  }

  Widget _linha(List<int> idx, bool par) {
    final ordem = par ? idx : idx.reversed.toList();
    final children = <Widget>[];
    for (var k = 0; k < ordem.length; k++) {
      children.add(_card(ordem[k]));
      if (k < ordem.length - 1) {
        // A seta só aparece quando a etapa de destino já foi revelada.
        final destino = ordem[k] > ordem[k + 1] ? ordem[k] : ordem[k + 1];
        children.add(_seta(
            par ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
            vis: _revelado(destino)));
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment:
            par ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: children,
      ),
    );
  }

  Widget _seta(IconData icone, {required bool vis}) => SizedBox(
        width: arrowW,
        height: cardH,
        child: AnimatedOpacity(
          opacity: vis ? 1 : 0,
          duration: _animDur,
          child: Icon(icone, size: 22, color: cs.primary),
        ),
      );

  Widget _descida({required bool alinharDireita, required bool vis}) {
    return Row(
      mainAxisAlignment:
          alinharDireita ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        SizedBox(
          width: cardW,
          child: AnimatedOpacity(
            opacity: vis ? 1 : 0,
            duration: _animDur,
            child: Column(
              children: [
                Container(width: 2, height: 12, color: cs.outlineVariant),
                Icon(Icons.arrow_downward_rounded,
                    size: 22, color: cs.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(int i) {
    final no = nos[i];
    final visivel = _revelado(i);
    final atual = i == passo && !mostrarTodos;
    final dark = cs.brightness == Brightness.dark;
    final acento = _acento(no.cor, dark); // cor legível p/ texto e borda

    return MouseRegion(
      cursor:
          visivel ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: IgnorePointer(
        ignoring: !visivel,
        child: GestureDetector(
          onTap: () => onTapCard(i),
          child: AnimatedSlide(
            offset: visivel ? Offset.zero : const Offset(0, 0.10),
            duration: _animDur,
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: visivel ? 1.0 : 0.0,
              duration: _animDur,
              child: AnimatedScale(
                scale: atual ? 1.04 : 1.0,
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.easeOut,
                  width: cardW,
                  height: cardH,
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: dark
                    ? Color.alphaBlend(
                        no.cor.withValues(alpha: atual ? 0.24 : 0.16),
                        cs.surface)
                    : no.cor.withValues(alpha: atual ? 0.12 : 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: acento.withValues(
                      alpha: atual ? 0.95 : (dark ? 0.7 : 0.45)),
                  width: atual ? 2.4 : 1.2,
                ),
                boxShadow: atual
                    ? [
                        BoxShadow(
                          color: acento.withValues(alpha: 0.35),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor:
                            acento.withValues(alpha: dark ? 0.28 : 0.16),
                        child: Icon(no.icone, size: 19, color: acento),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          no.titulo,
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: acento),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      no.subtitulo,
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.25,
                          color: dark ? cs.onSurface : cs.onSurfaceVariant),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (no.tag != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: acento.withValues(alpha: dark ? 0.24 : 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(no.tag!,
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: acento)),
                    ),
                ],
              ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Clareia a cor da seção no dark mode para garantir contraste/leitura.
  Color _acento(Color base, bool dark) {
    if (!dark) return base;
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withLightness((hsl.lightness + 0.30).clamp(0.0, 0.82))
        .withSaturation((hsl.saturation * 0.9).clamp(0.0, 1.0))
        .toColor();
  }
}
