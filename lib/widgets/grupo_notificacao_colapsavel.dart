import 'package:flutter/material.dart';

/// Grupo de notificações com cabeçalho clicável que expande/recolhe o conteúdo
/// (ticket #50). Cada "divisão" do painel de notificações usa um destes; a
/// expansão é independente por grupo e começa aberta por padrão.
class GrupoNotificacaoColapsavel extends StatefulWidget {
  final String titulo;
  final IconData icone;
  final Color cor;
  final int contador;
  final List<Widget> children;
  final bool inicialAberto;

  const GrupoNotificacaoColapsavel({
    super.key,
    required this.titulo,
    required this.icone,
    required this.cor,
    required this.contador,
    required this.children,
    this.inicialAberto = true,
  });

  @override
  State<GrupoNotificacaoColapsavel> createState() =>
      _GrupoNotificacaoColapsavelState();
}

class _GrupoNotificacaoColapsavelState
    extends State<GrupoNotificacaoColapsavel> {
  late bool _aberto = widget.inicialAberto;

  void _alternar() => setState(() => _aberto = !_aberto);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _alternar,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: widget.cor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(widget.icone, color: widget.cor, size: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.titulo,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: widget.cor,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: widget.cor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${widget.contador}',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: widget.cor),
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _aberto ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(Icons.expand_more,
                      size: 20, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: _aberto
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.children,
                )
              : const SizedBox(width: double.infinity),
        ),
        Divider(height: 1, indent: 20, endIndent: 20, color: cs.outlineVariant),
      ],
    );
  }
}
