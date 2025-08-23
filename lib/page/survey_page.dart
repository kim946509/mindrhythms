import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../feature/db.dart';
import '../feature/api.dart';
import '../widget/single_choice_question_widget.dart';
import '../widget/multiple_choice_question_widget.dart';
import '../widget/nine_point_scale_question_widget.dart';
import '../widget/txt_choice_question_widget.dart';
import '../widget/common_large_button.dart';

/// 설문 페이지를 관리하는 컨트롤러
/// 
/// 주요 기능:
/// 1. 설문 페이지 및 질문 데이터 로드
/// 2. followUp 로직에 따른 동적 질문 표시
/// 3. 사용자 답변 관리 및 상태 추적
/// 4. 페이지 간 네비게이션
class SurveyPageController extends GetxController {
  // === 기본 정보 ===
  final int surveyId;        // 설문 ID
  final String time;         // 설문 시간 (예: "09:00")
  
  // === 데이터 상태 ===
  var pages = <Map<String, dynamic>>[];           // 설문 페이지 목록
  var currentPageIndex = 0;                       // 현재 페이지 인덱스
  var isLoading = true;                           // 로딩 상태
  
  // === 질문 가시성 관리 ===
  /// 페이지별로 질문의 표시 여부를 관리
  /// Key: pageId, Value: {questionId: visible}
  var pageVisibleQuestions = <int, Map<String, bool>>{};
  
  // === 답변 관리 ===
  /// 모든 질문의 답변을 저장하는 Map
  /// Key: questionId, Value: 사용자 답변
  var allQuestionAnswers = <String, dynamic>{};
  
  // === FollowUp 로직 관리 ===
  /// 질문별 followUp 조건과 다음 질문들을 관리
  /// Key: questionId, Value: {condition: [...], then: [...]}
  var questionFollowUpMap = <String, Map<String, dynamic>>{};
  
  SurveyPageController({
    required this.surveyId,
    required this.time,
  });
  
  @override
  void onInit() {
    super.onInit();
    _loadSurveyPages();
  }
  
  // ========================================
  // 데이터 로드 및 초기화
  // ========================================
  
  /// 설문 페이지와 질문 데이터를 로드하는 메서드
  /// 
  /// 로드 과정:
  /// 1. survey_page 테이블에서 해당 설문의 페이지 조회
  /// 2. 각 페이지별로 survey_question 테이블에서 질문 조회
  /// 3. JSON 형태의 input_options와 follow_up 파싱
  /// 4. followUp Map과 질문 가시성 초기화
  Future<void> _loadSurveyPages() async {
    try {
      isLoading = true;
      update();
      
      debugPrint('설문 페이지 로드 시작: surveyId=$surveyId, time=$time');
      
      final db = await DataBaseManager.database;
      
      // 1단계: 해당 설문의 해당 시간대 페이지들을 조회
      final surveyPages = await db.query(
        'survey_page',
        where: 'survey_id = ? AND time = ?',
        whereArgs: [surveyId, time],
        orderBy: 'page_number ASC',
      );
      
      debugPrint('페이지 쿼리 결과: ${surveyPages.length}개의 페이지 발견');
      
      // 각 페이지별로 질문 정보를 개별적으로 조회
      pages = [];
      for (final page in surveyPages) {
        final pageId = page['id'] as int;
        final pageNumber = page['page_number'] as int;
        final pageTitle = page['title'] as String;
        
        debugPrint('');
        debugPrint('📖 === 페이지 $pageNumber 로드 시작 ===');
        debugPrint('📖 페이지 ID: $pageId');
        debugPrint('📖 페이지 제목: $pageTitle');
        
        // 해당 페이지의 질문들 조회
        final questions = await db.query(
          'survey_question',
          where: 'page_id = ?',
          whereArgs: [pageId],
          orderBy: 'id ASC',
        );
        
        debugPrint('📖 페이지 $pageNumber 질문 조회 결과: ${questions.length}개');
        
        // 각 질문의 상세 정보 출력
        for (int i = 0; i < questions.length; i++) {
          final question = questions[i];
          debugPrint('📖   ${i + 1}. 질문 ID: ${question['id']}');
          debugPrint('📖      텍스트: ${question['question_text']}');
          debugPrint('📖      타입: ${question['question_type']}');
          debugPrint('📖      페이지 ID: ${question['page_id']}');
        }
        
        // 질문 데이터 파싱 및 구조화
        final questionsList = questions.map((q) {
          dynamic inputOptions;
          dynamic followUp;
          
          // input_options JSON 파싱
          try {
            inputOptions = jsonDecode(q['input_options'] as String);
          } catch (e) {
            inputOptions = [];
          }
          
          // follow_up JSON 파싱
          try {
            followUp = jsonDecode(q['follow_up'] as String);
          } catch (e) {
            followUp = null;
          }
          
          return {
            'id': q['id'],
            'question_text': q['question_text'],
            'question_type': q['question_type'],
            'input_options': inputOptions,
            'follow_up': followUp,
          };
        }).toList();
        
        // 페이지 정보를 pages 배열에 추가
        pages.add({
          'id': page['id'],
          'page_number': page['page_number'],
          'title': page['title'],
          'questions': questionsList,
        });
        
        debugPrint('📖 페이지 $pageNumber 파싱 완료: ${questionsList.length}개 질문 처리됨');
        debugPrint('📖 === 페이지 $pageNumber 로드 완료 ===');
      }
      
      debugPrint('');
      debugPrint('🎯 === 전체 페이지 로드 요약 ===');
      debugPrint('🎯 총 페이지 수: ${pages.length}');
      for (int i = 0; i < pages.length; i++) {
        final page = pages[i];
        final pageNumber = page['page_number'] as int;
        final questionCount = (page['questions'] as List).length;
        debugPrint('🎯 페이지 $pageNumber: $questionCount개 질문');
      }
      debugPrint('🎯 === 전체 페이지 로드 요약 완료 ===');
      
      // 3단계: followUp Map과 질문 가시성 초기화
      _initializeQuestionFollowUpMap();
      _initializePageVisibleQuestions();
      
      debugPrint('페이지 파싱 완료: ${pages.length}개의 페이지 처리됨');
      
    } catch (e) {
      debugPrint('설문 페이지 로드 오류: $e');
    } finally {
      isLoading = false;
      update();
    }
  }
  
