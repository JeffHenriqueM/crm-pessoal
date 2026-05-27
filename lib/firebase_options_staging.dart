// lib/firebase_options_staging.dart
// Configuração Firebase para o ambiente de STAGING (loja-virtual-943d7).
// NÃO use esta configuração em produção.
//
// Para compilar apontando para staging:
//   flutter build web --release --no-tree-shake-icons --dart-define=ENV=staging
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class StagingFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    // Adicione outras plataformas conforme necessário
    return web;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDIbHh5LLgBPDtHE7cA8OYYvx3zVV0v3KU',
    appId: '1:380272223614:web:78dd54e34f10624c20ff2f',
    messagingSenderId: '380272223614',
    projectId: 'loja-virtual-943d7',
    authDomain: 'loja-virtual-943d7.firebaseapp.com',
    storageBucket: 'loja-virtual-943d7.firebasestorage.app',
  );
}
