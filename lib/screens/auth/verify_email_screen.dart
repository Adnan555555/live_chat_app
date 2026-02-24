// lib/screens/auth/verify_email_screen.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../const/app_constants.dart';
import '../../controllers/auth_controller.dart';
import '../../service/notification_service.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _checkTimer;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _checkTimer = Timer.periodic(const Duration(seconds: 4), (_) => _checkVerified());
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerified() async {
    try {
      // ✅ Wrap reload in try/catch — it throws PigeonUserInfo crash on some devices
      await _auth.currentUser?.reload();
    } catch (e) {
      // Pigeon decode crash — ignore, check emailVerified directly from token
      // Firebase still updates the local state even when reload() throws
    }

    // ✅ Check emailVerified directly — works even if reload() threw
    final user = _auth.currentUser;
    if (user == null) return;

    // Force refresh the ID token to get latest emailVerified status
    try {
      await user.getIdToken(true);
    } catch (_) {}

    // Re-read after token refresh
    final verified = _auth.currentUser?.emailVerified ?? false;
    if (verified) {
      _checkTimer?.cancel();
      await NotificationService().initialize();
      Get.offAll(() => const HomeScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AuthController>();
    final email = _auth.currentUser?.email ?? '';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(  // ✅ Fix overflow — wrap in SingleChildScrollView
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 48),

              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.secondary.withOpacity(0.3), width: 2),
                ),
                child: const Icon(Icons.mark_email_unread_outlined,
                    color: AppTheme.secondary, size: 44),
              ).animate().scale(begin: const Offset(0.5, 0.5), duration: 600.ms, curve: Curves.elasticOut),

              const SizedBox(height: 28),

              const Text(
                'Verify Your Email',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 10),

              Text(
                'Verification link sent to:\n$email',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 10),

              const Text(
                'Click the link in your inbox. This page will update automatically once verified.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.6),
              ).animate().fadeIn(delay: 400.ms),

              const SizedBox(height: 36),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.secondary.withOpacity(0.6)),
                  ),
                  const SizedBox(width: 10),
                  const Text('Checking verification status...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ).animate().fadeIn(delay: 500.ms),

              const SizedBox(height: 32),

              Obx(() => SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: controller.isLoading.value ? null : controller.resendVerification,
                  child: controller.isLoading.value
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2.5))
                      : const Text('Resend Verification Email'),
                ),
              )).animate().fadeIn(delay: 600.ms),

              const SizedBox(height: 14),

              TextButton(
                onPressed: () async {
                  _checkTimer?.cancel();
                  await _auth.signOut();
                  Get.offAll(() => const LoginScreen());
                },
                child: const Text('Back to Sign In', style: TextStyle(color: AppTheme.textSecondary)),
              ).animate().fadeIn(delay: 650.ms),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}