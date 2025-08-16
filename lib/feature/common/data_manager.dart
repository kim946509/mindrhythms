import 'package:mindrhythms/core/data_source.dart';
import 'package:mindrhythms/core/data_service.dart';

/// 데이터 관리 클래스 (간단한 절차지향 방식)
/// 로컬DB, API, 메모리 캐시를 통한 CRUD 작업을 처리
class DataManager {
  
  // ============================================================================
  // 로컬 DB 관련 메소드
  // ============================================================================
  
  /// 로컬DB에서 데이터 가져오기
  /// [key]: 데이터 키
  /// 반환값: 데이터 (없으면 null)
  static Future<T?> getFromLocal<T>(String key) async {
    try {
      final request = DataRequest(source: DataSource.localDb, key: key);
      final service = DataServiceFactory.getService(DataSource.localDb);
      final response = await service.getData<T>(request);
      
      if (response.success) {
        return response.data;
      }
      return null;
    } catch (e) {
      print('로컬DB 데이터 가져오기 실패: $e');
      return null;
    }
  }

  /// 로컬DB에 데이터 저장
  /// [key]: 데이터 키
  /// [data]: 저장할 데이터
  /// 반환값: true(성공), false(실패)
  static Future<bool> saveToLocal(String key, dynamic data) async {
    try {
      final request = DataRequest(source: DataSource.localDb, key: key);
      final service = DataServiceFactory.getService(DataSource.localDb);
      final response = await service.setData(request, data);
      
      return response.success;
    } catch (e) {
      print('로컬DB 데이터 저장 실패: $e');
      return false;
    }
  }

  /// 로컬DB에서 데이터 삭제
  /// [key]: 데이터 키
  /// 반환값: true(성공), false(실패)
  static Future<bool> deleteFromLocal(String key) async {
    try {
      final request = DataRequest(source: DataSource.localDb, key: key);
      final service = DataServiceFactory.getService(DataSource.localDb);
      final response = await service.deleteData(request);
      
      return response.success;
    } catch (e) {
      print('로컬DB 데이터 삭제 실패: $e');
      return false;
    }
  }

  // ============================================================================
  // API 관련 메소드
  // ============================================================================

  /// API에서 데이터 가져오기
  /// [key]: API 엔드포인트 키
  /// [params]: 요청 파라미터
  /// 반환값: 데이터 (없으면 null)
  static Future<T?> getFromApi<T>(String key, {Map<String, dynamic>? params}) async {
    try {
      final request = DataRequest(
        source: DataSource.api,
        key: key,
        params: params,
      );
      final service = DataServiceFactory.getService(DataSource.api);
      final response = await service.getData<T>(request);
      
      if (response.success) {
        return response.data;
      }
      return null;
    } catch (e) {
      print('API 데이터 가져오기 실패: $e');
      return null;
    }
  }

  /// API로 데이터 저장 (POST/PUT)
  /// [key]: API 엔드포인트 키
  /// [data]: 저장할 데이터
  /// [params]: 추가 파라미터
  /// 반환값: true(성공), false(실패)
  static Future<bool> saveToApi(String key, dynamic data, {Map<String, dynamic>? params}) async {
    try {
      final request = DataRequest(
        source: DataSource.api,
        key: key,
        params: params,
      );
      final service = DataServiceFactory.getService(DataSource.api);
      final response = await service.setData(request, data);
      
      return response.success;
    } catch (e) {
      print('API 데이터 저장 실패: $e');
      return false;
    }
  }

  /// API로 데이터 업데이트 (PUT/PATCH)
  /// [key]: API 엔드포인트 키
  /// [data]: 업데이트할 데이터
  /// [params]: 추가 파라미터
  /// 반환값: true(성공), false(실패)
  static Future<bool> updateToApi(String key, dynamic data, {Map<String, dynamic>? params}) async {
    // 업데이트도 saveToApi와 동일하게 처리 (실제 구현에서는 HTTP 메소드로 구분)
    return await saveToApi(key, data, params: params);
  }

  /// API에서 데이터 삭제 (DELETE)
  /// [key]: API 엔드포인트 키
  /// [params]: 삭제 조건 파라미터
  /// 반환값: true(성공), false(실패)
  static Future<bool> deleteFromApi(String key, {Map<String, dynamic>? params}) async {
    try {
      final request = DataRequest(
        source: DataSource.api,
        key: key,
        params: params,
      );
      final service = DataServiceFactory.getService(DataSource.api);
      final response = await service.deleteData(request);
      
      return response.success;
    } catch (e) {
      print('API 데이터 삭제 실패: $e');
      return false;
    }
  }

  // ============================================================================
  // 메모리 캐시 관련 메소드
  // ============================================================================

  /// 메모리 캐시에서 데이터 가져오기
  /// [key]: 캐시 키
  /// 반환값: 데이터 (없으면 null)
  static Future<T?> getFromCache<T>(String key) async {
    try {
      final request = DataRequest(source: DataSource.memory, key: key);
      final service = DataServiceFactory.getService(DataSource.memory);
      final response = await service.getData<T>(request);
      
      if (response.success) {
        return response.data;
      }
      return null;
    } catch (e) {
      print('캐시 데이터 가져오기 실패: $e');
      return null;
    }
  }

