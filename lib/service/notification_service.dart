// lib/service/notification_service.dart
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';

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

  static const String _projectId = 'live-chat-application-59fd5';
  static const String _clientEmail =
      'firebase-adminsdk-fbsvc@live-chat-application-59fd5.iam.gserviceaccount.com';

  // ════════════════════════════════════════════════════════════════════════
  // PASTE YOUR NEW private_key here (from the newly downloaded JSON file)
  // Open the JSON file, find "private_key", copy the entire value including
  // -----BEGIN PRIVATE KEY----- and -----END PRIVATE KEY-----
  // DO NOT share this key publicly anywhere
  // ════════════════════════════════════════════════════════════════════════
  static const String _privateKey =
      '-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC4M/eR45Jx71FG\nqGRYZJyPPdDLGIrS0L5Gz+a/hm13KqoxR8IkfK7SRqop392ndDcY6zDn/eb/C7jA\n6DXsXDAWwQ7I1JnUe4VUBSqu4TuxixftiDip1x8mUQURt5b+uHdSTFDzXww1m02K\nMT+IgVAwnIu4kWy9UiPXiRmk7OF5z8/OZ7aQpKJlSbV+neAZxndsrKeRkLnSw4lS\n+8KolYU2ENJoRdJsw6mlBZETi3EyUFdAl8Uhu1ZfhCFpD0SxMJYiZtajOkO7EUnI\nU1zEo5oaZAs0RtxLayh77IaYZBK4+Let1HlYbWm3IvyZNnclfESJJI0prAJo/DOC\nXCf+F8AZAgMBAAECggEABFg3b+Gz98t6+YVpvnr7BVbiKJQm3BOP1Vg8e0p2pP+k\n3X4xik5FilCf3VZ6IiO30/biI6qlquDSJfykHvPKr5K0oFCBY1VZfvKTP+Ywk/6x\nnQjgO0NHaQ4ypikUHuRnbhG+PAtDHLWRxd9k/fl81HSwx/ToIWwBS+lgKTdsFwUh\nNE235Aj3nQlvgUKmdFnZSNjfWBlpDnvQgefGAHp+Ce52skFgUY4V4lF+3K2VQqaF\n/hflfToDNl2jxK6TftCAO1Txu+klyyrr1/zapRkeqQMQlTcqRRvUFl3ERukrJWff\ne6zLaVMwUtJk7TL2OABAMXh7Na91LyizffU75dEKQQKBgQDzeMnkL0x7E2K6vGpN\n5ZgzfLJXTBkb56u7KQ2PV8ummvbANZC9Ps5R2WUt0OFpsT/qWmJ/iMtfMmVkqHAF\nutkM1uI/BvtWzWH6Vm0ugZmLRVhS2GxkpZsPqgejdT54quuJpMUJ6NPO3wzu6gID\nmXiVuUQNSVu7okmhGXyMHGAK+QKBgQDBrnDIm79Osb56yctH16Jhd6HX36eJZkpx\nlvusDIO6g6q3CCxwEoYEoYnqvxeC4+5Tim8kCjfPsncHjqxiDKjDVFllqO9a2Ejq\nrtqwm+5Q5BRbm/Jmtad9G/LGdNh/leT0JRYLrJzZ5oABlDpivj4Htfh737TJA2oh\nrpn91biGIQKBgCyKGzzgHjihqj0I/NV1O+unUyS/KhS9w9/AOdfQMtQuoxc0dV75\nX1r/zw+bl7DzGQMxN7Wm+7VVjdDlM2EI9m3v3YG0MESH2/Wk2+JXGRSuQeMd7m5X\nEU/DRhRz/VKrydzrRJR0gFLm4QHP00B/UdzqAHYBxoNDw/5xoCQtiLBZAoGBAK21\nocwa/FM9UcTZFixCN45JeOuf2ah/CQelzeV6d+8hxkxQ1WJTCsY+h+72IsUvXwKo\nZ5QgYfwzaVRq3ys1hWtjTKbEBKEq2QM7fkLmJ7F/Ts73KEp8ZFLubSkXhVGxA98B\nICuqTieU93vzEQac8A+EYu/fLUsYd+jrq4uhUtVhAoGAMzZK3F0OBZxaargbmxRV\nbrJAJhslaBHeYI7RjsqzaR0XEH1dkkgyunYzO2VsY2pC5wp/0grtk4UCBEiTm6if\n6dKNBNzbzssEBXPwxuTu9omiBRNWMLDYRBo8xR03JTBnj6adICVq+phUkeq0jIoJ\nAo6EaVNiW34GqUlGjq1Umuk=\n-----END PRIVATE KEY-----\n';

  Future<String?> _getAccessToken() async {
    try {
      final accountCredentials = ServiceAccountCredentials.fromJson({
        'type': 'service_account',
        'project_id': _projectId,
        'private_key': _privateKey,
        'client_email': _clientEmail,
        'token_uri': 'https://oauth2.googleapis.com/token',
        'client_id': '103858074903849396604',
      });
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final client = await clientViaServiceAccount(accountCredentials, scopes);
      final token = client.credentials.accessToken.data;
      client.close();
      return token;
    } catch (e) {
      print('Error getting access token: $e');
      return null;
    }
  }

  Future<void> initialize() async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      settings: InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    const channel = AndroidNotificationChannel(
      'wavechat_messages',
      'Messages',
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

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title ?? 'New Message',
      body: notification.body ?? '',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'wavechat_messages',
          'Messages',
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
      if (myUid == null || myUid == receiverId) return;

      final doc = await _firestore.collection('users').doc(receiverId).get();
      final token = doc.data()?['fcmToken'] as String?;
      if (token == null || token.isEmpty) return;

      final accessToken = await _getAccessToken();
      if (accessToken == null) return;

      final body = message.length > 100
          ? '${message.substring(0, 100)}...'
          : message;

      final response = await http.post(
        Uri.parse(
            'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': token,
            'notification': {
              'title': senderName,
              'body': body,
            },
            'android': {
              'priority': 'high',
              'notification': {
                'channel_id': 'wavechat_messages',
                'sound': 'default',
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              },
            },
            'apns': {
              'payload': {
                'aps': {'sound': 'default', 'badge': 1},
              },
            },
            'data': {
              'chatId': chatId,
              'senderId': myUid,
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        print('Notification sent successfully');
      } else {
        print('FCM V1 error: ${response.statusCode} ${response.body}');
      }
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