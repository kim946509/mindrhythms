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
    final path = join(dbPath, 'mind_rhythm_app_v3.db');

    // 개발 중 데이터베이스를 매번 초기화하고 싶을 때 아래 주석을 해제하세요.
    // await deleteDatabase(path);
    // debugPrint('기존 데이터베이스 삭제 완료');

    try {
      return await openDatabase(
        path,
        version: 9, // 버전 업데이트 (다중 설문 지원)
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
        version: 9,
        onCreate: _createDB,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      );
    }
  }

  // 테이블 생성 (다중 설문 지원 스키마)
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

    // 2. 설문 테이블 (다중 설문 지원을 위한 개선)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS survey (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        survey_uuid TEXT NOT NULL UNIQUE,
        survey_name TEXT NOT NULL,
        survey_description TEXT,
        start_date TEXT,
        end_date TEXT,
        survey_order INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
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
        FOREIGN KEY(survey_id) REFERENCES survey(id) ON DELETE CASCADE,
        UNIQUE(survey_id, time)
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

    // 9. 인덱스 생성 (성능 최적화)
    await db.execute('CREATE INDEX IF NOT EXISTS idx_survey_uuid ON survey(survey_uuid)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_survey_order ON survey(survey_order)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_survey_status_date ON survey_status(survey_date, time)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_survey_response_date ON survey_response(survey_date)');
  }
  
  // 데이터베이스 업그레이드 처리
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('데이터베이스 버전 업그레이드: $oldVersion → $newVersion');
    
    try {
      // 버전별 순차 업그레이드
      if (oldVersion < 9) {
        debugPrint('버전 9로 업그레이드: 다중 설문 지원 스키마 적용');
        
        // 기존 테이블 백업 후 새 스키마 적용
        await _migrateToMultiSurveySchema(db);
        
        debugPrint('다중 설문 지원 스키마 업그레이드 완료');
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

  // 다중 설문 지원 스키마로 마이그레이션
  static Future<void> _migrateToMultiSurveySchema(Database db) async {
    try {
      // 1. 기존 survey 테이블에 새 컬럼 추가
      await db.execute('ALTER TABLE survey ADD COLUMN survey_uuid TEXT');
      await db.execute('ALTER TABLE survey ADD COLUMN survey_order INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE survey ADD COLUMN is_active INTEGER DEFAULT 1');
      
      // 2. 기존 데이터에 UUID 생성
      final existingSurveys = await db.query('survey');
      for (int i = 0; i < existingSurveys.length; i++) {
        final survey = existingSurveys[i];
        final surveyId = survey['id'] as int;
        final uuid = 'survey_${surveyId}_${DateTime.now().millisecondsSinceEpoch}';
        
        await db.update(
          'survey',
          {
            'survey_uuid': uuid,
            'survey_order': i,
          },
          where: 'id = ?',
          whereArgs: [surveyId],
        );
      }
      
      // 3. UUID 컬럼을 NOT NULL로 변경하기 위해 임시 테이블 사용
      await db.execute('''
        CREATE TABLE survey_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          survey_uuid TEXT NOT NULL UNIQUE,
          survey_name TEXT NOT NULL,
          survey_description TEXT,
          start_date TEXT,
          end_date TEXT,
          survey_order INTEGER DEFAULT 0,
          is_active INTEGER DEFAULT 1,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      
      // 4. 데이터 복사
      await db.execute('''
        INSERT INTO survey_new (id, survey_uuid, survey_name, survey_description, 
                               start_date, end_date, survey_order, is_active, created_at, updated_at)
        SELECT id, survey_uuid, survey_name, survey_description, 
               start_date, end_date, survey_order, is_active, created_at, updated_at
        FROM survey WHERE survey_uuid IS NOT NULL
      ''');
      
      // 5. 기존 테이블 삭제 후 새 테이블로 교체
      await db.execute('DROP TABLE survey');
      await db.execute('ALTER TABLE survey_new RENAME TO survey');
      
      // 6. 인덱스 생성
      await db.execute('CREATE INDEX IF NOT EXISTS idx_survey_uuid ON survey(survey_uuid)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_survey_order ON survey(survey_order)');
      
      // 7. 기타 인덱스 생성
      await db.execute('CREATE INDEX IF NOT EXISTS idx_survey_status_date ON survey_status(survey_date, time)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_survey_response_date ON survey_response(survey_date)');
      
      debugPrint('다중 설문 스키마 마이그레이션 완료');
    } catch (e) {
      debugPrint('스키마 마이그레이션 중 오류: $e');
      // 마이그레이션 실패 시 전체 재생성
      rethrow;
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

  // API 응답 데이터를 정규화하여 DB에 저장 (다중 설문 지원)
  static Future<({int newRecords, int updatedRecords})> saveSurveyDataFromApi(String userId, Map<String, dynamic> data) async {
    final db = await database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 전체 변경 사항 추적을 위한 변수
    int totalNewRecords = 0;
    int totalUpdatedRecords = 0;
    
    try {
      // 1. API 응답 데이터에서 설문 정보 추출
      final surveys = data['surveys'] as List<dynamic>?;
      if (surveys == null || surveys.isEmpty) {
        return (newRecords: 0, updatedRecords: 0);
      }
      
      if (enableDebugLogs) {
        debugPrint('처리할 설문 개수: ${surveys.length}개');
      }
      
      // 2. 각 설문을 순회하여 처리
      for (int i = 0; i < surveys.length; i++) {
        final surveyData = surveys[i];
        if (surveyData == null || surveyData is! Map<String, dynamic>) {
          if (enableDebugLogs) {
            debugPrint('설문 $i: 잘못된 데이터 형식, 건너뜀');
          }
          continue;
        }
        
        if (enableDebugLogs) {
          debugPrint('\n=== 설문 ${i + 1}/${surveys.length} 처리 시작 ===');
        }
        
        // 3. 설문 UUID 생성 (고유 식별자)
        final surveyInfo = surveyData['surveyInfo'] as Map<String, dynamic>?;
        final surveyName = surveyInfo?['surveyName'] ?? '설문조사';
        final surveyUuid = 'survey_${i}_${surveyName.hashCode}_${DateTime.now().millisecondsSinceEpoch}';
        
        // 4. 현재 데이터베이스에 저장된 설문 데이터 조회
        final existingSurveyData = await _getCurrentSurveyDataByOrder(db, userId, i);
        
        // 5. 새 데이터와 기존 데이터 비교
        final comparisonResult = await _compareSurveyData(
          existingSurveyData, 
          surveyData, 
          userId, 
          today,
          surveyIndex: i,
          surveyUuid: surveyUuid,
        );
        
        totalNewRecords += comparisonResult.newRecords;
        totalUpdatedRecords += comparisonResult.updatedRecords;
        
        if (enableDebugLogs) {
          debugPrint('설문 ${i + 1} 완료: 새 레코드 ${comparisonResult.newRecords}개, 업데이트 ${comparisonResult.updatedRecords}개');
        }
      }
      
      if (enableDebugLogs) {
        debugPrint('\n=== 전체 설문 처리 완료 ===');
        debugPrint('총 새 레코드: $totalNewRecords개');
        debugPrint('총 업데이트: $totalUpdatedRecords개');
      }
      
      return (newRecords: totalNewRecords, updatedRecords: totalUpdatedRecords);
      
    } catch (e) {
      debugPrint('API 설문 데이터 저장 중 오류: $e');
      return (newRecords: totalNewRecords, updatedRecords: totalUpdatedRecords);
    }
  }
  
  // 설문 순서별로 기존 데이터 조회
  static Future<Map<String, dynamic>> _getCurrentSurveyDataByOrder(Database db, String userId, int surveyOrder) async {
    final result = <String, dynamic>{};
    
    try {
      // 1. 설문 기본 정보 조회 (순서별)
      final surveys = await db.query(
        'survey',
        where: 'survey_order = ?',
        whereArgs: [surveyOrder],
        limit: 1,
      );
      
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
      debugPrint('기존 설문 데이터 조회 중 오류 (순서: $surveyOrder): $e');
    }
    
    return result;
  }
  
  // 새 데이터와 기존 데이터를 비교하는 메서드 (다중 설문 지원)
  static Future<({int newRecords, int updatedRecords})> _compareSurveyData(
    Map<String, dynamic> existingData,
    Map<String, dynamic> newData,
    String userId,
    String today,
    {required int surveyIndex, required String surveyUuid}
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
              debugPrint('설문 기본 정보 업데이트 (ID: $surveyId, 순서: $surveyIndex)');
            }
          }
        } else {
          // 새 설문 정보 추가
          surveyId = await txn.insert('survey', {
            'survey_uuid': surveyUuid,
            'survey_name': surveyName,
            'survey_description': surveyDescription,
            'start_date': startDate,
            'end_date': endDate,
            'survey_order': surveyIndex,
            'is_active': 1,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
          newRecords++;
          
          if (enableDebugLogs) {
            debugPrint('새 설문 정보 추가 (ID: $surveyId, UUID: $surveyUuid, 순서: $surveyIndex)');
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
                debugPrint('새 알림 시간 추가: $time (Survey ID: $surveyId)');
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
                debugPrint('알림 시간 삭제: $existingTime (Survey ID: $surveyId)');
              }
            }
          }
        }
        
        // 3. 설문 상태 비교 및 업데이트 (API 응답으로 항상 덮어쓰기)
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
                    
                    // API 응답은 항상 덮어쓰기 (서버 응답이 가장 정확)
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
                      debugPrint('설문 상태 덮어쓰기: $timeStr (제출: $isSubmitted, Survey ID: $surveyId)');
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
                    debugPrint('새 설문 상태 추가: $timeStr (Survey ID: $surveyId)');
                  }
                }
              }
            }
          }
        }
        
        // 4. 설문 내용(페이지 및 질문) 비교 및 업데이트
        final surveyByTime = newData['surveyByTime'];
        if (surveyByTime != null && surveyByTime is List) {
          // 기존 설문 내용을 해시맵으로 변환
          final existingSurveyByTime = existingData['surveyByTime'] as List? ?? [];
          final existingContentHash = _generateContentHash(existingSurveyByTime);
          final newContentHash = _generateContentHash(surveyByTime);
          
          if (enableDebugLogs) {
            debugPrint('설문 내용 해시 비교 (Survey ID: $surveyId):');
            debugPrint('  기존 해시: $existingContentHash');
            debugPrint('  새 해시: $newContentHash');
          }
          
          // 내용이 다른 경우에만 업데이트
          if (existingContentHash != newContentHash) {
            if (enableDebugLogs) {
              debugPrint('설문 내용 변경 감지 (Survey ID: $surveyId)');
            }
            
            try {
              // 기존 페이지 및 질문 정보 조회
              final existingPages = await txn.query(
                'survey_page',
                where: 'survey_id = ?',
                whereArgs: [surveyId]
              );
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
                debugPrint('기존 데이터 조회 완료 (Survey ID: $surveyId): ${existingPages.length}개 페이지, ${existingQuestions.length}개 질문');
              }
              
              // 새 데이터와 기존 데이터 비교를 위한 변수
              final updatedPageIds = <int>{};
              final updatedQuestionIds = <String>{};
              
              if (enableDebugLogs) {
                debugPrint('설문 내용 upsert 시작 (Survey ID: $surveyId)');
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
                        debugPrint('페이지 업데이트 (ID: $pageId, Survey ID: $surveyId): 제목 변경');
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
                      debugPrint('새 페이지 추가 (ID: $pageId, Survey ID: $surveyId): $timeStr, 페이지 $pageNumber');
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
                        // 원래 ID를 시간대와 설문 ID를 포함한 고유 ID로 변환
                        final thenList = followUpData['then'] as List;
                        final updatedThenList = thenList.map((item) {
                          if (item != null) {
                            return '${surveyId}_${timeStr}_${item.toString()}';
                          }
                          return item;
                        }).toList();
                        
                        // 업데이트된 ID로 followUp 데이터 재구성
                        followUpData = Map<String, dynamic>.from(followUpData);
                        followUpData['then'] = updatedThenList;
                      }
                      
                      final followUp = followUpData != null ? jsonEncode(followUpData) : 'null';
                      
                      // 설문 ID, 시간대, 원본 ID를 포함한 고유 ID 생성
                      final uniqueId = '${surveyId}_${timeStr}_${id.toString()}';
                      
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
                            debugPrint('질문 업데이트 진행 중 (Survey ID: $surveyId): $updatedRecords개 완료');
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
                            debugPrint('질문 추가 진행 중 (Survey ID: $surveyId): $newRecords개 완료');
                          }
                        } catch (e) {
                          debugPrint('질문 추가 중 오류 (ID: $uniqueId, Survey ID: $surveyId): $e');
                        }
                      }
                    }
                  }
                }
              }
              
              if (enableDebugLogs) {
                debugPrint('설문 내용 upsert 완료 (Survey ID: $surveyId)');
                debugPrint('  업데이트된 페이지: ${updatedPageIds.length}개');
                debugPrint('  업데이트된 질문: ${updatedQuestionIds.length}개');
              }
            } catch (e) {
              debugPrint('설문 내용 비교 중 오류 (Survey ID: $surveyId): $e');
            }
          } else if (enableDebugLogs) {
            debugPrint('설문 내용 변경 없음 (Survey ID: $surveyId, 해시 일치)');
          }
        }
      }
      
      // 5. 요약 정보 출력
      if (enableDebugLogs) {
        debugPrint('\n===== 설문 ${surveyIndex + 1} 저장 요약 =====');
        debugPrint('새로운 레코드: $newRecords개');
        debugPrint('업데이트된 레코드: $updatedRecords개');
        debugPrint('총 변경 사항: ${newRecords + updatedRecords}개');
        debugPrint('================================\n');
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
  
  // 모든 설문 조회 (순서별 정렬)
  static Future<List<Map<String, dynamic>>> getAllSurveys() async {
    final db = await database;
    return await db.query(
      'survey',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'survey_order ASC',
    );
  }
  
  // 특정 설문의 알림 시간 조회
  static Future<List<String>> getSurveyNotificationTimes(int surveyId) async {
    final db = await database;
    final results = await db.query(
      'survey_notification_times',
      columns: ['time'],
      where: 'survey_id = ?',
      whereArgs: [surveyId],
      orderBy: 'time ASC',
    );
    return results.map((row) => row['time'] as String).toList();
  }
  
  // 특정 날짜의 모든 설문 상태 조회
  static Future<List<Map<String, dynamic>>> getAllSurveyStatusByDate({
    required String userId,
    required String surveyDate,
  }) async {
    final db = await database;
    
    return await db.rawQuery('''
      SELECT ss.*, s.survey_name, s.survey_uuid, s.survey_order
      FROM survey_status ss
      JOIN survey s ON ss.survey_id = s.id
      WHERE ss.user_id = ? AND ss.survey_date = ? AND s.is_active = 1
      ORDER BY s.survey_order ASC, ss.time ASC
    ''', [userId, surveyDate]);
  }
  
  // 특정 설문의 특정 날짜 상태 조회
  static Future<List<Map<String, dynamic>>> getSurveyStatusByDate({
    required String userId,
    required String surveyDate,
    int? surveyId,
  }) async {
    final db = await database;
    
    String whereClause = 'user_id = ? AND survey_date = ?';
    List<dynamic> whereArgs = [userId, surveyDate];
    
    if (surveyId != null) {
      whereClause += ' AND survey_id = ?';
      whereArgs.add(surveyId);
    }
    
    return await db.query(
      'survey_status',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'time ASC',
    );
  }
  
  // 설문 응답 저장
  static Future<void> saveSurveyResponse({
    required String questionId,
    required String userId,
    required String surveyDate,
    required String answer,
  }) async {
    final db = await database;
    
    try {
      await db.insert(
        'survey_response',
        {
          'question_id': questionId,
          'user_id': userId,
          'survey_date': surveyDate,
          'answer': answer,
          'submitted_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      if (enableDebugLogs) {
        debugPrint('설문 응답 저장 완료: $questionId');
      }
    } catch (e) {
      debugPrint('설문 응답 저장 중 오류: $e');
    }
  }
  
  // 특정 날짜의 설문 응답 조회
  static Future<List<Map<String, dynamic>>> getSurveyResponses({
    required String userId,
    required String surveyDate,
    int? surveyId,
  }) async {
    final db = await database;
    
    String query = '''
      SELECT sr.*, sq.question_text, sq.question_type, sp.title as page_title
      FROM survey_response sr
      JOIN survey_question sq ON sr.question_id = sq.id
      JOIN survey_page sp ON sq.page_id = sp.id
    ''';
    
    List<dynamic> whereArgs = [userId, surveyDate];
    String whereClause = 'sr.user_id = ? AND sr.survey_date = ?';
    
    if (surveyId != null) {
      query += ' JOIN survey s ON sp.survey_id = s.id';
      whereClause += ' AND s.id = ?';
      whereArgs.add(surveyId);
    }
    
    query += ' WHERE $whereClause ORDER BY sr.submitted_at DESC';
    
    return await db.rawQuery(query, whereArgs);
  }
  
  // 알림 스케줄 저장
  static Future<void> saveNotificationSchedule({
    required int surveyId,
    required String userId,
    required String time,
    required String startDate,
    required String endDate,
    required String notificationId,
  }) async {
    final db = await database;
    
    try {
      await db.insert(
        'notification_schedule',
        {
          'survey_id': surveyId,
          'user_id': userId,
          'time': time,
          'start_date': startDate,
          'end_date': endDate,
          'notification_id': notificationId,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      if (enableDebugLogs) {
        debugPrint('알림 스케줄 저장 완료: Survey ID $surveyId, Time $time');
      }
    } catch (e) {
      debugPrint('알림 스케줄 저장 중 오류: $e');
    }
  }
  
  // 알림 스케줄 조회
  static Future<List<Map<String, dynamic>>> getNotificationSchedules({
    required String userId,
    int? surveyId,
  }) async {
    final db = await database;
    
    String whereClause = 'user_id = ?';
    List<dynamic> whereArgs = [userId];
    
    if (surveyId != null) {
      whereClause += ' AND survey_id = ?';
      whereArgs.add(surveyId);
    }
    
    return await db.query(
      'notification_schedule',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'time ASC',
    );
  }
  
  // 설문 상태 업데이트 (제출 완료 처리)
  static Future<void> updateSurveyStatus({
    required int surveyId,
    required String userId,
    required String surveyDate,
    required String time,
    required bool submitted,
  }) async {
    final db = await database;
    
    try {
      await db.update(
        'survey_status',
        {
          'submitted': submitted ? 1 : 0,
          'submitted_at': submitted ? DateTime.now().toIso8601String() : null,
        },
        where: 'survey_id = ? AND user_id = ? AND survey_date = ? AND time = ?',
        whereArgs: [surveyId, userId, surveyDate, time],
      );
      
      if (enableDebugLogs) {
        debugPrint('설문 상태 업데이트 완료: Survey ID $surveyId, Time $time, Submitted: $submitted');
      }
    } catch (e) {
      debugPrint('설문 상태 업데이트 중 오류: $e');
    }
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
  
  /// 특정 설문의 모든 데이터 출력 (디버깅용)
  static Future<void> logSurveyData(int surveyId) async {
    if (!enableDebugLogs) return;
    
    final db = await database;
    
    debugPrint('\n===== SURVEY DATA DUMP (ID: $surveyId) =====');
    
    // 1. 설문 기본 정보
    final survey = await db.query('survey', where: 'id = ?', whereArgs: [surveyId]);
    debugPrint('Survey Info: ${survey.isNotEmpty ? survey.first : 'Not found'}');
    
    // 2. 알림 시간
    final times = await db.query('survey_notification_times', where: 'survey_id = ?', whereArgs: [surveyId]);
    debugPrint('Notification Times: $times');
    
    // 3. 설문 페이지
    final pages = await db.query('survey_page', where: 'survey_id = ?', whereArgs: [surveyId]);
    debugPrint('Pages: $pages');
    
    // 4. 설문 질문 (페이지별)
    for (final page in pages) {
      final pageId = page['id'];
      final questions = await db.query('survey_question', where: 'page_id = ?', whereArgs: [pageId]);
      debugPrint('Page $pageId Questions: $questions');
    }
    
    // 5. 설문 상태
    final status = await db.query('survey_status', where: 'survey_id = ?', whereArgs: [surveyId]);
    debugPrint('Survey Status: $status');
    
    debugPrint('===== END SURVEY DUMP =====\n');
  }

  /// 데이터베이스의 모든 데이터를 삭제
  static Future<void> clearAllData() async {
    final db = await database;
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
    
    // 외래키 제약 조건 해제
    await db.execute('PRAGMA foreign_keys = OFF');
    
    for (final table in tables) {
      await db.delete(table['name'] as String);
    }
    
    // 외래키 제약 조건 다시 활성화
    await db.execute('PRAGMA foreign_keys = ON');
    
    if (enableDebugLogs) {
      debugPrint('모든 테이블의 데이터 삭제 완료');
    }
  }
  
  /// 특정 설문 데이터만 삭제
  static Future<void> clearSurveyData(int surveyId) async {
    final db = await database;
    
    await db.transaction((txn) async {
      // 외래키 제약조건으로 인해 순서대로 삭제
      await txn.delete('notification_schedule', where: 'survey_id = ?', whereArgs: [surveyId]);
      await txn.delete('survey_response', where: 'question_id IN (SELECT sq.id FROM survey_question sq JOIN survey_page sp ON sq.page_id = sp.id WHERE sp.survey_id = ?)', whereArgs: [surveyId]);
      await txn.delete('survey_question', where: 'page_id IN (SELECT id FROM survey_page WHERE survey_id = ?)', whereArgs: [surveyId]);
      await txn.delete('survey_page', where: 'survey_id = ?', whereArgs: [surveyId]);
      await txn.delete('survey_status', where: 'survey_id = ?', whereArgs: [surveyId]);
      await txn.delete('survey_notification_times', where: 'survey_id = ?', whereArgs: [surveyId]);
      await txn.delete('survey', where: 'id = ?', whereArgs: [surveyId]);
    });
    
    if (enableDebugLogs) {
      debugPrint('설문 ID $surveyId 데이터 삭제 완료');
    }
  }
  
  /// 데이터베이스 통계 정보 출력
  static Future<void> logDatabaseStats() async {
    if (!enableDebugLogs) return;
    
    final db = await database;
    
    debugPrint('\n===== DATABASE STATISTICS =====');
    
    // 각 테이블별 레코드 수
    final tables = ['user_info', 'survey', 'survey_notification_times', 'survey_status', 
                   'survey_page', 'survey_question', 'survey_response', 'notification_schedule'];
    
    for (final table in tables) {
      try {
        final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
        final count = result.first['count'];
        debugPrint('$table: $count records');
      } catch (e) {
        debugPrint('$table: Error counting records - $e');
      }
    }
    
    // 설문별 통계
    try {
      final surveyStats = await db.rawQuery('''
        SELECT s.id, s.survey_name, s.survey_order,
               COUNT(DISTINCT snt.time) as notification_times_count,
               COUNT(DISTINCT sp.id) as pages_count,
               COUNT(DISTINCT sq.id) as questions_count
        FROM survey s
        LEFT JOIN survey_notification_times snt ON s.id = snt.survey_id
        LEFT JOIN survey_page sp ON s.id = sp.survey_id
        LEFT JOIN survey_question sq ON sp.id = sq.page_id
        WHERE s.is_active = 1
        GROUP BY s.id, s.survey_name, s.survey_order
        ORDER BY s.survey_order
      ''');
      
      debugPrint('\n--- Survey Details ---');
      for (final stat in surveyStats) {
        debugPrint('Survey ${stat['survey_order']}: ${stat['survey_name']}');
        debugPrint('  - ${stat['notification_times_count']} notification times');
        debugPrint('  - ${stat['pages_count']} pages');
        debugPrint('  - ${stat['questions_count']} questions');
      }
    } catch (e) {
      debugPrint('Survey statistics error: $e');
    }
    
    debugPrint('===============================\n');
  }
}