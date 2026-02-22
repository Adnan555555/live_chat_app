// // lib/screens/chat_screen.dart
// import 'dart:async';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:intl/intl.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import '../../const/app_constatnts.dart';
// import '../../model/message_model.dart';
// import '../../model/user_model.dart';
// import '../../service/chat_service.dart';
// import '../../utils/message_bubble.dart';
// import '../../utils/user_avtar.dart';
// import '../user/user_detail_screen.dart';
// class ChatScreen extends StatefulWidget {
//   final String chatId;
//   final UserModel otherUser;
//
//   const ChatScreen({
//     super.key,
//     required this.chatId,
//     required this.otherUser,
//   });
//
//   @override
//   State<ChatScreen> createState() => _ChatScreenState();
// }
//
// class _ChatScreenState extends State<ChatScreen> {
//   final _chatService = ChatService();
//   final _messageController = TextEditingController();
//   final _scrollController = ScrollController();
//   final _currentUserId = FirebaseAuth.instance.currentUser!.uid;
//   final _imagePicker = ImagePicker();
//
//   bool _isTyping = false;
//   Timer? _typingTimer;
//   MessageModel? _replyingTo;
//   bool _showEmojiPicker = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _chatService.markMessagesAsRead(widget.chatId);
//     _messageController.addListener(_onTextChanged);
//   }
//
//   @override
//   void dispose() {
//     _typingTimer?.cancel();
//     _chatService.setTypingStatus(widget.chatId, false);
//     _messageController.dispose();
//     _scrollController.dispose();
//     super.dispose();
//   }
//
//   void _onTextChanged() {
//     final isNowTyping = _messageController.text.isNotEmpty;
//     if (isNowTyping != _isTyping) {
//       setState(() => _isTyping = isNowTyping);
//       _chatService.setTypingStatus(widget.chatId, isNowTyping);
//     }
//
//     _typingTimer?.cancel();
//     if (isNowTyping) {
//       _typingTimer = Timer(const Duration(seconds: 3), () {
//         _chatService.setTypingStatus(widget.chatId, false);
//       });
//     }
//   }
//
//   void _scrollToBottom() {
//     if (_scrollController.hasClients) {
//       _scrollController.animateTo(
//         _scrollController.position.maxScrollExtent,
//         duration: const Duration(milliseconds: 300),
//         curve: Curves.easeOut,
//       );
//     }
//   }
//
//   Future<void> _sendMessage() async {
//     final text = _messageController.text.trim();
//     if (text.isEmpty) return;
//
//     _messageController.clear();
//     setState(() => _replyingTo = null);
//
//     await _chatService.sendMessage(
//       chatId: widget.chatId,
//       receiverId: widget.otherUser.uid,
//       content: text,
//       replyToId: _replyingTo?.id,
//       replyToContent: _replyingTo?.content,
//     );
//
//     Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
//   }
//
//   Future<void> _pickAndSendImage() async {
//     final picked = await _imagePicker.pickImage(
//       source: ImageSource.gallery,
//       imageQuality: 70,
//     );
//     if (picked == null) return;
//
//     await _chatService.sendImageMessage(
//       chatId: widget.chatId,
//       receiverId: widget.otherUser.uid,
//       imageFile: File(picked.path),
//     );
//     Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: _buildAppBar(),
//       body: Column(
//         children: [
//           // Messages
//           Expanded(
//             child: StreamBuilder<List<MessageModel>>(
//               stream: _chatService.getMessages(widget.chatId),
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return const Center(
//                     child: CircularProgressIndicator(color: AppTheme.secondary),
//                   );
//                 }
//
//                 final messages = snapshot.data ?? [];
//
//                 WidgetsBinding.instance.addPostFrameCallback(
//                         (_) => _scrollToBottom());
//
//                 if (messages.isEmpty) {
//                   return Center(
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Container(
//                           padding: const EdgeInsets.all(20),
//                           decoration: BoxDecoration(
//                             color: AppTheme.surfaceLight,
//                             shape: BoxShape.circle,
//                           ),
//                           child: const Icon(Icons.waving_hand_rounded,
//                               color: AppTheme.secondary, size: 36),
//                         ),
//                         const SizedBox(height: 16),
//                         Text(
//                           'Say hello to ${widget.otherUser.name.split(' ').first}!',
//                           style: const TextStyle(
//                               color: AppTheme.textSecondary, fontSize: 15),
//                         ),
//                       ],
//                     ),
//                   );
//                 }
//
//                 return ListView.builder(
//                   controller: _scrollController,
//                   padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
//                   itemCount: messages.length,
//                   itemBuilder: (context, index) {
//                     final message = messages[index];
//                     final isMe = message.senderId == _currentUserId;
//
//                     // Date separator
//                     bool showDate = false;
//                     if (index == 0) {
//                       showDate = true;
//                     } else {
//                       final prev = messages[index - 1];
//                       if (!_isSameDay(prev.timestamp, message.timestamp)) {
//                         showDate = true;
//                       }
//                     }
//
//                     return Column(
//                       children: [
//                         if (showDate) _buildDateSeparator(message.timestamp),
//                         GestureDetector(
//                           onLongPress: () => _showMessageOptions(message, isMe),
//                           onHorizontalDragEnd: (details) {
//                             if (details.primaryVelocity! > 0) {
//                               setState(() => _replyingTo = message);
//                             }
//                           },
//                           child: MessageBubble(
//                             message: message,
//                             isMe: isMe,
//                           ),
//                         ),
//                       ],
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//
//           // Reply preview
//           if (_replyingTo != null) _buildReplyPreview(),
//
//           // Input area
//           _buildInputArea(),
//         ],
//       ),
//     );
//   }
//
//   PreferredSizeWidget _buildAppBar() {
//     return AppBar(
//       leadingWidth: 36,
//       title: GestureDetector(
//         onTap: () => Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (_) => UserDetailScreen(user: widget.otherUser),
//           ),
//         ),
//         child: Row(
//           children: [
//             UserAvatar(user: widget.otherUser, size: 38),
//             const SizedBox(width: 12),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   widget.otherUser.name,
//                   style: const TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.w700,
//                     color: AppTheme.textPrimary,
//                   ),
//                 ),
//                 StreamBuilder<UserModel?>(
//                   stream: _chatService.getUserStream(widget.otherUser.uid),
//                   builder: (context, snapshot) {
//                     final user = snapshot.data;
//
//                     // Check typing status
//                     return StreamBuilder<Map<String, dynamic>>(
//                       stream: _chatService.getTypingStatus(widget.chatId),
//                       builder: (context, typingSnapshot) {
//                         final typing = typingSnapshot.data ?? {};
//                         final isTyping = typing[widget.otherUser.uid] == true;
//
//                         if (isTyping) {
//                           return Row(
//                             children: [
//                               _TypingIndicator(),
//                               const SizedBox(width: 6),
//                               const Text(
//                                 'typing...',
//                                 style: TextStyle(
//                                     color: AppTheme.secondary, fontSize: 12),
//                               ),
//                             ],
//                           );
//                         }
//
//                         if (user?.isOnline == true) {
//                           return const Text(
//                             'Online',
//                             style: TextStyle(
//                                 color: AppTheme.online, fontSize: 12),
//                           );
//                         }
//
//                         return Text(
//                           user?.lastSeen != null
//                               ? 'Last seen ${DateFormat('hh:mm a').format(user!.lastSeen)}'
//                               : 'Offline',
//                           style: const TextStyle(
//                               color: AppTheme.textSecondary, fontSize: 12),
//                         );
//                       },
//                     );
//                   },
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//       actions: [
//         IconButton(
//           onPressed: () {},
//           icon: const Icon(Icons.call_outlined, color: AppTheme.textPrimary),
//         ),
//         IconButton(
//           onPressed: () {},
//           icon: const Icon(Icons.videocam_outlined, color: AppTheme.textPrimary),
//         ),
//         const SizedBox(width: 8),
//       ],
//     );
//   }
//
//   Widget _buildReplyPreview() {
//     return Container(
//       margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//       decoration: BoxDecoration(
//         color: AppTheme.surfaceLight,
//         borderRadius: BorderRadius.circular(12),
//         border: const Border(
//           left: BorderSide(color: AppTheme.secondary, width: 3),
//         ),
//       ),
//       child: Row(
//         children: [
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   _replyingTo!.senderId == _currentUserId ? 'You' : widget.otherUser.name,
//                   style: const TextStyle(
//                       color: AppTheme.secondary,
//                       fontSize: 12,
//                       fontWeight: FontWeight.w600),
//                 ),
//                 const SizedBox(height: 2),
//                 Text(
//                   _replyingTo!.content,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(
//                       color: AppTheme.textSecondary, fontSize: 13),
//                 ),
//               ],
//             ),
//           ),
//           IconButton(
//             onPressed: () => setState(() => _replyingTo = null),
//             icon: const Icon(Icons.close_rounded,
//                 color: AppTheme.textSecondary, size: 20),
//             padding: EdgeInsets.zero,
//             constraints: const BoxConstraints(),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildInputArea() {
//     return Container(
//       padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
//       decoration: const BoxDecoration(
//         color: AppTheme.primary,
//         border: Border(top: BorderSide(color: AppTheme.divider)),
//       ),
//       child: SafeArea(
//         top: false,
//         child: Row(
//           children: [
//             // Attachment button
//             IconButton(
//               onPressed: _pickAndSendImage,
//               icon: const Icon(Icons.attach_file_rounded,
//                   color: AppTheme.textSecondary),
//             ),
//
//             // Text field
//             Expanded(
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: AppTheme.surfaceLight,
//                   borderRadius: BorderRadius.circular(24),
//                 ),
//                 child: Row(
//                   children: [
//                     Expanded(
//                       child: TextField(
//                         controller: _messageController,
//                         maxLines: 5,
//                         minLines: 1,
//                         style: const TextStyle(
//                             color: AppTheme.textPrimary, fontSize: 15),
//                         decoration: const InputDecoration(
//                           hintText: 'Type a message...',
//                           border: InputBorder.none,
//                           contentPadding: EdgeInsets.symmetric(
//                               horizontal: 16, vertical: 10),
//                           fillColor: Colors.transparent,
//                         ),
//                         textCapitalization: TextCapitalization.sentences,
//                         onSubmitted: (_) => _sendMessage(),
//                       ),
//                     ),
//                     IconButton(
//                       onPressed: () {},
//                       icon: const Icon(Icons.emoji_emotions_outlined,
//                           color: AppTheme.textSecondary, size: 22),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//
//             const SizedBox(width: 8),
//
//             // Send button
//             GestureDetector(
//               onTap: _sendMessage,
//               child: AnimatedContainer(
//                 duration: const Duration(milliseconds: 200),
//                 width: 48,
//                 height: 48,
//                 decoration: BoxDecoration(
//                   color: _isTyping
//                       ? AppTheme.secondary
//                       : AppTheme.secondary.withOpacity(0.3),
//                   shape: BoxShape.circle,
//                 ),
//                 child: Icon(
//                   Icons.send_rounded,
//                   color: _isTyping ? AppTheme.primary : AppTheme.textSecondary,
//                   size: 22,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildDateSeparator(DateTime date) {
//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 16),
//       child: Row(
//         children: [
//           Expanded(
//               child: Divider(color: AppTheme.divider.withOpacity(0.5), height: 1)),
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 12),
//             child: Text(
//               _formatDate(date),
//               style: const TextStyle(
//                   color: AppTheme.textSecondary,
//                   fontSize: 11,
//                   fontWeight: FontWeight.w500),
//             ),
//           ),
//           Expanded(
//               child: Divider(color: AppTheme.divider.withOpacity(0.5), height: 1)),
//         ],
//       ),
//     );
//   }
//
//   bool _isSameDay(DateTime a, DateTime b) {
//     return a.year == b.year && a.month == b.month && a.day == b.day;
//   }
//
//   String _formatDate(DateTime date) {
//     final now = DateTime.now();
//     if (_isSameDay(date, now)) return 'Today';
//     if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
//       return 'Yesterday';
//     }
//     return DateFormat('MMMM d, yyyy').format(date);
//   }
//
//   void _showMessageOptions(MessageModel message, bool isMe) {
//     HapticFeedback.mediumImpact();
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: AppTheme.surface,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (ctx) => Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             margin: const EdgeInsets.only(top: 10, bottom: 8),
//             width: 40,
//             height: 4,
//             decoration: BoxDecoration(
//               color: AppTheme.divider,
//               borderRadius: BorderRadius.circular(2),
//             ),
//           ),
//           // Message preview
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
//             child: Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: AppTheme.surfaceLight,
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Text(
//                 message.content,
//                 maxLines: 3,
//                 overflow: TextOverflow.ellipsis,
//                 style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
//               ),
//             ),
//           ),
//           _optionTile(
//             icon: Icons.reply_rounded,
//             label: 'Reply',
//             onTap: () {
//               Navigator.pop(ctx);
//               setState(() => _replyingTo = message);
//             },
//           ),
//           _optionTile(
//             icon: Icons.copy_rounded,
//             label: 'Copy',
//             onTap: () {
//               Navigator.pop(ctx);
//               Clipboard.setData(ClipboardData(text: message.content));
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(content: Text('Message copied')),
//               );
//             },
//           ),
//           if (isMe)
//             _optionTile(
//               icon: Icons.delete_outline_rounded,
//               label: 'Delete',
//               color: AppTheme.error,
//               onTap: () {
//                 Navigator.pop(ctx);
//                 _chatService.deleteMessage(widget.chatId, message.id);
//               },
//             ),
//           const SizedBox(height: 16),
//         ],
//       ),
//     );
//   }
//
//   Widget _optionTile({
//     required IconData icon,
//     required String label,
//     required VoidCallback onTap,
//     Color color = AppTheme.textPrimary,
//   }) {
//     return ListTile(
//       onTap: onTap,
//       leading: Icon(icon, color: color, size: 22),
//       title: Text(label, style: TextStyle(color: color, fontSize: 15)),
//     );
//   }
// }
//
// class _TypingIndicator extends StatefulWidget {
//   @override
//   State<_TypingIndicator> createState() => _TypingIndicatorState();
// }
//
// class _TypingIndicatorState extends State<_TypingIndicator>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//
//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1000),
//     )..repeat();
//   }
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return AnimatedBuilder(
//       animation: _controller,
//       builder: (_, __) {
//         return Row(
//           mainAxisSize: MainAxisSize.min,
//           children: List.generate(3, (i) {
//             final delay = i / 3;
//             final value = (_controller.value - delay).clamp(0.0, 1.0);
//             final opacity = (value < 0.5 ? value * 2 : (1 - value) * 2).clamp(0.3, 1.0);
//             return Container(
//               margin: const EdgeInsets.symmetric(horizontal: 1),
//               width: 4,
//               height: 4,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: AppTheme.secondary.withOpacity(opacity),
//               ),
//             );
//           }),
//         );
//       },
//     );
//   }
// }
// lib/screens/chat/chat_screen.dart
// ✅ Complete file — replaces your existing chat_screen.dart
// Only change from your version: call buttons now navigate to call screens

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../const/app_constatnts.dart';
import '../../model/message_model.dart';
import '../../model/user_model.dart';
import '../../service/chat_service.dart';
import '../../utils/message_bubble.dart';
import '../../utils/user_avtar.dart';
import '../call/audio_call.dart';
import '../call/video_call.dart';
import '../user/user_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final UserModel otherUser;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUser,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatService = ChatService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final _imagePicker = ImagePicker();

  bool _isTyping = false;
  Timer? _typingTimer;
  MessageModel? _replyingTo;

  @override
  void initState() {
    super.initState();
    _chatService.markMessagesAsRead(widget.chatId);
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _chatService.setTypingStatus(widget.chatId, false);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final isNowTyping = _messageController.text.isNotEmpty;
    if (isNowTyping != _isTyping) {
      setState(() => _isTyping = isNowTyping);
      _chatService.setTypingStatus(widget.chatId, isNowTyping);
    }
    _typingTimer?.cancel();
    if (isNowTyping) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _chatService.setTypingStatus(widget.chatId, false);
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final reply = _replyingTo;
    _messageController.clear();
    setState(() => _replyingTo = null);
    await _chatService.sendMessage(
      chatId: widget.chatId,
      receiverId: widget.otherUser.uid,
      content: text,
      replyToId: reply?.id,
      replyToContent: reply?.content,
    );
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  Future<void> _pickAndSendImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked == null) return;
    await _chatService.sendImageMessage(
      chatId: widget.chatId,
      receiverId: widget.otherUser.uid,
      imageFile: File(picked.path),
    );
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  // ✅ NEW: Navigate to voice call
  void _startVoiceCall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoiceCallScreen(otherUser: widget.otherUser),
      ),
    );
  }

  // ✅ NEW: Navigate to video call
  void _startVideoCall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(otherUser: widget.otherUser),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _chatService.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.secondary),
                  );
                }
                final messages = snapshot.data ?? [];
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.waving_hand_rounded,
                              color: AppTheme.secondary, size: 36),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Say hello to ${widget.otherUser.name.split(' ').first}!',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == _currentUserId;
                    bool showDate = index == 0 ||
                        !_isSameDay(
                            messages[index - 1].timestamp, message.timestamp);
                    return Column(
                      children: [
                        if (showDate) _buildDateSeparator(message.timestamp),
                        GestureDetector(
                          onLongPress: () =>
                              _showMessageOptions(message, isMe),
                          onHorizontalDragEnd: (details) {
                            if (details.primaryVelocity! > 0) {
                              setState(() => _replyingTo = message);
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
          if (_replyingTo != null) _buildReplyPreview(),
          _buildInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leadingWidth: 36,
      title: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => UserDetailScreen(user: widget.otherUser)),
        ),
        child: Row(
          children: [
            UserAvatar(user: widget.otherUser, size: 38),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUser.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                StreamBuilder<UserModel?>(
                  stream: _chatService.getUserStream(widget.otherUser.uid),
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    return StreamBuilder<Map<String, dynamic>>(
                      stream: _chatService.getTypingStatus(widget.chatId),
                      builder: (context, typingSnapshot) {
                        final typing = typingSnapshot.data ?? {};
                        final isTyping =
                            typing[widget.otherUser.uid] == true;
                        if (isTyping) {
                          return Row(
                            children: [
                              _TypingIndicator(),
                              const SizedBox(width: 6),
                              const Text('typing...',
                                  style: TextStyle(
                                      color: AppTheme.secondary, fontSize: 12)),
                            ],
                          );
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
      ),
      actions: [
        // ✅ VOICE CALL BUTTON — now works!
        IconButton(
          onPressed: _startVoiceCall,
          tooltip: 'Voice Call',
          icon: const Icon(Icons.call_outlined, color: AppTheme.textPrimary),
        ),
        // ✅ VIDEO CALL BUTTON — now works!
        IconButton(
          onPressed: _startVideoCall,
          tooltip: 'Video Call',
          icon:
          const Icon(Icons.videocam_outlined, color: AppTheme.textPrimary),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildReplyPreview() {
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
                  _replyingTo!.senderId == _currentUserId
                      ? 'You'
                      : widget.otherUser.name,
                  style: const TextStyle(
                      color: AppTheme.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyingTo!.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _replyingTo = null),
            icon: const Icon(Icons.close_rounded,
                color: AppTheme.textSecondary, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: AppTheme.primary,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              onPressed: _pickAndSendImage,
              icon: const Icon(Icons.attach_file_rounded,
                  color: AppTheme.textSecondary),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        maxLines: 5,
                        minLines: 1,
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          fillColor: Colors.transparent,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.emoji_emotions_outlined,
                          color: AppTheme.textSecondary, size: 22),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _isTyping
                      ? AppTheme.secondary
                      : AppTheme.secondary.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send_rounded,
                  color:
                  _isTyping ? AppTheme.primary : AppTheme.textSecondary,
                  size: 22,
                ),
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
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    return DateFormat('MMMM d, yyyy').format(date);
  }

  void _showMessageOptions(MessageModel message, bool isMe) {
    HapticFeedback.mediumImpact();
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(12)),
              child: Text(message.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
            ),
          ),
          _optionTile(
              icon: Icons.reply_rounded,
              label: 'Reply',
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyingTo = message);
              }),
          _optionTile(
              icon: Icons.copy_rounded,
              label: 'Copy',
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message copied')));
              }),
          if (isMe)
            _optionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                color: AppTheme.error,
                onTap: () {
                  Navigator.pop(ctx);
                  _chatService.deleteMessage(widget.chatId, message.id);
                }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _optionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppTheme.textPrimary,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: TextStyle(color: color, fontSize: 15)),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final delay = i / 3;
          final value = (_controller.value - delay).clamp(0.0, 1.0);
          final opacity =
          (value < 0.5 ? value * 2 : (1 - value) * 2).clamp(0.3, 1.0);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.secondary.withOpacity(opacity),
            ),
          );
        }),
      ),
    );
  }
}