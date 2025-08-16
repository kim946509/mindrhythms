/// 설문 상태 DTO (시간별 제출 여부)
class SurveyStatusDto {
  final String time;
  final bool submitted;

  const SurveyStatusDto({
    required this.time,
    required this.submitted,
  });

  factory SurveyStatusDto.fromJson(Map<String, dynamic> json) {
    return SurveyStatusDto(
      time: json['time'] ?? '',
      submitted: json['submitted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'time': time,
      'submitted': submitted,
    };
  }

  @override
  String toString() {
    return 'SurveyStatusDto{time: $time, submitted: $submitted}';
  }
}
