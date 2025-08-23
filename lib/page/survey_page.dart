import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../feature/db.dart';
import '../widget/single_choice_question_widget.dart';
import '../widget/multiple_choice_question_widget.dart';
import '../widget/nine_point_scale_question_widget.dart';
import '../widget/txt_choice_question_widget.dart';
import '../widget/common_large_button.dart';

class SurveyPageController extends GetxController {
  final int surveyId;
  final String time;
  
  var pages = <Map<String, dynamic>>[];
  var currentPageIndex = 0;
  var isLoading = true;
  var answers = <String, dynamic>{};
  var visibleQuestions = <String, bool>{};
  
  SurveyPageController({
    required this.surveyId,
    required this.time,
  });
  
  @override
  void onInit() {
    super.onInit();
    _loadSurveyPages();
  }
  
  Future<void> _loadSurveyPages() async {
    try {
      isLoading = true;
      update();
      
      debugPrint('설문 페이지 로드 시작: surveyId=$surveyId, time=$time');
      
      final db = await DataBaseManager.database;
      
      // 먼저 해당 설문의 해당 시간대 페이지들을 조회
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
        
        // 해당 페이지의 질문들 조회
        final questions = await db.query(
          'survey_question',
          where: 'page_id = ?',
          whereArgs: [pageId],
          orderBy: 'id ASC',
        );
        
        final questionsList = questions.map((q) {
          dynamic inputOptions;
          dynamic followUp;
          
          try {
            inputOptions = jsonDecode(q['input_options'] as String);
          } catch (e) {
            inputOptions = [];
          }
          
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
        
        pages.add({
          'id': page['id'],
          'page_number': page['page_number'],
          'title': page['title'],
          'questions': questionsList,
        });
      }
      
      // 각 페이지의 첫 번째 질문은 기본적으로 visible
      _initializeVisibleQuestions();
      
      debugPrint('페이지 파싱 완료: ${pages.length}개의 페이지 처리됨');
      
    } catch (e) {
      debugPrint('설문 페이지 로드 오류: $e');
    } finally {
      isLoading = false;
      update();
    }
  }
  
  // 질문 가시성 초기화
  void _initializeVisibleQuestions() {
    visibleQuestions.clear();
    for (final page in pages) {
      final questions = page['questions'] as List<Map<String, dynamic>>;
      if (questions.isNotEmpty) {
        // 첫 번째 질문은 항상 visible
        visibleQuestions[questions.first['id'].toString()] = true;
        // 나머지 질문들은 기본적으로 invisible
        for (int i = 1; i < questions.length; i++) {
          visibleQuestions[questions[i]['id'].toString()] = false;
        }
      }
    }
  }
  
  // 현재 페이지 가져오기
  Map<String, dynamic>? get currentPage {
    if (currentPageIndex >= 0 && currentPageIndex < pages.length) {
      return pages[currentPageIndex];
    }
    return null;
  }
  
  // 현재 페이지의 질문들 가져오기
  List<Map<String, dynamic>> get currentPageQuestions {
    final page = currentPage;
    if (page == null) return <Map<String, dynamic>>[];
    
    final questions = page['questions'] as List<Map<String, dynamic>>;
    // visible한 질문들만 반환
    return questions.where((q) => 
        visibleQuestions[q['id'].toString()] == true).toList();
  }
  
  // 답변 저장 및 followUp 처리
  void saveAnswer(String questionId, dynamic value) {
    answers[questionId] = value;
    
    // followUp 로직 처리
    _processFollowUp(questionId, value);
    
    update();
  }
  
  // followUp 로직 처리
  void _processFollowUp(String questionId, dynamic answer) {
    final page = currentPage;
    if (page == null) return;
    
    final questions = page['questions'] as List<Map<String, dynamic>>;
    final currentQuestion = questions.firstWhere(
      (q) => q['id'].toString() == questionId,
      orElse: () => <String, dynamic>{},
    );
    
    if (currentQuestion.isEmpty) return;
    
    final followUp = currentQuestion['follow_up'];
    if (followUp != null && followUp is Map) {
      final condition = followUp['condition'] as List?;
      final thenQuestions = followUp['then'] as List?;
      
      if (condition != null && thenQuestions != null) {
        // 조건에 맞는지 확인
        final shouldShowThen = condition.contains(answer.toString());
        
        if (shouldShowThen) {
          // then 질문들을 visible로 설정
          for (final thenQuestionId in thenQuestions) {
            visibleQuestions[thenQuestionId.toString()] = true;
          }
        } else {
          // 조건에 맞지 않으면 다음 순서의 질문을 visible로 설정
          final currentIndex = questions.indexWhere(
            (q) => q['id'].toString() == questionId,
          );
          
          if (currentIndex != -1 && currentIndex < questions.length - 1) {
            // 다음 질문을 visible로 설정
            final nextQuestion = questions[currentIndex + 1];
            visibleQuestions[nextQuestion['id'].toString()] = true;
          }
        }
      }
    } else {
      // followUp이 없으면 다음 순서의 질문을 visible로 설정
      final currentIndex = questions.indexWhere(
        (q) => q['id'].toString() == questionId,
      );
      
      if (currentIndex != -1 && currentIndex < questions.length - 1) {
        // 다음 질문을 visible로 설정
        final nextQuestion = questions[currentIndex + 1];
        visibleQuestions[nextQuestion['id'].toString()] = true;
      }
    }
  }
  
  // 현재 페이지의 모든 질문에 답변이 있는지 확인
  bool get isCurrentPageComplete {
    final questions = currentPageQuestions;
    if (questions.isEmpty) return true;
    
    for (final question in questions) {
      final questionId = question['id'].toString();
      if (!answers.containsKey(questionId)) {
        return false;
      }
    }
    return true;
  }
  
  // 다음 페이지로 이동
  void nextPage() {
    if (currentPageIndex < pages.length - 1) {
      currentPageIndex++;
      // 새 페이지의 질문 가시성 초기화
      _initializeVisibleQuestions();
      update();
    } else {
      // 설문 완료
      _completeSurvey();
    }
  }
  
  // 이전 페이지로 이동
  void previousPage() {
    if (currentPageIndex > 0) {
      currentPageIndex--;
      // 이전 페이지의 질문 가시성 초기화
      _initializeVisibleQuestions();
      update();
    }
  }
  
  // 설문 완료
  void _completeSurvey() {
    Get.snackbar(
      '설문 완료',
      '모든 질문에 답변했습니다.',
      snackPosition: SnackPosition.BOTTOM,
    );
    // TODO: 답변 저장 및 결과 페이지로 이동
    Get.back();
  }
  
  // 설문 진행률
  double get progress {
    if (pages.isEmpty) return 0.0;
    return (currentPageIndex + 1) / pages.length;
  }
}

class SurveyPage extends StatelessWidget {
  final int surveyId;
  final String surveyName;
  final String time; // 예: "09:00"
  
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
        appBar: AppBar(
          title: Text('$surveyName - $time'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Get.back(),
          ),
        ),
        body: controller.isLoading
            ? const Center(child: CircularProgressIndicator())
            : controller.pages.isEmpty
                ? const Center(child: Text('질문이 없습니다.'))
                : Column(
                    children: [
                      // 진행률 표시
                      LinearProgressIndicator(
                        value: controller.progress,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                      
                      // 현재 페이지 표시
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16.0),
                          child: _buildPageWidget(controller),
                        ),
                      ),
                      
