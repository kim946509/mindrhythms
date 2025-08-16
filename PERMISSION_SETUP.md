# 알림 권한 설정 가이드

## Android 설정

### 1. android/app/src/main/AndroidManifest.xml 파일 수정

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- 알림 권한 추가 -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    
    <application
        android:label="mindrhythms"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <!-- 기존 내용 유지 -->
    </application>
</manifest>
```

## iOS 설정

### 1. ios/Runner/Info.plist 파일 수정

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- 기존 내용 유지 -->
    
    <!-- 알림 권한 설명 추가 -->
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
</dict>
</plist>
```

## 패키지 설치

터미널에서 다음 명령어를 실행하여 의존성을 설치하세요:

```bash
flutter pub get
```

## 사용법 예시

```dart
import 'package:mindrhythms/feature/notification_permission_checker.dart';

// 권한 확인
bool isGranted = await NotificationPermissionChecker.isGranted();

// 권한 요청
bool granted = await NotificationPermissionChecker.request();

// 권한이 필요한 경우 체크 후 요청
bool hasPermission = await NotificationPermissionChecker.checkAndRequest();

// 설정 앱으로 이동 (영구 거부된 경우)
if (await NotificationPermissionChecker.isPermanentlyDenied()) {
    await NotificationPermissionChecker.openSettings();
}
```

## 주의사항

1. **Android 13+ (API 33+)**: POST_NOTIFICATIONS 권한이 필수입니다.
2. **iOS**: 알림 권한은 사용자가 직접 허용해야 합니다.
3. **테스트**: 실제 기기에서 테스트하는 것을 권장합니다.
