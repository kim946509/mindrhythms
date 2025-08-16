/// 데이터를 가져올 소스 타입
enum DataSource {
  /// 로컬 데이터베이스에서 데이터 가져오기
  localDb,
  
  /// API 서버에서 데이터 가져오기
  api,
  
  /// 메모리(캐시)에서 데이터 가져오기
  memory,
}

/// 데이터 요청 옵션
class DataRequest {
  final DataSource source;
  final String key;
  final Map<String, dynamic>? params;
  final Duration? timeout;

  const DataRequest({
    required this.source,
    required this.key,
    this.params,
    this.timeout,
  });
}

/// 데이터 응답
class DataResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final DataSource source;

  const DataResponse({
    required this.success,
    this.data,
    this.error,
    required this.source,
  });

  factory DataResponse.success(T data, DataSource source) {
    return DataResponse(
      success: true,
      data: data,
      source: source,
    );
  }

  factory DataResponse.error(String error, DataSource source) {
    return DataResponse(
      success: false,
      error: error,
      source: source,
    );
  }
}
