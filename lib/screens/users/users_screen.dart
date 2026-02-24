// lib/screens/users/users_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../const/app_constants.dart';
import '../../model/user_model.dart';
import '../../service/chat_service.dart';
import '../../widgets/user_avatar.dart';
import '../chat/chat_screen.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();
    final searchQuery = ''.obs;
    final searchController = TextEditingController();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'People',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ).animate().fadeIn().slideY(begin: -0.2),
                const SizedBox(height: 14),
                TextField(
                  controller: searchController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  onChanged: (v) => searchQuery.value = v.toLowerCase(),
                  decoration: const InputDecoration(
                    hintText: 'Search people...',
                    prefixIcon: Icon(Icons.search_rounded,
                        color: AppTheme.textSecondary, size: 22),
                  ),
                ).animate().fadeIn(delay: 100.ms),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: chatService.getAllUsers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.secondary),
                  );
                }

                return Obx(() {
                  var users = snapshot.data ?? [];
                  if (searchQuery.value.isNotEmpty) {
                    users = users
                        .where((u) =>
                            u.name
                                .toLowerCase()
                                .contains(searchQuery.value) ||
                            u.email
                                .toLowerCase()
                                .contains(searchQuery.value))
                        .toList();
                  }

                  if (users.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline_rounded,
                              color: AppTheme.textSecondary.withOpacity(0.4),
                              size: 72),
                          const SizedBox(height: 16),
                          const Text('No users found',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 15)),
                        ],
                      ),
                    );
                  }

                  final online = users.where((u) => u.isOnline).toList();
                  final offline = users.where((u) => !u.isOnline).toList();

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      if (online.isNotEmpty) ...[
                        _sectionHeader('Online Now', online.length),
                        ...online.asMap().entries.map((e) => _UserTile(
                              user: e.value,
                              index: e.key,
                              onTap: () => _openChat(chatService, e.value),
                            )),
                        const SizedBox(height: 8),
                      ],
                      if (offline.isNotEmpty) ...[
                        _sectionHeader('All Users', offline.length),
                        ...offline.asMap().entries.map((e) => _UserTile(
                              user: e.value,
                              index: online.length + e.key,
                              onTap: () => _openChat(chatService, e.value),
                            )),
                      ],
                      const SizedBox(height: 24),
                    ],
                  );
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              )),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(count.toString(),
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _openChat(ChatService chatService, UserModel user) async {
    final chatId = await chatService.getOrCreateChat(user.uid);
    Get.to(
      () => ChatScreen(chatId: chatId, otherUser: user),
      transition: Transition.rightToLeft,
    );
  }
}

class _UserTile extends StatelessWidget {
  final UserModel user;
  final int index;
  final VoidCallback onTap;

  const _UserTile({required this.user, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: UserAvatar(user: user, size: 52),
      title: Row(
        children: [
          Text(
            user.name,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          if (user.emailVerified) ...[
            const SizedBox(width: 4),
            const Icon(Icons.verified_rounded,
                color: AppTheme.secondary, size: 16),
          ],
        ],
      ),
      subtitle: Text(
        user.status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style:
            const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.secondary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.secondary.withOpacity(0.3)),
        ),
        child: const Text('Chat',
            style: TextStyle(
                color: AppTheme.secondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
    ).animate().fadeIn(delay: (index * 40).ms).slideX(begin: 0.1);
  }
}
