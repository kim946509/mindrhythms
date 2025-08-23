import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../feature/db.dart';
import '../widget/common_large_button.dart';
import '../page/survey_page.dart';

class SurveyDetailPageController extends GetxController {
  var surveyStatuses = <Map<String, dynamic>>[];
  var isLoading = true;
  var currentTime = DateTime.now();
  
  final int surveyId;
  final String surveyName;
  final String surveyDescription;
  
  SurveyDetailPageController({
    required this.surveyId,
    required this.surveyName,
    required this.surveyDescription,
  });

  @override
  void onInit() {
    super.onInit();
    _loadSurveyStatus();
    // 10초마다 현재 시간 업데이트 (더 빠른 반응을 위해)
    Timer.periodic(const Duration(seconds: 10), (_) {
      currentTime = DateTime.now();
      update(); // GetBuilder 업데이트
    });
  }

  Future<void> _loadSurveyStatus() async {
    try {
      isLoading = true;
      update(); // GetBuilder 업데이트
      
      final userInfo = await DataBaseManager.getUserInfo();
      if (userInfo == null) {
        isLoading = false;
        update(); // GetBuilder 업데이트
        return;
      }
      
      final userId = userInfo['user_id'] as String;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // survey_status 테이블에서 해당 설문의 상태 조회
      final db = await DataBaseManager.database;
      final statuses = await db.query(
        'survey_status',
        where: 'survey_id = ? AND user_id = ? AND survey_date = ?',
        whereArgs: [surveyId, userId, today],
        orderBy: 'time ASC',
      );
      
      if (statuses.isNotEmpty) {
        surveyStatuses = statuses;
      } else {
        // 기본 시간대 설정 (09:00, 12:00, 15:00, 18:00, 21:00)
        final defaultTimes = ['09:00', '12:00', '15:00', '18:00', '21:00'];
        final defaultStatuses = defaultTimes.map((time) => {
          'time': time,
          'submitted': 0,
          'submitted_at': null,
        }).toList();
        
        surveyStatuses = defaultStatuses;
      }
      
    } catch (e) {
      debugPrint('설문 상태 조회 오류: $e');
    } finally {
      isLoading = false;
      update(); // GetBuilder 업데이트
    }
  }

  // 특정 시간의 설문이 가능한지 확인
  bool canTakeSurvey(String timeStr) {
    try {
      final timeParts = timeStr.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      final surveyTime = DateTime(
        currentTime.year,
        currentTime.month,
        currentTime.day,
        hour,
        minute,
      );
      
      final now = currentTime;
      
      // 설문 시간부터 정확히 1시간까지만 가능
      // 예: 21:00 설문이면 21:00 ~ 22:00까지만 가능
      final startTime = surveyTime;
      final endTime = surveyTime.add(const Duration(hours: 1));
      
      return now.isAfter(startTime.subtract(const Duration(seconds: 1))) && 
             now.isBefore(endTime);
    } catch (e) {
      return false;
    }
  }

  // 설문 시작
  void startSurvey(String time) {
    if (canTakeSurvey(time)) {
      debugPrint('설문 시작: surveyId=$surveyId, surveyName=$surveyName, time=$time');
      // SurveyPage로 이동
      Get.to(() => SurveyPage(
        surveyId: surveyId,
        surveyName: surveyName,
        time: time,
      ));
    } else {
      Get.snackbar(
        '설문 불가',
        '$time 설문은 현재 시간으로부터 ±1시간 이내에만 가능합니다.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
      );
    }
  }

  // 현재 설문을 시작할 수 있는지 확인
  bool canStartSurvey() {
    return surveyStatuses.any((status) => 
        status['submitted'] != 1 && 
        canTakeSurvey(status['time']));
  }

