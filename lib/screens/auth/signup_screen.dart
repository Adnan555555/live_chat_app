// lib/screens/auth/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../const/app_constants.dart';
import '../../controllers/auth_controller.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AuthController>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.arrow_back_ios_rounded,
                      color: AppTheme.textPrimary),
                  padding: EdgeInsets.zero,
                ).animate().fadeIn(),

                const SizedBox(height: 28),

                const Text('Create Account',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5))
                    .animate().fadeIn(delay: 50.ms),

                const SizedBox(height: 8),
                const Text('Join Wavechat and start chatting',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 15))
                    .animate().fadeIn(delay: 100.ms),

                const SizedBox(height: 40),

                // Name
                _label('Full Name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'John Doe',
                    prefixIcon: Icon(Icons.person_outline_rounded,
                        color: AppTheme.textSecondary),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Name is required';
                    if (v.length < 2) return 'Name too short';
                    return null;
                  },
                ).animate().fadeIn(delay: 150.ms),

                const SizedBox(height: 18),

                // Email
                _label('Email'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'you@example.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded,
                        color: AppTheme.textSecondary),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 18),

                // Password
                _label('Password'),
                const SizedBox(height: 8),
                Obx(() => TextFormField(
                  controller: passwordController,
                  obscureText: !controller.isPasswordVisible.value,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Min. 6 characters',
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        color: AppTheme.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        controller.isPasswordVisible.value
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppTheme.textSecondary,
                      ),
                      onPressed: controller.togglePasswordVisibility,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'At least 6 characters';
                    return null;
                  },
                )).animate().fadeIn(delay: 250.ms),

                const SizedBox(height: 18),

                // Confirm Password
                _label('Confirm Password'),
                const SizedBox(height: 8),
                Obx(() => TextFormField(
                  controller: confirmPasswordController,
                  obscureText: !controller.isConfirmPasswordVisible.value,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Re-enter password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        color: AppTheme.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        controller.isConfirmPasswordVisible.value
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppTheme.textSecondary,
                      ),
                      onPressed: controller.toggleConfirmPasswordVisibility,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirm your password';
                    if (v != passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                )).animate().fadeIn(delay: 300.ms),

                Obx(() => controller.errorMessage.value.isNotEmpty
                    ? Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppTheme.error, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(controller.errorMessage.value,
                                  style: const TextStyle(
                                      color: AppTheme.error, fontSize: 13)),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink()),

                const SizedBox(height: 36),

                Obx(() => SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: controller.isLoading.value
                        ? null
                        : () {
                            if (formKey.currentState!.validate()) {
                              controller.clearError();
                              controller.signUp(
                                name: nameController.text.trim(),
                                email: emailController.text.trim(),
                                password: passwordController.text,
                              );
                            }
                          },
                    child: controller.isLoading.value
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: AppTheme.primary, strokeWidth: 2.5),
                          )
                        : const Text('Create Account'),
                  ),
                )).animate().fadeIn(delay: 350.ms),

                const SizedBox(height: 28),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? ',
                        style: TextStyle(color: AppTheme.textSecondary)),
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: const Text('Sign In',
                          style: TextStyle(
                              color: AppTheme.secondary,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ).animate().fadeIn(delay: 400.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      );
}
