// lib/model/message_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ Only text and audio — no file/image (no Firebase Storage needed)
enum MessageType { text, audio }

enum MessageStatus { sending, sent, delivered, read }

class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;       // text content OR base64 audio data URL
  final MessageType type;
  final MessageStatus status;
  final DateTime timestamp;
  final bool isDeleted;
  final String? replyToId;
  final String? replyToContent;
  final int? audioDuration;   // duration in seconds for audio messages

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.type = MessageType.text,
    this.status = MessageStatus.sending,
    required this.timestamp,
    this.isDeleted = false,
    this.replyToId,
    this.replyToContent,
    this.audioDuration,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      content: map['content'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'sent'),
        orElse: () => MessageStatus.sent,
      ),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: map['isDeleted'] ?? false,
      replyToId: map['replyToId'],
      replyToContent: map['replyToContent'],
      audioDuration: map['audioDuration'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'type': type.name,
      'status': status.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'isDeleted': isDeleted,
      'replyToId': replyToId,
      'replyToContent': replyToContent,
      'audioDuration': audioDuration,
    };
  }

  MessageModel copyWith({MessageStatus? status, bool? isDeleted}) {
    return MessageModel(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      content: content,
      type: type,
      status: status ?? this.status,
      timestamp: timestamp,
      isDeleted: isDeleted ?? this.isDeleted,
      replyToId: replyToId,
      replyToContent: replyToContent,
      audioDuration: audioDuration,
    );
  }
}
