/// 설문 기본 정보 DTO
class SurveyInfoDto {
  final String surveyName;
  final String surveyDescription;
  final List<String> notificationTimes;

  const SurveyInfoDto({
    required this.surveyName,
    required this.surveyDescription,
    required this.notificationTimes,
  });

  factory SurveyInfoDto.fromJson(Map<String, dynamic> json) {
    return SurveyInfoDto(
      surveyName: json['surveyName'] ?? '',
      surveyDescription: json['surveyDescription'] ?? '',
      notificationTimes: List<String>.from(json['notificationTimes'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'surveyName': surveyName,
      'surveyDescription': surveyDescription,
      'notificationTimes': notificationTimes,
    };
  }

  @override
  String toString() {
    return 'SurveyInfoDto{surveyName: $surveyName, surveyDescription: $surveyDescription, notificationTimes: $notificationTimes}';
  }
}
