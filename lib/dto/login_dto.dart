/// 로그인 DTO
class LoginDto {
  final bool success;
  final String msg;
  final String userCode;
  final String name;

  const LoginDto({
    required this.success,
    required this.msg,
    this.userCode = '',
    this.name = '',
  });

  factory LoginDto.fromJson(Map<String, dynamic> json) {
    return LoginDto(
      success: json['success'] ?? false,
      msg: json['msg'] ?? '',
      userCode: json['userCode'] ?? '',
      name: json['name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'msg': msg,
      'userCode': userCode,
      'name': name,
    };
  }

  @override
  String toString() {
    return 'LoginDto{success: $success, msg: $msg, userCode: $userCode, name: $name}';
  }
}
