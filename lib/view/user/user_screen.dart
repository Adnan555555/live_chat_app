// lib/screens/users_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../const/app_constatnts.dart';
import '../../model/user_model.dart';
import '../../service/chat_service.dart';
import '../../utils/user_avtar.dart';
import '../chat/chat_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _chatService = ChatService();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'People',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: 26,
                    letterSpacing: -0.5,
                  ),
                ).animate().fadeIn().slideY(begin: -0.2),
                const SizedBox(height: 14),
                // Search
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: 'Search people...',
                    prefixIcon: Icon(Icons.search_rounded,
                        color: AppTheme.textSecondary, size: 22),
                  ),
                ).animate().fadeIn(delay: 100.ms),
              ],
            ),
          ),

          // Users list
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: _chatService.getAllUsers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.secondary),
                  );
                }

                var users = snapshot.data ?? [];

                if (_searchQuery.isNotEmpty) {
                  users = users
                      .where((u) =>
                  u.name.toLowerCase().contains(_searchQuery) ||
                      u.email.toLowerCase().contains(_searchQuery))
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
                        const Text(
                          'No users found',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }

                // Separate online from offline
                final onlineUsers = users.where((u) => u.isOnline).toList();
                final offlineUsers = users.where((u) => !u.isOnline).toList();

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (onlineUsers.isNotEmpty) ...[
                      _buildSectionHeader('Online Now', onlineUsers.length),
                      ...onlineUsers.asMap().entries.map(
                            (e) => _UserTile(
                          user: e.value,
                          index: e.key,
                          onTap: () => _openChat(e.value),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (offlineUsers.isNotEmpty) ...[
                      _buildSectionHeader('All Users', offlineUsers.length),
                      ...offlineUsers.asMap().entries.map(
                            (e) => _UserTile(
                          user: e.value,
                          index: onlineUsers.length + e.key,
                          onTap: () => _openChat(e.value),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openChat(UserModel user) async {
    final chatId = await _chatService.getOrCreateChat(user.uid);
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(chatId: chatId, otherUser: user),
        ),
      );
    }
  }
}

class _UserTile extends StatelessWidget {
  final UserModel user;
  final int index;
  final VoidCallback onTap;

  const _UserTile({
    required this.user,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: Colors.transparent,
      leading: UserAvatar(user: user, size: 52),
      title: Text(
        user.name,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        user.status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.secondary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.secondary.withOpacity(0.3)),
        ),
        child: const Text(
          'Chat',
          style: TextStyle(
            color: AppTheme.secondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index * 40).ms).slideX(begin: 0.1);
  }
}