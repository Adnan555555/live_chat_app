// lib/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../const/app_constants.dart';
import '../../controllers/profile_controller.dart';
import '../../model/user_model.dart';
import '../../widgets/user_avatar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ProfileController());
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return SafeArea(
      child: StreamBuilder<UserModel?>(
        stream: controller.userStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.secondary));
          }

          final user = snapshot.data;
          if (user == null) {
            return const Center(
                child: Text('User not found',
                    style: TextStyle(color: AppTheme.textSecondary)));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Avatar (no photo upload — no Storage)
                UserAvatar(
                  user: user,
                  size: 100,
                  showOnlineIndicator: false,
                ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),

                const SizedBox(height: 16),

                // Name
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      user.name.isNotEmpty ? user.name : 'No name set',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (user.emailVerified)
                      const Icon(Icons.verified_rounded,
                          color: AppTheme.secondary, size: 20),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _editName(context, controller, user),
                      child: const Icon(Icons.edit_outlined,
                          color: AppTheme.secondary, size: 18),
                    ),
                  ],
                ).animate().fadeIn(delay: 100.ms),

                const SizedBox(height: 4),
                Text(user.email,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 14))
                    .animate().fadeIn(delay: 150.ms),

                if (user.emailVerified) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppTheme.secondary.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded,
                            color: AppTheme.secondary, size: 14),
                        SizedBox(width: 4),
                        Text('Verified Account',
                            style: TextStyle(
                                color: AppTheme.secondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                // Status
                GestureDetector(
                  onTap: () => _editStatus(context, controller, user),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppTheme.secondary.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            user.status,
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.edit_outlined,
                            color: AppTheme.secondary, size: 14),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 36),

                // Info section
                _section(children: [
                  _tile(
                    icon: Icons.person_outline_rounded,
                    title: 'Display Name',
                    subtitle: user.name.isNotEmpty ? user.name : 'Tap to set',
                    onTap: () => _editName(context, controller, user),
                    trailing: const Icon(Icons.edit_outlined,
                        color: AppTheme.textSecondary, size: 18),
                  ),
                  _divider(),
                  _tile(
                    icon: Icons.sentiment_satisfied_alt_outlined,
                    title: 'Status',
                    subtitle: user.status,
                    onTap: () => _editStatus(context, controller, user),
                    trailing: const Icon(Icons.edit_outlined,
                        color: AppTheme.textSecondary, size: 18),
                  ),
                  _divider(),
                  _tile(
                    icon: Icons.mail_outline_rounded,
                    title: 'Email',
                    subtitle: user.email,
                  ),
                  _divider(),
                  _tile(
                    icon: Icons.verified_outlined,
                    title: 'Email Verified',
                    subtitle:
                        user.emailVerified ? 'Verified ✓' : 'Not verified',
                    iconColor: user.emailVerified
                        ? AppTheme.secondary
                        : AppTheme.error,
                  ),
                ]).animate().fadeIn(delay: 250.ms),

                const SizedBox(height: 16),

                _section(children: [
                  _tile(
                    icon: Icons.logout_rounded,
                    title: 'Sign Out',
                    titleColor: AppTheme.error,
                    iconColor: AppTheme.error,
                    onTap: () => _confirmSignOut(context, controller),
                  ),
                ]).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 32),
                Text(
                  'Wavechat v1.0.0',
                  style: TextStyle(
                      color: AppTheme.textSecondary.withOpacity(0.5),
                      fontSize: 12),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _editName(
      BuildContext context, ProfileController controller, UserModel user) async {
    final textCtrl = TextEditingController(text: user.name);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Edit Name',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: textCtrl,
            style: const TextStyle(color: AppTheme.textPrimary),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Your name'),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Name cannot be empty';
              if (v.trim().length < 2) return 'Name too short';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Get.back();
                controller.updateName(textCtrl.text.trim());
              }
            },
            child: const Text('Save',
                style: TextStyle(
                    color: AppTheme.secondary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _editStatus(
      BuildContext context, ProfileController controller, UserModel user) async {
    final textCtrl = TextEditingController(text: user.status);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Edit Status',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: textCtrl,
          style: const TextStyle(color: AppTheme.textPrimary),
          maxLength: 100,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "What's on your mind?",
            counterStyle: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.updateStatus(textCtrl.text.trim());
            },
            child: const Text('Save',
                style: TextStyle(
                    color: AppTheme.secondary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(
      BuildContext context, ProfileController controller) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Sign Out',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.signOut();
            },
            child: const Text('Sign Out',
                style: TextStyle(
                    color: AppTheme.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _section({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    Color? titleColor,
    Color? iconColor,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (iconColor ?? AppTheme.secondary).withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? AppTheme.secondary, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? AppTheme.textPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 12))
          : null,
      trailing: trailing ??
          (onTap != null
              ? const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary, size: 20)
              : null),
    );
  }

  Widget _divider() =>
      Divider(height: 1, color: AppTheme.divider.withOpacity(0.5), indent: 72);
}
