class SurveyStatusItem {
  final String surveyTimeSlot;
  final int status; // 0: 미완료, 1: 완료

  SurveyStatusItem({
    required this.surveyTimeSlot,
    required this.status,
  });

  factory SurveyStatusItem.fromJson(Map<String, dynamic> json) {
    return SurveyStatusItem(
      surveyTimeSlot: json['survey_time'] ?? '',
      status: json['is_submitted'] ?? 0,
    );
  }
}
