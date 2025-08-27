import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../feature/db.dart';
import '../widget/common_large_button.dart';
import '../page/survey_page.dart';

class SurveyDetailPageController extends GetxController {
  // ===== 상태 변수 =====
  var surveyStatuses = <Map<String, dynamic>>[];
  var isLoading = true;
  var currentTime = DateTime.now();

  // ===== 생성자 매개변수 =====
  final int surveyId;
  final String surveyName;
  final String surveyDescription;

  SurveyDetailPageController({
    required this.surveyId,
    required this.surveyName,
    required this.surveyDescription,
  });

  // ===== 초기화 =====
  @override
  void onInit() {
    super.onInit();
    _loadSurveyStatus();
    _startPeriodicUpdate();
  }

  @override
  void onClose() {
    _stopPeriodicUpdate();
    super.onClose();
  }

  // ===== 주기적 업데이트 관리 =====
  Timer? _updateTimer;

  /// 주기적 업데이트 시작
  void _startPeriodicUpdate() {
    _updateTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _updateSurveyStatusInRealTime();
    });
  }

  /// 주기적 업데이트 중지
  void _stopPeriodicUpdate() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  // ===== 설문 상태 관리 =====

  /// 설문 상태 새로고침 (Pull to Refresh용)
  Future<void> refreshSurveyStatus() async {
    try {
      debugPrint('🔄 설문 상태 새로고침 시작...');
      debugPrint(
          '🔄 새로고침 전 현재 시간: ${DateFormat('HH:mm:ss').format(currentTime)}');

      // 현재 시간 업데이트
      currentTime = DateTime.now();
      debugPrint(
          '🔄 새로고침 후 현재 시간: ${DateFormat('HH:mm:ss').format(currentTime)}');

      // 설문 상태 다시 로드
      await _loadSurveyStatus();
      debugPrint('🔄 설문 상태 로드 완료');

      // 실시간 상태 재계산
      await _updateSurveyStatusInRealTime();
      debugPrint('🔄 실시간 상태 재계산 완료');

      // UI 업데이트
      update();
      debugPrint('✅ 설문 상태 새로고침 완료');
    } catch (e) {
      debugPrint('❌ 설문 상태 새로고침 오류: $e');
      debugPrint('❌ 오류 상세: ${e.toString()}');
    }
  }

  /// 실시간으로 설문 상태를 업데이트하는 메서드
  Future<void> _updateSurveyStatusInRealTime() async {
    try {
      debugPrint('🔄 실시간 상태 업데이트 시작...');
      debugPrint('🔄 현재 시간: ${DateFormat('HH:mm:ss').format(currentTime)}');

      // 새로운 상태 리스트 생성
      final updatedStatuses = <Map<String, dynamic>>[];

      // 현재 시간 기준으로 각 시간대의 상태를 재계산
      for (final status in surveyStatuses) {
        final time = status['time'] as String;

        // 현재 시간 기준으로 설문 가능 여부 재계산
        final canTake = canTakeSurvey(time);

        // 새로운 상태 맵 생성
        final updatedStatus = <String, dynamic>{
          ...status,
          'canTake': canTake,
        };

        updatedStatuses.add(updatedStatus);

        // 상태가 변경되었는지 확인하고 로그 출력
        if (status['canTake'] != canTake) {
          debugPrint(
              '🔄 시간대 $time 상태 변경: canTake ${status['canTake']} → $canTake');
        }
      }

      // 전체 리스트 교체
      surveyStatuses = updatedStatuses;
      debugPrint('✅ 실시간 상태 업데이트 완료: ${updatedStatuses.length}개 시간대');
    } catch (e) {
      debugPrint('❌ 실시간 상태 업데이트 오류: $e');
      debugPrint('❌ 오류 상세: ${e.toString()}');
    }
  }

  /// 설문 상태 로드
  Future<void> _loadSurveyStatus() async {
    try {
      isLoading = true;
      update();

      final userInfo = await DataBaseManager.getUserInfo();
      if (userInfo == null) {
        debugPrint('❌ 사용자 정보를 찾을 수 없습니다.');
        return;
      }

      final userId = userInfo['user_id'] as String;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      debugPrint('🔍 설문 상태 조회 시작...');
      debugPrint('🔍 사용자 ID: $userId, 설문 ID: $surveyId, 조회 날짜: $today');

      final db = await DataBaseManager.database;

      // 특정 조건으로 조회
      final statuses = await db.query(
        'survey_status',
        where: 'survey_id = ? AND user_id = ? AND survey_date = ?',
        whereArgs: [surveyId, userId, today],
        orderBy: 'time ASC',
      );

      // survey_page 테이블에서 해당 설문의 실제 시간대 조회
      final surveyPages = await db.rawQuery('''
        SELECT DISTINCT time 
        FROM survey_page 
        WHERE survey_id = ? 
        ORDER BY time ASC
      ''', [surveyId]);

      // 시간대 리스트 생성
      List<String> defaultTimes;
      if (surveyPages.isNotEmpty) {
        defaultTimes =
            surveyPages.map((page) => page['time'] as String).toList();
      } else {
        defaultTimes = ['09:00', '12:00', '15:00', '18:00', '21:00'];
      }

      // 각 시간대별로 상태 처리
      surveyStatuses = defaultTimes.map((time) {
        // DB에서 해당 시간대의 상태 찾기
        final existingStatus = statuses.firstWhere(
          (status) => status['time'] == time,
          orElse: () => {
            'time': time,
            'submitted': 0,
            'submitted_at': null,
          },
        );

        // 현재 시간 기준으로 설문 가능 여부 추가
        return {
          ...existingStatus,
          'canTake': canTakeSurvey(time),
        };
      }).toList();

      debugPrint('📊 설문 상태 로드 완료: ${surveyStatuses.length}개 시간대');

      // 새로운 시간대가 있다면 DB에 추가
      if (statuses.isEmpty) {
        await _createDefaultSurveyStatusRecords(defaultTimes, userId, today);
      }
    } catch (e) {
      debugPrint('❌ 설문 상태 조회 오류: $e');
    } finally {
      isLoading = false;
      update();
    }
  }

  /// 기본 설문 상태 데이터 생성
  Future<void> _createDefaultSurveyStatusData(
      String userId, String dateString) async {
    try {
      final db = await DataBaseManager.database;

      // survey_page 테이블에서 해당 설문의 실제 시간대 조회
      final surveyPages = await db.rawQuery('''
        SELECT DISTINCT time 
        FROM survey_page 
        WHERE survey_id = ? 
        ORDER BY time ASC
      ''', [surveyId]);

      List<String> times;
      if (surveyPages.isNotEmpty) {
        // 실제 설문 시간대 사용
        times = surveyPages.map((page) => page['time'] as String).toList();
        debugPrint('🔍 설문 시간대 조회 결과: $times');
      } else {
        // 기본 시간대 사용
        times = ['09:00', '12:00', '15:00', '18:00', '21:00'];
        debugPrint('📋 기본 시간대 사용: $times');
      }

      // 기본 상태 데이터 생성
      final defaultStatuses = times
          .map((time) => <String, dynamic>{
                'time': time,
                'submitted': 0,
                'submitted_at': null,
                'canTake': canTakeSurvey(time),
              })
          .toList();

      surveyStatuses = defaultStatuses;

      // 데이터베이스에 기본 레코드 생성
      await _createDefaultSurveyStatusRecords(times, userId, dateString);
    } catch (e) {
      debugPrint('❌ 기본 설문 상태 데이터 생성 오류: $e');
    }
  }

  // ===== 설문 시간 유효성 검사 =====

  /// 특정 시간의 설문이 가능한지 확인
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
      // 예: 9시 설문이면 9:00 ~ 10:00까지만 가능
      final startTime = surveyTime;
      final endTime = surveyTime.add(const Duration(hours: 1));

      final canTake =
          now.isAfter(startTime.subtract(const Duration(seconds: 1))) &&
              now.isBefore(endTime);

      debugPrint('🕐 시간대 $timeStr 설문 가능 여부: $canTake');
      debugPrint('   현재 시간: ${DateFormat('HH:mm:ss').format(now)}');
      debugPrint('   설문 시작: ${DateFormat('HH:mm:ss').format(startTime)}');
      debugPrint('   설문 종료: ${DateFormat('HH:mm:ss').format(endTime)}');

      return canTake;
    } catch (e) {
      debugPrint('❌ canTakeSurvey 오류: $e');
      return false;
    }
  }

  // ===== 설문 시작 관련 =====

  /// 설문 시작
  void startSurvey(String time) {
    if (canTakeSurvey(time)) {
      debugPrint(
          '🚀 설문 시작: surveyId=$surveyId, surveyName=$surveyName, time=$time');
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

  /// 현재 설문을 시작할 수 있는지 확인
  bool canStartSurvey() {
    return hasAvailableSurveyTime();
  }

  /// 이미 응답한 설문이 있는지 확인 (전체 설문 완료 여부)
  bool hasSubmittedSurvey() {
    // 모든 시간대에 대해 응답했는지 확인
    return surveyStatuses.every((status) => status['submitted'] == 1);
  }

  /// 특정 시간대에 이미 응답했는지 확인
  bool hasSubmittedSurveyAtTime(String time) {
    final status = surveyStatuses.firstWhere(
      (status) => status['time'] == time,
      orElse: () => <String, dynamic>{},
    );
    return status['submitted'] == 1;
  }

  /// 현재 응답 가능한 시간대가 있는지 확인
  bool hasAvailableSurveyTime() {
    debugPrint('🔍 응답 가능한 시간대 확인 시작...');
    debugPrint('🔍 현재 시간: ${DateFormat('HH:mm:ss').format(currentTime)}');

    for (final status in surveyStatuses) {
      final time = status['time'] as String;
      final submitted = status['submitted'] as int;
      final canTake = canTakeSurvey(time);

      debugPrint('🔍 시간대 $time: submitted=$submitted, canTake=$canTake');

      // 현재 시간이 설문 가능한 시간대이고, 아직 응답하지 않은 경우
      if (canTake && submitted == 0) {
        debugPrint('✅ 시간대 $time에서 응답 가능한 설문 발견!');
        return true;
      }
    }

    debugPrint('❌ 응답 가능한 시간대가 없습니다.');
    return false;
  }

  // ===== 버튼 텍스트 및 상태 =====

  /// 설문 시작 버튼 텍스트
  String getStartButtonText() {
    // 현재 응답 가능한 시간대가 있는지 확인
    if (hasAvailableSurveyTime()) {
      final availableTime = surveyStatuses.where((status) {
        final time = status['time'] as String;
        final submitted = status['submitted'] as int;
        final canTake = canTakeSurvey(time);
        return canTake && submitted == 0;
      }).firstOrNull;

      if (availableTime != null) {
        final time = availableTime['time'] as String;
        debugPrint('🎯 현재 응답 가능한 시간대: $time');
        return '$time 검사 시작';
      }
      return '검사 시작';
    } else {
      // 모든 설문을 완료했는지 확인
      if (hasSubmittedSurvey()) {
        return '오늘 설문 완료';
      }

      // 현재 시간 이후의 설문 시간들 찾기
      final futureSurveyTimes = surveyStatuses
          .where((status) {
            final time = status['time'] as String;
            final submitted = status['submitted'] as int;
            final surveyTime = _parseTimeToDateTime(time);
            final now = currentTime;

            // 아직 응답하지 않았고, 현재 시간 이후의 설문
            return submitted == 0 && surveyTime.isAfter(now);
          })
          .map((status) => status['time'] as String)
          .toList();

      if (futureSurveyTimes.isEmpty) {
        return '내일 설문';
      }

      // 가장 가까운 다음 설문 시간 찾기
      final nextSurveyTime = futureSurveyTimes
          .map((time) => _parseTimeToDateTime(time))
          .reduce((a, b) => a.isBefore(b) ? a : b);

      final timeStr = DateFormat('HH:mm').format(nextSurveyTime);
      return '다음 설문: $timeStr';
    }
  }

  /// 시간 문자열을 DateTime으로 변환하는 헬퍼 메서드
  DateTime _parseTimeToDateTime(String timeStr) {
    final timeParts = timeStr.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    return DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
      hour,
      minute,
    );
  }

  /// 버튼 배경색 결정
  Color getButtonBackgroundColor() {
    if (hasAvailableSurveyTime()) {
      return const Color(0xFF4CAF50); // 초록색 (활성화)
    }
    return const Color(0xFF9E9E9E); // 회색 (비활성화)
  }

  /// 버튼 비활성화 여부
  bool isButtonDisabled() {
    return !hasAvailableSurveyTime();
  }

  // ===== 데이터베이스 관리 =====

  /// survey_status 테이블에 기본 레코드 생성
  Future<void> _createDefaultSurveyStatusRecords(
      List<String> times, String userId, String dateString) async {
    try {
      final db = await DataBaseManager.database;

      for (final time in times) {
        final existingRecords = await db.query(
          'survey_status',
          where:
              'survey_id = ? AND user_id = ? AND survey_date = ? AND time = ?',
          whereArgs: [surveyId, userId, dateString, time],
        );

        if (existingRecords.isEmpty) {
          final result = await db.insert(
            'survey_status',
            {
              'survey_id': surveyId,
              'user_id': userId,
              'survey_date': dateString,
              'time': time,
              'submitted': 0,
              'submitted_at': null,
            },
          );

          if (result > 0) {
            debugPrint('✅ 시간대 $time 기본 레코드 생성 성공: ID=$result');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ 기본 레코드 생성 오류: $e');
    }
  }
}

// ===== UI 위젯 =====
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
          onRefresh: () => controller.refreshSurveyStatus(),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSurveyInfo(),
                        const SizedBox(height: 24),
                        _buildSurveyStatusTable(controller),
                        const SizedBox(height: 24),
                        _buildStartButton(controller),
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

  /// 설문 정보 섹션
  Widget _buildSurveyInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }

  /// 설문 현황 테이블
  Widget _buildSurveyStatusTable(SurveyDetailPageController controller) {
    return Container(
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
                  flex: 1,
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
                  flex: 1,
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
          ...controller.surveyStatuses
              .map((status) => _buildStatusRow(controller, status)),
        ],
      ),
    );
  }

  /// 상태 행 위젯
  Widget _buildStatusRow(
      SurveyDetailPageController controller, Map<String, dynamic> status) {
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
            flex: 1,
            child: Text(
              time,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Expanded(
            flex: 1,
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
                    Icons.close,
                    color: Colors.grey.shade500,
                    size: 24,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 설문 시작 버튼
  Widget _buildStartButton(SurveyDetailPageController controller) {
    return SizedBox(
      width: double.infinity,
      child: CommonLargeButton(
        text: controller.getStartButtonText(),
        onPressed: controller.isButtonDisabled()
            ? null
            : () {
                final availableTime = controller.surveyStatuses.where((status) {
                  final time = status['time'] as String;
                  final submitted = status['submitted'] as int;
                  final canTake = controller.canTakeSurvey(time);
                  return canTake && submitted == 0;
                }).firstOrNull;

                if (availableTime != null) {
                  controller.startSurvey(availableTime['time']);
                }
              },
        backgroundColor: controller.getButtonBackgroundColor(),
        textColor: Colors.white,
      ),
    );
  }
}
