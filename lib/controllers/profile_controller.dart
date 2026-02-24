// lib/controllers/profile_controller.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../service/auth_service.dart';
import '../service/chat_service.dart';
import '../service/notification_service.dart';
import '../model/user_model.dart';
import '../screens/auth/login_screen.dart';

class ProfileController extends GetxController {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();

  final isLoading = false.obs;

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void onInit() {
    super.onInit();
    // FIX: When the controller initialises, ensure the Firestore doc exists
    // for the current user. This handles the "User not found" case where a
    // user has a valid Firebase Auth account but no matching Firestore doc
    // (e.g. the doc was never created, was deleted, or signup failed midway).
    _repairUserDocIfMissing();
  }

  /// Checks if the Firestore user doc exists; if not, tells AuthService to
  /// create it. This is a safety net — the primary creation happens in
  /// AuthService.signIn(), but running it here too means the Profile screen
  /// will self-heal even if navigation happens via SplashScreen (which skips
  /// the normal signIn() flow when a user is already logged in).
  Future<void> _repairUserDocIfMissing() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final doc = await _chatService.getUserById(currentUser.uid);
      if (doc == null) {
        // Doc is missing — recreate it via AuthService
        // This will trigger the stream to emit a non-null UserModel
        // and the Profile screen will display correctly.
        await _authService.updateOnlineStatus(true);

        // AuthService.updateOnlineStatus uses set+merge, so if the doc
        // truly doesn't exist at all, we need a full create via the
        // dedicated repair method below.
        await _createMissingUserDoc(currentUser);
      }
    } catch (_) {}
  }

  Future<void> _createMissingUserDoc(User user) async {
    try {
      final name = (user.displayName?.trim().isNotEmpty == true)
          ? user.displayName!.trim()
          : (user.email?.split('@')[0] ?? 'User');

      await _chatService.updateProfile(
        uid: user.uid,
        name: name,
        status: '👋 Hey there! I am using Wavechat.',
      );

      // Also write the fields that updateProfile doesn't cover
      // by calling the auth service's full repair path
      await _authService.updateOnlineStatus(true);
    } catch (_) {}
  }

  Stream<UserModel?> get userStream => _chatService.getUserStream(uid);

  Future<void> updateName(String name) async {
    isLoading.value = true;
    try {
      await _chatService.updateProfile(uid: uid, name: name);
      await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
      Get.snackbar('Success', 'Name updated!',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateStatus(String status) async {
    isLoading.value = true;
    try {
      await _chatService.updateProfile(uid: uid, status: status);
      Get.snackbar('Success', 'Status updated!',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    await NotificationService().clearToken();
    await _authService.signOut();
    Get.offAll(() => const LoginScreen());
  }
}