  /// 질문별 followUp Map을 초기화하는 메서드
  /// 
  /// followUp 데이터 구조:
  /// {
  ///   "condition": ["예", "아니오"],  // 조건 값들
  ///   "then": ["2_09:00_2", "2_09:00_3"]  // 조건 만족 시 표시할 질문 ID들
  /// }
  void _initializeQuestionFollowUpMap() {
    questionFollowUpMap.clear();
    
    for (final page in pages) {
      final questions = page['questions'] as List<Map<String, dynamic>>;
      
      for (final question in questions) {
        final questionId = question['id'].toString();
        final followUp = question['follow_up'];
        
        // followUp 데이터가 있고 Map 형태인 경우만 처리
        if (followUp != null && followUp is Map) {
          final condition = followUp['condition'] as List?;
          final thenQuestions = followUp['then'] as List?;
          
          // condition과 then이 모두 존재하는 경우만 Map에 추가
          if (condition != null && thenQuestions != null) {
            questionFollowUpMap[questionId] = {
              'condition': condition,
              'then': thenQuestions,
            };
          }
        }
      }
    }
    
    debugPrint('질문별 followUp Map 초기화 완료: $questionFollowUpMap');
  }
  
  /// 페이지별 질문 가시성을 초기화하는 메서드
  /// 
  /// 초기 상태:
  /// - 첫 번째 질문: 항상 visible (true)
  /// - 나머지 질문들: 기본적으로 invisible (false)
  /// 
  /// followUp 로직에 따라 동적으로 변경됨
  void _initializePageVisibleQuestions() {
    pageVisibleQuestions.clear();
    
    for (final page in pages) {
      final pageId = page['id'] as int;
      final questions = page['questions'] as List<Map<String, dynamic>>;
      
      pageVisibleQuestions[pageId] = <String, bool>{};
      
      if (questions.isNotEmpty) {
        // 첫 번째 질문은 항상 visible
        pageVisibleQuestions[pageId]![questions.first['id'].toString()] = true;
        
        // 나머지 질문들은 기본적으로 invisible
        for (int i = 1; i < questions.length; i++) {
          pageVisibleQuestions[pageId]![questions[i]['id'].toString()] = false;
        }
      }
    }
    
    debugPrint('페이지별 visible 초기화 완료: $pageVisibleQuestions');
  }
  
  // ========================================
  // 데이터 접근자 (Getters)
  // ========================================
  
  /// 현재 페이지 정보를 반환
  Map<String, dynamic>? get currentPage {
    if (currentPageIndex >= 0 && currentPageIndex < pages.length) {
      return pages[currentPageIndex];
    }
    return null;
  }
  
  /// 현재 페이지의 visible한 질문들만 반환
  List<Map<String, dynamic>> get currentPageQuestions {
    final page = currentPage;
    if (page == null) return <Map<String, dynamic>>[];
    
    final pageId = page['id'] as int;
    final questions = page['questions'] as List<Map<String, dynamic>>;
    
    // pageVisibleQuestions에서 visible한 질문들만 필터링하여 반환
    return questions.where((q) => 
        pageVisibleQuestions[pageId]?[q['id'].toString()] == true).toList();
  }
  
  // ========================================
  // 답변 처리 및 FollowUp 로직
  // ========================================
  
