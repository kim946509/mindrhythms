import 'IData.dart';

// === 3. Survey Status Interface ===
abstract class ISurveyStatus extends IData {
  Map<String, dynamic> get items; // ISurveyStatusItem으로 나중에 타입 캐스팅
} 