// lib/controllers/auth_controller.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../service/auth_service.dart';
import '../service/notification_service.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/verify_email_screen.dart';
import '../screens/home/home_screen.dart';
import 'home_controller.dart';
import 'profile_controller.dart';

class AuthController extends GetxController {
  final AuthService _authService = AuthService();

  final isLoading = false.obs;
  final errorMessage = ''.obs;
  final isPasswordVisible = false.obs;
  final isConfirmPasswordVisible = false.obs;

  // ─── Sign Up ──────────────────────────────────────────────────────
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final error = await _authService.signUp(
        email: email,
        password: password,
        name: name,
      );
      if (error != null) {
        errorMessage.value = error;
      } else {
        Get.offAll(() => const VerifyEmailScreen());
      }
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Sign In ──────────────────────────────────────────────────────
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final error = await _authService.signIn(email: email, password: password);
      if (error != null) {
        errorMessage.value = error;
      } else {
        await NotificationService().initialize();
        // FIX: Purge any stale controllers from a previous session before
        // navigating to HomeScreen. HomeScreen's build() also does this, but
        // doing it here too means the controllers are clean before the route
        // transition even starts, preventing any brief flash of old data.
        _clearSessionControllers();
        Get.offAll(() => const HomeScreen());
      }
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Google Sign In ───────────────────────────────────────────────
  Future<void> signInWithGoogle() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final error = await _authService.signInWithGoogle();
      if (error != null) {
        errorMessage.value = error;
      } else {
        await NotificationService().initialize();
        _clearSessionControllers();
        Get.offAll(() => const HomeScreen());
      }
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Sign Out ─────────────────────────────────────────────────────
  Future<void> signOut() async {
    // FIX: Clear all session-scoped controllers BEFORE signing out so that
    // their onClose() callbacks (e.g. setting isOnline=false) still have a
    // valid Firebase user when they run.
    _clearSessionControllers();
    await NotificationService().clearToken();
    await _authService.signOut();
    Get.offAll(() => const LoginScreen());
  }

  // ─── Resend verification ──────────────────────────────────────────
  Future<void> resendVerification() async {
    isLoading.value = true;
    try {
      final error = await _authService.resendVerificationEmail();
      if (error != null) {
        errorMessage.value = error;
      } else {
        Get.snackbar(
          'Email Sent',
          'Verification email resent. Check your inbox.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Reset Password ───────────────────────────────────────────────
  Future<void> resetPassword(String email) async {
    isLoading.value = true;
    try {
      final error = await _authService.resetPassword(email);
      if (error != null) {
        errorMessage.value = error;
      } else {
        Get.back();
        Get.snackbar(
          'Email Sent',
          'Password reset link sent to $email',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  void togglePasswordVisibility() =>
      isPasswordVisible.value = !isPasswordVisible.value;

  void toggleConfirmPasswordVisibility() =>
      isConfirmPasswordVisible.value = !isConfirmPasswordVisible.value;

  void clearError() => errorMessage.value = '';

  // ─── Helper ───────────────────────────────────────────────────────
  /// Deletes all controllers that are scoped to a user session so they don't
  /// leak state between account switches.
  void _clearSessionControllers() {
    if (Get.isRegistered<HomeController>()) {
      Get.delete<HomeController>(force: true);
    }
    if (Get.isRegistered<ProfileController>()) {
      Get.delete<ProfileController>(force: true);
    }
  }
}