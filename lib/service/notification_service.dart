// lib/service/notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> initialize() async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // ✅ From screenshot: initialize() requires named param 'settings:'
    await _localNotifications.initialize(
      settings: InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );


    // ✅ AndroidNotificationChannel still uses positional args (id, name)
    const channel = AndroidNotificationChannel(
      'wavechat_messages', // positional id
      'Messages',          // positional name
      description: 'Chat message notifications',
      importance: Importance.high,
      playSound: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _saveToken();
    _fcm.onTokenRefresh.listen(_updateToken);
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  Future<void> _saveToken() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final token = await _fcm.getToken();
    if (token != null && token.isNotEmpty) {
      await _firestore
          .collection('users')
          .doc(uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
    }
  }

  Future<void> _updateToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .set({'fcmToken': token}, SetOptions(merge: true));
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // ✅ show() uses named 'id:' from screenshot
    // ✅ AndroidNotificationDetails uses 2 POSITIONAL args (channelId, channelName)
    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title ?? 'New Message',
      body: notification.body ?? '',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'wavechat_messages', // ✅ positional arg 1 = channelId
          'Messages',          // ✅ positional arg 2 = channelName
          channelDescription: 'Chat message notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> sendMessageNotification({
    required String receiverId,
    required String senderName,
    required String message,
    required String chatId,
  }) async {
    try {
      final myUid = _auth.currentUser?.uid;
      if (myUid == receiverId) return;

      final doc =
      await _firestore.collection('users').doc(receiverId).get();
      final token = doc.data()?['fcmToken'] as String?;
      if (token == null || token.isEmpty) return;

      await _firestore.collection('notifications').add({
        'to': token,
        'receiverId': receiverId,
        'title': senderName,
        'body': message.length > 100
            ? '${message.substring(0, 100)}...'
            : message,
        'chatId': chatId,
        'timestamp': FieldValue.serverTimestamp(),
        'sent': false,
      });
    } catch (e) {
      print('Notification error: $e');
    }
  }

  Future<void> clearToken() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _fcm.deleteToken();
    await _firestore
        .collection('users')
        .doc(uid)
        .set({'fcmToken': ''}, SetOptions(merge: true));
  }
}