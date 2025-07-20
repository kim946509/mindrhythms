import 'IData.dart';

// === 4. Survey Interface ===
abstract class ISurvey extends IData {
  List<String> get times;          // 서버에서 받은 동적 시간 값들 (예: ["09:30", "14:15", "18:00"])
  Map<String, dynamic> get surveys; // ITimedSurvey로 나중에 타입 캐스팅
} 