// lib/service/chat_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import '../const/app_constatnts.dart';
import '../model/chat_model.dart';
import '../model/message_model.dart';
import '../model/user_model.dart';
import 'notification_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();
  final _notificationService = NotificationService();

  String get currentUserId {
    final uid = _auth.currentUser?.uid?.trim();
    if (uid == null || uid.isEmpty) throw Exception('User not authenticated');
    return uid;
  }

  String getChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<String> getOrCreateChat(String otherUserId) async {
    final myUid = currentUserId;
    if (myUid.isEmpty || otherUserId.isEmpty) throw Exception('Invalid user ID');

    final chatId = getChatId(myUid, otherUserId);
    final chatDoc = await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .get();

    if (!chatDoc.exists) {
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .set({
        'participants': [myUid, otherUserId],
        'lastMessage': '',
        'lastMessageSenderId': '',
        'lastMessageTime': Timestamp.fromDate(DateTime.now()),
        'unreadCount': {myUid: 0, otherUserId: 0},
        'lastMessageType': 'text',
      });
    }
    return chatId;
  }

  // ✅ Send text message with notification
  Future<void> sendMessage({
    required String chatId,
    required String receiverId,
    required String content,
    MessageType type = MessageType.text,
    String? replyToId,
    String? replyToContent,
    String? fileName,
    int? fileSize,
  }) async {
    final myUid = currentUserId;
    final messageId = _uuid.v4();
    final now = DateTime.now();

    final message = MessageModel(
      id: messageId,
      senderId: myUid,
      receiverId: receiverId,
      content: content,
      type: type,
      status: MessageStatus.sent,
      timestamp: now,
      replyToId: replyToId,
      replyToContent: replyToContent,
      fileName: fileName,
      fileSize: fileSize,
    );

    final batch = _firestore.batch();

    final messageRef = _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection(AppConstants.messagesCollection)
        .doc(messageId);
    batch.set(messageRef, message.toMap());

    String lastMessagePreview;
    switch (type) {
      case MessageType.image:
        lastMessagePreview = '📷 Photo';
        break;
      case MessageType.audio:
        lastMessagePreview = '🎵 Voice message';
        break;
      case MessageType.file:
        lastMessagePreview = '📎 ${fileName ?? 'File'}';
        break;
      default:
        lastMessagePreview = content;
    }

    final chatRef =
    _firestore.collection(AppConstants.chatsCollection).doc(chatId);
    batch.update(chatRef, {
      'lastMessage': lastMessagePreview,
      'lastMessageSenderId': myUid,
      'lastMessageTime': Timestamp.fromDate(now),
      'lastMessageType': type.name,
      'unreadCount.$receiverId': FieldValue.increment(1),
    });

    await batch.commit();

    // ✅ Send notification to receiver
    final senderDoc = await _firestore.collection('users').doc(myUid).get();
    final senderName = senderDoc.data()?['name'] ?? 'Someone';
    await _notificationService.sendMessageNotification(
      receiverId: receiverId,
      senderName: senderName,
      message: lastMessagePreview,
      chatId: chatId,
    );
  }

  // ✅ Upload and send image
  Future<void> sendImageMessage({
    required String chatId,
    required String receiverId,
    required File imageFile,
  }) async {
    final imageId = _uuid.v4();
    final ref = _storage.ref().child('chat_images/$chatId/$imageId.jpg');

    // Show upload progress
    final uploadTask = ref.putFile(imageFile);
    await uploadTask;
    final url = await ref.getDownloadURL();

    await sendMessage(
      chatId: chatId,
      receiverId: receiverId,
      content: url,
      type: MessageType.image,
    );
  }

  // ✅ Upload and send any file (pdf, doc, zip, etc.)
  Future<void> sendFileMessage({
    required String chatId,
    required String receiverId,
    required File file,
  }) async {
    final fileId = _uuid.v4();
    final fileName = path.basename(file.path);
    final fileSize = await file.length();
    final ext = path.extension(file.path).toLowerCase();

    final ref =
    _storage.ref().child('chat_files/$chatId/$fileId$ext');
    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    await sendMessage(
      chatId: chatId,
      receiverId: receiverId,
      content: url,
      type: MessageType.file,
      fileName: fileName,
      fileSize: fileSize,
    );
  }

  // ✅ Upload and send voice message
  Future<void> sendAudioMessage({
    required String chatId,
    required String receiverId,
    required File audioFile,
    required int durationSeconds,
  }) async {
    final audioId = _uuid.v4();
    final ref =
    _storage.ref().child('chat_audio/$chatId/$audioId.m4a');
    await ref.putFile(audioFile);
    final url = await ref.getDownloadURL();

    await sendMessage(
      chatId: chatId,
      receiverId: receiverId,
      content: url,
      type: MessageType.audio,
      fileSize: durationSeconds, // reuse fileSize for duration
    );
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    return _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection(AppConstants.messagesCollection)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
        .toList());
  }

  Stream<List<ChatModel>> getUserChats() {
    final myUid = currentUserId;
    return _firestore
        .collection(AppConstants.chatsCollection)
        .where('participants', arrayContains: myUid)
        .snapshots()
        .map((snapshot) {
      final chats = snapshot.docs
          .map((doc) => ChatModel.fromMap(doc.data(), doc.id))
          .toList();
      chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      return chats;
    });
  }

  Future<void> markMessagesAsRead(String chatId) async {
    final myUid = currentUserId;
    await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .set({'unreadCount': {myUid: 0}}, SetOptions(merge: true));

    final messages = await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection(AppConstants.messagesCollection)
        .where('receiverId', isEqualTo: myUid)
        .where('status', whereIn: ['sent', 'delivered']).get();

    if (messages.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      batch.update(doc.reference, {'status': 'read'});
    }
    await batch.commit();
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection(AppConstants.messagesCollection)
        .doc(messageId)
        .update({'isDeleted': true, 'content': 'This message was deleted'});
  }

  Stream<List<UserModel>> getAllUsers() {
    final myUid = currentUserId;
    return _firestore
        .collection(AppConstants.usersCollection)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data()))
        .where((user) => user.uid != myUid && user.uid.isNotEmpty)
        .toList());
  }

  Future<UserModel?> getUserById(String uid) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();
    if (doc.exists) return UserModel.fromMap(doc.data()!);
    return null;
  }

  Stream<UserModel?> getUserStream(String uid) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromMap(doc.data()!) : null);
  }

  Future<void> updateProfile({
    required String uid,
    String? name,
    String? status,
    String? photoUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null && name.trim().isNotEmpty) updates['name'] = name.trim();
    if (status != null) updates['status'] = status;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (updates.isEmpty) return;
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .set(updates, SetOptions(merge: true));
  }

  Future<String> uploadProfilePicture(String uid, File imageFile) async {
    final ref = _storage.ref().child('profile_pictures/$uid.jpg');
    await ref.putFile(imageFile,
        SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  Future<void> setTypingStatus(String chatId, bool isTyping) async {
    try {
      final myUid = _auth.currentUser?.uid?.trim();
      if (myUid == null || myUid.isEmpty || chatId.isEmpty) return;
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .set({'typing': {myUid: isTyping}}, SetOptions(merge: true));
    } catch (_) {}
  }

  Stream<Map<String, dynamic>> getTypingStatus(String chatId) {
    return _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .snapshots()
        .map((doc) => Map<String, dynamic>.from(
        (doc.data()?['typing'] as Map<String, dynamic>?) ?? {}));
  }
}