  /// 사용자 답변을 저장하고 followUp 로직을 처리하는 메서드
  /// 
  /// 처리 과정:
  /// 1. 답변을 allQuestionAnswers에 저장
  /// 2. followUp 조건에 따라 다음 질문의 가시성 결정
  /// 3. UI 업데이트
  void saveAnswer(String questionId, dynamic value) {
    // 답변을 전체 질문 답변 Map에 저장
    allQuestionAnswers[questionId] = value;
    
    // followUp 로직 처리
    _processFollowUp(questionId, value);
    
    // 현재 페이지 완료 상태 로그 출력 (디버깅용)
    final isComplete = isCurrentPageComplete;
    final visibleQuestions = currentPageQuestions;
    debugPrint('질문 $questionId 답변 저장 후 페이지 완료 상태: $isComplete (visible 질문 수: ${visibleQuestions.length})');
    debugPrint('현재 페이지 답변 상태: $allQuestionAnswers');
    
    // UI 업데이트
    update();
  }
  
  /// FollowUp 로직을 처리하는 핵심 메서드
  /// 
  /// FollowUp 동작 원리:
  /// 1. 사용자가 질문에 답변
  /// 2. followUp이 있는 질문의 답변을 변경한 경우에만:
  ///    - 현재 질문 이후의 질문들을 invisible로 설정
  ///    - followUp 조건에 따라 다음 질문의 가시성 결정
  /// 3. followUp이 없는 질문은 기존 상태 유지
  /// 
  /// 예시:
  /// - 질문: "어제 음주를 하셨습니까?" (followUp 있음)
  /// - 답변: "예" → then 배열의 질문들 표시 (2번, 3번)
  /// - 답변: "아니오" → then 배열을 건너뛰고 4번 질문 표시
  /// 
  /// - 질문: "이름을 입력해주세요" (followUp 없음)
  /// - 답변 입력 → 기존 상태 유지, 다음 질문 표시
  void _processFollowUp(String questionId, dynamic answer) {
    final page = currentPage;
    if (page == null) return;
    
    debugPrint('=== followUp 처리 시작 ===');
    debugPrint('질문 ID: $questionId, 답변: $answer');
    
    final followUpData = questionFollowUpMap[questionId];
    debugPrint('질문 $questionId의 followUp 데이터: $followUpData');
    
    final pageId = page['id'] as int;
    
    // followUp이 있는 질문의 답변을 변경한 경우에만 상태 초기화
    if (followUpData != null) {
      // 현재 질문 이후의 모든 질문들을 invisible로 설정 (상태 초기화)
      _resetQuestionsAfterCurrent(pageId, questionId);
      
      final condition = followUpData['condition'] as List;
      final thenQuestions = followUpData['then'] as List;
      
      debugPrint('condition: $condition, thenQuestions: $thenQuestions');
      
      // 답변이 조건과 일치하는지 확인
      final shouldShowThen = condition.contains(answer.toString());
      debugPrint('답변이 condition과 일치하는가? $shouldShowThen');
      
      if (shouldShowThen) {
        // 조건에 맞으면 then 배열의 첫 번째 질문을 visible로 설정
        if (thenQuestions.isNotEmpty) {
          final nextQuestionId = thenQuestions.first.toString();
          pageVisibleQuestions[pageId]![nextQuestionId] = true;
          debugPrint('then 배열의 첫 번째 질문 $nextQuestionId를 visible로 설정');
        }
      } else {
        // 조건에 맞지 않으면 then 배열에 포함되지 않은 다음 순서의 질문을 visible로 설정
        final questions = page['questions'] as List<Map<String, dynamic>>;
        final currentIndex = questions.indexWhere(
          (q) => q['id'].toString() == questionId,
        );
        
        if (currentIndex != -1) {
          int nextIndex = currentIndex + 1;
          
          // then 배열에 포함된 질문들을 건너뛰기
          while (nextIndex < questions.length) {
            final nextQuestion = questions[nextIndex];
            final nextQuestionId = nextQuestion['id'].toString();
            
            if (!thenQuestions.contains(nextQuestionId)) {
              // then 배열에 포함되지 않은 질문을 visible로 설정
              pageVisibleQuestions[pageId]![nextQuestionId] = true;
              debugPrint('then 배열을 건너뛰고 질문 $nextQuestionId를 visible로 설정: ${nextQuestion['question_text']}');
              break;
            }
            
            debugPrint('질문 $nextQuestionId를 건너뛰기 (then 배열에 포함됨)');
            nextIndex++;
          }
        }
      }
    } else {
      // followUp이 없으면 다음 순서의 질문을 visible로 설정 (기존 상태 유지)
      debugPrint('followUp이 없음 - 다음 순서의 질문을 visible로 설정');
      final questions = page['questions'] as List<Map<String, dynamic>>;
      final currentIndex = questions.indexWhere(
        (q) => q['id'].toString() == questionId,
      );
      
      if (currentIndex != -1 && currentIndex < questions.length - 1) {
        final nextQuestion = questions[currentIndex + 1];
        final nextQuestionId = nextQuestion['id'].toString();
        
        // 이미 visible한 상태라면 그대로 유지, 아니면 visible로 설정
        if (pageVisibleQuestions[pageId]?[nextQuestionId] != true) {
          pageVisibleQuestions[pageId]![nextQuestionId] = true;
          debugPrint('다음 질문 $nextQuestionId를 visible로 설정: ${nextQuestion['question_text']}');
        } else {
          debugPrint('다음 질문 $nextQuestionId는 이미 visible 상태');
        }
      }
    }
    
    debugPrint('현재 pageVisibleQuestions 상태: $pageVisibleQuestions');
    debugPrint('=== followUp 처리 완료 ===');
  }
  
