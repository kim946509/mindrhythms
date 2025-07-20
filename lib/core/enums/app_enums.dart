// 앱에서 사용하는 모든 글로벌 Enums

// === 화면 타입 ===
enum ScreenType {
  splash,        // 스플래시
  login,         // 로그인
  surveyList,    // 설문목록
  surveyStatus,  // 설문현황
  surveyBefore,  // 설문조사전
  surveyStart,   // 설문조사시작
}

// === 인터페이스 타입 ===
enum InterfaceType {
  login,         // 로그인 데이터
  notification,  // 알림 데이터
  surveyStatus,  // 설문 상태 데이터
  survey,        // 설문 데이터
}

// === 설문 질문 타입 ===
enum QuestionType {
  singleChoice,  // 단일 선택 (single-choice)
  multiChoice,   // 복수 선택 (multi-choice)
  textInput,     // 텍스트 입력 (input)
  rating,        // 평점
  slider,        // 슬라이더
  yesNo,         // 예/아니오
}

// === 설문 상태 ===
enum SurveyStatus {
  pending,       // 대기 중
  inProgress,    // 진행 중
  completed,     // 완료
  expired,       // 만료
  unavailable,   // 이용 불가
}

// === 컴포넌트 타입 ===
enum ComponentType {
  header,        // 상단
  body,          // 메인
  footer,        // 하단
}

// === Enum 확장 메서드들 ===
extension QuestionTypeExtension on QuestionType {
  String get value {
    switch (this) {
      case QuestionType.singleChoice:
        return 'single-choice';
      case QuestionType.multiChoice:
        return 'multi-choice';
      case QuestionType.textInput:
        return 'input';
      case QuestionType.rating:
        return 'rating';
      case QuestionType.slider:
        return 'slider';
      case QuestionType.yesNo:
        return 'yes-no';
    }
  }
  
  static QuestionType fromString(String value) {
    switch (value) {
      case 'single-choice':
        return QuestionType.singleChoice;
      case 'multi-choice':
        return QuestionType.multiChoice;
      case 'input':
        return QuestionType.textInput;
      case 'rating':
        return QuestionType.rating;
      case 'slider':
        return QuestionType.slider;
      case 'yes-no':
        return QuestionType.yesNo;
      default:
        throw ArgumentError('Unknown QuestionType: $value');
    }
  }
}

extension InterfaceTypeExtension on InterfaceType {
  String get value {
    switch (this) {
      case InterfaceType.login:
        return 'login';
      case InterfaceType.notification:
        return 'notification';
      case InterfaceType.surveyStatus:
        return 'survey_status';
      case InterfaceType.survey:
        return 'survey';
    }
  }
  
  static InterfaceType fromString(String value) {
    switch (value) {
      case 'login':
        return InterfaceType.login;
      case 'notification':
        return InterfaceType.notification;
      case 'survey_status':
        return InterfaceType.surveyStatus;
      case 'survey':
        return InterfaceType.survey;
      default:
        throw ArgumentError('Unknown InterfaceType: $value');
    }
  }
} 