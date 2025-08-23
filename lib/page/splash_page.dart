import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../service/notification_permission_check.dart';
import '../service/user_info_check.dart';
import '../widget/common_title.dart';
import '../widget/common_sub_title.dart';
import 'permission_page.dart';
import 'login_page.dart';
import 'user_info_page.dart';

class SplashController extends GetxController with WidgetsBindingObserver {
  var notification = false;
  var userInfo = false;
  var isLoading = true;
  var loadingMessage = '초기화 중...';
  String? userId;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    checkPermissions();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkPermissions();
    }
  }

  Future<void> checkPermissions() async {
    isLoading = true;
    update();
    
    // 알림 권한 체크 (상태만 확인, 요청하지 않음)
    loadingMessage = '알림 권한을 확인하고 있습니다...';
    update();
    await Future.delayed(const Duration(milliseconds: 500)); // 메시지 표시를 위한 지연
    
    notification = await NotificationPermissionCheck.checkStatus();
    
    if (notification) {
      // 유저 정보 체크
      loadingMessage = '사용자 정보를 확인하고 있습니다...';
      update();
      await Future.delayed(const Duration(milliseconds: 500)); // 메시지 표시를 위한 지연
      
      final userCheck = await UserInfoCheck.check();
      userInfo = userCheck.isLoggedIn;
      userId = userCheck.userId;
    }
    
    isLoading = false;
    update();
  }
}

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SplashController>(
      builder: (controller) {
        return Scaffold(
          body: controller.isLoading 
            ? _buildLoadingScreen(controller)
            : _buildNavigationScreen(controller),
        );
      },
    );
  }
  
  Widget _buildLoadingScreen(SplashController controller) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 앱 타이틀
            const CommonTitle(
              text: '마음리듬',
              fontSize: 36,
            ),
            const SizedBox(height: 60),
            
            // 로딩 메시지
            CommonSubTitle(
              text: controller.loadingMessage,
              fontSize: 18,
              color: Colors.black87,
            ),
            const SizedBox(height: 24),
            
            // 진행 상태 바
            SizedBox(
              width: 240,
              child: LinearProgressIndicator(
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6B73FF)),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNavigationScreen(SplashController controller) {
    if (!controller.notification) {
      return const PermissionPage();
    }
    
    if (!controller.userInfo) {
      return LoginPage(
        userId: controller.userId,  // 이전 로그인 ID가 있다면 전달
      );
    }
    
    return UserInfoPage(userId: controller.userId!);
  }
}