  /// 현재 질문 이후의 모든 질문들을 invisible로 설정하는 메서드
  /// 
  /// 목적:
  /// - 사용자가 답변을 변경했을 때 이전 상태를 초기화
  /// - followUp 로직에 따라 새로운 질문 흐름을 구성
  /// - 기존에 입력된 답변 값들도 함께 삭제
  void _resetQuestionsAfterCurrent(int pageId, String currentQuestionId) {
    final page = currentPage;
    if (page == null) return;
    
    final questions = page['questions'] as List<Map<String, dynamic>>;
    final currentIndex = questions.indexWhere(
      (q) => q['id'].toString() == currentQuestionId,
    );
    
    if (currentIndex != -1) {
      // 현재 질문 이후의 모든 질문들을 invisible로 설정하고 답변 값 삭제
      for (int i = currentIndex + 1; i < questions.length; i++) {
        final questionId = questions[i]['id'].toString();
        
        // 질문을 invisible로 설정
        pageVisibleQuestions[pageId]![questionId] = false;
        
        // 기존에 입력된 답변 값 삭제
        if (allQuestionAnswers.containsKey(questionId)) {
          allQuestionAnswers.remove(questionId);
          debugPrint('질문 $questionId의 답변 값 삭제: ${questions[i]['question_text']}');
        }
        
        debugPrint('질문 $questionId를 invisible로 설정하고 답변 값 삭제');
      }
      
      // 현재 페이지 완료 상태 로그 출력 (디버깅용)
      final isComplete = isCurrentPageComplete;
      final visibleQuestions = currentPageQuestions;
      debugPrint('질문 $currentQuestionId 답변 변경 후 페이지 $pageId 완료 상태: $isComplete (visible 질문 수: ${visibleQuestions.length})');
      debugPrint('현재 페이지 답변 상태: $allQuestionAnswers');
    }
  }
  
  // ========================================
  // 페이지 완료 상태 확인
  // ========================================
  
  /// 현재 페이지의 모든 visible한 질문에 답변이 있는지 확인
  /// 
  /// 반환값:
  /// - true: 모든 질문에 답변 완료 → 다음 버튼 활성화
  /// - false: 일부 질문에 답변 없음 → 다음 버튼 비활성화
  bool get isCurrentPageComplete {
    final questions = currentPageQuestions;
    if (questions.isEmpty) return true;
    
    for (final question in questions) {
      final questionId = question['id'].toString();
      final answer = allQuestionAnswers[questionId];
      
      // 답변이 없거나 빈 배열인 경우 답변 미완료로 처리
      if (!_hasValidAnswer(answer)) {
        return false;
      }
    }
    return true;
  }
  
  /// 답변이 유효한지 확인하는 메서드
  /// 
  /// 유효하지 않은 답변:
  /// - null
  /// - 빈 문자열 ""
  /// - 빈 배열 []
  /// 
  /// 유효한 답변:
  /// - null이 아닌 값
  /// - 비어있지 않은 문자열
  /// - 비어있지 않은 배열
  bool _hasValidAnswer(dynamic answer) {
    if (answer == null) return false;
    
    if (answer is String) {
      return answer.trim().isNotEmpty;
    }
    
    if (answer is List) {
      return answer.isNotEmpty && answer.any((item) => 
        item != null && item.toString().trim().isNotEmpty
      );
    }
    
    // 기타 타입 (int, double 등)은 null이 아니면 유효
    return true;
  }
  
  // ========================================
  // 페이지 네비게이션
  // ========================================
  
  /// 다음 페이지로 이동하는 메서드
  /// 
  /// 동작:
  /// 1. 다음 페이지가 있으면: 페이지 인덱스 증가 및 질문 가시성 초기화
  /// 2. 마지막 페이지면: 설문 완료 처리
  void nextPage() {
    if (currentPageIndex < pages.length - 1) {
      currentPageIndex++;
      // 새 페이지의 질문 가시성 초기화
      _initializePageVisibleQuestions();
      update();
    } else {
      // 설문 완료
      _completeSurvey();
    }
  }
  
