import 'IServerResponse.dart';
import '../enums/app_enums.dart';

// === 화면 로직 Interface ===
abstract class IScreenLogic {
  // 서버 응답 기반 화면 결정
  ScreenType resolveScreen(IServerResponse serverResponse);
  
  // 인터페이스 타입별 화면 결정 로직
  ScreenType? getScreenFromInterface(InterfaceType interfaceType, dynamic data);
  
  // 화면 전환 가능성 체크
  bool canNavigateToScreen(ScreenType targetScreen, IServerResponse serverResponse);
  
  // 우선순위 기반 화면 결정
  ScreenType getHighestPriorityScreen(IServerResponse serverResponse);
  
  // 현재 시간 기준 적절한 화면 결정
  ScreenType resolveTimeBasedScreen(IServerResponse serverResponse);
} 