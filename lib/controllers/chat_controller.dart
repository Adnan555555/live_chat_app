// lib/controllers/chat_controller.dart
import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../model/message_model.dart';
import '../model/user_model.dart';
import '../service/chat_service.dart';

class ChatController extends GetxController {
  final ChatService _chatService = ChatService();
  final AudioRecorder _audioRecorder = AudioRecorder();

  final messages = <MessageModel>[].obs;
  final isRecording = false.obs;
  final isSending = false.obs;
  final recordingSeconds = 0.obs;
  final replyingTo = Rxn<MessageModel>();
  final isTyping = false.obs;

  late String chatId;
  late UserModel otherUser;

  Timer? _typingTimer;
  Timer? _recordingTimer;
  String? _recordingPath;

  @override
  void onClose() {
    _typingTimer?.cancel();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _chatService.setTypingStatus(chatId, false);
    super.onClose();
  }

  void init(String cId, UserModel user) {
    chatId = cId;
    otherUser = user;
    _chatService.markMessagesAsRead(chatId);
  }

  Stream<List<MessageModel>> get messagesStream =>
      _chatService.getMessages(chatId);

  Stream<UserModel?> get otherUserStream =>
      _chatService.getUserStream(otherUser.uid);

  Stream<Map<String, dynamic>> get typingStream =>
      _chatService.getTypingStatus(chatId);

  void onTypingChanged(String text) {
    final typing = text.isNotEmpty;
    if (typing != isTyping.value) {
      isTyping.value = typing;
      _chatService.setTypingStatus(chatId, typing);
    }
    _typingTimer?.cancel();
    if (typing) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _chatService.setTypingStatus(chatId, false);
      });
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final reply = replyingTo.value;
    replyingTo.value = null;

    await _chatService.sendMessage(
      chatId: chatId,
      receiverId: otherUser.uid,
      content: text.trim(),
      replyToId: reply?.id,
      replyToContent: reply?.content,
    );
  }

  Future<void> startRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      Get.snackbar('Permission', 'Microphone permission required',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _recordingPath!,
    );

    isRecording.value = true;
    recordingSeconds.value = 0;
    _recordingTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => recordingSeconds.value++);
  }

  Future<void> stopRecording({bool cancel = false}) async {
    _recordingTimer?.cancel();
    final path = await _audioRecorder.stop();
    isRecording.value = false;

    if (cancel || path == null) return;

    isSending.value = true;
    try {
      await _chatService.sendAudioMessage(
        chatId: chatId,
        receiverId: otherUser.uid,
        audioFile: File(path),
        durationSeconds: recordingSeconds.value,
      );
    } finally {
      isSending.value = false;
    }
  }

  void setReply(MessageModel message) => replyingTo.value = message;
  void clearReply() => replyingTo.value = null;

  Future<void> deleteMessage(String messageId) async {
    await _chatService.deleteMessage(chatId, messageId);
  }
}
