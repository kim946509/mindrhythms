import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'db.dart';

class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final int? statusCode;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.statusCode,
  });
}

class ApiService {
  static const String baseUrl = 'https://steam-v2.ansandy.co.kr/api';
  
  // 기본 헤더
  static Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }
  
  // 로그인 API
  static Future<ApiResponse<Map<String, dynamic>>> login(String userCode) async {
    try {
      final url = Uri.parse('$baseUrl/user/login');
      
      final body = jsonEncode({
        'userCode': userCode,
      });
      
      debugPrint('로그인 API 요청: $url');
      debugPrint('요청 바디: $body');
      
      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: body,
      ).timeout(const Duration(seconds: 30));
      
      debugPrint('응답 상태 코드: ${response.statusCode}');
      debugPrint('응답 바디: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['code'] == 200) {
          return ApiResponse(
            success: true,
            message: responseData['message'] ?? '로그인 성공',
            data: responseData['data'],
            statusCode: response.statusCode,
          );
        } else {
          return ApiResponse(
            success: false,
            message: responseData['message'] ?? '로그인 실패',
            statusCode: response.statusCode,
          );
        }
      } else {
        String errorMessage;
        
        try {
          final responseData = jsonDecode(response.body);
          errorMessage = responseData['message'] ?? '서버 오류: ${response.statusCode}';
        } catch (e) {
          errorMessage = response.body;
        }
        
        debugPrint('API 오류 응답: $errorMessage');
        
        return ApiResponse(
          success: false,
          message: errorMessage,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('로그인 API 오류: $e');
      return ApiResponse(
        success: false,
        message: '네트워크 오류: $e',
      );
    }
  }
  
  /// 설문 답변을 서버에 제출하는 API
  static Future<ApiResponse<Map<String, dynamic>>> submitSurveyResponses(
    int surveyId,
    String time,
    Map<String, dynamic> allQuestionAnswers,
  ) async {
    try {
      debugPrint('📤 설문 답변 서버 전송 시작...');
      debugPrint('📊 설문 정보: surveyId=$surveyId, time=$time');
      
      final db = await DataBaseManager.database;
      
      // 1. 사용자 정보 조회
      final userInfo = await db.query('user_info', limit: 1);
      if (userInfo.isEmpty) {
        debugPrint('❌ 사용자 정보를 찾을 수 없습니다.');
        return ApiResponse(
          success: false,
          message: '사용자 정보를 찾을 수 없습니다.',
        );
      }
      
      final userCode = userInfo.first['user_id'];
      if (userCode == null || userCode.toString().trim().isEmpty) {
        debugPrint('❌ 사용자 코드가 null이거나 비어있습니다. userCode: $userCode');
        return ApiResponse(
          success: false,
          message: '사용자 코드 정보가 올바르지 않습니다.',
        );
      }
      
      final userCodeString = userCode.toString();
      debugPrint('👤 사용자 코드: $userCodeString');
      
      // 2. 설문 정보 조회
      debugPrint('🔍 설문 정보 조회 시작: surveyId=$surveyId');
      
      final surveyInfo = await db.query(
        'survey',
        where: 'id = ?',
        whereArgs: [surveyId],
        limit: 1,
      );
      
      if (surveyInfo.isEmpty) {
        debugPrint('❌ 설문 정보를 찾을 수 없습니다. surveyId: $surveyId');
        return ApiResponse(
          success: false,
          message: '설문 정보를 찾을 수 없습니다. (ID: $surveyId)',
        );
      }
      
      final surveyName = surveyInfo.first['survey_name'];
      if (surveyName == null || surveyName.toString().trim().isEmpty) {
        debugPrint('❌ 설문 이름이 null이거나 비어있습니다. surveyId: $surveyId, surveyName: $surveyName');
        return ApiResponse(
          success: false,
          message: '설문 이름 정보가 올바르지 않습니다.',
        );
      }
      
      final surveyNameString = surveyName.toString();
      debugPrint('📋 설문 이름: $surveyNameString');
      
      // 3. API 요청 데이터 구성
      final requestData = {
        "userCode": userCodeString,
        "surveyName": surveyNameString,
        "time": time,
        "responses": _buildResponsesArray(allQuestionAnswers),
      };
      
      debugPrint('📋 API 요청 데이터 구성 완료');
      debugPrint('📋 요청 데이터: ${jsonEncode(requestData)}');
      
      // 4. API 호출
      final url = Uri.parse('$baseUrl/surveys/responses');
      debugPrint('🌐 API 엔드포인트: $url');
      
      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: jsonEncode(requestData),
      ).timeout(const Duration(seconds: 30));
      
      debugPrint('📡 API 응답 상태 코드: ${response.statusCode}');
      debugPrint('📡 API 응답 본문: ${response.body}');
      
      // 5. 응답 처리
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['code'] == 200) {
          final savedCount = responseData['data'] as int;
          debugPrint('✅ 설문 답변 저장 성공! 저장된 문항 수: $savedCount');
          
          return ApiResponse(
            success: true,
            message: responseData['message'] ?? '응답이 저장되었습니다.',
            data: responseData,
            statusCode: response.statusCode,
          );
        } else {
          final errorCode = responseData['code'] as String?;
          debugPrint('❌ API 비즈니스 로직 오류: $errorCode');
          
          return ApiResponse(
            success: false,
            message: _getUserFriendlyErrorMessage(errorCode),
            data: responseData,
            statusCode: response.statusCode,
          );
        }
      } else {
        String errorMessage;
        
        try {
          final responseData = jsonDecode(response.body);
          errorMessage = responseData['message'] ?? '서버 오류: ${response.statusCode}';
        } catch (e) {
          errorMessage = '서버 오류: ${response.statusCode}';
        }
        
        debugPrint('❌ HTTP 오류: $errorMessage');
        
        return ApiResponse(
          success: false,
          message: errorMessage,
          statusCode: response.statusCode,
        );
      }
      
    } catch (e) {
      debugPrint('❌ 설문 답변 전송 중 오류 발생: $e');
      return ApiResponse(
        success: false,
        message: '네트워크 오류가 발생했습니다. 다시 시도해주세요.',
      );
    }
  }
  
  /// 답변 데이터를 API 형식에 맞게 구성하는 메서드
  static List<Map<String, dynamic>> _buildResponsesArray(
    Map<String, dynamic> allQuestionAnswers,
  ) {
    final responses = <Map<String, dynamic>>[];
    
    debugPrint('📝 답변 데이터 구성 시작...');
    debugPrint('📝 총 답변 수: ${allQuestionAnswers.length}');
    
    allQuestionAnswers.forEach((questionId, answer) {
      if (!_isValidAnswer(answer)) {
        debugPrint('   질문 $questionId: 유효하지 않은 답변 제외 - $answer');
        return;
      }
      
      List<String> answerList;
      
      if (answer is List) {
        answerList = answer
            .where((item) => item != null && item.toString().trim().isNotEmpty)
            .map((e) => e.toString())
            .toList();
        
        if (answerList.isEmpty) {
          debugPrint('   질문 $questionId: 빈 배열 답변 제외');
          return;
        }
      } else {
        answerList = [answer.toString()];
      }
      
      responses.add({
        "id": _safeParseInt(questionId),
        "answer": answerList,
      });
      
      debugPrint('   질문 $questionId: $answerList');
    });
    
    debugPrint('📝 구성된 responses 배열: $responses');
    return responses;
  }
  
  /// 문자열을 안전하게 int로 변환하는 메서드
  /// 
  /// questionId가 "2_09:00_4" 형태일 때 마지막 숫자 부분만 추출
  /// 예시: "2_09:00_4" → 4, "2_09:00_15" → 15
  static int _safeParseInt(String value) {
    try {
      // 먼저 직접 int 변환 시도
      return int.parse(value);
    } catch (e) {
      // 실패 시 언더스코어가 포함된 형태인지 확인
      if (value.contains('_')) {
        try {
          // 마지막 언더스코어 이후의 숫자 부분 추출
          final parts = value.split('_');
          if (parts.isNotEmpty) {
            final lastPart = parts.last;
            final parsedInt = int.parse(lastPart);
            debugPrint('✅ questionId 파싱 성공: $value → $parsedInt (마지막 부분 추출)');
            return parsedInt;
          }
        } catch (e2) {
          debugPrint('⚠️ questionId 마지막 부분 추출 실패: $value, 오류: $e2');
        }
      }
      
      debugPrint('⚠️ questionId를 int로 변환 실패: $value, 오류: $e');
      return 0;
    }
  }
  
  /// 답변이 유효한지 확인하는 메서드
  static bool _isValidAnswer(dynamic answer) {
    if (answer == null) return false;
    
    if (answer is String) {
      return answer.trim().isNotEmpty;
    }
    
    if (answer is List) {
      return answer.isNotEmpty && answer.any((item) => 
        item != null && item.toString().trim().isNotEmpty
      );
    }
    
    return true;
  }
  
  /// API 오류 코드를 사용자 친화적인 메시지로 변환하는 메서드
  static String _getUserFriendlyErrorMessage(String? errorCode) {
    switch (errorCode) {
      case 'INVALID_INPUT':
        return '입력 데이터에 문제가 있습니다. 다시 시도해주세요.';
      case 'INVALID_SURVEY_TIME':
        return '설문 시간 형식이 올바르지 않습니다.';
      case 'INVALID_USER_CODE':
        return '사용자 정보가 유효하지 않습니다.';
      case 'SURVEY_NOT_FOUND':
        return '설문을 찾을 수 없습니다.';
      default:
        return '설문 저장 중 오류가 발생했습니다. 다시 시도해주세요.';
    }
  }
}