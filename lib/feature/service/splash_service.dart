import 'dart:async';

import 'package:mindrhythms/feature/common/data_manager.dart';
import 'package:mindrhythms/feature/common/notification_permission_checker.dart';

/// 간단한 3단계 스플래시 서비스
class SplashService {
  
  /// 3단계 진행 메시지
  static const List<String> _progressMessages = [
    '알림 권한을 확인하고 있습니다...\n필요시 권한을 요청합니다',
    '저장된 사용자 정보를 확인하고 있습니다...\n자동 로그인을 시도합니다',
    '로그인 상태를 확인하는 중입니다...\n잠시만 기다려주세요',
  ];

  /// 3단계 초기화 과정
  static Future<Map<String, dynamic>> initializeApp({
    Function(String message, int step, int totalSteps)? onProgress,
    Function(String title, String message, List<String> options)? onUserChoice,
  }) async {
    final result = <String, dynamic>{};
    final totalSteps = _progressMessages.length;

    // 1단계: 알림 권한 체크
    onProgress?.call(_progressMessages[0], 1, totalSteps);
    await Future.delayed(const Duration(seconds: 1));
    
    final permissionData = await _checkNotificationPermission(onUserChoice: onUserChoice);
    result['permission'] = permissionData;
    
    // 2단계: 사용자 정보 확인
    onProgress?.call(_progressMessages[1], 2, totalSteps);
    await Future.delayed(const Duration(seconds: 1));
    
    final userData = await _checkUserData();
    result['user'] = userData;
    
    // 3단계: 로그인 상태 확인 및 결정
    onProgress?.call(_progressMessages[2], 3, totalSteps);
    await Future.delayed(const Duration(seconds: 1));
    
    final loginStatus = _determineLoginStatus(userData);
    result['loginStatus'] = loginStatus;
    
    return result;
  }

