import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Serviço de Web Push Notifications via FCM.
///
/// Fluxo:
/// 1. [initialize] é chamado no login — solicita permissão e salva o token FCM
///    no documento `usuarios/{uid}` campo `fcmToken`.
/// 2. As Cloud Functions (functions/src/index.ts) ouvem eventos no Firestore
///    e disparam mensagens FCM para os tokens relevantes.
/// 3. O service worker (web/firebase-messaging-sw.js) exibe a notificação
///    quando o app está em background.
///
/// ⚠️ Para ativar as Cloud Functions é necessário:
///    - Migrar o projeto para o plano Firebase Blaze (pay-as-you-go)
///    - Rodar: cd functions && npm install && firebase deploy --only functions
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final _messaging = FirebaseMessaging.instance;
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Inicializa o serviço: pede permissão, obtém token, salva no Firestore.
  /// Deve ser chamado após o login do usuário.
  Future<void> initialize() async {
    // Web Push só funciona em browsers compatíveis
    if (!kIsWeb) return;

    try {
      // Solicita permissão ao usuário
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await _salvarToken();
      } else {
        debugPrint('[Push] Permissão negada pelo usuário.');
      }

      // Ouve renovação de token
      _messaging.onTokenRefresh.listen((novoToken) {
        _salvarTokenString(novoToken);
      });

      // Mensagens em foreground — mostra snackbar (tratado no app via stream)
      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('[Push] Mensagem em foreground: ${message.notification?.title}');
      });
    } catch (e) {
      debugPrint('[Push] Erro ao inicializar: $e');
    }
  }

  Future<void> _salvarToken() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final token = await _messaging.getToken(
        // VAPID key gerado no console Firebase > Project Settings > Cloud Messaging > Web Push certificates
        // Após obter a chave, substitua a string abaixo.
        vapidKey: 'SUBSTITUA_PELA_SUA_VAPID_KEY',
      );
      if (token != null) await _salvarTokenString(token);
    } catch (e) {
      debugPrint('[Push] Erro ao obter token: $e');
    }
  }

  Future<void> _salvarTokenString(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('usuarios').doc(uid).update({
        'fcmToken': token,
        'fcmTokenAtualizado': FieldValue.serverTimestamp(),
      });
      debugPrint('[Push] Token salvo para $uid');
    } catch (e) {
      debugPrint('[Push] Erro ao salvar token: $e');
    }
  }

  /// Remove o token ao fazer logout (evita notificações após deslogar).
  Future<void> removerToken() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _messaging.deleteToken();
      await _db.collection('usuarios').doc(uid).update({
        'fcmToken': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('[Push] Erro ao remover token: $e');
    }
  }
}
