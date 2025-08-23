import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

class DataBaseManager {
  static Database? _database;
  static bool enableDebugLogs = true;
  
  // JSON 객체를 정규화하는 헬퍼 함수 (키 정렬)
  static Map<String, dynamic> _normalizeMap(Map<String, dynamic> map) {
    final sortedMap = <String, dynamic>{};
    final sortedKeys = map.keys.toList()..sort();
    
    for (final key in sortedKeys) {
      final value = map[key];
      if (value is Map<String, dynamic>) {
        // 중첩된 맵도 정규화
        sortedMap[key] = _normalizeMap(value);
      } else if (value is List) {
        // 리스트 내의 맵도 정규화
        sortedMap[key] = _normalizeList(value);
      } else {
        sortedMap[key] = value;
      }
    }
    
    return sortedMap;
  }
  
  // 리스트 내의 맵을 정규화하는 헬퍼 함수
  static List<dynamic> _normalizeList(List<dynamic> list) {
    return list.map((item) {
      if (item is Map<String, dynamic>) {
        return _normalizeMap(item);
      } else if (item is List) {
        return _normalizeList(item);
      } else {
        return item;
      }
    }).toList();
  }

  // 데이터베이스 인스턴스 반환 (싱글톤)
  static Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDB();
    return _database!;
  }

  // 데이터베이스 초기화
  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'mind_rhythm_app_v2.db');

    // 개발 중 데이터베이스를 매번 초기화하고 싶을 때 아래 주석을 해제하세요.
    // await deleteDatabase(path);
    // debugPrint('기존 데이터베이스 삭제 완료');

    try {
      return await openDatabase(
        path,
        version: 8, // 버전 업데이트 (알림 스케줄 테이블 추가)
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      );
    } catch (e) {
      // 데이터베이스 열기 실패 시 기존 DB 삭제 후 재생성
      debugPrint('데이터베이스 열기 실패: $e');
      debugPrint('기존 데이터베이스 삭제 후 재생성 시도...');
      await deleteDatabase(path);
      
      return await openDatabase(
        path,
        version: 8,
        onCreate: _createDB,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      );
    }
  }

  // 테이블 생성 (새로운 정규화 스키마)
  static Future<void> _createDB(Database db, int version) async {
    // 1. 사용자 정보 테이블
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_info (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL UNIQUE,
        user_name TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 2. 설문 테이블
    await db.execute('''
      CREATE TABLE IF NOT EXISTS survey (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        survey_name TEXT NOT NULL,
        survey_description TEXT,
        start_date TEXT,
        end_date TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 3. 설문 알림 시간
    await db.execute('''
      CREATE TABLE IF NOT EXISTS survey_notification_times (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        survey_id INTEGER NOT NULL,
        time TEXT NOT NULL,
        FOREIGN KEY(survey_id) REFERENCES survey(id) ON DELETE CASCADE
      )
    ''');

    // 4. 설문 상태 (유저별, 날짜별 제출 여부)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS survey_status (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        survey_id INTEGER NOT NULL,
        user_id TEXT NOT NULL,
        survey_date TEXT NOT NULL,
        time TEXT NOT NULL,
        submitted INTEGER DEFAULT 0,
        submitted_at TEXT,
        FOREIGN KEY(survey_id) REFERENCES survey(id) ON DELETE CASCADE,
        FOREIGN KEY(user_id) REFERENCES user_info(user_id) ON DELETE CASCADE,
        UNIQUE(survey_id, user_id, survey_date, time)
      )
    ''');

    // 5. 설문 페이지
    await db.execute('''
      CREATE TABLE IF NOT EXISTS survey_page (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        survey_id INTEGER NOT NULL,
        time TEXT NOT NULL,
        page_number INTEGER NOT NULL,
        title TEXT,
        FOREIGN KEY(survey_id) REFERENCES survey(id) ON DELETE CASCADE,
        UNIQUE(survey_id, time, page_number)
      )
    ''');

    // 6. 설문 질문
    await db.execute('''
      CREATE TABLE IF NOT EXISTS survey_question (
        id TEXT PRIMARY KEY,
        page_id INTEGER NOT NULL,
        question_text TEXT,
        question_type TEXT,
        input_options TEXT, -- JSON 문자열 ["예","아니요"] 형태
        follow_up TEXT,     -- JSON 문자열
        FOREIGN KEY(page_id) REFERENCES survey_page(id) ON DELETE CASCADE
      )
    ''');

    // 7. 설문 응답 (유저별 답변 저장)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS survey_response (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        survey_date TEXT NOT NULL,
        answer TEXT,
        submitted_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(question_id) REFERENCES survey_question(id) ON DELETE CASCADE,
        FOREIGN KEY(user_id) REFERENCES user_info(user_id) ON DELETE CASCADE
      )
    ''');
    
    // 8. 알림 스케줄 테이블
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notification_schedule (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        survey_id INTEGER NOT NULL,
        user_id TEXT NOT NULL,
        time TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        notification_id TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(survey_id) REFERENCES survey(id) ON DELETE CASCADE,
        FOREIGN KEY(user_id) REFERENCES user_info(user_id) ON DELETE CASCADE,
        UNIQUE(survey_id, user_id, time)
      )
    ''');
  }
  
  // 데이터베이스 업그레이드 처리
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('데이터베이스 버전 업그레이드: $oldVersion → $newVersion');
    
    try {
      // 버전 7에서 8로 업그레이드: 알림 스케줄 테이블만 추가
      if (oldVersion == 7 && newVersion == 8) {
        debugPrint('버전 7에서 8로 업그레이드: 알림 스케줄 테이블 추가');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS notification_schedule (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            survey_id INTEGER NOT NULL,
            user_id TEXT NOT NULL,
            time TEXT NOT NULL,
            start_date TEXT NOT NULL,
            end_date TEXT NOT NULL,
            notification_id TEXT NOT NULL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(survey_id) REFERENCES survey(id) ON DELETE CASCADE,
            FOREIGN KEY(user_id) REFERENCES user_info(user_id) ON DELETE CASCADE,
            UNIQUE(survey_id, user_id, time)
          )
        ''');
        debugPrint('알림 스케줄 테이블 생성 완료');
        return;
      }
      
      // 그 외의 경우 모든 테이블 재생성 (기존 데이터 손실)
      debugPrint('전체 스키마 재생성 (버전 $oldVersion → $newVersion)');
      
      // 모든 이전 버전의 테이블을 삭제하여 스키마를 정리합니다.
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      for (final table in tables) {
        final tableName = table['name'] as String;
        if (!tableName.startsWith('sqlite_')) {
          await db.execute('DROP TABLE IF EXISTS $tableName');
        }
      }

      // 새 스키마로 테이블 재생성
      await _createDB(db, newVersion);
      debugPrint('테이블 스키마 업데이트 완료');
    } catch (e) {
      debugPrint('데이터베이스 업그레이드 중 오류 발생: $e');
      // 오류 발생 시 모든 테이블을 새로 생성
      await _createDB(db, newVersion);
    }
  }
  
  // 유저 정보 저장 (단일 사용자 가정)
  static Future<void> saveUserInfo({ required String userId, String? userName }) async {
  final db = await database;
  final now = DateTime.now().toIso8601String();
  
  try {
    // 기존 사용자 정보가 있는지 확인
    final existingUser = await db.query(
      'user_info',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    
    if (existingUser.isNotEmpty) {
      // 기존 사용자 정보 업데이트
      await db.update(
        'user_info',
        {
          'user_name': userName ?? 'user',
          'updated_at': now,
        },
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      debugPrint('사용자 정보 업데이트 완료: $userId');
    } else {
      // 새 사용자 정보 추가
      await db.insert('user_info', {
        'user_id': userId,
        'user_name': userName ?? 'user',
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      debugPrint('새 사용자 정보 추가 완료: $userId');
    }
  } catch (e) {
    debugPrint('사용자 정보 저장 오류: $e');
  }
}

  // API 응답 데이터를 정규화하여 DB에 저장 (JSON 비교 방식)
  static Future<({int newRecords, int updatedRecords})> saveSurveyDataFromApi(String userId, Map<String, dynamic> data) async {
    final db = await database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 변경 사항 추적을 위한 변수
    
    try {
      // 1. API 응답 데이터에서 설문 정보 추출
      final surveys = data['surveys'] as List<dynamic>?;
      if (surveys == null || surveys.isEmpty) {
        return (newRecords: 0, updatedRecords: 0);
      }
      
      // 2. 현재 데이터베이스에 저장된 설문 데이터 조회
      final existingSurveyData = await _getCurrentSurveyData(db, userId);
      
      // 3. 새 데이터와 기존 데이터 비교
      final comparisonResult = await _compareSurveyData(
        existingSurveyData, 
        surveys.first as Map<String, dynamic>, 
        userId, 
        today
      );
      
      return (newRecords: comparisonResult.newRecords, updatedRecords: comparisonResult.updatedRecords);
    } catch (e) {
      debugPrint('API 설문 데이터 저장 중 오류: $e');
      return (newRecords: 0, updatedRecords: 0);
    }
  }
  
  // 현재 데이터베이스에 저장된 설문 데이터를 조회하는 메서드
  static Future<Map<String, dynamic>> _getCurrentSurveyData(Database db, String userId) async {
    final result = <String, dynamic>{};
    
    try {
      // 1. 설문 기본 정보 조회
      final surveys = await db.query('survey');
      if (surveys.isNotEmpty) {
        final surveyId = surveys.first['id'] as int;
        result['survey'] = surveys.first;
        
        // 2. 알림 시간 조회
        final notificationTimes = await db.query(
          'survey_notification_times',
          where: 'survey_id = ?',
          whereArgs: [surveyId]
        );
        result['notificationTimes'] = notificationTimes;
        
        // 3. 설문 상태 조회
        final surveyStatus = await db.query(
          'survey_status',
          where: 'survey_id = ? AND user_id = ?',
          whereArgs: [surveyId, userId]
        );
        result['surveyStatus'] = surveyStatus;
        
        // 4. 설문 페이지 조회
        final surveyPages = await db.query(
          'survey_page',
          where: 'survey_id = ?',
          whereArgs: [surveyId]
        );
        
        // 5. 각 페이지별 질문 조회
        final surveyByTime = <String, dynamic>{};
        for (final page in surveyPages) {
          final pageId = page['id'] as int;
          final time = page['time'] as String;
          
          if (!surveyByTime.containsKey(time)) {
            surveyByTime[time] = <String, dynamic>{
              'time': time,
              'pages': <Map<String, dynamic>>[]
            };
          }
          
          final questions = await db.query(
            'survey_question',
            where: 'page_id = ?',
            whereArgs: [pageId]
          );
          
          final pageData = <String, dynamic>{
            'page': page['page_number'],
            'title': page['title'],
            'questions': questions.map((q) {
              // JSON 문자열을 객체로 변환
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
                'question': q['question_text'],
                'type': q['question_type'],
                'input': inputOptions,
                'followUp': followUp
              };
            }).toList()
          };
          
          (surveyByTime[time]['pages'] as List<Map<String, dynamic>>).add(pageData);
        }
        
        result['surveyByTime'] = surveyByTime.values.toList();
      }
    } catch (e) {
      debugPrint('기존 설문 데이터 조회 중 오류: $e');
    }
    
    return result;
  }
  
  // 새 데이터와 기존 데이터를 비교하는 메서드
  static Future<({int newRecords, int updatedRecords})> _compareSurveyData(
    Map<String, dynamic> existingData,
    Map<String, dynamic> newData,
    String userId,
    String today
  ) async {
    final db = await database;
    int newRecords = 0;
    int updatedRecords = 0;
    
    await db.transaction((txn) async {
      // 1. 설문 기본 정보 비교 및 업데이트
      final surveyInfo = newData['surveyInfo'];
      final period = newData['participationPeriod'];
      
      if (surveyInfo != null && surveyInfo is Map<String, dynamic> &&
          period != null && period is Map<String, dynamic>) {
        
        final surveyName = surveyInfo['surveyName'] ?? '설문조사';
        final surveyDescription = surveyInfo['surveyDescription'] ?? '';
        final startDate = period['startDate'] ?? today;
        final endDate = period['endDate'] ?? today;
        
        int surveyId;
        if (existingData.containsKey('survey')) {
          // 기존 설문 정보 업데이트
          surveyId = existingData['survey']['id'] as int;
          
          final existing = existingData['survey'];
          bool hasChanges = false;
          
          if (existing['survey_name'] != surveyName) hasChanges = true;
          if (existing['survey_description'] != surveyDescription) hasChanges = true;
          if (existing['start_date'] != startDate) hasChanges = true;
          if (existing['end_date'] != endDate) hasChanges = true;
          
          if (hasChanges) {
            await txn.update(
              'survey',
              {
                'survey_name': surveyName,
                'survey_description': surveyDescription,
                'start_date': startDate,
                'end_date': endDate,
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [surveyId]
            );
            updatedRecords++;
            
            if (enableDebugLogs) {
              debugPrint('설문 기본 정보 업데이트 (ID: $surveyId)');
            }
          }
        } else {
          // 새 설문 정보 추가
          surveyId = await txn.insert('survey', {
            'survey_name': surveyName,
            'survey_description': surveyDescription,
            'start_date': startDate,
            'end_date': endDate,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
          newRecords++;
          
          if (enableDebugLogs) {
            debugPrint('새 설문 정보 추가 (ID: $surveyId)');
          }
        }
        
        // 2. 알림 시간 비교 및 업데이트
        final times = surveyInfo['notificationTimes'];
        if (times != null && times is List) {
          final newTimeSet = times.where((t) => t != null).map((t) => t.toString()).toSet();
          
          // 기존 알림 시간
          final existingTimes = existingData['notificationTimes'] as List<Map<String, dynamic>>? ?? [];
          final existingTimeSet = existingTimes.map((t) => t['time'] as String).toSet();
          
          // 새로 추가할 시간
          for (final time in newTimeSet) {
            if (!existingTimeSet.contains(time)) {
              await txn.insert('survey_notification_times', {
                'survey_id': surveyId,
                'time': time,
              });
              newRecords++;
              
              if (enableDebugLogs) {
                debugPrint('새 알림 시간 추가: $time');
              }
            }
          }
          
          // 삭제할 시간
          for (final existing in existingTimes) {
            final existingTime = existing['time'] as String;
            if (!newTimeSet.contains(existingTime)) {
              await txn.delete(
                'survey_notification_times',
                where: 'id = ?',
                whereArgs: [existing['id']]
              );
              updatedRecords++;
              
              if (enableDebugLogs) {
                debugPrint('알림 시간 삭제: $existingTime');
              }
            }
          }
        }
        
        // 3. 설문 상태 비교 및 업데이트
        final surveyStatus = newData['surveyStatus'];
        if (surveyStatus != null && surveyStatus is List) {
          for (final status in surveyStatus) {
            if (status != null && status is Map<String, dynamic>) {
              final time = status['time'];
              if (time != null) {
                final timeStr = time.toString();
                final isSubmitted = (status['submitted'] == true) ? 1 : 0;
                
                // 기존 상태 조회
                bool found = false;
                final existingStatusList = existingData['surveyStatus'] as List<Map<String, dynamic>>? ?? [];
                
                for (final existing in existingStatusList) {
                  if (existing['time'] == timeStr && 
                      existing['survey_date'] == today) {
                    found = true;
                    
                    // 상태가 변경된 경우에만 업데이트
                    if (existing['submitted'] != isSubmitted) {
                      await txn.update(
                        'survey_status',
                        {
                          'submitted': isSubmitted,
                          'submitted_at': isSubmitted == 1 ? DateTime.now().toIso8601String() : null,
                        },
                        where: 'id = ?',
                        whereArgs: [existing['id']]
                      );
                      updatedRecords++;
                      
                      if (enableDebugLogs) {
                        debugPrint('설문 상태 업데이트: $timeStr (제출: $isSubmitted)');
                      }
                    }
                    break;
                  }
                }
                
                if (!found) {
                  // 새 상태 추가
                  await txn.insert('survey_status', {
                    'survey_id': surveyId,
                    'user_id': userId,
                    'survey_date': today,
                    'time': timeStr,
                    'submitted': isSubmitted,
                    'submitted_at': isSubmitted == 1 ? DateTime.now().toIso8601String() : null,
                  });
                  newRecords++;
                  
                  if (enableDebugLogs) {
                    debugPrint('새 설문 상태 추가: $timeStr');
                  }
                }
              }
            }
          }
        }
        
        // 4. 설문 내용(페이지 및 질문) 비교 및 업데이트
        // 이 부분은 복잡하므로 내용 기반 해시를 사용하여 비교
        final surveyByTime = newData['surveyByTime'];
        if (surveyByTime != null && surveyByTime is List) {
          // 기존 설문 내용을 해시맵으로 변환
          final existingSurveyByTime = existingData['surveyByTime'] as List? ?? [];
          final existingContentHash = _generateContentHash(existingSurveyByTime);
          final newContentHash = _generateContentHash(surveyByTime);
          
          if (enableDebugLogs) {
            debugPrint('설문 내용 해시 비교:');
            debugPrint('  기존 해시: $existingContentHash');
            debugPrint('  새 해시: $newContentHash');
          }
          
          // 내용이 다른 경우에만 업데이트
          if (existingContentHash != newContentHash) {
            if (enableDebugLogs) {
              debugPrint('설문 내용 변경 감지 (ID 제외한 내용 비교)');
            }
            
            try {
              // 기존 페이지 및 질문 정보 조회
              final existingPages = await txn.query('survey_page');
              final existingQuestions = await txn.query('survey_question');
              
              // 페이지 ID와 질문 ID를 맵으로 변환하여 빠른 조회 가능하게 함
              final existingPageMap = <String, Map<String, dynamic>>{};
              for (final page in existingPages) {
                final key = '${page['survey_id']}_${page['time']}_${page['page_number']}';
                existingPageMap[key] = page;
              }
              
              final existingQuestionMap = <String, Map<String, dynamic>>{};
              for (final question in existingQuestions) {
                existingQuestionMap[question['id'] as String] = question;
              }
              
              if (enableDebugLogs) {
                debugPrint('기존 데이터 조회 완료: ${existingPages.length}개 페이지, ${existingQuestions.length}개 질문');
              }
              
              // 새 데이터와 기존 데이터 비교를 위한 변수
              final updatedPageIds = <int>{};
              final updatedQuestionIds = <String>{};
              
              if (enableDebugLogs) {
                debugPrint('설문 내용 upsert 시작');
              }
            
            // 새 페이지 및 질문 upsert
            for (final timeSlot in surveyByTime) {
              if (timeSlot == null || timeSlot is! Map<String, dynamic>) {
                continue;
              }
              
              final time = timeSlot['time'];
              if (time == null) {
                continue;
              }
              final timeStr = time.toString();
              
              final pages = timeSlot['pages'];
              if (pages == null || pages is! List) {
                continue;
              }
              
              for (final pageData in pages) {
                if (pageData == null || pageData is! Map<String, dynamic>) {
                  continue;
                }
                
                final pageNumber = pageData['page'];
                final title = pageData['title'];
                
                if (pageNumber == null) {
                  continue;
                }
                
                // 페이지 키 생성 (survey_id + time + page_number)
                final pageKey = '${surveyId}_${timeStr}_$pageNumber';
                
                int pageId;
                if (existingPageMap.containsKey(pageKey)) {
                  // 기존 페이지 업데이트
                  final existingPage = existingPageMap[pageKey]!;
                  pageId = existingPage['id'] as int;
                  
                  // 제목이 변경된 경우에만 업데이트
                  if (existingPage['title'] != title) {
                    await txn.update(
                      'survey_page',
                      {'title': title ?? ''},
                      where: 'id = ?',
                      whereArgs: [pageId]
                    );
                    updatedRecords++;
                    updatedPageIds.add(pageId);
                    
                    if (enableDebugLogs) {
                      debugPrint('페이지 업데이트 (ID: $pageId): 제목 변경');
                    }
                  }
                } else {
                  // 새 페이지 추가
                  pageId = await txn.insert('survey_page', {
                    'survey_id': surveyId,
                    'time': timeStr,
                    'page_number': pageNumber,
                    'title': title ?? '',
                  });
                  newRecords++;
                  
                  if (enableDebugLogs) {
                    debugPrint('새 페이지 추가 (ID: $pageId): $timeStr, 페이지 $pageNumber');
                  }
                }
                
                final questions = pageData['questions'];
                if (questions != null && questions is List) {
                  for (final qData in questions) {
                    if (qData == null || qData is! Map<String, dynamic>) {
                      continue;
                    }
                    
                    final id = qData['id'];
                    if (id == null) {
                      continue;
                    }
                    
                    // 질문 정규화
                    String normalizeText(String? text) {
                      if (text == null) return '';
                      return text.trim().replaceAll(RegExp(r'\s+'), ' ');
                    }
                    
                    final questionText = normalizeText(qData['question']?.toString());
                    final questionType = qData['type']?.toString() ?? '';
                    final inputOptions = qData['input'] != null ? jsonEncode(qData['input']) : '[]';
                    
                    // followUp 필드 처리 (ID 참조 업데이트)
                    dynamic followUpData = qData['followUp'];
                    if (followUpData != null && followUpData is Map<String, dynamic> && 
                        followUpData.containsKey('then') && followUpData['then'] is List) {
                      // 원래 ID를 시간대를 포함한 고유 ID로 변환
                      final thenList = followUpData['then'] as List;
                      final updatedThenList = thenList.map((item) {
                        if (item != null) {
                          return '${timeStr}_${item.toString()}';
                        }
                        return item;
                      }).toList();
                      
                      // 업데이트된 ID로 followUp 데이터 재구성
                      followUpData = Map<String, dynamic>.from(followUpData);
                      followUpData['then'] = updatedThenList;
                    }
                    
                    final followUp = followUpData != null ? jsonEncode(followUpData) : 'null';
                    
                    // 시간대를 포함한 고유 ID 생성 (시간대_원본ID 형식)
                    final uniqueId = '${timeStr}_${id.toString()}';
                    
                    // 질문 데이터
                    final questionData = {
                      'page_id': pageId,
                      'question_text': questionText,
                      'question_type': questionType,
                      'input_options': inputOptions,
                      'follow_up': followUp,
                    };
                    
                    if (existingQuestionMap.containsKey(uniqueId)) {
                      // 기존 질문 업데이트
                      final existingQuestion = existingQuestionMap[uniqueId]!;
                      
                      // 내용이 변경된 경우에만 업데이트
                      bool hasChanges = false;
                      if (existingQuestion['page_id'] != pageId) hasChanges = true;
                      if (existingQuestion['question_text'] != questionText) hasChanges = true;
                      if (existingQuestion['question_type'] != questionType) hasChanges = true;
                      if (existingQuestion['input_options'] != inputOptions) hasChanges = true;
                      if (existingQuestion['follow_up'] != followUp) hasChanges = true;
                      
                      if (hasChanges) {
                        await txn.update(
                          'survey_question',
                          questionData,
                          where: 'id = ?',
                          whereArgs: [uniqueId]
                        );
                        updatedRecords++;
                        updatedQuestionIds.add(uniqueId);
                        
                        if (enableDebugLogs && updatedRecords % 10 == 0) {
                          debugPrint('질문 업데이트 진행 중: $updatedRecords개 완료');
                        }
                      }
                    } else {
                      // 새 질문 추가
                      try {
                        await txn.insert('survey_question', {
                          'id': uniqueId,
                          ...questionData,
                        });
                        newRecords++;
                        
                        if (enableDebugLogs && newRecords % 10 == 0) {
                          debugPrint('질문 추가 진행 중: $newRecords개 완료');
                        }
                      } catch (e) {
                        debugPrint('질문 추가 중 오류 (ID: $uniqueId): $e');
                      }
                    }
                  }
                }
              }
            }
            
            if (enableDebugLogs) {
              debugPrint('설문 내용 upsert 완료');
              debugPrint('  업데이트된 페이지: ${updatedPageIds.length}개');
              debugPrint('  업데이트된 질문: ${updatedQuestionIds.length}개');
              debugPrint('  새로 추가된 레코드: $newRecords개');
            }
          } catch (e) {
            debugPrint('설문 내용 비교 중 오류: $e');
          }
          
          } else if (enableDebugLogs) {
            debugPrint('설문 내용 변경 없음 (해시 일치)');
          }
        }
      }
      
      // 5. 요약 정보 출력
      if (enableDebugLogs) {
        debugPrint('\n===== 데이터 저장 요약 =====');
        debugPrint('새로운 레코드: $newRecords개');
        debugPrint('업데이트된 레코드: $updatedRecords개');
        debugPrint('총 변경 사항: ${newRecords + updatedRecords}개');
        debugPrint('==========================\n');
      }
    });
    
    return (newRecords: newRecords, updatedRecords: updatedRecords);
  }
  
  // 설문 내용의 해시를 생성하는 헬퍼 메서드 (ID 제외)
  static String _generateContentHash(List<dynamic> content) {
    try {
      // ID를 제외한 내용만 정규화하여 JSON 문자열로 변환
      final normalizedContent = content.map((item) {
        if (item is Map<String, dynamic>) {
          // ID 필드 제거한 맵 복사
          final itemWithoutIds = _removeIdsFromMap(item);
          return _normalizeMap(itemWithoutIds);
        }
        return item;
      }).toList();
      
      // 정규화된 JSON을 문자열로 변환하고 해시 생성
      final contentJson = jsonEncode(normalizedContent);
      return contentJson.hashCode.toString();
    } catch (e) {
      debugPrint('콘텐츠 해시 생성 중 오류: $e');
      return DateTime.now().millisecondsSinceEpoch.toString(); // 오류 시 현재 시간을 해시로 사용
    }
  }
  
  // 맵에서 ID 필드를 제거하는 헬퍼 메서드
  static Map<String, dynamic> _removeIdsFromMap(Map<String, dynamic> map) {
    final result = Map<String, dynamic>.from(map);
    
    // 최상위 ID 필드 제거
    result.remove('id');
    
    // 중첩된 객체 처리
    result.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        // 중첩된 맵의 ID 필드 제거
        result[key] = _removeIdsFromMap(value);
      } else if (value is List) {
        // 리스트 내 맵의 ID 필드 제거
        result[key] = _removeIdsFromList(value);
      }
    });
    
    return result;
  }
  
  // 리스트 내의 맵에서 ID 필드를 제거하는 헬퍼 메서드
  static List<dynamic> _removeIdsFromList(List<dynamic> list) {
    return list.map((item) {
      if (item is Map<String, dynamic>) {
        return _removeIdsFromMap(item);
      } else if (item is List) {
        return _removeIdsFromList(item);
      } else {
        return item;
      }
    }).toList();
  }

  // 유저 정보 가져오기
  static Future<Map<String, dynamic>?> getUserInfo() async {
    final db = await database;
    final users = await db.query('user_info', orderBy: 'created_at DESC', limit: 1);
    return users.isNotEmpty ? users.first : null;
  }
  
  // 유저 이름 가져오기
  static Future<String> getUserName() async {
    final userInfo = await getUserInfo();
    return userInfo?['user_name'] as String? ?? '';
  }
  
  // 특정 날짜의 설문 상태 목록 조회 (단일 사용자 가정)
  static Future<List<Map<String, dynamic>>> getSurveyStatusByDate({
    required String userId,
    required String surveyDate,
  }) async {
    final db = await database;
    
    // 단일 사용자 가정이므로 survey_id 조건 없이 조회
    return await db.query(
      'survey_status',
      where: 'user_id = ? AND survey_date = ?',
      whereArgs: [userId, surveyDate],
      orderBy: 'time ASC', // 시간 순으로 정렬
    );
  }



  // =========== 디버깅 메서드 ===========
  
  /// 모든 테이블의 모든 데이터 출력
  static Future<void> logAllData() async {
    if (!enableDebugLogs) return;
    
    final db = await database;
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
    
    debugPrint('\n===== DATABASE DUMP =====');
    for (final table in tables) {
      final tableName = table['name'] as String;
      final rows = await db.query(tableName);
      debugPrint('\n--- TABLE: $tableName (${rows.length} rows) ---');
      if (rows.isEmpty) {
        debugPrint('No data');
      } else {
        for (final row in rows) {
          debugPrint(row.toString());
        }
      }
    }
    debugPrint('\n===== END DUMP =====');
  }

  /// 데이터베이스의 모든 데이터를 삭제
  static Future<void> clearAllData() async {
    final db = await database;
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
    
    for (final table in tables) {
      await db.delete(table['name'] as String);
    }
    
    if (enableDebugLogs) {
      debugPrint('모든 테이블의 데이터 삭제 완료');
    }
  }
}