import 'package:mindrhythms/dto/login_dto.dart';
import 'package:mindrhythms/dto/survey_info_dto.dart';
import 'package:mindrhythms/dto/survey_status_dto.dart';
import 'package:mindrhythms/dto/survey_by_time_dto.dart';

/// 전체 설문 데이터 DTO (surveys 배열의 각 항목)
class SurveyDto {
  final SurveyInfoDto surveyInfo;
  final List<SurveyStatusDto> surveyStatus;
  final List<SurveyByTimeDto> surveyByTime;

  const SurveyDto({
    required this.surveyInfo,
    required this.surveyStatus,
    required this.surveyByTime,
  });

  factory SurveyDto.fromJson(Map<String, dynamic> json) {
    return SurveyDto(
      surveyInfo: SurveyInfoDto.fromJson(json['surveyInfo'] ?? {}),
      surveyStatus: (json['surveyStatus'] as List<dynamic>?)
          ?.map((s) => SurveyStatusDto.fromJson(s))
          .toList() ?? [],
      surveyByTime: (json['surveyByTime'] as List<dynamic>?)
          ?.map((s) => SurveyByTimeDto.fromJson(s))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'surveyInfo': surveyInfo.toJson(),
      'surveyStatus': surveyStatus.map((s) => s.toJson()).toList(),
      'surveyByTime': surveyByTime.map((s) => s.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'SurveyDto{surveyInfo: $surveyInfo, surveyStatus: ${surveyStatus.length} statuses, surveyByTime: ${surveyByTime.length} times}';
  }
}

/// API 응답의 data 부분 DTO
class ApiDataDto {
  final LoginDto login;
  final List<SurveyDto> surveys;

  const ApiDataDto({
    required this.login,
    required this.surveys,
  });

  factory ApiDataDto.fromJson(Map<String, dynamic> json) {
    return ApiDataDto(
      login: LoginDto.fromJson(json['login'] ?? {}),
      surveys: (json['surveys'] as List<dynamic>?)
          ?.map((s) => SurveyDto.fromJson(s))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'login': login.toJson(),
      'surveys': surveys.map((s) => s.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'ApiDataDto{login: $login, surveys: ${surveys.length} surveys}';
  }
}

/// 전체 API 응답 DTO
class UserLoginResponseDto {
  final int code;
  final String message;
  final ApiDataDto data;

  const UserLoginResponseDto({
    required this.code,
    required this.message,
    required this.data,
  });

  /// 성공 여부 확인
  bool get isSuccess => code == 200;

  /// 로그인 성공 여부 확인
  bool get isLoginSuccess => data.login.success;

  /// 설문 데이터 가져오기
  List<SurveyDto> get surveys => data.surveys;

  /// 첫 번째 설문 정보 (보통 하나의 설문이 있을 것으로 예상)
  SurveyDto? get firstSurvey => surveys.isNotEmpty ? surveys.first : null;

  factory UserLoginResponseDto.fromJson(Map<String, dynamic> json) {
    return UserLoginResponseDto(
      code: json['code'] ?? 0,
      message: json['message'] ?? '',
      data: ApiDataDto.fromJson(json['data'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
      'data': data.toJson(),
    };
  }

  /// 로컬 저장을 위한 간소화된 데이터
  Map<String, dynamic> toStorageData() {
    return {
      'lastUpdated': DateTime.now().toIso8601String(),
      'code': code,
      'message': message,
      'loginSuccess': isLoginSuccess,
      'loginMessage': data.login.msg,
      'surveys': surveys.map((s) => s.toJson()).toList(),
    };
  }

  /// 로컬 저장 데이터에서 복원
  static UserLoginResponseDto fromStorageData(Map<String, dynamic> storageData) {
    return UserLoginResponseDto(
      code: storageData['code'] ?? 200,
      message: storageData['message'] ?? '로컬 데이터 로드 성공',
      data: ApiDataDto(
        login: LoginDto(
          success: storageData['loginSuccess'] ?? false,
          msg: storageData['loginMessage'] ?? '로컬 데이터 로드',
        ),
        surveys: (storageData['surveys'] as List<dynamic>?)
            ?.map((s) => SurveyDto.fromJson(s))
            .toList() ?? [],
      ),
    );
  }

  @override
  String toString() {
    return 'UserLoginResponseDto{code: $code, message: $message, data: $data}';
  }
}
