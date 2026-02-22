// lib/service/call_service.dart
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CallService {
  // 🔴 REPLACE WITH YOUR ZEGO CREDENTIALS
  // Get them from: https://console.zegocloud.com/
  static const int appID = 0;              // ← your numeric App ID
  static const String appSign = '894a77b2e40b481288c06fdc24c56a53'; // ← your App Sign string

  static String get currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  static String get currentUserName =>
      FirebaseAuth.instance.currentUser?.displayName ??
          FirebaseAuth.instance.currentUser?.email?.split('@')[0] ??
          'User';

  // Call unique ID — both users must join same room
  static String getCallId(String uid1, String uid2, {bool isVideo = false}) {
    final sorted = [uid1, uid2]..sort();
    final prefix = isVideo ? 'video' : 'audio';
    return '${prefix}_${sorted[0]}_${sorted[1]}';
  }
}