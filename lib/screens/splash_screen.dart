// lib/screens/splash_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../const/app_constants.dart';
import '../service/auth_service.dart';
import 'auth/login_screen.dart';
import 'auth/verify_email_screen.dart';
import 'home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Get.offAll(() => const LoginScreen());
      return;
    }

    // FIX: Refresh the token so emailVerified is accurate
    try { await user.reload(); } catch (_) {}
    final freshUser = FirebaseAuth.instance.currentUser;

    if (freshUser == null) {
      Get.offAll(() => const LoginScreen());
      return;
    }

    if (!freshUser.emailVerified &&
        freshUser.providerData.first.providerId == 'password') {
      Get.offAll(() => const VerifyEmailScreen());
      return;
    }

    // FIX: When the app launches with an already-logged-in user (i.e. they
    // didn't go through signIn() this session), we must still ensure their
    // Firestore doc exists and their online status is correct.
    // Previously this was only done inside signIn(), so users who were
    // auto-logged-in via SplashScreen would get "User not found" on Profile
    // and "No users found" on People if their doc was missing.
    final authService = AuthService();
    await authService.ensureUserDocOnAppStart(freshUser);

    Get.offAll(() => const HomeScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppTheme.secondary,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.secondary.withOpacity(0.3),
                    blurRadius: 32,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.waves_rounded,
                  color: AppTheme.primary, size: 48),
            )
                .animate()
                .scale(
                begin: const Offset(0.5, 0.5),
                duration: 600.ms,
                curve: Curves.elasticOut)
                .fadeIn(duration: 400.ms),
            const SizedBox(height: 24),
            const Text(
              AppConstants.appName,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3),
            const SizedBox(height: 8),
            const Text(
              'Connect. Chat. Wave.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ).animate().fadeIn(delay: 500.ms),
          ],
        ),
      ),
    );
  }
}