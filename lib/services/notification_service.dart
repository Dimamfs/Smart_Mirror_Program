import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/alert_provider.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("🚨 BACKGROUND ALERT RECEIVED (App is sleeping) 🚨");
  
  final prefs = await SharedPreferences.getInstance();
  final savedAlerts = prefs.getStringList('alerts') ?? [];

  final newAlert = {
    'id': DateTime.now().millisecondsSinceEpoch.toString(),
    'title': message.notification?.title ?? 'Security Alert',
    'body': message.notification?.body ?? 'An event occurred at the mirror.',
    'timestamp': DateTime.now().toIso8601String(),
  };

  savedAlerts.insert(0, jsonEncode(newAlert));
  await prefs.setStringList('alerts', savedAlerts);
}

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true, badge: true, sound: true,
    );

    try {
      String? token = await _firebaseMessaging.getToken();
      debugPrint('\n🚨 YOUR FCM DEVICE TOKEN: $token\n');
    } catch (e) {
      debugPrint('Failed to get FCM token: $e');
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🚨 FOREGROUND ALERT RECEIVED 🚨');
      
      if (message.notification != null && navigatorKey.currentContext != null) {
        final context = navigatorKey.currentContext!;
        final title = message.notification!.title ?? 'Security Alert';
        final body = message.notification!.body ?? 'An event occurred at the mirror.';

        Provider.of<AlertProvider>(context, listen: false).addAlert(title, body);
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('DISMISS', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🚨 BACKGROUND NOTIFICATION TAPPED 🚨');

      if (navigatorKey.currentContext != null) {
        Provider.of<AlertProvider>(navigatorKey.currentContext!, listen: false).loadAlerts();
      }
    });

    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM Token Refreshed: $newToken');
    });
  }
}