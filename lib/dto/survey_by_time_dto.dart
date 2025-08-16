/// 후속 질문 조건 DTO
class FollowUpDto {
  final List<String> condition;
  final List<String> then;

  const FollowUpDto({
    required this.condition,
    required this.then,
  });

  factory FollowUpDto.fromJson(Map<String, dynamic> json) {
    return FollowUpDto(
      condition: List<String>.from(json['condition'] ?? []),
      then: List<String>.from(json['then'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'condition': condition,
      'then': then,
    };
  }

  @override
  String toString() {
    return 'FollowUpDto{condition: $condition, then: $then}';
  }
}

/// 개별 질문 DTO
class QuestionDto {
  final String id;
  final String question;
  final String type; // "single-choice", "multi-choice", "text", "scale"
  final List<String> input;
  final FollowUpDto? followUp;

  const QuestionDto({
    required this.id,
    required this.question,
    required this.type,
    required this.input,
    this.followUp,
  });

  factory QuestionDto.fromJson(Map<String, dynamic> json) {
    return QuestionDto(
      id: json['id'] ?? '',
      question: json['question'] ?? '',
      type: json['type'] ?? '',
      input: List<String>.from(json['input'] ?? []),
      followUp: json['followUp'] != null 
          ? FollowUpDto.fromJson(json['followUp'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'type': type,
      'input': input,
      'followUp': followUp?.toJson(),
    };
  }

  @override
  String toString() {
    return 'QuestionDto{id: $id, question: $question, type: $type, input: $input, followUp: $followUp}';
  }
}

/// 설문 페이지 DTO
class SurveyPageDto {
  final int page;
  final String title;
  final List<QuestionDto> questions;

  const SurveyPageDto({
    required this.page,
    required this.title,
    required this.questions,
  });

  factory SurveyPageDto.fromJson(Map<String, dynamic> json) {
    return SurveyPageDto(
      page: json['page'] ?? 0,
      title: json['title'] ?? '',
      questions: (json['questions'] as List<dynamic>?)
          ?.map((q) => QuestionDto.fromJson(q))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'title': title,
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'SurveyPageDto{page: $page, title: $title, questions: ${questions.length} questions}';
  }
}

/// 시간별 설문 데이터 DTO
class SurveyByTimeDto {
  final String time;
  final List<SurveyPageDto> pages;

  const SurveyByTimeDto({
    required this.time,
    required this.pages,
  });

  factory SurveyByTimeDto.fromJson(Map<String, dynamic> json) {
    return SurveyByTimeDto(
      time: json['time'] ?? '',
      pages: (json['pages'] as List<dynamic>?)
          ?.map((p) => SurveyPageDto.fromJson(p))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'time': time,
      'pages': pages.map((p) => p.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'SurveyByTimeDto{time: $time, pages: ${pages.length} pages}';
  }
}
