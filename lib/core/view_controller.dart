import 'package:get/get.dart';
import 'package:mindrhythms/core/data_source.dart';
import 'package:mindrhythms/core/data_service.dart';
import 'package:mindrhythms/core/app_context.dart';

/// 모든 페이지 컨트롤러의 기본 클래스
/// init: 화면이 뜨기 전 데이터 준비 작업
/// execute: 화면 표시 및 이벤트 처리 작업
abstract class ViewController extends GetxController {
  bool _isInitialized = false;
  bool _isExecuted = false;

  bool get isInitialized => _isInitialized;
  bool get isExecuted => _isExecuted;

  /// AppContext 인스턴스 접근
  AppContext get context => AppContext.instance;

  @override
  void onInit() {
    super.onInit();
    _performInit();
  }

  @override
  void onReady() {
    super.onReady();
    _performExecute();
  }

  /// 화면이 뜨기 전에 해야할 일들
  /// - 데이터 가져오기
  /// - 데이터 가공
  /// - 초기 상태 설정
  Future<void> init();

  /// 데이터를 가지고 화면에 띄우고 이벤트를 처리
  /// - UI 업데이트
  /// - 이벤트 리스너 등록
  /// - 네비게이션 로직
  Future<void> execute();

  Future<void> _performInit() async {
    if (!_isInitialized) {
      await init();
      _isInitialized = true;
      update();
    }
  }

  Future<void> _performExecute() async {
    if (_isInitialized && !_isExecuted) {
      await execute();
      _isExecuted = true;
      update();
    }
  }

  /// 데이터를 가져오는 헬퍼 메소드
  Future<DataResponse<T>> fetchData<T>({
    required DataSource source,
    required String key,
    Map<String, dynamic>? params,
    Duration? timeout,
  }) async {
    final request = DataRequest(
      source: source,
      key: key,
      params: params,
      timeout: timeout,
    );
    
    final service = DataServiceFactory.getService(source);
    return await service.getData<T>(request);
  }

  /// 데이터를 저장하는 헬퍼 메소드
  Future<DataResponse<bool>> saveData({
    required DataSource source,
    required String key,
    required dynamic data,
    Map<String, dynamic>? params,
  }) async {
    final request = DataRequest(
      source: source,
      key: key,
      params: params,
    );
    
    final service = DataServiceFactory.getService(source);
    return await service.setData(request, data);
  }

  /// 데이터를 삭제하는 헬퍼 메소드
  Future<DataResponse<bool>> deleteData({
    required DataSource source,
    required String key,
    Map<String, dynamic>? params,
  }) async {
    final request = DataRequest(
      source: source,
      key: key,
      params: params,
    );
    
    final service = DataServiceFactory.getService(source);
    return await service.deleteData(request);
  }

  /// Context에 데이터 저장
  void setContextData(String key, dynamic value) {
    context.setCache(key, value);
  }

  /// Context에서 데이터 가져오기
  T? getContextData<T>(String key) {
    return context.getCache<T>(key);
  }

  /// 여러 소스에서 데이터를 순서대로 시도 (폴백 전략)
  Future<DataResponse<T>> fetchDataWithFallback<T>({
    required String key,
    required List<DataSource> sources,
    Map<String, dynamic>? params,
  }) async {
    for (final source in sources) {
      final response = await fetchData<T>(
        source: source,
        key: key,
        params: params,
      );
      
      if (response.success) {
        return response;
      }
    }
    
    return DataResponse.error(
      '모든 데이터 소스에서 데이터를 가져오는데 실패했습니다',
      sources.last,
    );
  }
}
