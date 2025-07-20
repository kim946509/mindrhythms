import 'ISurvey.dart';

abstract class IQuestion extends ISurvey {
  int get id;
  String get title;
  String get type;
  List<String> get data;
  dynamic get attribute; // IQuestionAttribute로 나중에 타입 캐스팅
} 