  /// 페이지의 질문 가시성을 답변 상태에 따라 복원하는 메서드
  /// 
  /// 사용 시기:
  /// - 뒤로가기 버튼으로 이전 페이지로 이동할 때
  /// - 이전 페이지에서 답변한 질문들을 다시 표시
  /// 
  /// 복원 로직:
  /// - 첫 번째 질문: 항상 visible
  /// - 나머지 질문들: allQuestionAnswers에 답변이 있는 경우만 visible
  void _restorePageVisibleQuestions() {
    final page = currentPage;
    if (page == null) return;
    
    final pageId = page['id'] as int;
    final questions = page['questions'] as List<Map<String, dynamic>>;
    
    // 페이지별 visible 초기화
    pageVisibleQuestions[pageId] = <String, bool>{};
    
    if (questions.isNotEmpty) {
      // 첫 번째 질문은 항상 visible
      pageVisibleQuestions[pageId]![questions.first['id'].toString()] = true;
      
      // 답변이 있는 질문들만 visible로 설정
      for (int i = 1; i < questions.length; i++) {
        final questionId = questions[i]['id'].toString();
        
        // 현재 질문에 답변이 있으면 visible로 설정
        if (allQuestionAnswers.containsKey(questionId)) {
          pageVisibleQuestions[pageId]![questionId] = true;
        } else {
          pageVisibleQuestions[pageId]![questionId] = false;
        }
      }
    }
    
    debugPrint('페이지 $pageId의 질문 가시성 복원 완료: ${pageVisibleQuestions[pageId]}');
    
    // 현재 페이지 완료 상태 로그 출력 (디버깅용)
    final isComplete = isCurrentPageComplete;
    final visibleQuestions = currentPageQuestions;
    debugPrint('페이지 $pageId 완료 상태: $isComplete (visible 질문 수: ${visibleQuestions.length})');
    debugPrint('현재 페이지 답변 상태: $allQuestionAnswers');
  }
  
  // ========================================
  // 설문 완료 처리
  // ========================================
  
  /// 설문 완료 시 호출되는 메서드
  /// 
  /// TODO: 
  /// - 답변 데이터를 서버에 전송
  /// - 결과 페이지로 이동
  /// - 설문 완료 상태 업데이트
  void _completeSurvey() {
    // === 설문 완료 시 상세한 답변 상태 로그 ===
    debugPrint('🎉 === 설문 완료! 상세한 답변 상태 === 🎉');
    debugPrint('📊 설문 정보: surveyId=$surveyId, time=$time');
    debugPrint('📄 총 페이지 수: ${pages.length}');
    debugPrint('📝 총 답변한 질문 수: ${allQuestionAnswers.length}');
    
    // 각 페이지별로 질문과 답변 상태 출력
    for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final page = pages[pageIndex];
      final pageId = page['id'] as int;
      final pageTitle = page['title'] as String;
      final questions = page['questions'] as List<Map<String, dynamic>>;
      
      debugPrint('');
      debugPrint('📖 페이지 ${pageIndex + 1}: $pageTitle (ID: $pageId)');
      debugPrint('   └─ 총 질문 수: ${questions.length}개');
      
      for (int qIndex = 0; qIndex < questions.length; qIndex++) {
        final question = questions[qIndex];
        final questionId = question['id'].toString();
        final questionText = question['question_text'] as String;
        final questionType = question['question_type'] as String;
        final isVisible = pageVisibleQuestions[pageId]?[questionId] == true;
        final hasAnswer = allQuestionAnswers.containsKey(questionId);
        final answer = allQuestionAnswers[questionId];
        
        // 질문 상태에 따른 아이콘과 텍스트
        String statusIcon = '❓';
        String statusText = '답변 없음';
        
        if (hasAnswer) {
          statusIcon = '✅';
          statusText = '답변 완료';
        } else if (isVisible) {
          statusIcon = '👁️';
          statusText = '표시됨 (답변 대기)';
        } else {
          statusIcon = '🚫';
          statusText = '숨김 처리됨';
        }
        
        debugPrint('   ${qIndex + 1}. $statusIcon $questionText');
        debugPrint('      ├─ 질문 ID: $questionId');
        debugPrint('      ├─ 질문 유형: $questionType');
        debugPrint('      ├─ 상태: $statusText');
        
        if (hasAnswer) {
          // 답변 값 상세 출력
          if (answer is List) {
            debugPrint('      ├─ 답변: [${answer.join(', ')}]');
          } else {
            debugPrint('      ├─ 답변: $answer');
          }
        }
        
        // FollowUp 정보 출력
        final followUp = question['follow_up'];
        if (followUp != null && followUp is Map) {
          final condition = followUp['condition'] as List?;
          final thenQuestions = followUp['then'] as List?;
          
          if (condition != null && thenQuestions != null) {
            debugPrint('      ├─ FollowUp 조건: $condition');
            debugPrint('      └─ Then 질문들: $thenQuestions');
          }
        } else {
          debugPrint('      └─ FollowUp: 없음');
        }
      }
    }
    
