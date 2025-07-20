import 'app_enums.dart';

// === 추가 Enum 확장 메서드들 ===

extension ScreenTypeExtension on ScreenType {
  String get displayName {
    switch (this) {
      case ScreenType.splash:
        return '스플래시';
      case ScreenType.login:
        return '로그인';
      case ScreenType.surveyList:
        return '설문목록';
      case ScreenType.surveyStatus:
        return '설문현황';
      case ScreenType.surveyBefore:
        return '설문조사전';
      case ScreenType.surveyStart:
        return '설문조사시작';
    }
  }
  
  bool get requiresAuth {
    switch (this) {
      case ScreenType.splash:
      case ScreenType.login:
        return false;
      default:
        return true;
    }
  }
}

extension SurveyStatusExtension on SurveyStatus {
  String get displayName {
    switch (this) {
      case SurveyStatus.pending:
        return '대기 중';
      case SurveyStatus.inProgress:
        return '진행 중';
      case SurveyStatus.completed:
        return '완료';
      case SurveyStatus.expired:
        return '만료됨';
      case SurveyStatus.unavailable:
        return '이용 불가';
    }
  }
  
  bool get isActionable {
    switch (this) {
      case SurveyStatus.pending:
      case SurveyStatus.inProgress:
        return true;
      default:
        return false;
    }
  }
}



extension ComponentTypeExtension on ComponentType {
  String get displayName {
    switch (this) {
      case ComponentType.header:
        return '상단';
      case ComponentType.body:
        return '메인';
      case ComponentType.footer:
        return '하단';
    }
  }
} 