import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:easy_localization/easy_localization.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  static Future<void> initialize(BuildContext context) async {
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
      debugPrint("FCM Token: $token");
      // TODO: Envoyer ce token via ApiService.enregistrerFcmToken(token);

      // Écoute des messages lorsque l'application est au premier plan
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          _afficherAlerteInApp(context, message.notification!.title ?? "Notification", message.notification!.body ?? "");
        }
      });
    } else {
      debugPrint("Permissions de notification refusées.");
    }
  }

  static void _afficherAlerteInApp(BuildContext context, String title, String body) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.notifications_active, color: Color(0xFF1A529B)),
            const SizedBox(width: 8),
            Text(title),
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