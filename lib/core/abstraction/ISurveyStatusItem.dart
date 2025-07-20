import 'IData.dart';
import '../enums/app_enums.dart';

abstract class ISurveyStatusItem extends IData {
  String get title;
  List<SurveyStatus> get status;   // List<bool> -> List<SurveyStatus> enum (더 명확한 상태 관리)
} 