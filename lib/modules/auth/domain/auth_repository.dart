import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import 'entities/login_result.dart';
import 'entities/register_result.dart';
import 'entities/resend_code_result.dart';
import 'entities/password_reset_account.dart';
import 'entities/username_availability.dart';
import 'entities/verify_code_result.dart';

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
    String? venueName,
    String? venueAddress,
    String? phone,
    String? cityId,
    String? districtId,
    String? neighborhoodId,
    String? studioName,
    String? studioAddress,
    String? studioPhone,
  });

  Future<Result<VerifyCodeResult>> verifyCode({
    required String email,
    required String code,
  });

  Future<Result<ResendCodeResult>> resendCode({required String email});

  Future<Result<UsernameAvailability>> checkUsernameAvailability({
    required String username,
  }) async {
    return const Result.failure(
      AppError(
        code: 'auth_username_availability_unsupported',
        message: 'Kullanıcı adı uygunluk kontrolü desteklenmiyor.',
      ),
    );
  }

  Future<Result<PasswordResetAccount>> resolvePasswordResetAccount({
    required String identifier,
  }) async {
    return const Result.failure(
      AppError(
        code: 'auth_password_reset_account_unsupported',
        message: 'Hesap kontrolü desteklenmiyor.',
      ),
    );
  }

  Future<Result<void>> requestPasswordReset({required String identifier});

  Future<Result<void>> resetPassword({
    required String identifier,
    required String code,
    required String password,
    required String rePassword,
  });

  Future<Result<String>> updateUsername({required String username});
}