    // === 답변 요약 통계 ===
    debugPrint('');
    debugPrint('📈 === 답변 요약 통계 ===');
    
    // 질문 유형별 답변 통계
    Map<String, int> typeStats = {};
    Map<String, int> typeTotal = {};
    
    for (final page in pages) {
      final questions = page['questions'] as List<Map<String, dynamic>>;
      
      for (final question in questions) {
        final questionType = question['question_type'] as String;
        final questionId = question['id'].toString();
        final hasAnswer = allQuestionAnswers.containsKey(questionId);
        
        typeTotal[questionType] = (typeTotal[questionType] ?? 0) + 1;
        if (hasAnswer) {
          typeStats[questionType] = (typeStats[questionType] ?? 0) + 1;
        }
      }
    }
    
    debugPrint('질문 유형별 답변 현황:');
    typeTotal.forEach((type, total) {
      final answered = typeStats[type] ?? 0;
      final percentage = total > 0 ? ((answered / total) * 100).toStringAsFixed(1) : '0.0';
      debugPrint('   $type: $answered/$total ($percentage%)');
    });
    
    // 페이지별 완료율
    debugPrint('');
    debugPrint('페이지별 완료율:');
    for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final page = pages[pageIndex];
      final pageId = page['id'] as int;
      final questions = page['questions'] as List<Map<String, dynamic>>;
      
      int answeredCount = 0;
      for (final question in questions) {
        final questionId = question['id'].toString();
        if (allQuestionAnswers.containsKey(questionId)) {
          answeredCount++;
        }
      }
      
