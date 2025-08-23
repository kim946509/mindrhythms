import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../feature/api.dart';
import '../feature/db.dart';
import '../service/notification_service.dart';
import 'home_page.dart';
import 'login_page.dart';

class UserInfoPage extends StatelessWidget {
  final String userId;

  const UserInfoPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    // 컨트롤러 초기화 (userId 전달)
    Get.put(UserInfoController(userId: userId));
    
    return Scaffold(
      body: SafeArea(
        child: GetBuilder<UserInfoController>(
          builder: (controller) => Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Stack(
              children: [
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          controller.loadingMessage,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        LinearProgressIndicator(
                          value: controller.progressValue,
                          backgroundColor: Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6B73FF)),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 40,
                  child: Center(
                    child: Text(
                      '마음리듬과 함께 하루를 기록해보세요',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
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

class UserInfoController extends GetxController {
  final String userId;
  UserInfoController({required this.userId});

  String loadingMessage = '사용자 정보를 확인 중입니다...';
  double progressValue = 0.1;
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    _loadUserInfo();
  }

  @override
  void onClose() {
    _timer?.cancel();
    _animationTimer?.cancel();
    super.onClose();
  }

  Future<void> _loadUserInfo() async {
    try {
      // 1. 초기 메시지
      _updateProgress('로그인 시도 중입니다.', 0.1);
      await Future.delayed(const Duration(milliseconds: 300));

      // 2. API 호출
      _updateProgress('서버에 로그인 정보 전송 중...', 0.2);
      await Future.delayed(const Duration(milliseconds: 300));
      
      final response = await ApiService.login(userId);
      _updateProgress('서버 응답 확인 중...', 0.3);
      await Future.delayed(const Duration(milliseconds: 300));

      if (response.success && response.data != null) {
        try {
          // 로그인 성공 처리
          _updateProgress('로그인 성공! 사용자 정보 저장 중...', 0.4);
          await Future.delayed(const Duration(milliseconds: 300));

          // 3. 사용자 정보 저장 (API 응답에서 이름 가져오기)
          final userName = response.data!['login']?['name'] as String? ?? '';
          await DataBaseManager.saveUserInfo(userId: userId, userName: userName);
          _updateProgress('사용자 정보 저장 완료', 0.5);
          await Future.delayed(const Duration(milliseconds: 300));

          // 4. API 응답 데이터 처리 시작
          _updateProgress('설문 정보 분석 중...', 0.6);
          await Future.delayed(const Duration(milliseconds: 300));
          
          // 5. 데이터 비교 및 저장 진행
          _updateProgress('설문 정보 비교 중...', 0.7);
          await Future.delayed(const Duration(milliseconds: 300));
          
          // 6. API 응답 데이터를 정규화하여 DB에 저장
          _updateProgress('변경된 설문 정보 업데이트 중...', 0.8);
          final stopwatch = Stopwatch()..start();
          await DataBaseManager.saveSurveyDataFromApi(userId, response.data!);
          stopwatch.stop();
          
          // 7. 데이터 저장 완료 및 결과 표시
          if (stopwatch.elapsedMilliseconds < 500) {
            await Future.delayed(Duration(milliseconds: 500 - stopwatch.elapsedMilliseconds));
          }
          
          // 8. 알림 권한 요청
          _updateProgress('알림 권한 확인 중...', 0.85);
          await NotificationService.requestPermission();
          
          // 9. 설문 정보 기반으로 알림 스케줄링
          _updateProgress('알림 일정 설정 중...', 0.9);
          
          // 설문 정보 조회
          final surveys = await DataBaseManager.database.then((db) => 
            db.query('survey', orderBy: 'id DESC', limit: 1));
          
          if (surveys.isNotEmpty) {
            final survey = surveys.first;
            final surveyId = survey['id'] as int;
            final startDate = survey['start_date'] as String;
            final endDate = survey['end_date'] as String;
            
            // 알림 시간 조회
            final notificationTimes = await DataBaseManager.database.then((db) => 
              db.query('survey_notification_times', 
                where: 'survey_id = ?', 
                whereArgs: [surveyId]
              ));
            
            final times = notificationTimes.map((t) => t['time'] as String).toList();
            
            // 알림 스케줄링
            await NotificationService.scheduleSurveyNotifications(
              userId: userId,
              surveyId: surveyId,
              startDate: startDate,
              endDate: endDate,
              notificationTimes: times,
            );
          }
          
          final message = '설문 정보 업데이트 완료';
          _updateProgress(message, 0.95);
          await Future.delayed(const Duration(milliseconds: 300));
          
          // 8. 모든 DB 데이터 로그 출력 (디버깅용)
          if (DataBaseManager.enableDebugLogs) {
            await DataBaseManager.logAllData();
          }
        } catch (e) {
          debugPrint('데이터 저장 중 오류 발생: $e');
          _updateProgress('데이터 저장 중 오류가 발생했습니다. 계속 진행합니다...', 0.8);
          await Future.delayed(const Duration(milliseconds: 500));
          // 오류가 발생해도 계속 진행
        }

        _updateProgress('설정 완료! 홈 화면으로 이동합니다.', 1.0);
        await Future.delayed(const Duration(milliseconds: 500));

        Get.offAll(() => const HomePage());
      } else {
        // 로그인 실패 처리
        _updateProgress('로그인 실패: 사용자 정보를 확인해주세요.', 0.0);
        await Future.delayed(const Duration(seconds: 2));
        Get.offAll(() => LoginPage(userId: userId));
      }
    } catch (e) {
      // 오류 처리
      _updateProgress('오류 발생: $e', 0.0);
      debugPrint('사용자 정보 로드 중 오류: $e');
      await Future.delayed(const Duration(seconds: 2));
      Get.offAll(() => LoginPage(userId: userId));
    }
  }

  // 로딩 애니메이션을 위한 타이머
  Timer? _animationTimer;
  int _dotCount = 0;
  
  void _updateProgress(String message, double value) {
    // 애니메이션 타이머가 이미 실행 중이면 취소
    _animationTimer?.cancel();
    
    // 기본 메시지 설정 (점 없는 상태)
    String baseMessage = message.replaceAll('...', '');
    loadingMessage = baseMessage;
    progressValue = value;
    update();
    
    // 애니메이션 타이머 시작 (점을 추가하는 애니메이션)
    _dotCount = 0;
    _animationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _dotCount = (_dotCount + 1) % 4;
      String dots = '.' * _dotCount;
      loadingMessage = baseMessage + dots;
      update();
    });
  }
}
