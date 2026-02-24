// lib/service/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../const/app_constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─── Sign Up ──────────────────────────────────────────────────────────────
  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      final errStr = e.toString();
      final isPigeonCrash = errStr.contains('PigeonUserDetails') ||
          errStr.contains('PigeonUserInfo') ||
          errStr.contains('List<Object?>') ||
          errStr.contains('type cast');

      if (isPigeonCrash && _auth.currentUser != null) {
        // ✅ Account was created despite the crash — continue
      } else if (e is FirebaseAuthException) {
        return _handleError(e);
      } else {
        return errStr;
      }
    }

    final user = _auth.currentUser;
    if (user == null) return 'Sign up failed — please try again.';

    // Update display name (ignore errors)
    try { await user.updateDisplayName(name.trim()); } catch (_) {}

    // Send verification email (ignore errors)
    try { await user.sendEmailVerification(); } catch (_) {}

    // ✅ Save to Firestore — this MUST succeed
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .set({
        'uid': user.uid,
        'name': name.trim(),
        'email': email.trim(),
        'photoUrl': '',
        'isOnline': false,
        'emailVerified': false,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
        'status': '👋 Hey there! I am using Wavechat.',
        'fcmToken': '',
      });
    } catch (e) {
      return 'Account created but profile save failed: $e';
    }

    return null; // null = success
  }

  // ─── Sign In ──────────────────────────────────────────────────────────────
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      final errStr = e.toString();
      final isPigeonCrash = errStr.contains('PigeonUserDetails') ||
          errStr.contains('PigeonUserInfo') ||
          errStr.contains('List<Object?>') ||
          errStr.contains('type cast');

      if (isPigeonCrash && _auth.currentUser != null) {
        // Signed in despite crash
      } else if (e is FirebaseAuthException) {
        return _handleError(e);
      } else {
        return errStr;
      }
    }

    final user = _auth.currentUser;
    if (user == null) return 'Sign in failed';

    // ✅ Get fresh token to check emailVerified accurately
    try { await user.getIdToken(true); } catch (_) {}

    if (!(_auth.currentUser?.emailVerified ?? false)) {
      await _auth.signOut();
      return 'Please verify your email first. Check your inbox for the verification link.';
    }

    // ✅ Ensure Firestore doc exists (in case signup Firestore write failed)
    await _ensureUserDoc(user);
    await _updateOnlineStatus(user.uid, true);
    return null;
  }

  // ─── Google Sign In ───────────────────────────────────────────────────────
  Future<String?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return 'Google sign in cancelled';

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
    } catch (e) {
      final errStr = e.toString();
      final isPigeonCrash = errStr.contains('PigeonUserDetails') ||
          errStr.contains('PigeonUserInfo') ||
          errStr.contains('List<Object?>') ||
          errStr.contains('type cast');

      if (isPigeonCrash && _auth.currentUser != null) {
        // Signed in despite crash
      } else if (e is FirebaseAuthException) {
        return _handleError(e);
      } else {
        return errStr;
      }
    }

    final user = _auth.currentUser;
    if (user == null) return 'Google sign in failed';

    await _ensureUserDoc(user, isGoogleUser: true);
    await _updateOnlineStatus(user.uid, true);
    return null;
  }

  // ─── Ensure user doc exists in Firestore ─────────────────────────────────
  // Called on every sign in — creates doc if missing (handles signup Pigeon crash case)
  Future<void> _ensureUserDoc(User user, {bool isGoogleUser = false}) async {
    final ref = _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid);

    // ✅ Always use set+merge — works whether doc exists or not
    // Never use update() — it throws if doc doesn't exist
    await ref.set({
      'uid': user.uid,
      'name': user.displayName ?? user.email?.split('@')[0] ?? 'User',
      'email': user.email ?? '',
      'photoUrl': user.photoURL ?? '',
      'isOnline': true,
      'emailVerified': isGoogleUser ? true : (user.emailVerified),
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
      'status': '👋 Hey there! I am using Wavechat.',
      'fcmToken': '',
    }, SetOptions(merge: true)); // merge: true = won't overwrite existing fields like status
  }
  Future<void> _updateOnlineStatus(String uid, bool isOnline) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .set({
        'isOnline': isOnline,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true)); // ✅ set+merge instead of update()
    } catch (_) {}
  }
  Future<String?> resendVerificationEmail() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _handleError(e);
    }
  }

  Future<void> signOut() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) await _updateOnlineStatus(uid, false);
    } catch (_) {}
    try { await _googleSignIn.signOut(); } catch (_) {}
    await _auth.signOut();
  }

  Future<void> updateOnlineStatus(bool isOnline) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    await _updateOnlineStatus(uid, isOnline);
  }

  String _handleError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':       return 'No account found with this email.';
      case 'wrong-password':       return 'Incorrect password.';
      case 'invalid-credential':   return 'Incorrect email or password.';
      case 'email-already-in-use': return 'An account already exists with this email.';
      case 'weak-password':        return 'Password must be at least 6 characters.';
      case 'invalid-email':        return 'Please enter a valid email address.';
      case 'too-many-requests':    return 'Too many attempts. Please try again later.';
      case 'network-request-failed': return 'Network error. Check your connection.';
      default: return e.message ?? 'An error occurred. Please try again.';
    }
  }
}