// lib/model/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String photoUrl;
  final bool isOnline;
  final bool emailVerified;
  final DateTime lastSeen;
  final String status;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl = '',
    this.isOnline = false,
    this.emailVerified = false,
    required this.lastSeen,
    this.status = '👋 Hey there! I am using Wavechat.',
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      isOnline: map['isOnline'] ?? false,
      emailVerified: map['emailVerified'] ?? false,
      lastSeen: (map['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? '👋 Hey there! I am using Wavechat.',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'isOnline': isOnline,
      'emailVerified': emailVerified,
      'lastSeen': Timestamp.fromDate(lastSeen),
      'status': status,
    };
  }

  UserModel copyWith({
    String? name,
    String? photoUrl,
    bool? isOnline,
    bool? emailVerified,
    DateTime? lastSeen,
    String? status,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email,
      photoUrl: photoUrl ?? this.photoUrl,
      isOnline: isOnline ?? this.isOnline,
      emailVerified: emailVerified ?? this.emailVerified,
      lastSeen: lastSeen ?? this.lastSeen,
      status: status ?? this.status,
    );
  }
}