  // 설문 시작 버튼 텍스트
  String getStartButtonText() {
    if (canStartSurvey()) {
      // 가능한 시간 중 첫 번째 시간 표시
      final availableTime = surveyStatuses
          .where((status) => 
              status['submitted'] != 1 && 
              canTakeSurvey(status['time']))
          .firstOrNull;
      
      if (availableTime != null) {
        return '${availableTime['time']} 검사 시작';
      }
      return '검사 시작';
    } else {
      // 현재 시간과 가장 가까운 다음 설문 시간 표시
      final futureSurveyTimes = surveyStatuses
          .where((status) => status['submitted'] != 1)
          .map((status) => status['time'] as String)
          .toList();
      
      if (futureSurveyTimes.isEmpty) {
        return '설문 없음';
      }
      
      // 현재 시간 이후의 설문 시간들 찾기
      final futureTimes = futureSurveyTimes
          .map((time) {
            final timeParts = time.split(':');
            final hour = int.parse(timeParts[0]);
            final minute = int.parse(timeParts[1]);
            return DateTime(
              currentTime.year,
              currentTime.month,
              currentTime.day,
              hour,
              minute,
            );
          })
          .where((surveyTime) => surveyTime.isAfter(currentTime))
          .toList();
      
      if (futureTimes.isEmpty) {
        // 모든 설문 시간이 지났다면 내일 첫 번째 설문 시간 표시
        final firstTime = futureSurveyTimes.first;
        return '내일 $firstTime';
      }
      
      // 가장 가까운 다음 설문 시간 찾기
      final nextSurveyTime = futureTimes.reduce((a, b) => a.isBefore(b) ? a : b);
      final timeStr = DateFormat('HH:mm').format(nextSurveyTime);
      return '다음 설문: $timeStr';
    }
  }
}

class SurveyDetailPage extends StatelessWidget {
  final int surveyId;
  final String surveyName;
  final String surveyDescription;

  const SurveyDetailPage({
    super.key,
    required this.surveyId,
    required this.surveyName,
    required this.surveyDescription,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SurveyDetailPageController>(
      init: SurveyDetailPageController(
        surveyId: surveyId,
        surveyName: surveyName,
        surveyDescription: surveyDescription,
      ),
      builder: (controller) => Scaffold(
        appBar: AppBar(
          title: Text(surveyName),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Get.back(),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            // 설문 상태 새로고침
            await controller._loadSurveyStatus();
            // 현재 시간도 새로고침
            controller.currentTime = DateTime.now();
            controller.update();
          },
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(), // 항상 스크롤 가능하도록
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 설문 정보
                        Text(
                          surveyName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          surveyDescription,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          DateFormat('yyyy.MM.dd').format(DateTime.now()),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // 설문 현황 테이블
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              // 테이블 헤더
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(8),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 1, // 1:1 비율로 변경
                                      child: Text(
                                        '설문 시간',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1, // 1:1 비율로 변경
                                      child: Text(
                                        '설문 여부',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // 테이블 내용
                              ...controller.surveyStatuses.map((status) {
                                final time = status['time'] as String;
                                final isSubmitted = status['submitted'] == 1;
                                final canTake = controller.canTakeSurvey(time);
                                
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(color: Colors.grey.shade200),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 1, // 1:1 비율로 변경
                                        child: Text(
                                          time,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1, // 1:1 비율로 변경
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            if (isSubmitted)
                                              const Icon(
                                                Icons.check_circle,
                                                color: Colors.green,
                                                size: 24,
                                              )
                                            else if (canTake)
                                              const Icon(
                                                Icons.access_time,
                                                color: Colors.orange,
                                                size: 24,
                                              )
                                            else
                                              Icon(
                                                Icons.close, // 동그라미 X에서 일반 X로 변경
                                                color: Colors.grey.shade500,
                                                size: 24,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // 설문 시작 버튼
                        SizedBox(
                          width: double.infinity,
                          child: CommonLargeButton(
                            text: controller.getStartButtonText(),
                            onPressed: controller.canStartSurvey() ? () {
                              // 현재 가능한 시간 찾기
                              final availableTime = controller.surveyStatuses
                                  .where((status) => 
                                      status['submitted'] != 1 && 
                                      controller.canTakeSurvey(status['time']))
                                  .firstOrNull;
                              
                              if (availableTime != null) {
                                controller.startSurvey(availableTime['time']);
                              }
                            } : null,
                            backgroundColor: controller.canStartSurvey() 
                                ? const Color(0xFF4CAF50)  // 초록색 (활성화)
                                : const Color(0xFF9E9E9E), // 회색 (비활성화)
                            textColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