  /// 1단계: 알림 권한 체크 및 요청
  static Future<Map<String, dynamic>> _checkNotificationPermission({
    Function(String title, String message, List<String> options)? onUserChoice,
  }) async {
    // 현재 권한 상태 확인
    final permissionChecker = NotificationPermissionChecker.instance;
    bool isGranted = await permissionChecker.isGranted();
    String statusString = await permissionChecker.getStatusString();
    String statusMessage = await permissionChecker.getStatusMessage();
    
    bool requestAttempted = false;
    bool requestSucceeded = false;
    String finalMessage = statusMessage;

    // 권한이 없다면 요청 시도
    if (!isGranted) {
      // 영구적으로 거부된 경우 설정 이동 안내
      if (await permissionChecker.isPermanentlyDenied()) {
        finalMessage = '알림 권한이 영구적으로 거부되었습니다.\n설정에서 직접 허용해주세요';
        
        // 권한이 허용될 때까지 반복
        bool permissionGranted = false;
        while (!permissionGranted) {
          if (onUserChoice != null) {
            final choice = await _showUserChoice(
              onUserChoice,
              '알림 권한 필수',
              '이 앱은 설문 알림을 위해 알림 권한이 필수입니다.\n설정에서 권한을 허용해주세요.',
              ['설정으로 이동', '앱 종료'],
            );
            
            if (choice == 0) { // 설정으로 이동
              await permissionChecker.openSettings();
              // 설정에서 돌아온 후 다시 확인
              await Future.delayed(const Duration(seconds: 2));
              isGranted = await permissionChecker.isGranted();
              if (isGranted) {
                statusString = 'granted';
                finalMessage = '알림 권한이 허용되었습니다';
                permissionGranted = true;
              } else {
                // 설정에서도 허용하지 않으면 계속 반복
                finalMessage = '설정에서 알림 권한을 허용해주세요.\n앱 사용을 위해 필수입니다.';
              }
            } else { // 앱 종료 (choice == 1)
              // Exception 대신 결과에 종료 정보 포함
              finalMessage = '알림 권한이 필요합니다.\n설정에서 권한을 허용해주세요.';
              permissionGranted = true; // 루프 종료
              
              // 특별한 상태 정보 추가
              statusString = 'user_denied_exit';
            }
          } else {
            // 사용자 선택 콜백이 없으면 바로 설정 안내 메시지만 표시
            print('💡 사용자 선택 콜백이 없습니다. 설정 안내 메시지를 표시합니다.');
            finalMessage = '알림 권한이 필요합니다.\n설정 > 앱 > 마음리듬 > 알림에서 권한을 허용해주세요.';
            statusString = 'permanently_denied_no_callback';
            permissionGranted = true; // 루프 종료
          }
        }
      } else {
        // 권한 요청 시도
        requestAttempted = true;
        requestSucceeded = await permissionChecker.request();
        
        if (requestSucceeded) {
          isGranted = true;
          statusString = 'granted';
          finalMessage = '알림 권한이 허용되었습니다';
        } else {
          // 권한이 거부된 경우 - 필수 권한이므로 재시도 필요
          finalMessage = '알림 권한이 필요합니다.\n이 앱은 설문 알림을 위해 알림 권한이 필수입니다.';
          
          // 권한이 허용될 때까지 반복
          bool permissionGranted = false;
          while (!permissionGranted) {
            if (onUserChoice != null) {
              final choice = await _showUserChoice(
                onUserChoice,
                '알림 권한 필수',
                '이 앱은 설문 알림을 위해 알림 권한이 필수입니다.\n권한을 허용해주세요.',
                ['다시 시도', '설정에서 허용', '앱 종료'],
              );
              
              if (choice == 0) { // 다시 시도
                requestSucceeded = await permissionChecker.request();
                if (requestSucceeded) {
                  isGranted = true;
                  statusString = 'granted';
                  finalMessage = '알림 권한이 허용되었습니다';
                  permissionGranted = true;
                } else {
                  // 다시 거부되면 계속 반복
                  finalMessage = '알림 권한이 거부되었습니다.\n앱 사용을 위해 권한이 필요합니다.';
                }
              } else if (choice == 1) { // 설정에서 허용
                await permissionChecker.openSettings();
                // 설정에서 돌아온 후 다시 확인
                await Future.delayed(const Duration(seconds: 2));
                isGranted = await permissionChecker.isGranted();
                if (isGranted) {
                  statusString = 'granted';
                  finalMessage = '알림 권한이 허용되었습니다';
                  permissionGranted = true;
                } else {
                  // 설정에서도 허용하지 않으면 계속 반복
                  finalMessage = '설정에서 알림 권한을 허용해주세요.\n앱 사용을 위해 필수입니다.';
                }
              } else { // 앱 종료 (choice == 2)
                // Exception 대신 결과에 종료 정보 포함
                finalMessage = '알림 권한이 필요합니다.\n설정에서 권한을 허용해주세요.';
                statusString = 'user_denied_exit';
                permissionGranted = true; // 루프 종료
              }
            } else {
              // 사용자 선택 콜백이 없으면 바로 설정 안내 메시지 표시
              print('💡 사용자 선택 콜백이 없습니다. 설정 안내 메시지를 표시합니다.');
              finalMessage = '알림 권한이 필요합니다.\n설정에서 권한을 허용해주세요.';
              statusString = 'denied_no_callback';
              permissionGranted = true; // 루프 종료
            }
          }
        }
      }
    }

    // 설정 화면 이동이 필요한지 판단
    final needsSettingsNavigation = !isGranted && (
      statusString == 'user_denied_exit' || 
      statusString == 'settings_retry_exceeded' || 
      statusString == 'retry_exceeded' ||
      statusString == 'permanently_denied_no_callback' ||
      statusString == 'denied_no_callback'
    );

    final permissionData = {
      'isGranted': isGranted,
      'status': statusString,
      'message': finalMessage,
      'requestAttempted': requestAttempted,
      'requestSucceeded': requestSucceeded,
      'needsSettingsNavigation': needsSettingsNavigation,
      'settingsGuideMessage': needsSettingsNavigation 
          ? '설정 > 앱 > 마음리듬 > 알림 권한을 허용해주세요.'
          : null,
      'checkedAt': DateTime.now().toIso8601String(),
    };

    // 권한 상태를 로컬에 저장
    await DataManager.saveToLocal('notification_permission', permissionData);

    return permissionData;
  }

  /// 2단계: 로컬DB에서 사용자 데이터 확인
  static Future<Map<String, dynamic>> _checkUserData() async {
    // 로컬DB에서 사용자 정보 확인
    final userData = await DataManager.getFromLocal('user_profile');
    final loginToken = await DataManager.getFromLocal('login_token');
    
    return {
      'userData': userData,
      'loginToken': loginToken,
      'hasUserData': userData != null,
      'hasToken': loginToken != null,
      'checkedAt': DateTime.now().toIso8601String(),
    };
  }

  /// 3단계: 로그인 상태 결정
  static Map<String, dynamic> _determineLoginStatus(Map<String, dynamic> userData) {
    final hasUserData = userData['hasUserData'] ?? false;
    final hasToken = userData['hasToken'] ?? false;
    
    // 사용자 데이터와 토큰이 모두 있으면 자동 로그인
    if (hasUserData && hasToken) {
      return {
        'shouldAutoLogin': true,
        'shouldGoToLogin': false,
        'nextRoute': '/home', // 홈으로 이동
        'message': '자동 로그인 중입니다...',
      };
    }
    
    // 사용자 데이터나 토큰이 없으면 로그인 페이지로
    return {
      'shouldAutoLogin': false,
      'shouldGoToLogin': true,
      'nextRoute': '/login', // 로그인 페이지로 이동
      'message': '로그인이 필요합니다',
    };
  }

  /// 알림 권한이 영구 거부된 경우 설정으로 이동 안내
  static Future<bool> openNotificationSettings() async {
    return await NotificationPermissionChecker.instance.openSettings();
  }

