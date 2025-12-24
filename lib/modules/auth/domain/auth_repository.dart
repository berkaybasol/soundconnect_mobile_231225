import '../../../core/error/result.dart';
import 'entities/login_result.dart';
import 'entities/register_result.dart';
import 'entities/resend_code_result.dart';

abstract class AuthRepository {
  Future<Result<LoginResult>> login({
    required String username,
    required String password,
  });

  Future<Result<RegisterResult>> register({
    required String username,
    required String email,
    required String password,
    required String rePassword,
    required String role,
  });

  Future<Result<void>> verifyCode({
    required String email,
    required String code,
  });

  Future<Result<ResendCodeResult>> resendCode({
    required String email,
  });
}
