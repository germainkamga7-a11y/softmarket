import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../main.dart' show scaffoldMessengerKey;

bool get _isDesktopNative =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
     defaultTargetPlatform == TargetPlatform.macOS ||
     defaultTargetPlatform == TargetPlatform.linux);

// Handler de notification en arrière-plan (top-level obligatoire)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  debugPrint(
      '[FCM] Message en arrière-plan : ${message.notification?.title}');
}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;

  /// Initialise FCM : permissions + token + listeners
  static Future<void> initialize() async {
    // FCM non supporté sur Windows/macOS/Linux natif
    if (_isDesktopNative) return;

    // Web : pas de background handler
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
    }

    // Demander la permission (iOS + Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint(
        '[FCM] Permission : ${settings.authorizationStatus}');

    // Sauvegarder le token dès qu'un utilisateur se connecte
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) _saveToken();
    });

    // Rafraîchir le token si renouvelé
    _messaging.onTokenRefresh.listen(_updateToken);

    // Notification reçue en foreground
    FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title ?? '';
      final body = message.notification?.body ?? '';
      debugPrint('[FCM] Foreground : $title');
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title.isNotEmpty)
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              if (body.isNotEmpty) Text(body),
            ],
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  static Future<void> _saveToken() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final token = await _messaging.getToken();
      if (token != null) await _updateToken(token);
    } catch (e) {
      debugPrint('[FCM] Erreur token : $e');
    }
  }

  static Future<void> _updateToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'fcm_token': token}, SetOptions(merge: true));
    debugPrint('[FCM] Token sauvegardé');
  }

  /// Envoie une notification à un utilisateur (côté client — démo)
  /// En production, utiliser Firebase Cloud Functions
  static Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}
