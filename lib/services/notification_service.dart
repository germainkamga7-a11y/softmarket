import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:go_router/go_router.dart';

import '../main.dart' show navigatorKey, scaffoldMessengerKey;
import '../router/app_router.dart';

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
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'messages',
    'Messages',
    description: 'Notifications de nouveaux messages',
    importance: Importance.high,
    playSound: true,
  );

  /// Initialise FCM : permissions + canal + token + listeners
  static Future<void> initialize() async {
    // FCM non supporté sur Windows/macOS/Linux natif
    if (_isDesktopNative) return;

    // Web : pas de background handler ni de local notifications
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
      await _initLocalNotifications();
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
      debugPrint('[FCM] Foreground : ${message.notification?.title}');
      if (kIsWeb) {
        _showSnackBar(message);
      } else {
        _showLocalNotification(message);
      }
    });

    // Notification tapée depuis l'arrière-plan
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Notification tapée quand l'app était fermée
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(milliseconds: 800), () {
        _handleNotificationTap(initialMessage);
      });
    }
  }

  // ─── Local notifications (Android/iOS seulement) ──────────────────────────

  static Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Payload encodé en JSON : type, sender_id, sender_name
        if (details.payload != null) {
          _handlePayload(details.payload!);
        }
      },
    );

    // Créer le canal Android "messages" (Android 8+)
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final title = notification.title ?? '';
    final body = notification.body ?? '';
    final data = message.data;

    // Payload simplifié pour retrouver la destination au tap
    final payload =
        '${data['type'] ?? ''}|${data['sender_id'] ?? ''}|${data['sender_name'] ?? ''}';

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFFCC0000),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  static void _handlePayload(String payload) {
    final parts = payload.split('|');
    if (parts.isEmpty) return;
    final type = parts[0];
    final senderId = parts.length > 1 ? parts[1] : null;
    final senderName = parts.length > 2 ? parts[2] : 'Utilisateur';

    if (type == 'message' && senderId != null && senderId.isNotEmpty) {
      navigatorKey.currentContext?.push(Routes.chat, extra: ChatArgs(
        otherUserId: senderId,
        otherUserName: senderName,
      ));
    }
  }

  // ─── SnackBar fallback (web) ───────────────────────────────────────────────

  static void _showSnackBar(RemoteMessage message) {
    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
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
        action: SnackBarAction(
          label: 'Voir',
          onPressed: () => _handleNotificationTap(message),
        ),
      ),
    );
  }

  // ─── Navigation au tap ─────────────────────────────────────────────────────

  static void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;
    debugPrint('[FCM] Tap notification type=$type');

    if (type == 'message') {
      final senderId = data['sender_id'] as String?;
      final senderName = data['sender_name'] as String? ?? 'Utilisateur';
      if (senderId == null) return;
      navigatorKey.currentContext?.push(Routes.chat, extra: ChatArgs(
        otherUserId: senderId,
        otherUserName: senderName,
      ));
    } else if (type == 'order' || type == 'order_status') {
      final orderId = data['order_id'] as String?;
      if (orderId == null) return;
      navigatorKey.currentContext?.push(Routes.orderPath(orderId));
    }
  }

  // ─── Token FCM ─────────────────────────────────────────────────────────────

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
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    final snap = await ref.get();
    if (!snap.exists) return; // Profil pas encore créé, réessai au prochain lancement
    await ref.update({'fcm_token': token});
    debugPrint('[FCM] Token sauvegardé');
  }

  static Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}
