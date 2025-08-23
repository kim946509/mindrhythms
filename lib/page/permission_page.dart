import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../service/notification_permission_check.dart';
import '../widget/common_title.dart';
import '../widget/common_sub_title.dart';
import '../widget/common_large_button.dart';
import '../widget/common_botton_button.dart';
import 'splash_page.dart';

class PermissionController extends GetxController with WidgetsBindingObserver {
  var isRequestingPermission = false;
  var showSettingsButton = false;
  
  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 앱이 포그라운드로 돌아왔을 때 권한 다시 확인
      checkPermissionAndNavigate();
    }
  }

  Future<void> requestPermission() async {
    isRequestingPermission = true;
    update();
    
    // 권한 요청
    final hasPermission = await NotificationPermissionCheck.requestPermission();
    bool exactGranted = true;
    if (hasPermission && GetPlatform.isAndroid) {
      // Android 정확 알람 권한 확인/요청
      final canExact = await NotificationPermissionCheck.canScheduleExactAlarms();
      if (!canExact) {
        exactGranted = await NotificationPermissionCheck.requestExactAlarmsPermission();
      }
    }
    
    isRequestingPermission = false;
    update();
    
    if (hasPermission && exactGranted) {
      // 권한이 허용된 경우
      Get.offAll(() => const SplashPage());
      return;
    }
    
    // 권한이 거부된 경우 설정으로 이동하는 버튼 표시
    showSettingsButton = true;
    update();
  }
  
  Future<void> openSettings() async {
    await NotificationPermissionCheck.openSettings();
  }
  
  Future<void> checkPermissionAndNavigate() async {
    final hasPermission = await NotificationPermissionCheck.checkStatus();
    if (hasPermission) {
      // 권한이 허용되었으면 스플래시 페이지로 돌아가 다음 단계 진행
      Get.offAll(() => const SplashPage());
    }
  }
}

class PermissionPage extends StatelessWidget {
  const PermissionPage({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(PermissionController());
    
    return GetBuilder<PermissionController>(
      builder: (controller) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
    
              const SizedBox(height: 24),
              const CommonTitle(
                text: '앱 사용을 위해 알림 권한이 필요합니다',
                fontSize: 20,
              ),
              const SizedBox(height: 16),
              const CommonSubTitle(
                text: '마음리듬은 정해진 시간에 알림을 통해\n설문을 안내해 드립니다.',
                fontSize: 16,
              ),
              const SizedBox(height: 32),
              
              // 권한 요청 상태에 따라 다른 UI 표시
              Builder(
                builder: (context) {
                  if (controller.isRequestingPermission) {
                    // 권한 요청 중
                    return const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        CommonSubTitle(text: '권한 요청 중...', fontSize: 16, color: Colors.black54),
                      ],
                    );
                  } else if (controller.showSettingsButton) {
                    // 권한 거부 후 설정 버튼 표시
                    return Column(
                      children: [
                        CommonSubTitle(
                          text: '알림 권한이 거부되었습니다.\n${NotificationPermissionCheck.getPermissionGuideText()}',
                          fontSize: 16,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 24),
                        CommonLargeButton(
                          text: '설정으로 이동',
                          onPressed: controller.openSettings,
                          backgroundColor: Colors.blue,
                          textColor: Colors.white,
                        ),
                      ],
                    );
                  } else {
                    // 초기 상태 - 권한 요청 버튼 표시
                    return CommonBottomButton(
                      text: '권한 허용하기',
                      onPressed: controller.requestPermission,
                      backgroundColor: const Color(0xFF6B73FF),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
