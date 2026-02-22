// lib/service/chat_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../const/app_constatnts.dart';
import '../model/chat_model.dart';
import '../model/message_model.dart';
import '../model/user_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  // ✅ Safe uid getter
  String get currentUserId {
    final uid = _auth.currentUser?.uid?.trim();
    if (uid == null || uid.isEmpty) throw Exception('User not authenticated');
    return uid;
  }

  String getChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  // ✅ FIXED: uid validated before use as map key
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
        'unreadCount': {
          myUid: 0,       // ✅ always valid, never empty
          otherUserId: 0,
        },
        'lastMessageType': 'text',
      });
    }
    return chatId;
  }

  Future<void> sendMessage({
    required String chatId,
    required String receiverId,
    required String content,
    MessageType type = MessageType.text,
    String? replyToId,
    String? replyToContent,
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
    );

    final batch = _firestore.batch();

    final messageRef = _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection(AppConstants.messagesCollection)
        .doc(messageId);
    batch.set(messageRef, message.toMap());

    final chatRef =
    _firestore.collection(AppConstants.chatsCollection).doc(chatId);
    batch.update(chatRef, {
      'lastMessage': type == MessageType.image ? '📷 Photo' : content,
      'lastMessageSenderId': myUid,
      'lastMessageTime': Timestamp.fromDate(now),
      'lastMessageType': type.name,
      'unreadCount.$receiverId': FieldValue.increment(1),
    });

    await batch.commit();
  }

  Future<void> sendImageMessage({
    required String chatId,
    required String receiverId,
    required File imageFile,
  }) async {
    final imageId = _uuid.v4();
    final ref = _storage.ref().child('chat_images/$chatId/$imageId.jpg');
    await ref.putFile(imageFile);
    final url = await ref.getDownloadURL();
    await sendMessage(
      chatId: chatId,
      receiverId: receiverId,
      content: url,
      type: MessageType.image,
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

  // ✅ No orderBy — sorted in Dart to avoid index requirement
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

  // ✅ Filtered in Dart — no index needed
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
    if (name != null) updates['name'] = name;
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
    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }

  // ✅ Fully guarded — never crashes
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