  /// 메모리 캐시에 데이터 저장
  /// [key]: 캐시 키
  /// [data]: 저장할 데이터
  /// 반환값: true(성공), false(실패)
  static Future<bool> saveToCache(String key, dynamic data) async {
    try {
      final request = DataRequest(source: DataSource.memory, key: key);
      final service = DataServiceFactory.getService(DataSource.memory);
      final response = await service.setData(request, data);
      
      return response.success;
    } catch (e) {
      print('캐시 데이터 저장 실패: $e');
      return false;
    }
  }

  /// 메모리 캐시에서 데이터 삭제
  /// [key]: 캐시 키
  /// 반환값: true(성공), false(실패)
  static Future<bool> deleteFromCache(String key) async {
    try {
      final request = DataRequest(source: DataSource.memory, key: key);
      final service = DataServiceFactory.getService(DataSource.memory);
      final response = await service.deleteData(request);
      
      return response.success;
    } catch (e) {
      print('캐시 데이터 삭제 실패: $e');
      return false;
    }
  }

  // ============================================================================
  // 통합 메소드 (폴백 전략)
  // ============================================================================

  /// 여러 소스에서 데이터 가져오기 (캐시 → 로컬DB → API 순)
  /// [key]: 데이터 키
  /// [params]: API 요청 시 사용할 파라미터
  /// 반환값: 데이터 (없으면 null)
  static Future<T?> getData<T>(String key, {Map<String, dynamic>? params}) async {
    // 1. 캐시에서 확인
    T? data = await getFromCache<T>(key);
    if (data != null) {
      print('캐시에서 데이터 로드: $key');
      return data;
    }

    // 2. 로컬DB에서 확인
    data = await getFromLocal<T>(key);
    if (data != null) {
      print('로컬DB에서 데이터 로드: $key');
      // 캐시에도 저장
      await saveToCache(key, data);
      return data;
    }

    // 3. API에서 가져오기
    data = await getFromApi<T>(key, params: params);
    if (data != null) {
      print('API에서 데이터 로드: $key');
      // 로컬DB와 캐시에 저장
      await saveToLocal(key, data);
      await saveToCache(key, data);
      return data;
    }

    print('모든 소스에서 데이터를 찾을 수 없음: $key');
    return null;
  }

  /// 모든 소스에 데이터 저장 (API → 로컬DB → 캐시)
  /// [key]: 데이터 키
  /// [data]: 저장할 데이터
  /// [saveToApiToo]: API에도 저장할지 여부
  /// 반환값: true(성공), false(실패)
  static Future<bool> saveData(String key, dynamic data, {bool saveToApiToo = false}) async {
    bool success = true;

    // 1. API에 저장 (옵션)
    if (saveToApiToo) {
      final apiResult = await saveToApi(key, data);
      if (!apiResult) {
        print('API 저장 실패: $key');
        success = false;
      }
    }

    // 2. 로컬DB에 저장
    final localResult = await saveToLocal(key, data);
    if (!localResult) {
      print('로컬DB 저장 실패: $key');
      success = false;
    }

    // 3. 캐시에 저장
    final cacheResult = await saveToCache(key, data);
    if (!cacheResult) {
      print('캐시 저장 실패: $key');
      success = false;
    }

    return success;
  }

  /// 모든 소스에서 데이터 삭제 (API → 로컬DB → 캐시)
  /// [key]: 데이터 키
  /// [deleteFromApiToo]: API에서도 삭제할지 여부
  /// 반환값: true(성공), false(실패)
  static Future<bool> deleteData(String key, {bool deleteFromApiToo = false}) async {
    bool success = true;

    // 1. API에서 삭제 (옵션)
    if (deleteFromApiToo) {
      final apiResult = await deleteFromApi(key);
      if (!apiResult) {
        print('API 삭제 실패: $key');
        success = false;
      }
    }

    // 2. 로컬DB에서 삭제
    final localResult = await deleteFromLocal(key);
    if (!localResult) {
      print('로컬DB 삭제 실패: $key');
      success = false;
    }

    // 3. 캐시에서 삭제
    final cacheResult = await deleteFromCache(key);
    if (!cacheResult) {
      print('캐시 삭제 실패: $key');
      success = false;
    }

    return success;
  }

  /// 데이터 동기화 (로컬 → API)
  /// [key]: 데이터 키
  /// 반환값: true(성공), false(실패)
  static Future<bool> syncToApi(String key) async {
    final localData = await getFromLocal(key);
    if (localData != null) {
      return await saveToApi(key, localData);
    }
    return false;
  }

  /// 데이터 동기화 (API → 로컬)
  /// [key]: 데이터 키
  /// [params]: API 요청 파라미터
  /// 반환값: true(성공), false(실패)
  static Future<bool> syncFromApi(String key, {Map<String, dynamic>? params}) async {
    final apiData = await getFromApi(key, params: params);
    if (apiData != null) {
      final localSaved = await saveToLocal(key, apiData);
      final cacheSaved = await saveToCache(key, apiData);
      return localSaved && cacheSaved;
    }
    return false;
  }
}
