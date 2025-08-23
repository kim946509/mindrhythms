import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../feature/db.dart';
import '../feature/api.dart';
import '../feature/notification_register.dart';
import 'package:intl/intl.dart';
import '../page/survey_detail_page.dart'; // Added import for SurveyDetailPage

class HomePageController extends GetxController {
  var surveys = <Map<String, dynamic>>[];
  var isLoading = true;
  String? userId;
  String userName = '';

  @override
  void onInit() {
    super.onInit();
    _loadSurveys();
  }

  Future<void> _loadSurveys() async {
    try {
      isLoading = true;
      update(); // GetBuilder 업데이트
      
      final userInfo = await DataBaseManager.getUserInfo();
      if (userInfo == null) {
        isLoading = false;
        update(); // GetBuilder 업데이트
        return;
      }
      userId = userInfo['user_id'] as String;
      userName = userInfo['user_name'] as String? ?? '';

      // survey 테이블에서 설문 정보 조회
      final db = await DataBaseManager.database;
      final surveyList = await db.query('survey');
      
      if (surveyList.isNotEmpty) {
        surveys = surveyList;
      } else {
        // 기본 설문 정보 (테스트용)
        surveys = [
          {
            'id': 1,
            'survey_name': '우울증 진단',
            'survey_description': '일상적인 우울감과 우울증을 구분하여 진단합니다.',
          },
          {
            'id': 2,
            'survey_name': '불안증 진단',
            'survey_description': '불안 수준을 평가하고 적절한 대처 방법을 제시합니다.',
          },
          {
            'id': 3,
            'survey_name': '스트레스 진단',
            'survey_description': '현재 스트레스 수준을 파악하고 관리 방안을 제시합니다.',
          },
        ];
      }

    } catch (e) {
      debugPrint('설문 로드 오류: $e');
      // 오류 발생 시 기본값 설정
      surveys = [
        {
          'id': 1,
          'survey_name': '우울증 진단',
          'survey_description': '일상적인 우울감과 우울증을 구분하여 진단합니다.',
        },
      ];
    } finally {
      isLoading = false;
      update(); // GetBuilder 업데이트
    }
  }

  // 백그라운드에서 서버 데이터 동기화 (UI 표시 없음)
  Future<void> _syncDataInBackground() async {
    try {
      if (userId == null) return;
      
      debugPrint('백그라운드 데이터 동기화 시작...');
      
      // 1. API 호출하여 최신 데이터 가져오기
      final response = await ApiService.login(userId!);
      
      if (response.success && response.data != null) {
        // 2. 사용자 정보 업데이트
        final userName = response.data!['login']?['name'] as String? ?? '';
        await DataBaseManager.saveUserInfo(userId: userId!, userName: userName);
        
        // 3. 설문 데이터 동기화
        await DataBaseManager.saveSurveyDataFromApi(userId!, response.data!);
        
        // 4. 알림 재스케줄링
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
          
          // 알림 재스케줄링
          await NotificationService.scheduleSurveyNotifications(
            userId: userId!,
            surveyId: surveyId,
            startDate: startDate,
            endDate: endDate,
            notificationTimes: times,
          );
        }
        
        debugPrint('백그라운드 데이터 동기화 완료');
        
        // 5. 설문 목록 새로고침
        await _loadSurveys();
      }
    } catch (e) {
      debugPrint('백그라운드 데이터 동기화 오류: $e');
      // 오류가 발생해도 UI에는 표시하지 않음
    }
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(HomePageController());
    
    return GetBuilder<HomePageController>(
      builder: (controller) => Scaffold(
        appBar: AppBar(
          title: const Text('마음리듬'),
          
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            // 백그라운드에서 서버 데이터 동기화
            await controller._syncDataInBackground();
          },
          child: controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : controller.surveys.isEmpty
                  ? const Center(child: Text('설문이 없습니다.'))
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          
                          
                          const SizedBox(height: 24),
                          
                          // 설문 목록 설명
                          Row(
                            children: [
                              Icon(
                                Icons.quiz,
                                color: Colors.orange.shade600,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${controller.userName.isNotEmpty ? controller.userName : controller.userId ?? '사용자'}님, 진단 설문 목록',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '아래 설문을 터치하여 시작하세요',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // 설문 목록
                          ...controller.surveys.asMap().entries.map((entry) {
                            final index = entry.key;
                            final survey = entry.value;
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16.0),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Get.to(() => SurveyDetailPage(
                                    surveyId: survey['id'] ?? 1,
                                    surveyName: survey['survey_name'] ?? '설문 ${index + 1}',
                                    surveyDescription: survey['survey_description'] ?? '설문 설명이 없습니다.',
                                  ));
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  survey['survey_name'] ?? '설문 ${index + 1}',
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  survey['survey_description'] ?? '설문 설명이 없습니다.',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey,
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade100,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Icon(
                                              Icons.arrow_forward_ios,
                                              color: Colors.blue.shade600,
                                              size: 20,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '터치하여 시작',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          
                          // 하단 여백
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}
