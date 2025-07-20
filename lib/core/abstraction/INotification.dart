import 'IData.dart';

// === 2. Notification Interface ===  
abstract class INotification extends IData {
  List<String> get surveyPeriod;
  List<String> get alarmTime;
} 