      final percentage = questions.isNotEmpty ? ((answeredCount / questions.length) * 100).toStringAsFixed(1) : '0.0';
      debugPrint('   페이지 ${pageIndex + 1}: $answeredCount/${questions.length} ($percentage%)');
    }
    
    // === 최종 완료 메시지 ===
    debugPrint('');
    debugPrint('🎯 설문 완료! 모든 답변 데이터가 로그에 출력되었습니다.');
    debugPrint('�� 다음 단계: 서버 전송 또는 결과 페이지 이동');
    debugPrint('🎉 === 설문 완료 로그 끝 === 🎉');
    
    // API 호출하여 답변 데이터 전송
    _submitSurveyResponses();
  }
  
  /// 설문 답변을 서버에 전송하는 메서드
  Future<void> _submitSurveyResponses() async {
    try {
      debugPrint('📤 설문 답변 서버 전송 시작...');
      
      // ApiService를 사용하여 설문 답변 제출
      final apiResponse = await ApiService.submitSurveyResponses(
        surveyId,
        time,
        allQuestionAnswers,
      );
      
      if (apiResponse.success) {
        // 성공 시 survey_status 테이블 업데이트
        await _updateSurveyStatus(true);
        
        // 성공 메시지 표시
        Get.snackbar(
          '설문 완료',
          apiResponse.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green[100],
          colorText: Colors.green[900],
        );
        
        // 홈 화면으로 이동
        Get.offAllNamed('/'); // 홈 화면으로 이동
        
      } else {
        // API 오류 메시지 표시
        Get.snackbar(
          '오류',
          apiResponse.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900],
        );
      }
      
    } catch (e) {
      debugPrint('❌ 설문 답변 전송 중 오류 발생: $e');
      Get.snackbar(
        '오류',
        '네트워크 오류가 발생했습니다. 다시 시도해주세요.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
      );
    }
  }
  
  /// survey_status 테이블을 업데이트하는 메서드
  Future<void> _updateSurveyStatus(bool isCompleted) async {
    try {
      final db = await DataBaseManager.database;
      
      // 오늘 날짜의 해당 시간대 설문 상태 업데이트
      final today = DateTime.now();
      final dateString = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      
      final result = await db.update(
        'survey_status',
        {
          'submitted': isCompleted ? 1 : 0,
          'submitted_at': DateTime.now().toIso8601String(),
        },
        where: 'survey_id = ? AND time = ? AND survey_date = ?',
        whereArgs: [surveyId, time, dateString],
      );
      
      if (result > 0) {
        debugPrint('✅ survey_status 테이블 업데이트 성공: $result개 행 수정됨');
      } else {
        debugPrint('⚠️ survey_status 테이블 업데이트 실패: 수정된 행이 없음');
      }
      
    } catch (e) {
      debugPrint('❌ survey_status 테이블 업데이트 중 오류: $e');
    }
  }
  
  // ========================================
  // 진행률 계산
  // ========================================
  
  /// 설문 진행률을 계산하는 getter
  /// 
  /// 계산 방식:
  /// - 분자: 답변한 질문 수 (allQuestionAnswers.length)
  /// - 분모: 동적으로 계산된 총 질문 수 (_calculateDynamicTotalQuestions)
  /// 
  /// 동적 질문 수란?
  /// - followUp 로직에 따라 실제로 표시될 질문들의 총 개수
  /// - 사용자의 답변에 따라 실시간으로 변함
  double get progress {
    if (pages.isEmpty) return 0.0;
    
    // 현재 답변 상태에 따른 동적 질문 수 계산
    int dynamicTotalQuestions = _calculateDynamicTotalQuestions();
    
    if (dynamicTotalQuestions == 0) return 0.0;
    
    // 답변한 질문 수 계산
    int answeredQuestions = allQuestionAnswers.length;
    
    debugPrint('동적 총 질문 수: $dynamicTotalQuestions, 답변한 질문 수: $answeredQuestions');
    
    return answeredQuestions / dynamicTotalQuestions;
  }
  
  /// 진행률을 텍스트로 표시하는 getter
  /// 
  /// 예시: "3/5 질문 완료"
  String get progressText {
    if (pages.isEmpty) return "0/0 질문 완료";
    
    int dynamicTotalQuestions = _calculateDynamicTotalQuestions();
    int answeredQuestions = allQuestionAnswers.length;
    
    return "$answeredQuestions/$dynamicTotalQuestions 질문 완료";
  }
  
  /// 현재 답변 상태에 따른 동적 질문 수를 계산하는 메서드
  /// 
  /// 계산 과정:
  /// 1. 각 페이지의 질문들을 순회
  /// 2. 첫 번째 질문은 항상 포함
  /// 3. 나머지 질문들은 이전 질문들의 followUp 조건에 따라 포함 여부 결정
  /// 
  /// 이 메서드는 진행률 바의 정확한 계산을 위해 필요
  int _calculateDynamicTotalQuestions() {
    int totalQuestions = 0;
    
    for (final page in pages) {
      final questions = page['questions'] as List<Map<String, dynamic>>;
      
      for (int i = 0; i < questions.length; i++) {
        final question = questions[i];
        final questionId = question['id'].toString();
        
        if (i == 0) {
          // 첫 번째 질문은 항상 포함
          totalQuestions++;
        } else {
          // 이전 질문들의 답변에 따라 현재 질문 포함 여부 결정
          bool shouldInclude = _shouldIncludeQuestion(questions, i);
          if (shouldInclude) {
            totalQuestions++;
          }
        }
      }
    }
    
    return totalQuestions;
  }
  
  /// 특정 질문이 현재 답변 상태에 따라 포함되어야 하는지 확인하는 메서드
  /// 
  /// 판단 기준:
  /// 1. 첫 번째 질문: 항상 포함
  /// 2. 나머지 질문들: 이전 질문들의 followUp 조건 확인
  /// 
  /// followUp 조건 확인:
  /// - 이전 질문의 답변이 condition과 일치하면: then 배열의 질문들만 포함
  /// - 이전 질문의 답변이 condition과 일치하지 않으면: then 배열에 포함되지 않은 질문들만 포함
  bool _shouldIncludeQuestion(List<Map<String, dynamic>> questions, int questionIndex) {
    if (questionIndex == 0) return true;
    
    // 이전 질문들 중 followUp이 있는 질문을 찾아서 조건 확인
    for (int i = questionIndex - 1; i >= 0; i--) {
      final prevQuestion = questions[i];
      final prevQuestionId = prevQuestion['id'].toString();
      final followUp = prevQuestion['follow_up'];
      
      if (followUp != null && followUp is Map) {
        final condition = followUp['condition'] as List?;
        final thenQuestions = followUp['then'] as List?;
        
        if (condition != null && thenQuestions != null) {
          final prevAnswer = allQuestionAnswers[prevQuestionId];
          
          // 유효한 답변이 있는 경우에만 followUp 로직 적용
          if (prevAnswer != null && _hasValidAnswer(prevAnswer)) {
            final currentQuestionId = questions[questionIndex]['id'].toString();
            
            // 이전 질문의 답변이 condition과 일치하는지 확인
            final shouldShowThen = condition.contains(prevAnswer.toString());
            
            if (shouldShowThen) {
              // then 배열에 포함된 질문인지 확인
              return thenQuestions.contains(currentQuestionId);
            } else {
              // then 배열에 포함되지 않은 질문인지 확인
              return !thenQuestions.contains(currentQuestionId);
            }
          }
        }
      }
    }
    
    // followUp이 없으면 기본적으로 포함
    return true;
  }
}

// ========================================
// SurveyPage UI 위젯
// ========================================

/// 설문 질문을 표시하는 페이지
/// 
/// 주요 구성 요소:
/// 1. AppBar: 설문 제목과 뒤로가기 버튼
/// 2. 진행률 바: 동적 질문 수 대비 답변 진행률
/// 3. 질문 목록: 현재 페이지의 visible한 질문들
/// 4. 네비게이션: 다음/완료 버튼
class SurveyPage extends StatelessWidget {
  final int surveyId;        // 설문 ID
  final String surveyName;   // 설문 이름
  final String time;         // 설문 시간 (예: "09:00")
  
