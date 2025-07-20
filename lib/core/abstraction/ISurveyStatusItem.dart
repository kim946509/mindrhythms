import 'IData.dart';

abstract class ISurveyStatusItem extends IData {
  String get title;
  List<bool> get status;
} 