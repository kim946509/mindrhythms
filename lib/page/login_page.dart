import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../feature/db.dart';
import 'user_info_page.dart';

class LoginController extends GetxController {
  final TextEditingController userCodeController = TextEditingController();
  var isLoading = false;
  var isButtonActive = false;
  
  @override
  void onInit() {
    super.onInit();
    userCodeController.addListener(_updateButtonState);
  }
  
  void _updateButtonState() {
    final newState = userCodeController.text.trim().isNotEmpty;
    if (isButtonActive != newState) {
      isButtonActive = newState;
      update();
    }
  }
  
  @override
  void onClose() {
    userCodeController.removeListener(_updateButtonState);
    userCodeController.dispose();
    super.onClose();
  }
  
  Future<void> login() async {
    final userCode = userCodeController.text.trim();
    
    if (userCode.isEmpty) {
      Get.snackbar(
        '로그인 실패',
        '사용자 코드를 입력해주세요',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    
    isLoading = true;
    update();
    
    try {
      // 임시 로그인 처리 (실제로는 서버 통신 필요)
      await Future.delayed(const Duration(seconds: 1)); // 서버 통신 시뮬레이션
      
      // 사용자 정보 페이지로 이동 (API 검증은 UserInfoPage에서 수행)
      Get.to(() => UserInfoPage(userId: userCode));
    } finally {
      isLoading = false;
      update();
    }
  }
}

class LoginPage extends StatelessWidget {
  final String? userId;
  
  const LoginPage({super.key, this.userId});

  @override
  Widget build(BuildContext context) {
    // 컨트롤러 초기화 및 이전 ID 설정은 initState와 같은 역할을 하도록 수정
    final controller = Get.put(LoginController());
    
    // 빌드 메서드에서 직접 업데이트하지 않고 마이크로태스크로 예약
    if (userId != null && userId!.isNotEmpty) {
      // 빌드가 완료된 후 실행되도록 스케줄링
      Future.microtask(() {
        controller.userCodeController.text = userId!;
        controller.isButtonActive = true;
        controller.update();
      });
    }
    
    return GetBuilder<LoginController>(
      builder: (controller) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 80),
                // 앱 타이틀
                const Center(
                  child: Text(
                    '마음리듬',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 80),
                
                // 발급받은 코드 라벨
                const Text(
                  '발급받은 코드',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // 사용자 코드 입력 필드
                TextField(
                  controller: controller.userCodeController,
                  decoration: const InputDecoration(
                    hintText: '발급받은 코드를 입력하세요',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                
                const Spacer(),
                
                // 로그인 버튼
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: ElevatedButton(
                    onPressed: (controller.isLoading || !controller.isButtonActive) 
                        ? null 
                        : controller.login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: controller.isButtonActive 
                          ? const Color(0xFF6B73FF) 
                          : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade500,
                    ),
                    child: controller.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            '로그인',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
