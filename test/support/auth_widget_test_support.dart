import 'dart:async';

import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/auth_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/login_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/password_reset_account.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/register_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/resend_code_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/user_status.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/username_availability.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/verify_code_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/check_username_availability_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/login_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/register_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/request_password_reset_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/resolve_password_reset_account_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/reset_password_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/resend_code_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/update_username_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/verify_code_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/cubit/auth_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/city.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/district.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/neighborhood.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/location_repository.dart';

AuthCubit createAuthCubit(
  RecordingAuthRepository repository, {
  TokenStore? tokenStore,
  AuthSessionManager? sessionManager,
}) {
  return AuthCubit(
    loginUseCase: LoginUseCase(repository),
    registerUseCase: RegisterUseCase(repository),
    verifyCodeUseCase: VerifyCodeUseCase(repository),
    resendCodeUseCase: ResendCodeUseCase(repository),
    requestPasswordResetUseCase: RequestPasswordResetUseCase(repository),
    resetPasswordUseCase: ResetPasswordUseCase(repository),
    updateUsernameUseCase: UpdateUsernameUseCase(repository),
    checkUsernameAvailabilityUseCase: CheckUsernameAvailabilityUseCase(
      repository,
    ),
    resolvePasswordResetAccountUseCase: ResolvePasswordResetAccountUseCase(
      repository,
    ),
    tokenStore: tokenStore ?? MemoryTokenStore(),
    sessionManager: sessionManager,
  );
}

class RecordedRegistration {
  const RecordedRegistration({
    required this.username,
    required this.email,
    required this.password,
    required this.rePassword,
    required this.role,
    this.venueName,
    this.venueAddress,
    this.phone,
    this.cityId,
    this.districtId,
    this.neighborhoodId,
    this.studioName,
    this.studioAddress,
    this.studioPhone,
  });

  final String username;
  final String email;
  final String password;
  final String rePassword;
  final String role;
  final String? venueName;
  final String? venueAddress;
  final String? phone;
  final String? cityId;
  final String? districtId;
  final String? neighborhoodId;
  final String? studioName;
  final String? studioAddress;
  final String? studioPhone;
}

class RecordingAuthRepository extends AuthRepository {
  Result<RegisterResult> registerResult = const Result.success(
    RegisterResult(
      email: 'registered@example.com',
      status: UserStatus.inactive,
      otpTtlSeconds: 180,
      mailQueued: true,
    ),
  );
  Result<VerifyCodeResult> verifyResult = const Result.success(
    VerifyCodeResult(),
  );
  Result<ResendCodeResult> resendResult = const Result.success(
    ResendCodeResult(otpTtlSeconds: 180, mailQueued: true, cooldownSeconds: 30),
  );
  Result<void> requestPasswordResetResult = const Result.success(null);
  Result<UsernameAvailability>? usernameAvailabilityResult;
  Result<PasswordResetAccount> passwordResetAccountResult =
      const Result.success(PasswordResetAccount(username: 'resolved-user'));
  Result<void> resetPasswordResult = const Result.success(null);
  Result<String> updateUsernameResult = const Result.success('updated-user');

  Completer<Result<RegisterResult>>? registerCompleter;
  Completer<Result<VerifyCodeResult>>? verifyCompleter;
  Completer<Result<ResendCodeResult>>? resendCompleter;
  Completer<Result<void>>? requestPasswordResetCompleter;
  Completer<Result<UsernameAvailability>>? usernameAvailabilityCompleter;
  Completer<Result<PasswordResetAccount>>? passwordResetAccountCompleter;
  Completer<Result<void>>? resetPasswordCompleter;
  Completer<Result<String>>? updateUsernameCompleter;

  int registerCalls = 0;
  int verifyCalls = 0;
  int resendCalls = 0;
  int requestPasswordResetCalls = 0;
  int usernameAvailabilityCalls = 0;
  int passwordResetAccountCalls = 0;
  int resetPasswordCalls = 0;
  int updateUsernameCalls = 0;
  RecordedRegistration? lastRegistration;
  String? lastVerifyEmail;
  String? lastVerifyCode;
  String? lastResendEmail;
  String? lastPasswordResetIdentifier;
  String? lastUsernameAvailability;
  String? lastPasswordResetAccountIdentifier;
  String? lastResetIdentifier;
  String? lastResetCode;
  String? lastResetPassword;
  String? lastResetRePassword;
  String? lastUpdatedUsername;

