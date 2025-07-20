import 'IData.dart';

// === 4. Survey Interface ===
abstract class ISurvey extends IData {
  List<String> get times;
  Map<String, dynamic> get surveys; // ITimedSurvey로 나중에 타입 캐스팅
} 