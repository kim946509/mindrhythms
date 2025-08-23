import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'db.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  // 알림 채널 ID 및 이름
  static const String channelId = 'survey_notification_channel';
  static const String channelName = '설문조사 알림';
  static const String channelDescription = '설문조사 시간 알림을 위한 채널입니다.';

  // 알림 초기화
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // 타임존 초기화 (기기 로컬 타임존 사용)
    tz_data.initializeTimeZones();

    // Android 설정
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 설정
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    // 초기화 설정
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // 플러그인 초기화
    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // 알림 클릭 시 처리 (필요한 경우 구현)
        debugPrint('알림 클릭: ${response.payload}');
      },
    );

    _isInitialized = true;
    debugPrint('알림 서비스 초기화 완료');
  }

  // 안드로이드에서 가능한 스케줄 모드를 사전 결정
  static Future<AndroidScheduleMode> _getAndroidScheduleMode() async {
    if (!Platform.isAndroid) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    try {
      final android = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final canExact = await android?.canScheduleExactNotifications() ?? false;
      return canExact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
    } catch (e) {
      debugPrint('정확 알람 가능 여부 확인 실패, inexact 사용: $e');
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  // 알림 권한 요청
  static Future<bool> requestPermission() async {
    if (!_isInitialized) await initialize();
    
    bool allPermissionsGranted = true;
    
    // iOS 권한 요청
    if (Platform.isIOS) {
      final settings = await _notificationsPlugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      allPermissionsGranted = allPermissionsGranted && (settings ?? true);
    }
    
    // Android 백그라운드 알림 권한 확인
    if (Platform.isAndroid) {
      try {
        final android = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
        // 1. 기본 알림 권한 확인
        final areNotificationsEnabled = await android?.areNotificationsEnabled() ?? false;
        if (!areNotificationsEnabled) {
          debugPrint('기본 알림 권한이 비활성화되어 있습니다.');
          allPermissionsGranted = false;
        }
        
        // 2. 정확 알람 권한 확인 (Android 12+)
        final canExact = await android?.canScheduleExactNotifications() ?? false;
        if (!canExact) {
          debugPrint('정확 알람 권한이 없습니다. 백그라운드 알림이 부정확할 수 있습니다.');
          // Android 12+에서는 시스템 설정으로 이동해야 함
          await android?.requestExactAlarmsPermission();
        }
        
        // 3. 권한 상태 로그
        debugPrint('Android 권한 상태:');
        debugPrint('  - 기본 알림: ${areNotificationsEnabled ? "허용" : "차단"}');
        debugPrint('  - 정확 알람: ${canExact ? "허용" : "차단"}');
        
      } catch (e) {
        debugPrint('Android 권한 확인 중 오류: $e');
        allPermissionsGranted = false;
      }
    }
    
    return allPermissionsGranted;
  }



  // 설문 알림 스케줄링
  static Future<void> scheduleSurveyNotifications({
    required String userId,
    required int surveyId,
    required String startDate,
    required String endDate,
    required List<String> notificationTimes,
  }) async {
    if (!_isInitialized) await initialize();
    
    // 권한 확인 및 요청
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      debugPrint('알림 권한이 부족합니다. 백그라운드 알림이 작동하지 않을 수 있습니다.');
    }
    
    // 1. DB에서 기존 알림 정보 조회
    final db = await DataBaseManager.database;
    final existingNotifications = await db.query(
      'notification_schedule',
      where: 'survey_id = ? AND user_id = ?',
      whereArgs: [surveyId, userId],
    );
    
    debugPrint('=== 알림 상태 진단 ===');
    debugPrint('DB 조회 결과: ${existingNotifications.length}개');
    debugPrint('알림 권한 상태: ${hasPermission ? "허용됨" : "부족함"}');
    
    if (existingNotifications.isNotEmpty) {
      debugPrint('DB 첫 번째 항목: ${existingNotifications.first}');
    }
    
    // 2. 변경사항 확인 (DB와 새 요청 비교)
    bool hasChanges = _checkForChangesFromDB(
      existingNotifications, 
      startDate, 
      endDate, 
      notificationTimes
    );
    
    // 3. 변경사항이 없으면 스킵
    if (!hasChanges) {
      debugPrint('알림 스케줄 변경 없음 → 스킵');
      return;
    }
    
    // 4. 기존 알림 모두 삭제
    await _cancelAllSurveyNotifications(surveyId, userId);
    
    // 5. 새 알림 모두 등록
    await _registerAllNotifications(
      userId: userId,
      surveyId: surveyId,
      startDate: startDate,
      endDate: endDate,
      notificationTimes: notificationTimes,
    );
    
    // 6. DB 동기화
    await _syncNotificationDatabase(
      db, 
      surveyId, 
      userId, 
      startDate, 
      endDate, 
      notificationTimes
    );
    
    debugPrint('알림 스케줄링 완료: ${notificationTimes.length}개 시간 등록');
  }

  // DB 데이터와 비교하여 변경사항 확인
  static bool _checkForChangesFromDB(
    List<Map<String, dynamic>> existingNotifications,
    String newStartDate,
    String newEndDate,
    List<String> newTimes,
  ) {
    // 기존 알림이 없으면 변경사항 있음
    if (existingNotifications.isEmpty) {
      debugPrint('변경사항 감지: 기존 알림이 없음');
      return true;
    }
    
    // 시간 개수 비교
    final existingTimes = existingNotifications
        .map((n) => n['time'] as String)
        .toSet();
    final newTimesSet = newTimes.where((t) => t.isNotEmpty).toSet();
    
    debugPrint('=== 알림 비교 로그 ===');
    debugPrint('DB 시간: $existingTimes');
    debugPrint('새 요청 시간: $newTimesSet');
    debugPrint('DB 시작일: ${existingNotifications.first['start_date']}');
    debugPrint('DB 종료일: ${existingNotifications.first['end_date']}');
    debugPrint('새 시작일: $newStartDate');
    debugPrint('새 종료일: $newEndDate');
    
    // DB 데이터 상세 출력
    debugPrint('--- DB 데이터 상세 ---');
    for (int i = 0; i < existingNotifications.length; i++) {
      final notification = existingNotifications[i];
      debugPrint('  [$i] ID: ${notification['id']}, 시간: ${notification['time']}, 시작일: ${notification['start_date']}, 종료일: ${notification['end_date']}');
    }
    debugPrint('--- 새 요청 데이터 ---');
    for (int i = 0; i < newTimes.length; i++) {
      if (newTimes[i].isNotEmpty) {
        debugPrint('  [$i] 시간: ${newTimes[i]}');
      }
    }
    
    // 시간 개수 비교
    if (existingTimes.length != newTimesSet.length) {
      debugPrint('변경사항 감지: 시간 개수 다름 (DB: ${existingTimes.length}, 새: ${newTimesSet.length})');
      return true;
    }
    
    // 시간 내용 비교
    if (!existingTimes.containsAll(newTimesSet)) {
      final addedTimes = newTimesSet.difference(existingTimes);
      final removedTimes = existingTimes.difference(newTimesSet);
      debugPrint('변경사항 감지: 시간 내용 다름');
      if (addedTimes.isNotEmpty) debugPrint('  추가된 시간: $addedTimes');
      if (removedTimes.isNotEmpty) debugPrint('  제거된 시간: $removedTimes');
      return true;
    }
    
    // 날짜 비교 (하나라도 다르면 변경사항 있음)
    for (final notification in existingNotifications) {
      if (notification['start_date'] != newStartDate || 
          notification['end_date'] != newEndDate) {
        debugPrint('변경사항 감지: 날짜 다름');
        debugPrint('  DB 시작일: ${notification['start_date']} vs 새 시작일: $newStartDate');
        debugPrint('  DB 종료일: ${notification['end_date']} vs 새 종료일: $newEndDate');
        return true;
      }
    }
    
    debugPrint('변경사항 없음: 모든 데이터가 동일');
    debugPrint('========================');
    return false; // 변경사항 없음
  }

  // 기존 알림 모두 삭제
  static Future<void> _cancelAllSurveyNotifications(int surveyId, String userId) async {
    // 로컬 알림 시스템에서 해당 설문의 모든 알림 삭제
    final pending = await _notificationsPlugin.pendingNotificationRequests();
    
    int cancelledCount = 0;
    for (final notification in pending) {
      try {
        if (notification.payload != null && notification.payload!.isNotEmpty) {
          final payload = jsonDecode(notification.payload!);
          if (payload['survey_id'] == surveyId && 
              payload['user_id'] == userId) {
            await _notificationsPlugin.cancel(notification.id);
            cancelledCount++;
            
            // 삭제된 알림의 payload 로그
            debugPrint('알림 삭제: ID ${notification.id}, Payload: ${notification.payload}');
          }
        }
      } catch (_) {
        // payload 파싱 실패 시 무시
      }
    }
    
    debugPrint('설문 $surveyId의 기존 알림 모두 삭제 완료: $cancelledCount개');
  }

  // 새 알림 모두 등록
  static Future<void> _registerAllNotifications({
    required String userId,
    required int surveyId,
    required String startDate,
    required String endDate,
    required List<String> notificationTimes,
  }) async {
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);
    final androidMode = await _getAndroidScheduleMode();
    
    for (final time in notificationTimes) {
      if (time.isEmpty) continue;
      
      final timeParts = time.split(':');
      if (timeParts.length != 2) {
        debugPrint('잘못된 시간 형식, 스킵: $time');
        continue;
      }
      
      int hour;
      int minute;
      try {
        hour = int.parse(timeParts[0]);
        minute = int.parse(timeParts[1]);
      } catch (e) {
        debugPrint('시간 파싱 실패, 스킵 ($time): $e');
        continue;
      }
      
      // 기간 내 매일 알림 등록
      await _scheduleDailyNotificationsInRange(
        idBase: _generateUniqueId(surveyId, time),
        title: '마음리듬 설문조사',
        body: '$time 설문조사에 참여해주세요.',
        startDate: start,
        endDate: end,
        hour: hour,
        minute: minute,
        androidMode: androidMode,
        surveyId: surveyId,
        timeStr: time,
        existingIds: <int>{}, // 빈 Set (중복 체크 불필요)
        payload: jsonEncode({
          'survey_id': surveyId,
          'time': time,
          'user_id': userId,
          'start_date': startDate,  // 시작일 추가
          'end_date': endDate,      // 종료일 추가
        }),
      );
      
      debugPrint('알림 등록: $time (시작일: $startDate, 종료일: $endDate)');
    }
  }



  // DB 동기화 (기존 데이터 유지하면서 업데이트)
  static Future<void> _syncNotificationDatabase(
    dynamic db,
    int surveyId,
    String userId,
    String startDate,
    String endDate,
    List<String> notificationTimes,
  ) async {
    // 기존 데이터 삭제
    await db.delete(
      'notification_schedule',
      where: 'survey_id = ? AND user_id = ?',
      whereArgs: [surveyId, userId],
    );

    // 새 데이터 삽입
    for (final time in notificationTimes) {
      if (time.isEmpty) continue;
      
      await db.insert('notification_schedule', {
        'survey_id': surveyId,
        'user_id': userId,
        'time': time,
        'start_date': startDate,
        'end_date': endDate,
        'notification_id': '${surveyId}_${time.replaceAll(':', '')}',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
    debugPrint('DB 동기화 완료: ${notificationTimes.length}개 시간');
  }

  // 주어진 기간 동안 매일 단일 알림 스케줄링 (반복 없이 날짜별 생성)
  static Future<void> _scheduleDailyNotificationsInRange({
    required int idBase,
    required String title,
    required String body,
    required DateTime startDate,
    required DateTime endDate,
    required int hour,
    required int minute,
    required AndroidScheduleMode androidMode,
    required int surveyId,
    required String timeStr,
    required Set<int> existingIds,
    String? payload,
  }) async {
    // 시작이 종료 이후면 스킵
    if (startDate.isAfter(endDate)) return;

    // 오늘 기준으로 과거는 건너뜀
    DateTime cursor = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (startDate.isAfter(cursor)) cursor = startDate;

    int dayOffset = 0;
    while (!cursor.isAfter(endDate)) {
      final dateForSchedule = DateTime(cursor.year, cursor.month, cursor.day, hour, minute);
      // 유니크 ID: base + dayOffset
      final id = idBase + dayOffset;
      // 이미 등록되어 있으면 스킵
      if (existingIds.contains(id)) {
        dayOffset += 1;
        cursor = cursor.add(const Duration(days: 1));
        continue;
      }
      await _scheduleNotification(
        id: id,
        title: title,
        body: body,
        startDate: startDate,
        endDate: endDate,
        hour: dateForSchedule.hour,
        minute: dateForSchedule.minute,
        androidMode: androidMode,
        payload: payload,
        scheduledDateOverride: dateForSchedule,
      );
      cursor = cursor.add(const Duration(days: 1));
      dayOffset += 1;
    }
  }

  // 고유한 알림 ID 생성 (시간 문자열을 정수로 변환)
  static int _generateUniqueId(int surveyId, String time) {
    // 시간을 시와 분으로 분리
    final timeParts = time.split(':');
    if (timeParts.length == 2) {
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      // surveyId를 앞자리로 하고 시간을 뒷자리로 하는 정수 생성
      // 예: surveyId=1, 시간=09:00 -> 10900 (1*10000 + 9*100 + 0)
      return surveyId * 10000 + hour * 100 + minute;
    }
    
    // 시간 형식이 잘못된 경우 기본값으로 surveyId에 1000을 곱한 값 반환
    return surveyId * 1000;
  }
  
  // 단일 알림 스케줄링 (내부 사용)
  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime startDate,
    required DateTime endDate,
    required int hour,
    required int minute,
    required AndroidScheduleMode androidMode,
    String? payload,
    DateTime? scheduledDateOverride,
  }) async {
    // 현재 날짜
    final now = DateTime.now();
    
    // 오늘 날짜에 시간 설정
    final scheduledDate = scheduledDateOverride ?? DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    
    // 이미 지난 시간이면 내일로 설정
    DateTime effectiveDate = scheduledDate;
    if (scheduledDate.isBefore(now)) {
      effectiveDate = scheduledDate.add(const Duration(days: 1));
    }
    
    // 종료일을 넘어가면 스케줄링하지 않음
    if (effectiveDate.isAfter(endDate)) {
      debugPrint('알림 스케줄링 취소: 종료일($endDate)을 넘어감');
      return;
    }
    
    // 시작일 이전이면 시작일로 설정
    if (effectiveDate.isBefore(startDate)) {
      effectiveDate = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        hour,
        minute,
      );
    }
    
    // 타임존 설정
    final scheduledTime = tz.TZDateTime.from(effectiveDate, tz.local);
    
    // 알림 상세 설정
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    
    // 알림 스케줄링
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      notificationDetails,
      androidScheduleMode: androidMode,
      // 반복 알림이 아닌 개별 알림로 스케줄링 (기간 종료를 준수)
      matchDateTimeComponents: null,
      payload: payload,
    );
    
    debugPrint('알림 스케줄링: ID $id, 시간 ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}, 날짜 $effectiveDate');
  }

  // 알림 취소
  static Future<void> _cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
    debugPrint('알림 취소: ID $id');
  }

  // 모든 알림 취소
  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    debugPrint('모든 알림 취소');
  }

  // 특정 설문의 모든 알림 취소
  static Future<void> cancelSurveyNotifications(int surveyId) async {
    // 대기 중인 모든 알림 조회 후 payload 기반으로 취소
    final pending = await _notificationsPlugin.pendingNotificationRequests();
    int cancelled = 0;
    for (final p in pending) {
      try {
        if (p.payload != null && p.payload!.isNotEmpty) {
          final map = jsonDecode(p.payload!);
          if (map is Map && map['survey_id'] == surveyId) {
            await _cancelNotification(p.id);
            cancelled += 1;
          }
        }
      } catch (_) {
        // payload 파싱 실패 시 무시
      }
    }
    
    // DB에서도 해당 설문 스케줄 메타 삭제
    final db = await DataBaseManager.database;
    await db.delete(
      'notification_schedule',
      where: 'survey_id = ?',
      whereArgs: [surveyId],
    );
    
    debugPrint('설문 $surveyId의 모든 알림 취소: $cancelled개');
  }
}
