// lib/service/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import '../const/app_constatnts.dart';
import '../model/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign Up
  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        // ✅ Write all fields explicitly — do not rely on toMap() in case something is null
        final userData = {
          'uid': result.user!.uid,
          'name': name.trim(),
          'email': email.trim(),
          'photoUrl': '',
          'isOnline': true,
          'lastSeen': Timestamp.fromDate(DateTime.now()),
          'status': '👋 Hey there! I am using Wavechat.',
        };

        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(result.user!.uid)
            .set(userData); // full set — no merge on signup

        await result.user!.updateDisplayName(name.trim());

        return UserModel.fromMap(userData);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Sign In
  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        final uid = result.user!.uid;

        // ✅ Get user doc first
        final doc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(uid)
            .get();

        if (doc.exists) {
          // ✅ Update online status only if doc exists
          await _updateOnlineStatus(uid, true);
          return UserModel.fromMap(doc.data()!);
        } else {
          // ✅ Doc missing — create it from Auth info
          final userData = {
            'uid': uid,
            'name': result.user!.displayName ?? email.split('@')[0],
            'email': email.trim(),
            'photoUrl': result.user!.photoURL ?? '',
            'isOnline': true,
            'lastSeen': Timestamp.fromDate(DateTime.now()),
            'status': '👋 Hey there! I am using Wavechat.',
          };
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(uid)
              .set(userData);
          return UserModel.fromMap(userData);
        }
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      if (_auth.currentUser != null) {
        await _updateOnlineStatus(_auth.currentUser!.uid, false);
      }
    } catch (e) {
      debugPrint('Error updating online status: $e');
    } finally {
      await _auth.signOut();
    }
  }

  // ✅ Update online status using set+merge — never fails
  Future<void> _updateOnlineStatus(String uid, bool isOnline) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .set({
      'isOnline': isOnline,
      'lastSeen': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
  }

  Future<void> updateOnlineStatus(bool isOnline) async {
    final uid = _auth.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      await _updateOnlineStatus(uid, isOnline);
    }
  }

  // Forgot password
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}