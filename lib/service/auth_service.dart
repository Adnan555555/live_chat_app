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
        // Account was created despite the crash — continue
      } else if (e is FirebaseAuthException) {
        return _handleError(e);
      } else {
        return errStr;
      }
    }

    final user = _auth.currentUser;
    if (user == null) return 'Sign up failed — please try again.';

    try { await user.updateDisplayName(name.trim()); } catch (_) {}
    try { await user.sendEmailVerification(); } catch (_) {}

    // Save to Firestore
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
        'lastSeen': Timestamp.fromDate(DateTime.now()),
        'status': '👋 Hey there! I am using Wavechat.',
        'fcmToken': '',
      });
    } catch (e) {
      return 'Account created but profile save failed: $e';
    }

    return null;
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

    // Get fresh token to check emailVerified accurately
    try { await user.getIdToken(true); } catch (_) {}

    if (!(_auth.currentUser?.emailVerified ?? false)) {
      await _auth.signOut();
      return 'Please verify your email first. Check your inbox for the verification link.';
    }

    // FIX: Always ensure Firestore doc exists on every sign-in.
    // This handles cases where:
    //   1. The signup Firestore write failed (Pigeon crash, network error)
    //   2. The user doc was manually deleted
    //   3. Old accounts that predate Firestore doc creation
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
  // FIX: This method now CHECKS if the doc exists first.
  // - If doc EXISTS: only updates online-status fields (preserves name, status, etc.)
  // - If doc MISSING: creates a complete new doc from Auth user data
  // This prevents overwriting a user's custom name/status on every login.
  Future<void> _ensureUserDoc(User user, {bool isGoogleUser = false}) async {
    final ref = _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid);

    final doc = await ref.get();

    if (!doc.exists) {
      // Doc is completely missing — create it fresh
      // This fixes the "User not found" and "No users found" bugs
      final name = (user.displayName?.trim().isNotEmpty == true)
          ? user.displayName!.trim()
          : (user.email?.split('@')[0] ?? 'User');

      await ref.set({
        'uid': user.uid,
        'name': name,
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'isOnline': true,
        'emailVerified': isGoogleUser ? true : (user.emailVerified),
        'lastSeen': Timestamp.fromDate(DateTime.now()),
        'status': '👋 Hey there! I am using Wavechat.',
        'fcmToken': '',
      });
    } else {
      // Doc exists — only update fields that should refresh on login
      // Use merge:true and only touch online-status related fields
      // so we never overwrite user's customized name or status
      await ref.set({
        'isOnline': true,
        'lastSeen': Timestamp.fromDate(DateTime.now()),
        // FIX: Also refresh emailVerified in case user just verified their email
        'emailVerified': isGoogleUser ? true : (user.emailVerified),
        // FIX: Ensure uid and email fields are always present (handles
        // docs created before these fields were added)
        'uid': user.uid,
        'email': user.email ?? doc.data()?['email'] ?? '',
      }, SetOptions(merge: true));
    }
  }

  Future<void> _updateOnlineStatus(String uid, bool isOnline) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .set({
        'isOnline': isOnline,
        'lastSeen': Timestamp.fromDate(DateTime.now()),
      }, SetOptions(merge: true));
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

  // FIX: Public method called from SplashScreen for users who are already
  // logged in when the app starts (i.e. they skip the signIn() flow).
  // Without this, a user whose Firestore doc is missing would see
  // "User not found" on Profile and "No users found" on People every time
  // they open the app after a fresh install or cache clear.
  Future<void> ensureUserDocOnAppStart(User user) async {
    final isGoogle = user.providerData
        .any((p) => p.providerId == 'google.com');
    await _ensureUserDoc(user, isGoogleUser: isGoogle);
    await _updateOnlineStatus(user.uid, true);
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