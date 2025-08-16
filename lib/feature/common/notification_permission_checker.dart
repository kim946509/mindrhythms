import 'package:permission_handler/permission_handler.dart';

/// 알림 권한 체크 클래스 (싱글톤 패턴)
class NotificationPermissionChecker {
  static NotificationPermissionChecker? _instance;
  static NotificationPermissionChecker get instance {
    _instance ??= NotificationPermissionChecker._internal();
    return _instance!;
  }
  
  NotificationPermissionChecker._internal();
  
  // 권한 상태 변화 콜백
  Function(bool isGranted)? _onPermissionChanged;
  
  // 마지막 권한 상태 캐시
  bool? _lastPermissionStatus;
  
  /// 권한 상태 변화 콜백 설정
  void setPermissionChangedCallback(Function(bool isGranted)? callback) {
    _onPermissionChanged = callback;
  }
  
  /// 현재 알림 권한 상태 확인
  /// 반환값: true(허용), false(거부)
  Future<bool> isGranted() async {
    try {
      final status = await Permission.notification.status;
      final isGranted = status == PermissionStatus.granted;
      
      // 권한 상태가 변경되었으면 콜백 호출
      if (_lastPermissionStatus != null && _lastPermissionStatus != isGranted) {
        _onPermissionChanged?.call(isGranted);
      }
      _lastPermissionStatus = isGranted;
      
      return isGranted;
    } catch (e) {
      return false;
    }
  }

  /// 알림 권한이 거부되었는지 확인
  /// 반환값: true(거부), false(허용 또는 미요청)
  Future<bool> isDenied() async {
    try {
      final status = await Permission.notification.status;
      return status == PermissionStatus.denied;
    } catch (e) {
      return false;
    }
  }

  /// 알림 권한이 영구적으로 거부되었는지 확인
  /// 반환값: true(영구거부), false(그 외)
  Future<bool> isPermanentlyDenied() async {
    try {
      final status = await Permission.notification.status;
      return status == PermissionStatus.permanentlyDenied;
    } catch (e) {
      return false;
    }
  }

  /// 알림 권한 요청
  /// 반환값: true(허용), false(거부)
  Future<bool> request() async {
    try {
      final status = await Permission.notification.request();
      return status == PermissionStatus.granted;
    } catch (e) {
      return false;
    }
  }

  /// 설정 앱으로 이동
  /// 반환값: true(성공), false(실패)
  Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      return false;
    }
  }

  /// 권한 상태를 문자열로 반환
  /// 반환값: "granted", "denied", "permanently_denied", "unknown"
  Future<String> getStatusString() async {
    try {
      final status = await Permission.notification.status;
      switch (status) {
        case PermissionStatus.granted:
          return "granted";
        case PermissionStatus.denied:
          return "denied";
        case PermissionStatus.permanentlyDenied:
          return "permanently_denied";
        case PermissionStatus.restricted:
          return "restricted";
        default:
          return "unknown";
      }
    } catch (e) {
      return "unknown";
    }
  }

  /// 권한이 필요한 경우 요청하고 결과 반환
  /// 반환값: true(권한 있음), false(권한 없음)
  Future<bool> checkAndRequest() async {
    // 1. 현재 상태 확인
    if (await isGranted()) {
      return true;
    }

    // 2. 영구적으로 거부된 경우 설정으로 이동 안내
    if (await isPermanentlyDenied()) {
      return false; // 호출하는 곳에서 설정 이동 처리
    }

    // 3. 권한 요청
    final result = await request();
    
    // 권한 요청 후 상태 업데이트를 위해 다시 확인
    await isGranted();
    
    return result;
  }

  /// 권한 상태에 따른 메시지 반환
  Future<String> getStatusMessage() async {
    final status = await getStatusString();
    switch (status) {
      case "granted":
        return "알림 권한이 허용되어 있습니다";
      case "denied":
        return "알림 권한이 거부되었습니다";
      case "permanently_denied":
        return "알림 권한이 영구적으로 거부되었습니다. 설정에서 직접 허용해주세요";
      case "restricted":
        return "알림 권한이 제한되어 있습니다";
      default:
        return "알림 권한 상태를 확인할 수 없습니다";
    }
  }
}
