import 'db.dart';

class UserInfoCheck {
  static Future<({bool isLoggedIn, String? userId})> check() async {
    try {
      // 가장 최근에 생성된 사용자 정보 조회
      final db = await DataBaseManager.database;
      final List<Map<String, dynamic>> users = await db.query(
        'user_info',
        orderBy: 'created_at DESC',
        limit: 1,
      );

      // 사용자 정보가 없는 경우
      if (users.isEmpty) {
        return (isLoggedIn: false, userId: null);
      }

      // 사용자 정보가 있는 경우, 자동 로그인 대상으로 간주
      final lastUser = users.first;
      final userId = lastUser['user_id'] as String?;

      return (isLoggedIn: true, userId: userId);
    } catch (e) {
      print('사용자 정보 체크 중 오류 발생: $e');
      return (isLoggedIn: false, userId: null);
    }
  }
}