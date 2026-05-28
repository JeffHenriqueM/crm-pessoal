// lib/utils/env.dart
// Detecção de ambiente por hostname em runtime — sem necessidade de --dart-define.
import 'package:flutter/foundation.dart';

/// true quando o app está rodando em https://loja-virtual-943d7.web.app (staging).
/// false em produção (crm-pessoal-d993d.web.app) e em qualquer plataforma nativa.
bool get kIsStaging =>
    kIsWeb && Uri.base.host.contains('loja-virtual-943d7');
