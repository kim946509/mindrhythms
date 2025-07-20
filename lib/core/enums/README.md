# Global Enums 구조

## 파일 구성

### `app_enums.dart` - 핵심 Enum 정의
- **ScreenType**: 앱의 6개 화면 타입
- **InterfaceType**: 서버 4개 인터페이스 타입  
- **QuestionType**: 설문 질문 타입들
- **SurveyStatus**: 설문 상태들
- **ComponentType**: UI 컴포넌트 타입

### `enum_extensions.dart` - 확장 메서드들
- 각 Enum의 `displayName` 속성
- 비즈니스 로직 관련 확장 메서드들

## Interface와의 연동

### 변경된 Interface들
```dart
// 기존: String -> 변경: QuestionType enum
IQuestion.type: QuestionType

// 서버에서 받은 동적 시간 값들 사용
ISurvey.times: List<String>  // 예: ["09:30", "14:15", "18:00"]

// 기존: List<bool> -> 변경: List<SurveyStatus> enum
ISurveyStatusItem.status: List<SurveyStatus>

// 새로 추가된 enum 기반 헬퍼 메서드들
IServerResponse.getActiveInterfaces(): List<InterfaceType>
IServerResponse.getPrimaryInterface(): InterfaceType?
```

## 사용 예시

```dart
// Enum 값 사용
QuestionType.singleChoice.value  // "single-choice"
SurveyStatus.pending.displayName // "대기 중"

// String에서 Enum 변환
QuestionType.fromString("single-choice")  // QuestionType.singleChoice

// 비즈니스 로직
SurveyStatus.pending.isActionable        // 액션 가능한 상태인지
ScreenType.login.requiresAuth            // 인증이 필요한 화면인지

// 동적 시간 처리 (lib/core/utils/time_utils.dart 사용)
TimeUtils.isCurrentTime("09:30")         // 현재 시간이 09:30인지 (±30분)
TimeUtils.formatTimeDisplay("14:15")     // "오후 2:15"
TimeUtils.findNearestTime(["09:30", "14:15"]) // 가장 가까운 시간
```

## 장점

1. **타입 안전성**: 컴파일 타임에 타입 오류 감지
2. **가독성**: String 대신 의미있는 enum 사용
3. **확장성**: extension 메서드로 비즈니스 로직 추가
4. **유지보수성**: 중앙 집중화된 enum 관리
5. **IDE 지원**: 자동완성, 리팩토링 지원 