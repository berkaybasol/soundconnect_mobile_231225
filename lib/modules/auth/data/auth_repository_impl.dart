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
      return Result.failure(e.error);
    } catch (e) {
      return Result.failure(const AppError(
        code: 'auth_login_unknown',
        message: 'Login failed',
      ));
    }
  }

  @override
  Future<Result<RegisterResult>> register({
    required String username,
    required String email,
    required String password,
    required String rePassword,
    required String role,
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
        ).toJson(),
        decoder: (json) =>
            RegisterResponse.fromJson(json as Map<String, dynamic>).toEntity(),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (e) {
      return Result.failure(const AppError(
        code: 'auth_register_unknown',
        message: 'Register failed',
      ));
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
      return Result.failure(const AppError(
        code: 'auth_verify_unknown',
        message: 'Verification failed',
      ));
    }
  }

  @override
  Future<Result<ResendCodeResult>> resendCode({
    required String email,
  }) async {
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
      return Result.failure(const AppError(
        code: 'auth_resend_unknown',
        message: 'Resend failed',
      ));
    }
  }
}
