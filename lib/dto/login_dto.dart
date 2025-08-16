/// 로그인 DTO
class LoginDto {
  final bool success;
  final String msg;

  const LoginDto({
    required this.success,
    required this.msg,
  });

  factory LoginDto.fromJson(Map<String, dynamic> json) {
    return LoginDto(
      success: json['success'] ?? false,
      msg: json['msg'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'msg': msg,
    };
  }

  @override
  String toString() {
    return 'LoginDto{success: $success, msg: $msg}';
  }
}
