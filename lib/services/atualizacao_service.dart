import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Identificador do build atual, carimbado em tempo de compilação via
/// `--dart-define=APP_BUILD=...` (ver `scripts/build_web.sh`). Fica vazio em
/// `flutter run` (dev) → a checagem de atualização é desativada.
const String kAppBuild = String.fromEnvironment('APP_BUILD');

/// Detecta quando uma nova versão do app foi publicada enquanto a aba seguia
/// aberta. Faz polling do arquivo `app_build.json` (gravado no deploy) e, se o
/// build do servidor for diferente do embutido, sinaliza para a UI oferecer o
/// recarregamento.
class AtualizacaoService {
  AtualizacaoService._();
  static final AtualizacaoService instance = AtualizacaoService._();

  /// `true` quando há uma versão mais nova publicada do que a carregada.
  final ValueNotifier<bool> disponivel = ValueNotifier(false);

  Timer? _timer;
  bool _iniciado = false;

  /// Liga o polling (idempotente). No-op em dev (sem `APP_BUILD`).
  void iniciar() {
    if (_iniciado || !kIsWeb || kAppBuild.isEmpty) return;
    _iniciado = true;
    // Primeira checagem após 1 min (evita corrida com o carregamento inicial),
    // depois a cada 5 min.
    Future.delayed(const Duration(minutes: 1), _checar);
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _checar());
  }

  Future<void> _checar() async {
    if (disponivel.value) return; // já avisado uma vez
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final resp = await web.window
          .fetch(
            'app_build.json?ts=$ts'.toJS,
            web.RequestInit(cache: 'no-store'),
          )
          .toDart;
      if (!resp.ok) return;
      final corpo = (await resp.text().toDart).toDart;
      final servidor =
          (jsonDecode(corpo) as Map)['build']?.toString() ?? '';
      if (servidor.isNotEmpty && servidor != kAppBuild) {
        disponivel.value = true;
        _timer?.cancel();
      }
    } catch (_) {
      // Offline, arquivo ausente ou JSON inválido → ignora e tenta de novo.
    }
  }

  /// Recarrega a página para carregar a nova versão.
  void recarregar() => web.window.location.reload();
}