  @override
  Future<Result<LoginResult>> login({
    required String username,
    required String password,
  }) async {
    return const Result.failure(
      AppError(code: 'not_used', message: 'Login is not used in this test'),
    );
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
    registerCalls += 1;
    lastRegistration = RecordedRegistration(
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
    );
    return registerCompleter?.future ?? registerResult;
  }

  @override
  Future<Result<VerifyCodeResult>> verifyCode({
    required String email,
    required String code,
  }) async {
    verifyCalls += 1;
    lastVerifyEmail = email;
    lastVerifyCode = code;
    return verifyCompleter?.future ?? verifyResult;
  }

  @override
  Future<Result<ResendCodeResult>> resendCode({required String email}) async {
    resendCalls += 1;
    lastResendEmail = email;
    return resendCompleter?.future ?? resendResult;
  }

  @override
  Future<Result<UsernameAvailability>> checkUsernameAvailability({
    required String username,
  }) async {
    usernameAvailabilityCalls += 1;
    lastUsernameAvailability = username;
    return usernameAvailabilityCompleter?.future ??
        usernameAvailabilityResult ??
        Result.success(
          UsernameAvailability(username: username, available: true),
        );
  }

  @override
  Future<Result<PasswordResetAccount>> resolvePasswordResetAccount({
    required String identifier,
  }) async {
    passwordResetAccountCalls += 1;
    lastPasswordResetAccountIdentifier = identifier;
    return passwordResetAccountCompleter?.future ?? passwordResetAccountResult;
  }

  @override
  Future<Result<void>> requestPasswordReset({
    required String identifier,
  }) async {
    requestPasswordResetCalls += 1;
    lastPasswordResetIdentifier = identifier;
    return requestPasswordResetCompleter?.future ?? requestPasswordResetResult;
  }

  @override
  Future<Result<void>> resetPassword({
    required String identifier,
    required String code,
    required String password,
    required String rePassword,
  }) async {
    resetPasswordCalls += 1;
    lastResetIdentifier = identifier;
    lastResetCode = code;
    lastResetPassword = password;
    lastResetRePassword = rePassword;
    return resetPasswordCompleter?.future ?? resetPasswordResult;
  }

  @override
  Future<Result<String>> updateUsername({required String username}) async {
    updateUsernameCalls += 1;
    lastUpdatedUsername = username;
    return updateUsernameCompleter?.future ?? updateUsernameResult;
  }
}

class FakeLocationRepository implements LocationRepository {
  Result<List<City>> citiesResult = const Result.success(<City>[
    City(id: 'city-1', name: 'Istanbul'),
  ]);
  Result<List<District>> districtsResult = const Result.success(<District>[
    District(id: 'district-1', name: 'Kadikoy', cityId: 'city-1'),
  ]);
  Result<List<Neighborhood>> neighborhoodsResult = const Result.success(
    <Neighborhood>[
      Neighborhood(
        id: 'neighborhood-1',
        name: 'Moda',
        districtId: 'district-1',
      ),
    ],
  );

  int citiesCalls = 0;
  int districtsCalls = 0;
  int neighborhoodsCalls = 0;
  String? lastCityId;
  String? lastDistrictId;

  @override
  Future<Result<List<City>>> getCities() async {
    citiesCalls += 1;
    return citiesResult;
  }

  @override
  Future<Result<List<District>>> getDistricts(String cityId) async {
    districtsCalls += 1;
    lastCityId = cityId;
    return districtsResult;
  }

  @override
  Future<Result<List<Neighborhood>>> getNeighborhoods(String districtId) async {
    neighborhoodsCalls += 1;
    lastDistrictId = districtId;
    return neighborhoodsResult;
  }
}

class MemoryTokenStore implements TokenStore {
  String? token;
  int clearCalls = 0;

  @override
  Future<void> clear() async {
    clearCalls += 1;
    token = null;
  }

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String token) async {
    this.token = token;
  }
}

class MemoryAuthSessionStore implements AuthSessionStore {
  AuthSessionMetadata? metadata;
  int clearCalls = 0;

  @override
  Future<void> clear() async {
    clearCalls += 1;
    metadata = null;
  }

  @override
  Future<AuthSessionMetadata?> read() async => metadata;

  @override
  Future<void> write(AuthSessionMetadata metadata) async {
    this.metadata = metadata;
  }
}

AuthSessionManager createSessionManager({
  required MemoryTokenStore tokenStore,
  required MemoryAuthSessionStore sessionStore,
}) {
  return AuthSessionManager(tokenStore: tokenStore, sessionStore: sessionStore);
}
