import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../feature/db.dart';
import 'package:intl/intl.dart';

class HomePageController extends GetxController {
  var surveys = <Map<String, dynamic>>[].obs;
  var isLoading = true.obs;
  String? userId;
  String userName = '';

  @override
  void onInit() {
    super.onInit();
    _loadSurveys();
  }

  Future<void> _loadSurveys() async {
    try {
      isLoading(true);
      
      final userInfo = await DataBaseManager.getUserInfo();
      if (userInfo == null) {
        isLoading(false);
        return;
      }
      userId = userInfo['user_id'] as String;
      userName = userInfo['user_name'] as String? ?? '';

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      try {
        final surveyStatuses = await DataBaseManager.getSurveyStatusByDate(
          userId: userId!,
          surveyDate: today,
        );

        final newSurveys = surveyStatuses.map((status) {
          return {
            'survey_time': status['time'] ?? '00:00',
            'is_submitted': status['submitted'] == 1,
          };
        }).toList();
        
        if (newSurveys.isEmpty) {
          // 기본 시간대 설정
          surveys.assignAll([
            {'survey_time': '09:00', 'is_submitted': false},
            {'survey_time': '13:00', 'is_submitted': false},
            {'survey_time': '17:00', 'is_submitted': false},
            {'survey_time': '21:00', 'is_submitted': false},
          ]);
        } else {
          surveys.assignAll(newSurveys);
        }
      } catch (e) {
        debugPrint('설문 상태 조회 오류: $e');
        // 오류 발생 시 기본 시간대 설정
        surveys.assignAll([
          {'survey_time': '09:00', 'is_submitted': false},
          {'survey_time': '13:00', 'is_submitted': false},
          {'survey_time': '17:00', 'is_submitted': false},
          {'survey_time': '21:00', 'is_submitted': false},
        ]);
      }

    } catch (e) {
      debugPrint('설문 로드 오류: $e');
    } finally {
      isLoading(false);
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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: 설정 페이지로 이동
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 사용자 인사
            Text(
              '안녕하세요, ${controller.userName.isNotEmpty ? controller.userName : controller.userId}님',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '오늘의 마음 상태를 기록해 보세요',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            
            // 오늘의 설문 목록
            const Text(
              '오늘의 설문',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: controller.surveys.length,
                itemBuilder: (context, index) {
                  final survey = controller.surveys[index];
                  final isCompleted = survey['is_submitted'] as bool;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Icon(
                        isCompleted ? Icons.check_circle : Icons.access_time,
                        color: isCompleted ? Colors.green : Colors.orange,
                      ),
                      title: Text(survey['survey_time']),
                      subtitle: Text(
                        isCompleted ? '완료됨' : '진행 중',
                      ),
                      trailing: ElevatedButton(
                        onPressed: isCompleted ? null : () {
                          // TODO: 설문 페이지로 이동
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: Text(isCompleted ? '완료' : '시작'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
