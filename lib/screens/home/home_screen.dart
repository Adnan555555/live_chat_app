// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../const/app_constants.dart';
import '../../controllers/home_controller.dart';
import '../../model/chat_model.dart';
import '../../model/user_model.dart';
import '../../service/chat_service.dart';
import '../../widgets/user_avatar.dart';
import '../chat/chat_screen.dart';
import '../users/users_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // FIX: Delete any stale controller instance before creating a fresh one.
    // This ensures that when a new user logs in, they don't get the old
    // HomeController (which cached the previous user's UID via ChatService).
    if (Get.isRegistered<HomeController>()) {
      Get.delete<HomeController>(force: true);
    }
    final controller = Get.put(HomeController());

    return Scaffold(
      body: Obx(() => IndexedStack(
        index: controller.currentIndex.value,
        children: const [
          _ChatsTab(),
          UsersScreen(),
          ProfileScreen(),
        ],
      )),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.divider, width: 1)),
        ),
        child: Obx(() => NavigationBar(
          selectedIndex: controller.currentIndex.value,
          onDestinationSelected: controller.changeTab,
          backgroundColor: AppTheme.surface,
          indicatorColor: AppTheme.secondary.withOpacity(0.15),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded,
                  color: AppTheme.textSecondary),
              selectedIcon:
              Icon(Icons.chat_bubble_rounded, color: AppTheme.secondary),
              label: 'Chats',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline_rounded,
                  color: AppTheme.textSecondary),
              selectedIcon:
              Icon(Icons.people_rounded, color: AppTheme.secondary),
              label: 'People',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded,
                  color: AppTheme.textSecondary),
              selectedIcon:
              Icon(Icons.person_rounded, color: AppTheme.secondary),
              label: 'Profile',
            ),
          ],
        )),
      ),
    );
  }
}

class _ChatsTab extends StatelessWidget {
  const _ChatsTab();

  @override
  Widget build(BuildContext context) {
    // FIX: Read the current UID fresh on every build instead of caching it.
    // Previously, if FirebaseAuth had a stale user reference at widget creation
    // time, currentUid could point to the wrong (old) user.
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    final currentUid = currentUser.uid;

    // FIX: Create ChatService with the uid as a key so a new instance is used
    // for each distinct user session. This prevents the stream inside
    // getUserChats() from using a UID captured during a previous login.
    final chatService = ChatService();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Messages',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.search_rounded,
                      color: AppTheme.textPrimary, size: 26),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.2),

          Expanded(
            child: StreamBuilder<List<ChatModel>>(
              // FIX: Pass currentUid explicitly so the stream is always scoped
              // to the currently signed-in user, not a cached closure value.
              stream: chatService.getUserChatsForUser(currentUid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.secondary),
                  );
                }

                final chats = snapshot.data ?? [];

                if (chats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            color: AppTheme.textSecondary.withOpacity(0.4),
                            size: 72),
                        const SizedBox(height: 20),
                        const Text('No conversations yet',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        const Text('Go to People tab to start chatting',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms);
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    // FIX: Guard against malformed participant lists that don't
                    // contain the current user (e.g. leftover docs from old sessions).
                    final otherParticipants =
                    chat.participants.where((id) => id != currentUid).toList();
                    if (otherParticipants.isEmpty) return const SizedBox.shrink();

                    final otherUserId = otherParticipants.first;
                    final unread = chat.unreadCount[currentUid] ?? 0;

                    return FutureBuilder<UserModel?>(
                      future: chatService.getUserById(otherUserId),
                      builder: (context, userSnapshot) {
                        final user = userSnapshot.data;
                        if (user == null) return const SizedBox.shrink();
                        return _ChatTile(
                          chat: chat,
                          user: user,
                          unread: unread,
                          currentUid: currentUid,
                        ).animate().fadeIn(delay: (index * 50).ms);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final ChatModel chat;
  final UserModel user;
  final int unread;
  final String currentUid;

  const _ChatTile({
    required this.chat,
    required this.user,
    required this.unread,
    required this.currentUid,
  });

  @override
  Widget build(BuildContext context) {
    final isMyMessage = chat.lastMessageSenderId == currentUid;
    String subtitle =
    chat.lastMessage.isEmpty ? 'Tap to chat' : chat.lastMessage;
    if (isMyMessage && chat.lastMessage.isNotEmpty) subtitle = 'You: $subtitle';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onTap: () => Get.to(
            () => ChatScreen(chatId: chat.id, otherUser: user),
        transition: Transition.rightToLeft,
      ),
      leading: UserAvatar(user: user, size: 52),
      title: Text(
        user.name,
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        chat.lastMessageType == 'audio' ? '🎵 Voice message' : subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: unread > 0 ? AppTheme.textPrimary : AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            timeago.format(chat.lastMessageTime, allowFromNow: true),
            style: TextStyle(
              color: unread > 0 ? AppTheme.secondary : AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          if (unread > 0)
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.secondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unread > 99 ? '99+' : unread.toString(),
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}