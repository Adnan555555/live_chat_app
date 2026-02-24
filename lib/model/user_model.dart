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
      uid: map['uid'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String? ?? '',
      isOnline: map['isOnline'] as bool? ?? false,
      emailVerified: map['emailVerified'] as bool? ?? false,
      // FIX: lastSeen can be stored as either a Firestore Timestamp OR a plain
      // int (milliseconds since epoch). The original code cast it directly to
      // Timestamp?, which threw a _CastError when the value was an int,
      // silently breaking fromMap() and causing "User not found" / empty lists.
      lastSeen: _parseLastSeen(map['lastSeen']),
      status: map['status'] as String? ?? '👋 Hey there! I am using Wavechat.',
    );
  }

  /// Safely parses lastSeen regardless of how it was stored in Firestore.
  /// - Firestore Timestamp  → convert via .toDate()
  /// - int (milliseconds)   → convert via DateTime.fromMillisecondsSinceEpoch()
  /// - anything else / null → fall back to DateTime.now()
  static DateTime _parseLastSeen(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    // Handle server timestamp that may come as a Map during pending writes
    if (value is Map) return DateTime.now();
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'isOnline': isOnline,
      'emailVerified': emailVerified,
      // Store consistently as Timestamp so reads are predictable
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