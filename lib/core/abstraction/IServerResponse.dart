import 'IData.dart';
import 'ILogin.dart';
import 'INotification.dart';
import 'ISurveyStatus.dart';
import 'ISurvey.dart';

// === Server Response Interface ===
abstract class IServerResponse extends IData {
  ILogin? get login;
  INotification? get notification;
  ISurveyStatus? get surveyStatus;
  ISurvey? get survey;
}
