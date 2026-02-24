// lib/service/chat_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../const/app_constants.dart';
import '../model/chat_model.dart';
import '../model/message_model.dart';
import '../model/user_model.dart';
import 'notification_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
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
    if (otherUserId.isEmpty) throw Exception('Invalid user ID');

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

  // ✅ Send text message
  Future<void> sendMessage({
    required String chatId,
    required String receiverId,
    required String content,
    String? replyToId,
    String? replyToContent,
  }) async {
    final myUid = currentUserId;
    final messageId = _uuid.v4();
    final now = DateTime.now();

    final batch = _firestore.batch();

    final messageRef = _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection(AppConstants.messagesCollection)
        .doc(messageId);

    batch.set(messageRef, {
      'id': messageId,
      'senderId': myUid,
      'receiverId': receiverId,
      'content': content,
      'type': 'text',
      'status': 'sent',
      'timestamp': Timestamp.fromDate(now),
      'isDeleted': false,
      'replyToId': replyToId,
      'replyToContent': replyToContent,
    });

    final chatRef =
    _firestore.collection(AppConstants.chatsCollection).doc(chatId);
    batch.update(chatRef, {
      'lastMessage': content,
      'lastMessageSenderId': myUid,
      'lastMessageTime': Timestamp.fromDate(now),
      'lastMessageType': 'text',
      'unreadCount.$receiverId': FieldValue.increment(1),
    });

    await batch.commit();

    // Send notification
    final senderDoc =
    await _firestore.collection('users').doc(myUid).get();
    final senderName = senderDoc.data()?['name'] ?? 'Someone';
    await _notificationService.sendMessageNotification(
      receiverId: receiverId,
      senderName: senderName,
      message: content,
      chatId: chatId,
    );
  }

  // ✅ Send audio message — stored as base64 in Firestore (no Storage needed)
  Future<void> sendAudioMessage({
    required String chatId,
    required String receiverId,
    required File audioFile,
    required int durationSeconds,
  }) async {
    final myUid = currentUserId;
    final messageId = _uuid.v4();
    final now = DateTime.now();

    final bytes = await audioFile.readAsBytes();
    final base64Audio = base64Encode(bytes);

    final batch = _firestore.batch();

    final messageRef = _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection(AppConstants.messagesCollection)
        .doc(messageId);

    batch.set(messageRef, {
      'id': messageId,
      'senderId': myUid,
      'receiverId': receiverId,
      'content': base64Audio,
      'type': 'audio',
      'status': 'sent',
      'timestamp': Timestamp.fromDate(now),
      'isDeleted': false,
      'audioDuration': durationSeconds,
    });

    final chatRef =
    _firestore.collection(AppConstants.chatsCollection).doc(chatId);
    batch.update(chatRef, {
      'lastMessage': '🎵 Voice message',
      'lastMessageSenderId': myUid,
      'lastMessageTime': Timestamp.fromDate(now),
      'lastMessageType': 'audio',
      'unreadCount.$receiverId': FieldValue.increment(1),
    });

    await batch.commit();

    final senderDoc =
    await _firestore.collection('users').doc(myUid).get();
    final senderName = senderDoc.data()?['name'] ?? 'Someone';
    await _notificationService.sendMessageNotification(
      receiverId: receiverId,
      senderName: senderName,
      message: '🎵 Voice message',
      chatId: chatId,
    );
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    return _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection(AppConstants.messagesCollection)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs
        .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
        .toList());
  }

  // FIX: Original getUserChats() read currentUserId lazily inside the stream
  // closure — fine at the Firestore level, but the _ChatsTab widget captured
  // the stream at build time and, because it lives in an IndexedStack, never
  // rebuilt when the user switched accounts. The new method accepts the uid
  // explicitly so the caller can key the StreamBuilder on it and force a full
  // stream replacement on account switch.
  Stream<List<ChatModel>> getUserChatsForUser(String uid) {
    if (uid.isEmpty) return const Stream.empty();
    return _firestore
        .collection(AppConstants.chatsCollection)
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snap) {
      final chats = snap.docs
          .map((doc) => ChatModel.fromMap(doc.data(), doc.id))
          .toList();
      chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      return chats;
    });
  }

  // Keep original for any code that still calls it directly
  Stream<List<ChatModel>> getUserChats() {
    return getUserChatsForUser(currentUserId);
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
        .map((snap) => snap.docs
        .map((doc) => UserModel.fromMap(doc.data()))
        .where((u) => u.uid != myUid && u.uid.isNotEmpty)
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
  }) async {
    final updates = <String, dynamic>{};
    if (name != null && name.trim().isNotEmpty) updates['name'] = name.trim();
    if (status != null) updates['status'] = status;
    if (updates.isEmpty) return;
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .set(updates, SetOptions(merge: true));
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