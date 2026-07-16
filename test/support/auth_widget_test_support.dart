import 'dart:async';

import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/auth_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/login_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/register_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/resend_code_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/user_status.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/login_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/register_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/resend_code_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/verify_code_usecase.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/cubit/auth_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/city.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/district.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/neighborhood.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/location_repository.dart';

AuthCubit createAuthCubit(RecordingAuthRepository repository) {
  return AuthCubit(
    loginUseCase: LoginUseCase(repository),
    registerUseCase: RegisterUseCase(repository),
    verifyCodeUseCase: VerifyCodeUseCase(repository),
    resendCodeUseCase: ResendCodeUseCase(repository),
    tokenStore: MemoryTokenStore(),
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
}

class RecordingAuthRepository implements AuthRepository {
  Result<RegisterResult> registerResult = const Result.success(
    RegisterResult(
      email: 'registered@example.com',
      status: UserStatus.inactive,
      otpTtlSeconds: 180,
      mailQueued: true,
    ),
  );
  Result<void> verifyResult = const Result.success(null);
  Result<ResendCodeResult> resendResult = const Result.success(
    ResendCodeResult(otpTtlSeconds: 180, mailQueued: true, cooldownSeconds: 30),
  );

  Completer<Result<RegisterResult>>? registerCompleter;
  Completer<Result<void>>? verifyCompleter;
  Completer<Result<ResendCodeResult>>? resendCompleter;

  int registerCalls = 0;
  int verifyCalls = 0;
  int resendCalls = 0;
  RecordedRegistration? lastRegistration;
  String? lastVerifyEmail;
  String? lastVerifyCode;
  String? lastResendEmail;

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
    );
    return registerCompleter?.future ?? registerResult;
  }

  @override
  Future<Result<void>> verifyCode({
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
