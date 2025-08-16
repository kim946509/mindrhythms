import 'package:get/get.dart';

/// 앱 전역에서 사용할 수 있는 컨텍스트
/// 데이터, 설정, 상태 등을 저장하고 관리
class AppContext extends GetxController {
  static AppContext get instance => Get.find<AppContext>();

  // 사용자 정보
  final RxMap<String, dynamic> _userInfo = <String, dynamic>{}.obs;
  Map<String, dynamic> get userInfo => _userInfo;

  // 앱 설정
  final RxMap<String, dynamic> _appSettings = <String, dynamic>{}.obs;
  Map<String, dynamic> get appSettings => _appSettings;

  // 캐시 데이터 (메모리)
  final Map<String, dynamic> _cache = {};

  // 임시 데이터 저장소
  final Map<String, dynamic> _tempData = {};

  /// 사용자 정보 설정
  void setUserInfo(Map<String, dynamic> userInfo) {
    _userInfo.clear();
    _userInfo.addAll(userInfo);
  }

  /// 사용자 정보 업데이트
  void updateUserInfo(String key, dynamic value) {
    _userInfo[key] = value;
  }

  /// 앱 설정 저장
  void setAppSettings(Map<String, dynamic> settings) {
    _appSettings.clear();
    _appSettings.addAll(settings);
  }

  /// 앱 설정 업데이트
  void updateAppSettings(String key, dynamic value) {
    _appSettings[key] = value;
  }

  /// 캐시에 데이터 저장
  void setCache(String key, dynamic value) {
    _cache[key] = value;
  }

  /// 캐시에서 데이터 가져오기
  T? getCache<T>(String key) {
    return _cache[key] as T?;
  }

  /// 캐시 확인
  bool hasCache(String key) {
    return _cache.containsKey(key);
  }

  /// 캐시 삭제
  void removeCache(String key) {
    _cache.remove(key);
  }

  /// 캐시 전체 삭제
  void clearCache() {
    _cache.clear();
  }

  /// 임시 데이터 저장
  void setTempData(String key, dynamic value) {
    _tempData[key] = value;
  }

  /// 임시 데이터 가져오기
  T? getTempData<T>(String key) {
    return _tempData[key] as T?;
  }

  /// 임시 데이터 삭제
  void removeTempData(String key) {
    _tempData.remove(key);
  }

  /// 임시 데이터 전체 삭제
  void clearTempData() {
    _tempData.clear();
  }

  /// 컨텍스트 초기화
  void clear() {
    _userInfo.clear();
    _appSettings.clear();
    _cache.clear();
    _tempData.clear();
  }
}
