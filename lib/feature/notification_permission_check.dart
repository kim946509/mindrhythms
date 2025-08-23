import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationPermissionCheck {
  static final FlutterLocalNotificationsPlugin _flnp = FlutterLocalNotificationsPlugin();

  // 현재 권한 상태만 확인 (권한 요청 없음)
  static Future<bool> checkStatus() async {
    try {
      final status = await Permission.notification.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('알림 권한 상태 체크 중 오류 발생: $e');
      return false;
    }
  }
  
  // 권한 요청 (사용자에게 권한 요청 다이얼로그 표시)
  static Future<bool> requestPermission() async {
    try {
      // iOS에서는 권한 요청 시 추가 처리가 필요할 수 있음
      if (Platform.isIOS) {
        debugPrint('iOS에서 알림 권한 요청');
        // iOS 세부 권한(Alert/Badge/Sound)
        final ios = _flnp.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        await ios?.requestPermissions(alert: true, badge: true, sound: true);
        // 시스템 Notification 권한도 확인
        final result = await Permission.notification.request();
        await Future.delayed(const Duration(milliseconds: 300));
        return result.isGranted;
      } else {
        // Android 13+ 에서 Notification 권한
        final result = await Permission.notification.request();
        return result.isGranted;
      }
    } catch (e) {
      debugPrint('알림 권한 요청 중 오류 발생: $e');
      return false;
    }
  }

  // ANDROID: 정확 알람(EXACT ALARM) 사용 가능 여부
  static Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true; // iOS에는 해당 없음
    try {
      final android = _flnp.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final bool? canSchedule = await android?.canScheduleExactNotifications();
      return canSchedule ?? false;
    } catch (e) {
      debugPrint('정확 알람 가능 여부 확인 오류: $e');
      return false;
    }
  }

  // ANDROID: 정확 알람 권한 요청(설정 화면 유도 포함)
  static Future<bool> requestExactAlarmsPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final android = _flnp.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final bool? granted = await android?.requestExactAlarmsPermission();
      return granted ?? false;
    } catch (e) {
      debugPrint('정확 알람 권한 요청 중 오류: $e');
      return false;
    }
  }
  
  // 설정 앱으로 이동
  static Future<void> openSettings() async {
    try {
      if (Platform.isIOS) {
        // iOS에서는 설정 앱으로 이동
        debugPrint('iOS 설정 앱으로 이동');
        await openAppSettings();
      } else {
        // Android 또는 다른 플랫폼
        await openAppSettings();
      }
    } catch (e) {
      debugPrint('설정 앱 열기 중 오류 발생: $e');
    }
  }
  
  // iOS 및 Android 모두에서 사용할 수 있는 알림 권한 안내 문구
  static String getPermissionGuideText() {
    if (Platform.isIOS) {
      return '설정 → 알림 → 마음리듬에서 알림을 허용해주세요.';
    } else {
      return '설정 → 앱 → 마음리듬 → 알림에서 알림을 허용해주세요.';
    }
  }
}
