// lib/model/message_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ Added file type
enum MessageType { text, image, audio, file }

enum MessageStatus { sending, sent, delivered, read }

class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final MessageType type;
  final MessageStatus status;
  final DateTime timestamp;
  final bool isDeleted;
  final String? replyToId;
  final String? replyToContent;
  final String? fileName;   // ✅ for file messages
  final int? fileSize;      // ✅ file size in bytes, or duration in seconds for audio

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
    this.fileName,
    this.fileSize,
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
      fileName: map['fileName'],
      fileSize: map['fileSize'],
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
      'fileName': fileName,
      'fileSize': fileSize,
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
      fileName: fileName,
      fileSize: fileSize,
    );
  }
}