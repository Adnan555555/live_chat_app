// lib/firebase_options.dart
// ✅ Auto-configured with your Firebase project: live-chat-application-59fd5

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCfFr1e8uCzR2yxKWnzCNm2GUfin78N9p0',
    appId: '1:803553172966:android:74b8c4aa8b6e50e5964a27',
    messagingSenderId: '803553172966',
    projectId: 'live-chat-application-59fd5',
    storageBucket: 'live-chat-application-59fd5.firebasestorage.app',
  );

  // ⚠️ Add iOS app in Firebase Console if you need iOS support,
  // then replace these placeholder values.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCfFr1e8uCzR2yxKWnzCNm2GUfin78N9p0',
    appId: '1:803553172966:ios:PLACEHOLDER',
    messagingSenderId: '803553172966',
    projectId: 'live-chat-application-59fd5',
    storageBucket: 'live-chat-application-59fd5.firebasestorage.app',
    iosBundleId: 'com.adnan-chat-app.flutterChatApp',
  );

  // ⚠️ Add Web app in Firebase Console if you need Web support.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCfFr1e8uCzR2yxKWnzCNm2GUfin78N9p0',
    appId: '1:803553172966:web:PLACEHOLDER',
    messagingSenderId: '803553172966',
    projectId: 'live-chat-application-59fd5',
    storageBucket: 'live-chat-application-59fd5.firebasestorage.app',
  );
}