// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../const/app_constatnts.dart';
import '../../model/chat_model.dart';
import '../../model/user_model.dart';
import '../../service/auth_service.dart';
import '../../service/chat_service.dart';
import '../../utils/user_avtar.dart';
import '../auth/profile_screen.dart';
import '../chat/chat_screen.dart';
import '../user/user_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _chatService = ChatService();
  final _authService = AuthService();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _authService.updateOnlineStatus(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _ChatsTab(),
          UsersScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.divider, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          backgroundColor: AppTheme.surface,
          indicatorColor: AppTheme.secondary.withOpacity(0.15),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded,
                  color: AppTheme.textSecondary),
              selectedIcon: Icon(Icons.chat_bubble_rounded,
                  color: AppTheme.secondary),
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
        ),
      ),
    );
  }
}

class _ChatsTab extends StatelessWidget {
  const _ChatsTab();

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Messages',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: 26,
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

          // Chat list
          Expanded(
            child: StreamBuilder<List<ChatModel>>(
              stream: chatService.getUserChats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child:
                    CircularProgressIndicator(color: AppTheme.secondary),
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
                        const Text(
                          'No conversations yet',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Start chatting with people',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms);
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    final otherUserId = chat.participants
                        .firstWhere((id) => id != currentUid);
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
    String subtitle = chat.lastMessage.isEmpty ? 'Tap to chat' : chat.lastMessage;
    if (isMyMessage && chat.lastMessage.isNotEmpty) subtitle = 'You: $subtitle';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tileColor: Colors.transparent,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                chatId: chat.id,
                otherUser: user,
              ),
            ),
          );
        },
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
          chat.lastMessageType == 'image' ? '📷 Photo' : subtitle,
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
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
      ),
    );
  }
}