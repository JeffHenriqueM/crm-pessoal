import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';

/// Seção do dashboard que pode ser recolhida/expandida. O estado (recolhida ou
/// não) é lembrado por usuário, persistido em SharedPreferences com a chave
/// `secao_recolhida_<uid>_<id>`.
///
/// Uso:
/// ```dart
/// SecaoRecolhivel(
///   id: 'equipe_resumo',
///   titulo: 'Resumo da Equipe',
///   icone: Icons.groups_outlined,
///   child: _kpiRow(...),
/// )
/// ```
class SecaoRecolhivel extends StatefulWidget {
  /// Identificador estável da seção (compõe a chave de persistência).
  final String id;
  final String titulo;
  final Widget child;
  final IconData? icone;

  /// Widget opcional à direita do título (ex.: um filtro, um contador).
  final Widget? acaoTrailing;

  /// Estado inicial caso ainda não exista preferência salva.
  final bool inicialExpandido;

  const SecaoRecolhivel({
    super.key,
    required this.id,
    required this.titulo,
    required this.child,
    this.icone,
    this.acaoTrailing,
    this.inicialExpandido = true,
  });

  @override
  State<SecaoRecolhivel> createState() => _SecaoRecolhivelState();
}

class _SecaoRecolhivelState extends State<SecaoRecolhivel> {
  late bool _expandido = widget.inicialExpandido;

  String get _chave {
    final uid = AuthService().getCurrentUser()?.uid ?? 'anon';
    return 'secao_recolhida_${uid}_${widget.id}';
  }

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final p = await SharedPreferences.getInstance();
      final recolhida = p.getBool(_chave);
      if (mounted && recolhida != null) {
        setState(() => _expandido = !recolhida);
      }
    } catch (_) {/* ignora — usa o estado inicial */}
  }

  Future<void> _alternar() async {
    setState(() => _expandido = !_expandido);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_chave, !_expandido); // grava "recolhida"
    } catch (_) {/* ignora persistência */}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: _alternar,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                if (widget.icone != null) ...[
                  Icon(widget.icone, size: 18, color: cs.onSurface),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    widget.titulo,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                if (widget.acaoTrailing != null) widget.acaoTrailing!,
                AnimatedRotation(
                  turns: _expandido ? 0.0 : -0.25,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(Icons.expand_more, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: widget.child,
          ),
          secondChild: const SizedBox(width: double.infinity),
          crossFadeState: _expandido
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 180),
        ),
      ],
    );
  }
}
