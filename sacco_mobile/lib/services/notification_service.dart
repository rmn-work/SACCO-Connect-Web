import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/api_service.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Clé globale pour afficher des dialogues ou naviguer sans avoir besoin d'un BuildContext local
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> initialize() async {
    // Demande de permission pour les notifications (iOS / Android 13+)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint("Permissions de notification accordées.");

      // Récupération du token FCM pour l'envoyer au serveur Django
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        debugPrint("FCM Token: $token");
        try {
          await ApiService.enregistrerFcmToken(token);
        } catch (e) {
          debugPrint("Erreur lors de l'envoi du token FCM au serveur : $e");
        }
      }

      // Écoute des messages lorsque l'application est au premier plan
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          _afficherAlerteInApp(
            message.notification!.title ?? "Notification",
            message.notification!.body ?? ""
          );
        }
      });
    } else {
      debugPrint("Permissions de notification refusées.");
    }
  }

  static void _afficherAlerteInApp(String title, String body) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.notifications_active, color: Color(0xFF1A529B)),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('close'.tr()),
          ),
        ],
      ),
    );
  }
}