                      // 네비게이션 버튼
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            if (controller.currentPageIndex > 0)
                              Expanded(
                                child: CommonLargeButton(
                                  text: '이전',
                                  onPressed: controller.previousPage,
                                  backgroundColor: Colors.grey.shade600,
                                  textColor: Colors.white,
                                ),
                              ),
                            if (controller.currentPageIndex > 0)
                              const SizedBox(width: 16),
                            Expanded(
                              child: CommonLargeButton(
                                text: controller.currentPageIndex < controller.pages.length - 1
                                    ? '다음'
                                    : '완료',
                                onPressed: () {
                                  // 현재 페이지의 모든 질문에 답변이 있는지 확인
                                  if (controller.isCurrentPageComplete) {
                                    controller.nextPage();
                                  } else {
                                    Get.snackbar(
                                      '답변 필요',
                                      '현재 페이지의 모든 질문에 답변해주세요.',
                                      snackPosition: SnackPosition.BOTTOM,
                                    );
                                  }
                                },
                                backgroundColor: Colors.blue,
                                textColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
  
  Widget _buildPageWidget(SurveyPageController controller) {
    final page = controller.currentPage;
    if (page == null) return const SizedBox.shrink();
    
    final pageTitle = page['title'] as String;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pageTitle,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        ...(page['questions'] as List<Map<String, dynamic>>).map((question) {
          final questionId = question['id'].toString();
          final isVisible = controller.visibleQuestions[questionId] == true;
          
          if (!isVisible) return const SizedBox.shrink();
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _buildQuestionWidget(controller, question),
          );
        }),
      ],
    );
  }
  
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
          selected: controller.answers[questionId],
          onChanged: (value) => controller.saveAnswer(questionId, value),
        );
        
      case 'multi-choice':
        final options = (question['input_options'] as List).cast<String>();
        final selected = (controller.answers[questionId] as List?)?.cast<String>() ?? [];
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
          selected: controller.answers[questionId],
          onChanged: (score) => controller.saveAnswer(questionId, score),
        );
        
      case 'text':
        return TxtChoiceQuestionWidget(
          title: questionText,
          selected: controller.answers[questionId],
          onChanged: (value) => controller.saveAnswer(questionId, value),
        );
        
      default:
        return Text('지원하지 않는 질문 유형: $questionType');
    }
  }
}