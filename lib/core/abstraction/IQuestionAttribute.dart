import 'ISurvey.dart';

abstract class IQuestionAttribute extends ISurvey {
  List<int>? get groupSurvey;
  List<String>? get options;
} 