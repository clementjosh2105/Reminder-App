import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/config/firebase_config.dart';
import 'notification_service.dart'; // Handles local visual banners

// Top-level background message handler for FCM (Runs when app is minimized or closed)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: FirebaseConfig.currentPlatform);
  }
  NotificationService.log(
    "Handling background FCM message: ${message.messageId}",
  );

  // Trigger the physical notification banner even when minimized/closed
  if (message.notification != null) {
    await NotificationService.showLocalPushBanner(
      id: message.hashCode,
      title: message.notification!.title ?? '',
      body: message.notification!.body ?? '',
      payload: jsonEncode(message.data),
    );
  }
}

class FirebaseNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init() async {
    if (kIsWeb) {
      NotificationService.log("FirebaseNotificationService skipped on Web.");
      return;
    }
    // 1. Set background messaging handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Request Permissions
    await requestPermissions();

    // 3. Configure foreground notification presentation options
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 4. Retrieve FCM Token
    await retrieveAndSaveToken();

    // 5. Handle foreground messages (App is actively open on screen)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      NotificationService.log(
        '🔔 Foreground FCM Message received: ${message.notification?.title}',
      );

      if (message.notification != null) {
        NotificationService.showLocalPushBanner(
          id: message.hashCode,
          title: message.notification!.title ?? '',
          body: message.notification!.body ?? '',
          payload: jsonEncode(message.data),
        );
      }
    });

    // 6. Handle app opened via notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      NotificationService.log(
        '📩 Notification clicked & opened app from background: ${message.data}',
      );
    });

    // 7. Handle app opened via notification (terminated state)
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      NotificationService.log(
        '📩 App opened from fully terminated state via FCM: ${initialMessage.data}',
      );
    }

    // 8. Listen to token refresh
    _fcm.onTokenRefresh.listen((newToken) async {
      NotificationService.log('FCM Token refreshed: $newToken');
      await _saveTokenToFirestore(newToken);
    });
  }

  Future<void> requestPermissions() async {
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    NotificationService.log(
      '🔔 User notification permission status: ${settings.authorizationStatus}',
    );
  }

  Future<void> retrieveAndSaveToken() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        NotificationService.log('🔑 FCM Registration Token: $token');
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      NotificationService.log('Error retrieving FCM Token: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        NotificationService.log('Skipped FCM sync: user is not signed in.');
        return;
      }
      final docRef = FirebaseFirestore.instance
          .collection('device_tokens')
          .doc(token);
      final settingsBox = Hive.isBoxOpen('settings_box_v1')
          ? Hive.box('settings_box_v1')
          : await Hive.openBox('settings_box_v1');
      final socialNotifications =
          settingsBox.get('social_notifications', defaultValue: true) as bool;
      await docRef.set({
        'token': token,
        'uid': user.uid,
        'socialNotifications': socialNotifications,
        'lastUpdated': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.toString(),
      });
      NotificationService.log('FCM Token synced to Firestore.');
    } catch (e) {
      NotificationService.log('Failed to sync FCM Token to Firestore: $e');
    }
  }
}
