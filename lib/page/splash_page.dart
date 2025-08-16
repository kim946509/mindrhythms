import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mindrhythms/core/view_controller.dart';
import 'package:mindrhythms/feature/service/splash_service.dart';

class SplashController extends ViewController {
  // 스플래시 관련 데이터
  String appName = '마음리듬';
  String subtitle = '당신의 마음을 듣다';
  String loadingMessage = '마음리듬을 시작합니다...';
  bool isLoading = true;
  
  // 진행 상황 관련
  int currentStep = 0;
  int totalSteps = 3;

  @override
  Future<void> init() async {
    // 화면이 뜨기 전 데이터 준비
    isLoading = true;
    currentStep = 0;
    loadingMessage = '마음리듬을 시작합니다...';
    update();

    // SimpleSplashService를 통한 3단계 초기화
    final initResult = await SplashService.initializeApp( 
      onProgress: (message, step, total) {
        print('💡 Progress Update: Step $step/$total - $message');
        loadingMessage = message;
        currentStep = step;
        totalSteps = total;
        update();
      },
    );

        // 초기화 결과를 컨트롤러 변수에 저장
    final permissionData = initResult['permission'] as Map<String, dynamic>;
    final userData = initResult['user'] as Map<String, dynamic>;
    final loginStatus = initResult['loginStatus'] as Map<String, dynamic>;

    // Context에 데이터 저장
    setContextData('permission', permissionData);
    setContextData('user', userData);
    setContextData('loginStatus', loginStatus);
  }

  @override
  Future<void> execute() async {
    // 화면 표시 후 실행할 작업
    print('🎯 Execute started - determining next route');
    
    // 마지막 완료 메시지를 2초 보여줌
    await Future.delayed(const Duration(seconds: 2));
    
    // 이제 로딩 완료
    isLoading = false;
    update();
    
    // 1초 더 대기
    await Future.delayed(const Duration(seconds: 1));
    
    // 초기화 결과 출력
    final permissionData = getContextData<Map>('permission') ?? {};
    final userData = getContextData<Map>('user') ?? {};
    final loginStatus = getContextData<Map>('loginStatus') ?? {};
    
    SplashService.printInitializationResult(
      permissionData: permissionData as Map<String, dynamic>,
      userData: userData as Map<String, dynamic>,
      loginStatus: loginStatus as Map<String, dynamic>,
    );
    
    // 로그인 상태에 따라 라우팅
    final nextRoute = loginStatus['nextRoute'] ?? '/login';
    print('🚀 다음 화면으로 이동: $nextRoute');
    
    // TODO: 실제 라우팅 구현
    // Get.offNamed(nextRoute);
    
    // 임시: 콘솔에만 출력
    if (loginStatus['shouldAutoLogin'] == true) {
      print('✅ 자동 로그인 - 홈 화면으로 이동');
    } else {
      print('🔐 로그인 필요 - 로그인 화면으로 이동');
    }
  }
}

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GetBuilder<SplashController>(
        init: SplashController(),
        builder: (controller) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                
                // 진행 메시지
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey(controller.loadingMessage),
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      controller.loadingMessage,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // 진행상태바
                Container(
                  width: MediaQuery.of(context).size.width * 0.7,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width: (MediaQuery.of(context).size.width * 0.7) * 
                           (controller.currentStep / controller.totalSteps),
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B73FF),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 진행률 텍스트
                Text(
                  '${controller.currentStep}/${controller.totalSteps}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                
                const Spacer(flex: 3),
              ],
            ),
          );
        },
      ),
    );
  }
}
