import 'ISurvey.dart';

abstract class ITimedSurvey extends ISurvey {
  int get page;
  String get title;
  List<dynamic> get questions; // IQuestion으로 나중에 타입 캐스팅
} 