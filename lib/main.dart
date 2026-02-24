// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'const/app_constants.dart';
import 'firebase_options.dart';
import 'service/notification_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register the background message handler ONLY — do NOT call the full
  // NotificationService().initialize() here because that tries to save the
  // FCM token to Firestore, but no user is logged in yet at app startup.
  // Full initialization (permissions + token save) is done inside signIn()
  // and signInWithGoogle() in AuthController, after auth succeeds.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const WavechatApp());
}

class WavechatApp extends StatelessWidget {
  const WavechatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      defaultTransition: Transition.fade,
      home: const SplashScreen(),
    );
  }
}