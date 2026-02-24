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
