import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
      
      // 요청 바디 생성
      final body = jsonEncode({
        'userCode': userCode,
      });
      
      debugPrint('로그인 API 요청: $url');
      debugPrint('요청 바디: $body');
      
      // POST 요청 보내기 (타임아웃 시간 증가)
      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: body,
      ).timeout(const Duration(seconds: 30)); // 30초로 타임아웃 증가
      
      debugPrint('응답 상태 코드: ${response.statusCode}');
      debugPrint('응답 바디: ${response.body}');
      
      // 응답 처리
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // 실제 응답 구조 확인 (code, message, data 형태)
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
        // 상태 코드가 200이 아닌 경우 (4xx, 5xx 등)
        String errorMessage;
        
        try {
          // 응답 본문이 JSON 형식인지 확인
          final responseData = jsonDecode(response.body);
          errorMessage = responseData['message'] ?? '서버 오류: ${response.statusCode}';
        } catch (e) {
          // JSON이 아닌 경우 응답 본문 그대로 사용
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
  
  // 두 번째 API 메서드 (추후 구현)
  static Future<ApiResponse<Map<String, dynamic>>> secondApiMethod() async {
    // 두 번째 API 구현
    throw UnimplementedError('두 번째 API 메서드가 아직 구현되지 않았습니다.');
  }
}