  /// 권한 허용 안내와 함께 설정 화면으로 이동
  static Future<Map<String, dynamic>> navigateToSettingsWithGuide() async {
    final opened = await NotificationPermissionChecker.instance.openSettings();
    
    return {
      'settingsOpened': opened,
      'guideMessage': '설정 > 앱 > 마음리듬 > 알림 권한을 허용해주세요.',
      'detailedSteps': [
        '1. 설정 앱이 열립니다',
        '2. "앱" 또는 "애플리케이션"을 찾아주세요',
        '3. "마음리듬" 앱을 선택해주세요',
        '4. "알림" 또는 "권한"을 선택해주세요',
        '5. 알림 권한을 허용으로 변경해주세요',
        '6. 앱으로 돌아와주세요'
      ],
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// 권한 상태 재확인 (설정에서 돌아온 후 사용)
  static Future<Map<String, dynamic>> recheckNotificationPermission() async {
    return await _checkNotificationPermission();
  }

  /// 사용자 선택 다이얼로그 표시 헬퍼
  static Future<int> _showUserChoice(
    Function(String title, String message, List<String> options) onUserChoice,
    String title,
    String message,
    List<String> options,
  ) async {
    final completer = Completer<int>();
    
    // 콜백을 호출하여 UI에서 사용자 선택을 받음
    onUserChoice(title, message, options);
    
    // 실제 구현에서는 UI에서 선택된 인덱스를 반환해야 함
    // 여기서는 기본값으로 0을 반환 (첫 번째 옵션 - "권한 없이 계속")
    // 실제로는 UI 콜백에서 completer.complete(selectedIndex) 호출
    
    // 10초 후 기본 선택 (첫 번째 옵션)
    Future.delayed(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        print('사용자 선택 시간 초과 - 첫 번째 옵션을 선택합니다.');
        completer.complete(0); // 첫 번째 옵션 선택
      }
    });
    
    return completer.future;
  }

  /// UI에서 사용자 선택을 완료했을 때 호출하는 메서드
  /// 실제 구현에서는 이 메서드를 통해 사용자 선택을 전달받아야 함
  static final Map<String, Completer<int>> _activeChoices = {};
  
  /// 사용자 선택 완료 알림 (UI에서 호출)
  static void completeUserChoice(String choiceId, int selectedIndex) {
    final completer = _activeChoices[choiceId];
    if (completer != null && !completer.isCompleted) {
      completer.complete(selectedIndex);
      _activeChoices.remove(choiceId);
    }
  }

  /// 테스트용 - onUserChoice 콜백 없이 초기화 (권한 거부 시 메시지만 표시)
  static Future<Map<String, dynamic>> initializeAppWithoutUserChoice({
    Function(String message, int step, int totalSteps)? onProgress,
  }) async {
    return await initializeApp(
      onProgress: onProgress,
      onUserChoice: null, // 사용자 선택 없이 메시지만 표시
    );
  }

  /// 권한 상태와 안내 메시지를 간단히 확인하는 메서드
  static Future<Map<String, dynamic>> checkPermissionStatus() async {
    final permissionChecker = NotificationPermissionChecker.instance;
    final isGranted = await permissionChecker.isGranted();
    final statusString = await permissionChecker.getStatusString();
    final statusMessage = await permissionChecker.getStatusMessage();
    
    return {
      'isGranted': isGranted,
      'status': statusString,
      'message': statusMessage,
      'needsSettings': !isGranted,
      'guideMessage': !isGranted 
          ? '설정 > 앱 > 마음리듬 > 알림에서 권한을 허용해주세요.'
          : null,
    };
  }

  /// 결과 출력용 메서드
  static void printInitializationResult({
    required Map<String, dynamic> permissionData,
    required Map<String, dynamic> userData,
    required Map<String, dynamic> loginStatus,
  }) {
    print('🔔 알림 권한: ${permissionData['status']}');
    
    // 권한 요청 시도 여부 출력
    if (permissionData['requestAttempted'] == true) {
      if (permissionData['requestSucceeded'] == true) {
        print('   ✅ 권한 요청 성공');
      } else {
        print('   ❌ 권한 요청 거부됨');
      }
    }
    
    // 설정 이동 필요 여부 출력
    if (permissionData['needsSettingsNavigation'] == true) {
      print('⚙️  설정 화면 이동 필요');
      print('   💡 ${permissionData['settingsGuideMessage']}');
    }
    
    print('👤 사용자 데이터: ${userData['hasUserData'] ? '있음' : '없음'}');
    print('🔑 로그인 토큰: ${userData['hasToken'] ? '있음' : '없음'}');
    
    // 권한이 없어서 설정 이동이 필요한 경우 다른 정보 표시 안함
    if (permissionData['needsSettingsNavigation'] != true) {
    print('🚀 다음 경로: ${loginStatus['nextRoute']}');
    
    if (loginStatus['shouldAutoLogin']) {
      print('✅ 자동 로그인 진행');
    } else {
      print('🔐 로그인 페이지로 이동');
      }
    } else {
      print('⏸️  권한 허용 후 앱을 다시 시작해주세요');
    }
  }
}
