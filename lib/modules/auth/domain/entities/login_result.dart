import 'user_status.dart';

class LoginResult {
  final String token;
  final UserStatus status;

  const LoginResult({required this.token, this.status = UserStatus.active});
}
