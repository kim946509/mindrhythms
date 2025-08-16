import 'package:mindrhythms/core/data_source.dart';
import 'package:mindrhythms/core/app_context.dart';

/// 데이터 서비스 추상 클래스
abstract class DataService {
  Future<DataResponse<T>> getData<T>(DataRequest request);
  Future<DataResponse<bool>> setData(DataRequest request, dynamic data);
  Future<DataResponse<bool>> deleteData(DataRequest request);
}

/// 로컬 데이터베이스 서비스 (실제로는 SharedPreferences나 Hive 등 사용)
class LocalDbService implements DataService {
  @override
  Future<DataResponse<T>> getData<T>(DataRequest request) async {
    try {
      // TODO: 실제 로컬DB (SharedPreferences, Hive 등) 구현
      await Future.delayed(const Duration(milliseconds: 100)); // 시뮬레이션
      
      // 시뮬레이션 데이터
      Map<String, dynamic> mockData = {
        'user_settings': {'theme': 'dark', 'language': 'ko'},
        'app_config': {'version': '1.0.0', 'name': '마음리듬'},
      };

      final data = mockData[request.key] as T?;
      if (data != null) {
        return DataResponse.success(data, DataSource.localDb);
      } else {
        return DataResponse.error('데이터를 찾을 수 없습니다', DataSource.localDb);
      }
    } catch (e) {
      return DataResponse.error('로컬DB 오류: $e', DataSource.localDb);
    }
  }

  @override
  Future<DataResponse<bool>> setData(DataRequest request, dynamic data) async {
    try {
      // TODO: 실제 로컬DB 저장 구현
      await Future.delayed(const Duration(milliseconds: 50));
      return DataResponse.success(true, DataSource.localDb);
    } catch (e) {
      return DataResponse.error('저장 실패: $e', DataSource.localDb);
    }
  }

  @override
  Future<DataResponse<bool>> deleteData(DataRequest request) async {
    try {
      // TODO: 실제 로컬DB 삭제 구현
      await Future.delayed(const Duration(milliseconds: 50));
      return DataResponse.success(true, DataSource.localDb);
    } catch (e) {
      return DataResponse.error('삭제 실패: $e', DataSource.localDb);
    }
  }
}

/// API 서비스
class ApiService implements DataService {
  @override
  Future<DataResponse<T>> getData<T>(DataRequest request) async {
    try {
      // TODO: 실제 HTTP 요청 구현
      await Future.delayed(const Duration(milliseconds: 500)); // 네트워크 시뮬레이션
      
      // 시뮬레이션 API 응답
      Map<String, dynamic> mockApiData = {
        'user_profile': {'id': 1, 'name': '사용자', 'email': 'user@example.com'},
        'app_info': {'version': '1.0.0', 'updates': []},
      };

      final data = mockApiData[request.key] as T?;
      if (data != null) {
        return DataResponse.success(data, DataSource.api);
      } else {
        return DataResponse.error('API에서 데이터를 찾을 수 없습니다', DataSource.api);
      }
    } catch (e) {
      return DataResponse.error('API 오류: $e', DataSource.api);
    }
  }

  @override
  Future<DataResponse<bool>> setData(DataRequest request, dynamic data) async {
    try {
      // TODO: 실제 HTTP POST/PUT 요청 구현
      await Future.delayed(const Duration(milliseconds: 300));
      return DataResponse.success(true, DataSource.api);
    } catch (e) {
      return DataResponse.error('API 저장 실패: $e', DataSource.api);
    }
  }

  @override
  Future<DataResponse<bool>> deleteData(DataRequest request) async {
    try {
      // TODO: 실제 HTTP DELETE 요청 구현
      await Future.delayed(const Duration(milliseconds: 300));
      return DataResponse.success(true, DataSource.api);
    } catch (e) {
      return DataResponse.error('API 삭제 실패: $e', DataSource.api);
    }
  }
}

/// 메모리(캐시) 서비스
class MemoryService implements DataService {
  @override
  Future<DataResponse<T>> getData<T>(DataRequest request) async {
    try {
      final context = AppContext.instance;
      final data = context.getCache<T>(request.key);
      
      if (data != null) {
        return DataResponse.success(data, DataSource.memory);
      } else {
        return DataResponse.error('캐시에 데이터가 없습니다', DataSource.memory);
      }
    } catch (e) {
      return DataResponse.error('메모리 오류: $e', DataSource.memory);
    }
  }

  @override
  Future<DataResponse<bool>> setData(DataRequest request, dynamic data) async {
    try {
      final context = AppContext.instance;
      context.setCache(request.key, data);
      return DataResponse.success(true, DataSource.memory);
    } catch (e) {
      return DataResponse.error('캐시 저장 실패: $e', DataSource.memory);
    }
  }

  @override
  Future<DataResponse<bool>> deleteData(DataRequest request) async {
    try {
      final context = AppContext.instance;
      context.removeCache(request.key);
      return DataResponse.success(true, DataSource.memory);
    } catch (e) {
      return DataResponse.error('캐시 삭제 실패: $e', DataSource.memory);
    }
  }
}

/// 데이터 서비스 팩토리
class DataServiceFactory {
  static final Map<DataSource, DataService> _services = {
    DataSource.localDb: LocalDbService(),
    DataSource.api: ApiService(),
    DataSource.memory: MemoryService(),
  };

  static DataService getService(DataSource source) {
    return _services[source]!;
  }
}
