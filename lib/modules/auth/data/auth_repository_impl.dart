import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/auth_repository.dart';
import '../domain/entities/login_result.dart';
import '../domain/entities/register_result.dart';
import '../domain/entities/resend_code_result.dart';
import 'auth_endpoints.dart';
import 'models/login_request.dart';
import 'models/login_response.dart';
import 'models/register_request.dart';
import 'models/register_response.dart';
import 'models/resend_code_request.dart';
import 'models/resend_code_response.dart';
import 'models/verify_code_request.dart';

class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _apiClient;

  AuthRepositoryImpl(this._apiClient);

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
}
