// lib/screens/chat/chat_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../const/app_constatnts.dart';
import '../../model/message_model.dart';
import '../../model/user_model.dart';
import '../../service/chat_service.dart';
import '../../utils/message_bubble.dart';
import '../../utils/user_avtar.dart';
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
  final _audioRecorder = AudioRecorder();

  bool _isTyping = false;
  bool _isRecording = false;
  bool _isSendingFile = false;
  int _recordingSeconds = 0;
  Timer? _typingTimer;
  Timer? _recordingTimer;
  MessageModel? _replyingTo;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _chatService.markMessagesAsRead(widget.chatId);
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
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

  // ✅ Pick image from gallery or camera
  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded,
                color: AppTheme.secondary),
            title: const Text('Gallery',
                style: TextStyle(color: AppTheme.textPrimary)),
            onTap: () async {
              Navigator.pop(ctx);
              await _pickImage(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded,
                color: AppTheme.secondary),
            title: const Text('Camera',
                style: TextStyle(color: AppTheme.textPrimary)),
            onTap: () async {
              Navigator.pop(ctx);
              await _pickImage(ImageSource.camera);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 70,
    );
    if (picked == null) return;
    setState(() => _isSendingFile = true);
    try {
      await _chatService.sendImageMessage(
        chatId: widget.chatId,
        receiverId: widget.otherUser.uid,
        imageFile: File(picked.path),
      );
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } finally {
      if (mounted) setState(() => _isSendingFile = false);
    }
  }

  // ✅ Pick any file
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    setState(() => _isSendingFile = true);
    try {
      await _chatService.sendFileMessage(
        chatId: widget.chatId,
        receiverId: widget.otherUser.uid,
        file: File(file.path!),
      );
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending file: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingFile = false);
    }
  }

  // ✅ Show attachment menu
  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _attachmentItem(
                  icon: Icons.image_rounded,
                  label: 'Photo',
                  color: const Color(0xFF4ECDC4),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showImagePicker();
                  },
                ),
                _attachmentItem(
                  icon: Icons.insert_drive_file_rounded,
                  label: 'File',
                  color: const Color(0xFF7B2FBE),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFile();
                  },
                ),
                _attachmentItem(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: const Color(0xFF3A86FF),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _attachmentItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  // ✅ Voice recording
  Future<void> _startRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) return;

    final dir = await getTemporaryDirectory();
    _recordingPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _recordingPath!,
    );

    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
    });

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordingSeconds++);
    });
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    _recordingTimer?.cancel();
    final path = await _audioRecorder.stop();

    setState(() => _isRecording = false);

    if (cancel || path == null) return;

    setState(() => _isSendingFile = true);
    try {
      await _chatService.sendAudioMessage(
        chatId: widget.chatId,
        receiverId: widget.otherUser.uid,
        audioFile: File(path),
        durationSeconds: _recordingSeconds,
      );
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } finally {
      if (mounted) setState(() => _isSendingFile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Upload progress indicator
          if (_isSendingFile)
            LinearProgressIndicator(
              color: AppTheme.secondary,
              backgroundColor: AppTheme.secondary.withOpacity(0.2),
            ),

          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _chatService.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child:
                    CircularProgressIndicator(color: AppTheme.secondary),
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
                          decoration: const BoxDecoration(
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
                                      color: AppTheme.secondary,
                                      fontSize: 12)),
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
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.call_outlined, color: AppTheme.textPrimary),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.videocam_outlined,
              color: AppTheme.textPrimary),
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
    // ✅ Recording UI
    if (_isRecording) {
      final minutes = _recordingSeconds ~/ 60;
      final seconds = _recordingSeconds % 60;
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
              // Cancel
              GestureDetector(
                onTap: () => _stopRecording(cancel: true),
                child: const Icon(Icons.delete_outline_rounded,
                    color: AppTheme.error, size: 28),
              ),
              const SizedBox(width: 12),
              // Recording indicator
              Expanded(
                child: Container(
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
                          color: AppTheme.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text('Recording...',
                          style: TextStyle(
                              color: AppTheme.textPrimary, fontSize: 14)),
                      const Spacer(),
                      Text(
                        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            color: AppTheme.secondary,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Send recording
              GestureDetector(
                onTap: () => _stopRecording(),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppTheme.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: AppTheme.primary, size: 22),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ Normal input UI
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
            // Attachment button
            IconButton(
              onPressed: _showAttachmentMenu,
              icon: const Icon(Icons.add_circle_outline_rounded,
                  color: AppTheme.secondary, size: 28),
            ),

            // Text field
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
                  ],
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Send or mic button
            GestureDetector(
              onTap: _isTyping ? _sendMessage : null,
              onLongPress: _isTyping ? null : _startRecording,
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
                  _isTyping ? Icons.send_rounded : Icons.mic_rounded,
                  color: _isTyping
                      ? AppTheme.primary
                      : AppTheme.textSecondary,
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
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
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
            padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(12)),
              child: Text(
                  message.type == MessageType.text
                      ? message.content
                      : '(${message.type.name})',
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
          if (message.type == MessageType.text)
            _optionTile(
                icon: Icons.copy_rounded,
                label: 'Copy',
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(
                      ClipboardData(text: message.content));
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