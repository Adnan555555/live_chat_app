// lib/controllers/home_controller.dart
import 'package:get/get.dart';
import '../service/auth_service.dart';

class HomeController extends GetxController {
  final AuthService _authService = AuthService();
  final currentIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _authService.updateOnlineStatus(true);
  }

  @override
  void onClose() {
    _authService.updateOnlineStatus(false);
    super.onClose();
  }

  void changeTab(int index) => currentIndex.value = index;
}
