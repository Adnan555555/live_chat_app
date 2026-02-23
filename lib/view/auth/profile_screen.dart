// lib/screens/profile/profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../const/app_constatnts.dart';
import '../../model/user_model.dart';
import '../../service/auth_service.dart';
import '../../service/chat_service.dart';
import '../../service/notification_service.dart';
import '../../utils/user_avtar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _chatService = ChatService();
  final _imagePicker = ImagePicker();
  bool _isUploading = false;

  Future<void> _updateProfilePicture() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final url = await _chatService.uploadProfilePicture(
          uid, File(picked.path));
      await _chatService.updateProfile(uid: uid, photoUrl: url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profile picture updated!'),
            backgroundColor: AppTheme.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ✅ Fixed edit name — actually saves to Firestore
  Future<void> _editName(UserModel user) async {
    final controller = TextEditingController(text: user.name);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Edit Name',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Save',
                style: TextStyle(
                    color: AppTheme.secondary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != user.name) {
      try {
        await _chatService.updateProfile(uid: user.uid, name: result);
        // Also update Firebase Auth display name
        await FirebaseAuth.instance.currentUser?.updateDisplayName(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Name updated!'),
              backgroundColor: AppTheme.secondary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'),
                backgroundColor: AppTheme.error),
          );
        }
      }
    }
  }

  // ✅ Fixed edit status — actually saves
  Future<void> _editStatus(UserModel user) async {
    final controller = TextEditingController(text: user.status);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Edit Status',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppTheme.textPrimary),
          maxLength: 100,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: "What's on your mind?",
              counterStyle: TextStyle(color: AppTheme.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save',
                style: TextStyle(
                    color: AppTheme.secondary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (result != null && result != user.status) {
      try {
        await _chatService.updateProfile(uid: user.uid, status: result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Status updated!'),
              backgroundColor: AppTheme.secondary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'),
                backgroundColor: AppTheme.error),
          );
        }
      }
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Sign Out',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out',
                style: TextStyle(
                    color: AppTheme.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await NotificationService().clearToken();
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return SafeArea(
      child: StreamBuilder<UserModel?>(
        stream: _chatService.getUserStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                CircularProgressIndicator(color: AppTheme.secondary));
          }

          final user = snapshot.data;
          if (user == null) {
            return const Center(
                child: Text('User not found',
                    style: TextStyle(color: AppTheme.textSecondary)));
          }

          return RefreshIndicator(
            color: AppTheme.secondary,
            onRefresh: () async => setState(() {}),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // ✅ Avatar with camera icon
                  GestureDetector(
                    onTap: _updateProfilePicture,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        UserAvatar(
                            user: user,
                            size: 100,
                            showOnlineIndicator: false),
                        if (_isUploading)
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const CircularProgressIndicator(
                                color: AppTheme.secondary),
                          )
                        else
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppTheme.secondary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppTheme.primary, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt_rounded,
                                  color: AppTheme.primary, size: 16),
                            ),
                          ),
                      ],
                    ),
                  ).animate().fadeIn().scale(
                      begin: const Offset(0.9, 0.9)),

                  const SizedBox(height: 16),

                  // Name with edit icon
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
                      GestureDetector(
                        onTap: () => _editName(user),
                        child: const Icon(Icons.edit_outlined,
                            color: AppTheme.secondary, size: 18),
                      ),
                    ],
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 4),

                  Text(
                    user.email,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 14),
                  ).animate().fadeIn(delay: 150.ms),

                  const SizedBox(height: 10),

                  // Status with edit
                  GestureDetector(
                    onTap: () => _editStatus(user),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
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
                                  color: AppTheme.textSecondary,
                                  fontSize: 13),
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
                  _buildSection(
                    children: [
                      _buildTile(
                        icon: Icons.person_outline_rounded,
                        title: 'Display Name',
                        subtitle: user.name.isNotEmpty
                            ? user.name
                            : 'Tap to set name',
                        onTap: () => _editName(user),
                        trailing: const Icon(Icons.edit_outlined,
                            color: AppTheme.textSecondary, size: 18),
                      ),
                      _buildDivider(),
                      _buildTile(
                        icon: Icons.sentiment_satisfied_alt_outlined,
                        title: 'Status',
                        subtitle: user.status,
                        onTap: () => _editStatus(user),
                        trailing: const Icon(Icons.edit_outlined,
                            color: AppTheme.textSecondary, size: 18),
                      ),
                      _buildDivider(),
                      _buildTile(
                        icon: Icons.mail_outline_rounded,
                        title: 'Email',
                        subtitle: user.email,
                      ),
                    ],
                  ).animate().fadeIn(delay: 250.ms),

                  const SizedBox(height: 16),

                  _buildSection(
                    children: [
                      _buildTile(
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        onTap: () {},
                      ),
                      _buildDivider(),
                      _buildTile(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy',
                        onTap: () {},
                      ),
                    ],
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 16),

                  _buildSection(
                    children: [
                      _buildTile(
                        icon: Icons.logout_rounded,
                        title: 'Sign Out',
                        titleColor: AppTheme.error,
                        iconColor: AppTheme.error,
                        onTap: _signOut,
                      ),
                    ],
                  ).animate().fadeIn(delay: 350.ms),

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
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTile({
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
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (iconColor ?? AppTheme.secondary).withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            color: iconColor ?? AppTheme.secondary, size: 20),
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
          ? Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            color: AppTheme.textSecondary, fontSize: 12),
      )
          : null,
      trailing: trailing ??
          (onTap != null
              ? const Icon(Icons.chevron_right_rounded,
              color: AppTheme.textSecondary, size: 20)
              : null),
    );
  }

  Widget _buildDivider() {
    return Divider(
        height: 1,
        color: AppTheme.divider.withOpacity(0.5),
        indent: 72);
  }
}