  const SurveyPage({
    super.key,
    required this.surveyId,
    required this.surveyName,
    required this.time,
  });
  
  @override
  Widget build(BuildContext context) {
    return GetBuilder<SurveyPageController>(
      init: SurveyPageController(
        surveyId: surveyId,
        time: time,
      ),
      builder: (controller) => Scaffold(
        // === AppBar ===
        appBar: AppBar(
          title: Text('$surveyName - $time'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (controller.currentPageIndex > 0) {
                // 이전 페이지로 이동
                controller.currentPageIndex--;
                // 이전 페이지의 질문 가시성을 답변 상태에 따라 복원
                controller._restorePageVisibleQuestions();
                // UI 상태 업데이트 (다음 버튼 상태 포함)
                controller.update();
              } else {
                // 첫 번째 페이지면 이전 화면으로 이동
                Get.back();
              }
            },
          ),
        ),
        
        // === Body ===
        body: controller.isLoading
            ? const Center(child: CircularProgressIndicator())
            : controller.pages.isEmpty
                ? const Center(child: Text('질문이 없습니다.'))
                : Column(
                    children: [
                      // === 진행률 표시 ===
                      Column(
                        children: [
                          LinearProgressIndicator(
                            value: controller.progress,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              controller.progressText,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      // === 현재 페이지 질문 목록 ===
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16.0),
                          child: _buildPageWidget(controller),
                        ),
                      ),
                      
                      // === 네비게이션 버튼 ===
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            // 다음/완료 버튼
                            CommonLargeButton(
                              text: controller.currentPageIndex < controller.pages.length - 1
                                  ? '다음'
                                  : '완료',
                              onPressed: controller.isCurrentPageComplete 
                                  ? () => controller.nextPage()
                                  : null,
                              backgroundColor: controller.isCurrentPageComplete 
                                  ? Colors.blue 
                                  : Colors.grey.shade400,
                              textColor: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
  
  // ========================================
  // UI 구성 메서드들
  // ========================================
  
  /// 현재 페이지의 전체 위젯을 구성하는 메서드
  /// 
  /// 구성 요소:
  /// 1. 페이지 제목
  /// 2. visible한 질문들의 위젯들
  Widget _buildPageWidget(SurveyPageController controller) {
    final page = controller.currentPage;
    if (page == null) return const SizedBox.shrink();
    
    final pageTitle = page['title'] as String;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 페이지 제목
        Text(
          pageTitle,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        
        // 질문 위젯들 (visible한 것만)
        ...(page['questions'] as List<Map<String, dynamic>>).map((question) {
          final questionId = question['id'].toString();
          final isVisible = controller.pageVisibleQuestions[page['id'] as int]?[questionId] == true;
          
          // visible하지 않은 질문은 렌더링하지 않음
          if (!isVisible) return const SizedBox.shrink();
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _buildQuestionWidget(controller, question),
          );
        }),
      ],
    );
  }
  
  /// 개별 질문 위젯을 구성하는 메서드
  /// 
  /// 질문 유형별로 적절한 위젯을 반환:
  /// - single-choice: SingleChoiceQuestionWidget
  /// - multi-choice: MultipleChoiceQuestionWidget
  /// - scale: NinePointScaleQuestionWidget
  /// - text: TxtChoiceQuestionWidget
  Widget _buildQuestionWidget(SurveyPageController controller, Map<String, dynamic> question) {
    final questionType = question['question_type'] as String;
    final questionText = question['question_text'] as String;
    final questionId = question['id'].toString();
    
    switch (questionType) {
      case 'single-choice':
        final options = (question['input_options'] as List).cast<String>();
        return SingleChoiceQuestionWidget(
          title: questionText,
          selections: options,
          selected: controller.allQuestionAnswers[questionId],
          onChanged: (value) => controller.saveAnswer(questionId, value),
        );
        
      case 'multi-choice':
        final options = (question['input_options'] as List).cast<String>();
        final selected = (controller.allQuestionAnswers[questionId] as List?)?.cast<String>() ?? [];
        return MultipleChoiceQuestionWidget(
          title: questionText,
          options: options,
          selected: selected,
          onChanged: (value, isChecked) {
            final currentSelected = List<String>.from(selected);
            if (isChecked) {
              currentSelected.add(value);
            } else {
              currentSelected.remove(value);
            }
            controller.saveAnswer(questionId, currentSelected);
          },
        );
        
      case 'scale':
        return NinePointScaleQuestionWidget(
          title: questionText,
          selected: controller.allQuestionAnswers[questionId],
          onChanged: (score) => controller.saveAnswer(questionId, score),
        );
        
      case 'text':
        return TxtChoiceQuestionWidget(
          title: questionText,
          selected: controller.allQuestionAnswers[questionId],
          onChanged: (value) => controller.saveAnswer(questionId, value),
        );
        
      default:
        return Text('지원하지 않는 질문 유형: $questionType');
    }
  }
}