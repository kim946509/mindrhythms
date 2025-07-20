import 'ISurvey.dart';
import 'IQuestion.dart';
import '../enums/app_enums.dart';

// === 설문 로직 Interface ===
abstract class ISurveyLogic {
  // 현재 시간 기준 진행 가능한 설문 시간들 확인
  List<String> getAvailableTimes(ISurvey survey);
  
  // 특정 시간에 설문 진행 가능 여부
  bool canStartSurvey(ISurvey survey, String timeString);
  
  // 현재 시간에 맞는 설문 시간 반환
  String? getCurrentAvailableTime(ISurvey survey);
  
  // 질문 타입별 유효성 검사
  bool validateAnswer(IQuestion question, dynamic answer);
  
  // 조건부 질문 로직 (group_survey 처리)
  bool shouldShowQuestion(IQuestion question, Map<int, dynamic> currentAnswers);
  
  // 다음/이전 질문 결정
  IQuestion? getNextQuestion(
    List<IQuestion> questions,
    int currentIndex,
    Map<int, dynamic> currentAnswers,
  );
  
  IQuestion? getPreviousQuestion(
    List<IQuestion> questions,
    int currentIndex,
    Map<int, dynamic> currentAnswers,
  );
  
  // 설문 완료 조건 체크
  bool isSurveyCompleted(
    List<IQuestion> questions,
    Map<int, dynamic> currentAnswers,
  );
  
  // 설문 진행률 계산
  double calculateProgress(
    List<IQuestion> questions,
    int currentIndex,
    Map<int, dynamic> currentAnswers,
  );
} 