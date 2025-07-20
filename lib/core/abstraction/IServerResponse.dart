import 'IData.dart';
import 'ILogin.dart';
import 'INotification.dart';
import 'ISurveyStatus.dart';
import 'ISurvey.dart';
import '../enums/app_enums.dart';

// === Server Response Interface ===
abstract class IServerResponse extends IData {
  ILogin? get login;
  INotification? get notification;
  ISurveyStatus? get surveyStatus;
  ISurvey? get survey;
  
  // === Enum 기반 헬퍼 메서드들 ===
  bool hasLogin();
  bool hasNotification();
  bool hasSurveyStatus();
  bool hasSurvey();
  
  // 현재 활성화된 인터페이스 타입들 반환
  List<InterfaceType> getActiveInterfaces();
  
  // 우선순위가 가장 높은 인터페이스 타입 반환
  InterfaceType? getPrimaryInterface();
  
  // 특정 인터페이스 타입 존재 여부 확인
  bool hasInterface(InterfaceType interfaceType);
}
