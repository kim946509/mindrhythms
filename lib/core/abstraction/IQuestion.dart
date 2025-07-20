import 'ISurvey.dart';
import '../enums/app_enums.dart';

abstract class IQuestion extends ISurvey {
  int get id;
  String get title;
  QuestionType get type;           // String -> QuestionType enum
  List<String> get data;
  dynamic get attribute; // IQuestionAttribute로 나중에 타입 캐스팅
} 