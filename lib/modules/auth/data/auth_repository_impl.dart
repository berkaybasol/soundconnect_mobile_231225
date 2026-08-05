import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/auth_repository.dart';
import '../domain/entities/login_result.dart';
import '../domain/entities/password_reset_account.dart';
import '../domain/entities/register_result.dart';
import '../domain/entities/resend_code_result.dart';
import '../domain/entities/username_availability.dart';
import 'auth_endpoints.dart';
import 'models/forgot_password_request.dart';
import 'models/login_request.dart';
import 'models/login_response.dart';
import 'models/password_reset_account_response.dart';
import 'models/register_request.dart';
import 'models/register_response.dart';
import 'models/reset_password_request.dart';
import 'models/resend_code_request.dart';
import 'models/resend_code_response.dart';
import 'models/update_username_request.dart';
import 'models/username_availability_request.dart';
import 'models/username_availability_response.dart';
import 'models/verify_code_request.dart';

class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _apiClient;
  final String? Function() _sessionKeyProvider;

  AuthRepositoryImpl(this._apiClient, {String? Function()? sessionKeyProvider})
    : _sessionKeyProvider = sessionKeyProvider ?? _emptySessionKey;

  static String? _emptySessionKey() => null;

  @override
  Future<Result<LoginResult>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post<LoginResult>(
        AuthEndpoints.login,
        body: LoginRequest(username: username, password: password).toJson(),
        decoder: (json) =>
            LoginResponse.fromJson(json as Map<String, dynamic>).toEntity(),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(_normalizeLoginError(e.error));
    } catch (e) {
      return Result.failure(
        const AppError(
          code: 'auth_login_unknown',
          message:
              'Giriş yapılamadı. Bilgilerini kontrol edip tekrar deneyebilirsin.',
        ),
      );
    }
  }

  AppError _normalizeLoginError(AppError error) {
    final message = error.message.trim();
    final lowerMessage = message.toLowerCase();
    if (error.code == '1105') {
      return const AppError(
        code: 'auth_pending_venue_approval',
        message: 'Mekan başvurun inceleniyor.',
      );
    }
    if (error.code == '1106') {
      return const AppError(
        code: 'auth_pending_studio_approval',
        message: 'Stüdyo başvurun inceleniyor.',
      );
    }
    if (error.code == '1112') {
      return const AppError(
        code: 'auth_studio_application_rejected',
        message:
            'Stüdyo başvurun onaylanmadı. İtiraz veya bilgi için destek ekibimizle iletişime geçebilirsin.',
      );
    }
    final isCredentialError =
        error.code == '1001' ||
        error.code == '1100' ||
        error.code == '401' ||
        error.code == '403' ||
        lowerMessage.contains('user not found') ||
        lowerMessage.contains('bad credentials') ||
        lowerMessage.contains('invalid username') ||
        lowerMessage.contains('invalid credentials') ||
        lowerMessage.contains('kullanıcı sistemde bulunamadı') ||
        lowerMessage.contains('kullanıcı adı veya şifre hatalı');

    if (isCredentialError) {
      return const AppError(
        code: 'auth_invalid_credentials',
        message:
            'Kullanıcı adı veya şifre hatalı. Bilgilerini kontrol edip tekrar deneyebilirsin.',
      );
    }

    if (message.isEmpty || lowerMessage == 'login failed') {
      return const AppError(
        code: 'auth_login_failed',
        message:
            'Giriş yapılamadı. Bilgilerini kontrol edip tekrar deneyebilirsin.',
      );
    }

    return error;
  }

  @override
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
  }) async {
    try {
      final response = await _apiClient.post<RegisterResult>(
        AuthEndpoints.register,
        body: RegisterRequest(
          username: username,
          email: email,
          password: password,
          rePassword: rePassword,
          role: role,
          venueName: venueName,
          venueAddress: venueAddress,
          phone: phone,
          cityId: cityId,
          districtId: districtId,
          neighborhoodId: neighborhoodId,
          studioName: studioName,
          studioAddress: studioAddress,
          studioPhone: studioPhone,
        ).toJson(),
        decoder: (json) =>
            RegisterResponse.fromJson(json as Map<String, dynamic>).toEntity(),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (e) {
      return Result.failure(
        const AppError(
          code: 'auth_register_unknown',
          message: 'Register failed',
        ),
      );
    }
  }

  @override
  Future<Result<void>> verifyCode({
    required String email,
    required String code,
  }) async {
    try {
      await _apiClient.post<Object?>(
        AuthEndpoints.verifyCode,
        body: VerifyCodeRequest(email: email, code: code).toJson(),
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (e) {
      return Result.failure(
        const AppError(
          code: 'auth_verify_unknown',
          message: 'Verification failed',
        ),
      );
    }
  }

  @override
  Future<Result<ResendCodeResult>> resendCode({required String email}) async {
    try {
      final response = await _apiClient.post<ResendCodeResult>(
        AuthEndpoints.resendCode,
        body: ResendCodeRequest(email: email).toJson(),
        decoder: (json) => ResendCodeResponse.fromJson(
          json as Map<String, dynamic>,
        ).toEntity(),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (e) {
      return Result.failure(
        const AppError(code: 'auth_resend_unknown', message: 'Resend failed'),
      );
    }
  }

  @override
  Future<Result<UsernameAvailability>> checkUsernameAvailability({
    required String username,
  }) async {
    try {
      final response = await _apiClient.post<UsernameAvailability>(
        AuthEndpoints.usernameAvailability,
        body: UsernameAvailabilityRequest(username: username).toJson(),
        decoder: (json) => UsernameAvailabilityResponse.fromJson(
          json as Map<String, dynamic>,
        ).toEntity(),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'auth_username_availability_unknown',
          message: 'Kullanıcı adı şu anda kontrol edilemiyor.',
        ),
      );
    }
  }

  @override
  Future<Result<PasswordResetAccount>> resolvePasswordResetAccount({
    required String identifier,
  }) async {
    try {
      final response = await _apiClient.post<PasswordResetAccount>(
        AuthEndpoints.passwordResetAccount,
        body: ForgotPasswordRequest(identifier: identifier).toJson(),
        decoder: (json) => PasswordResetAccountResponse.fromJson(
          json as Map<String, dynamic>,
        ).toEntity(),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'auth_password_reset_account_unknown',
          message: 'Hesap şu anda kontrol edilemiyor. Lütfen tekrar dene.',
        ),
      );
    }
  }

  @override
  Future<Result<void>> requestPasswordReset({
    required String identifier,
  }) async {
    try {
      await _apiClient.post<Object?>(
        AuthEndpoints.forgotPassword,
        body: ForgotPasswordRequest(identifier: identifier).toJson(),
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'auth_forgot_password_unknown',
          message: 'İstek tamamlanamadı. Lütfen tekrar dene.',
        ),
      );
    }
  }

  @override
  Future<Result<void>> resetPassword({
    required String identifier,
    required String code,
    required String password,
    required String rePassword,
  }) async {
    try {
      await _apiClient.post<Object?>(
        AuthEndpoints.resetPassword,
        body: ResetPasswordRequest(
          identifier: identifier,
          code: code,
          password: password,
          rePassword: rePassword,
        ).toJson(),
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'auth_reset_password_unknown',
          message: 'Şifre güncellenemedi. Lütfen tekrar dene.',
        ),
      );
    }
  }

  @override
  Future<Result<String>> updateUsername({required String username}) async {
    try {
      final sessionKey = _sessionKeyProvider()?.trim();
      final canonicalUsername = await _apiClient.request<String>(
        ApiHttpMethod.patch,
        AuthEndpoints.updateUsername,
        body: UpdateUsernameRequest(username: username).toJson(),
        decoder: (json) {
          if (json is Map<String, dynamic>) {
            return json['username']?.toString() ?? '';
          }
          return json?.toString() ?? '';
        },
        requestContext: sessionKey == null || sessionKey.isEmpty
            ? null
            : ApiRequestContext(expectedSessionKey: sessionKey),
      );
      return Result.success(canonicalUsername);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'auth_update_username_unknown',
          message: 'Kullanıcı adı güncellenemedi. Lütfen tekrar dene.',
        ),
      );
    }
  }
}
