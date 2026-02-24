// lib/screens/chat/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../const/app_constants.dart';
import '../../controllers/chat_controller.dart';
import '../../model/message_model.dart';
import '../../model/user_model.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/user_avatar.dart';

class ChatScreen extends StatelessWidget {
  final String chatId;
  final UserModel otherUser;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUser,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      ChatController(),
      tag: chatId,
    );
    controller.init(chatId, otherUser);

    final messageTextController = TextEditingController();
    final scrollController = ScrollController();
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    void scrollToBottom() {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }

    return Scaffold(
      appBar: _buildAppBar(controller),
      body: Column(
        children: [
          // Sending indicator
          Obx(() => controller.isSending.value
              ? LinearProgressIndicator(
                  color: AppTheme.secondary,
                  backgroundColor: AppTheme.secondary.withOpacity(0.2),
                )
              : const SizedBox.shrink()),

          // Messages list
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: controller.messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.secondary),
                  );
                }

                final messages = snapshot.data ?? [];
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => scrollToBottom());

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                              color: AppTheme.surfaceLight,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.waving_hand_rounded,
                              color: AppTheme.secondary, size: 36),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Say hello to ${otherUser.name.split(' ').first}!',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;
                    final showDate = index == 0 ||
                        !_isSameDay(
                            messages[index - 1].timestamp, message.timestamp);
                    return Column(
                      children: [
                        if (showDate) _buildDateSeparator(message.timestamp),
                        GestureDetector(
                          onLongPress: () {
                            HapticFeedback.mediumImpact();
                            _showMessageOptions(
                                context, message, isMe, controller);
                          },
                          onHorizontalDragEnd: (details) {
                            if (details.primaryVelocity! > 0) {
                              controller.setReply(message);
                            }
                          },
                          child: MessageBubble(message: message, isMe: isMe),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Reply preview
          Obx(() => controller.replyingTo.value != null
              ? _buildReplyPreview(controller, currentUserId)
              : const SizedBox.shrink()),

          // Input area
          Obx(() => controller.isRecording.value
              ? _buildRecordingUI(controller)
              : _buildInputArea(
                  context, controller, messageTextController, scrollToBottom)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ChatController controller) {
    return AppBar(
      leadingWidth: 36,
      title: Row(
        children: [
          UserAvatar(user: otherUser, size: 38),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                otherUser.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              StreamBuilder<UserModel?>(
                stream: controller.otherUserStream,
                builder: (context, snapshot) {
                  final user = snapshot.data;
                  return StreamBuilder<Map<String, dynamic>>(
                    stream: controller.typingStream,
                    builder: (context, typingSnap) {
                      final typing = typingSnap.data ?? {};
                      final isTyping = typing[otherUser.uid] == true;
                      if (isTyping) {
                        return const Text('typing...',
                            style: TextStyle(
                                color: AppTheme.secondary, fontSize: 12));
                      }
                      if (user?.isOnline == true) {
                        return const Text('Online',
                            style: TextStyle(
                                color: AppTheme.online, fontSize: 12));
                      }
                      return Text(
                        user?.lastSeen != null
                            ? 'Last seen ${DateFormat('hh:mm a').format(user!.lastSeen)}'
                            : 'Offline',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview(ChatController controller, String currentUserId) {
    final reply = controller.replyingTo.value!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
            left: BorderSide(color: AppTheme.secondary, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reply.senderId == currentUserId ? 'You' : otherUser.name,
                  style: const TextStyle(
                      color: AppTheme.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  reply.type == MessageType.audio
                      ? '🎵 Voice message'
                      : reply.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: controller.clearReply,
            icon: const Icon(Icons.close_rounded,
                color: AppTheme.textSecondary, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(
    BuildContext context,
    ChatController controller,
    TextEditingController textController,
    VoidCallback scrollToBottom,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      decoration: const BoxDecoration(
        color: AppTheme.primary,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: textController,
                  maxLines: 5,
                  minLines: 1,
                  style:
                      const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    fillColor: Colors.transparent,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: controller.onTypingChanged,
                  onSubmitted: (text) async {
                    if (text.trim().isNotEmpty) {
                      textController.clear();
                      controller.onTypingChanged('');
                      await controller.sendMessage(text);
                      Future.delayed(const Duration(milliseconds: 100),
                          scrollToBottom);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send / mic button
            Obx(() {
              final hasText = controller.isTyping.value;
              return GestureDetector(
                onTap: hasText
                    ? () async {
                        final text = textController.text;
                        textController.clear();
                        controller.onTypingChanged('');
                        await controller.sendMessage(text);
                        Future.delayed(
                            const Duration(milliseconds: 100), scrollToBottom);
                      }
                    : null,
                onLongPress: hasText ? null : controller.startRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: hasText
                        ? AppTheme.secondary
                        : AppTheme.secondary.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasText ? Icons.send_rounded : Icons.mic_rounded,
                    color: hasText ? AppTheme.primary : AppTheme.textSecondary,
                    size: 22,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingUI(ChatController controller) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppTheme.primary,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => controller.stopRecording(cancel: true),
              child: const Icon(Icons.delete_outline_rounded,
                  color: AppTheme.error, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Obx(() {
                final seconds = controller.recordingSeconds.value;
                final m = seconds ~/ 60;
                final s = seconds % 60;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                            color: AppTheme.error, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      const Text('Recording...',
                          style: TextStyle(
                              color: AppTheme.textPrimary, fontSize: 14)),
                      const Spacer(),
                      Text(
                        '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            color: AppTheme.secondary,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => controller.stopRecording(),
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                    color: AppTheme.secondary, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded,
                    color: AppTheme.primary, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
              child: Divider(
                  color: AppTheme.divider.withOpacity(0.5), height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(_formatDate(date),
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
              child: Divider(
                  color: AppTheme.divider.withOpacity(0.5), height: 1)),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'Today';
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return DateFormat('MMMM d, yyyy').format(date);
  }

  void _showMessageOptions(
    BuildContext context,
    MessageModel message,
    bool isMe,
    ChatController controller,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2)),
          ),
          ListTile(
            onTap: () {
              Get.back();
              controller.setReply(message);
            },
            leading: const Icon(Icons.reply_rounded, color: AppTheme.secondary),
            title: const Text('Reply',
                style: TextStyle(color: AppTheme.textPrimary)),
          ),
          if (message.type == MessageType.text)
            ListTile(
              onTap: () {
                Get.back();
                Clipboard.setData(ClipboardData(text: message.content));
                Get.snackbar('Copied', 'Message copied to clipboard',
                    snackPosition: SnackPosition.BOTTOM);
              },
              leading: const Icon(Icons.copy_rounded,
                  color: AppTheme.textSecondary),
              title: const Text('Copy',
                  style: TextStyle(color: AppTheme.textPrimary)),
            ),
          if (isMe)
            ListTile(
              onTap: () {
                Get.back();
                controller.deleteMessage(message.id);
              },
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppTheme.error),
              title: const Text('Delete',
                  style: TextStyle(color: AppTheme.error)),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
