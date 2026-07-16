import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/data/auth_endpoints.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/data/auth_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/data/models/login_request.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/data/models/login_response.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/data/models/register_request.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/data/models/register_response.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/data/models/resend_code_request.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/data/models/resend_code_response.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/data/models/verify_code_request.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/user_status.dart';

void main() {
  group('auth request serialization', () {
    test('login, verify, and resend requests use backend field names', () {
      expect(
        const LoginRequest(username: 'user', password: 'secret').toJson(),
        <String, dynamic>{'username': 'user', 'password': 'secret'},
      );
      expect(
        const VerifyCodeRequest(
          email: 'user@example.com',
          code: '012345',
        ).toJson(),
        <String, dynamic>{'email': 'user@example.com', 'code': '012345'},
      );
      expect(
        const ResendCodeRequest(email: 'user@example.com').toJson(),
        <String, dynamic>{'email': 'user@example.com'},
      );
    });

    test('register omits every absent venue-only field', () {
      final Map<String, dynamic> json = const RegisterRequest(
        username: 'listener',
        email: 'listener@example.com',
        password: 'password',
        rePassword: 'password',
        role: 'ROLE_LISTENER',
      ).toJson();

      expect(json.keys.toSet(), <String>{
        'username',
        'email',
        'password',
        'rePassword',
        'role',
      });
      expect(json.containsKey('venueName'), isFalse);
      expect(json.containsKey('neighborhoodId'), isFalse);
    });

    test('register preserves all explicitly supplied venue fields', () {
      final Map<String, dynamic> json = const RegisterRequest(
        username: 'venue',
        email: 'venue@example.com',
        password: 'password',
        rePassword: 'password',
        role: 'ROLE_VENUE',
        venueName: 'Venue',
        venueAddress: 'Address',
        phone: '5551112233',
        cityId: 'city-1',
        districtId: 'district-1',
        neighborhoodId: 'neighborhood-1',
      ).toJson();

      expect(json['venueName'], 'Venue');
      expect(json['venueAddress'], 'Address');
      expect(json['phone'], '5551112233');
      expect(json['cityId'], 'city-1');
      expect(json['districtId'], 'district-1');
      expect(json['neighborhoodId'], 'neighborhood-1');
    });

    test('non-null empty optional values are not silently discarded', () {
      final Map<String, dynamic> json = const RegisterRequest(
        username: 'venue',
        email: 'venue@example.com',
        password: 'password',
        rePassword: 'password',
        role: 'ROLE_VENUE',
        phone: '',
      ).toJson();

      expect(json.containsKey('phone'), isTrue);
      expect(json['phone'], '');
    });
  });

  group('auth response parsing', () {
    test('login parses mixed list and CSV authorization representations', () {
      final LoginResponse response = LoginResponse.fromJson(<String, dynamic>{
        'token': 'jwt-token',
        'status': 'PENDING_VENUE_REQUEST',
        'userId': 17,
        'username': 'venue-user',
        'roles': <Object?>[' ROLE_VENUE ', '', 9],
        'permissions': 'READ_PROFILE, MANAGE_EVENTS, ',
        'isAdmin': true,
      });
      final entity = response.toEntity();

      expect(response.token, 'jwt-token');
      expect(response.status, UserStatus.pendingVenueRequest);
      expect(response.userId, '17');
      expect(response.roles, <String>['ROLE_VENUE', '9']);
      expect(response.permissions, <String>['READ_PROFILE', 'MANAGE_EVENTS']);
      expect(response.isAdmin, isTrue);
      expect(entity.token, response.token);
      expect(entity.status, response.status);
      expect(entity.roles, response.roles);
      expect(entity.permissions, response.permissions);
      expect(entity.isAdmin, isTrue);
    });

    test('login accepts legacy admin flag and safe null defaults', () {
      final LoginResponse legacy = LoginResponse.fromJson(<String, dynamic>{
        'admin': true,
      });

      expect(legacy.token, '');
      expect(legacy.status, UserStatus.inactive);
      expect(legacy.roles, isEmpty);
      expect(legacy.permissions, isEmpty);
      expect(legacy.isAdmin, isTrue);
    });

    test('register converts numeric ttl and maps status into the entity', () {
      final RegisterResponse response =
          RegisterResponse.fromJson(<String, dynamic>{
            'email': 'venue@example.com',
            'status': 'ACTIVE',
            'otpTtlSeconds': 89.9,
            'mailQueued': true,
          });
      final entity = response.toEntity();

      expect(response.otpTtlSeconds, 89);
      expect(entity.email, 'venue@example.com');
      expect(entity.status, UserStatus.active);
      expect(entity.otpTtlSeconds, 89);
      expect(entity.mailQueued, isTrue);
    });

    test(
      'register and resend use conservative defaults for missing fields',
      () {
        final RegisterResponse register = RegisterResponse.fromJson(
          <String, dynamic>{},
        );
        final ResendCodeResponse resend = ResendCodeResponse.fromJson(
          <String, dynamic>{},
        );

        expect(register.email, '');
        expect(register.status, 'INACTIVE');
        expect(register.otpTtlSeconds, 0);
        expect(register.mailQueued, isFalse);
        expect(register.toEntity().status, UserStatus.inactive);
        expect(resend.otpTtlSeconds, 0);
        expect(resend.cooldownSeconds, 0);
        expect(resend.mailQueued, isFalse);
      },
    );

    test('resend converts numeric values and transfers them to the entity', () {
      final ResendCodeResponse response = ResendCodeResponse.fromJson(
        <String, dynamic>{
          'otpTtlSeconds': 120.8,
          'cooldownSeconds': 29.9,
          'mailQueued': true,
        },
      );
      final entity = response.toEntity();

      expect(entity.otpTtlSeconds, 120);
      expect(entity.cooldownSeconds, 29);
      expect(entity.mailQueued, isTrue);
    });
  });

  group('UserStatusParser and endpoints', () {
    test('round-trips every supported status', () {
      for (final UserStatus status in UserStatus.values) {
        expect(UserStatusParser.fromApi(status.apiValue), status);
      }
    });

    test('unknown, null, and incorrectly cased values fail to inactive', () {
      expect(UserStatusParser.fromApi(null), UserStatus.inactive);
      expect(UserStatusParser.fromApi('UNKNOWN'), UserStatus.inactive);
      expect(UserStatusParser.fromApi('active'), UserStatus.inactive);
    });

    test('endpoint constants remain under the versioned auth base', () {
      expect(AuthEndpoints.base, '/api/v1/auth');
      expect(AuthEndpoints.login, '/api/v1/auth/login');
      expect(AuthEndpoints.register, '/api/v1/auth/register');
      expect(AuthEndpoints.verifyCode, '/api/v1/auth/verify-code');
      expect(AuthEndpoints.resendCode, '/api/v1/auth/resend-code');
      expect(AuthEndpoints.googleSignIn, '/api/v1/auth/google-sign-in');
    });
  });

  group('AuthRepositoryImpl', () {
    test(
      'login posts exact credentials and decodes the domain result',
      () async {
        final _RecordingApiClient client = _RecordingApiClient(
          response: <String, dynamic>{
            'token': 'jwt-token',
            'status': 'ACTIVE',
            'userId': 'user-1',
            'roles': <String>['ROLE_LISTENER'],
          },
        );
        final AuthRepositoryImpl repository = AuthRepositoryImpl(client);

        final result = await repository.login(
          username: 'listener',
          password: 'secret',
        );

        expect(client.path, AuthEndpoints.login);
        expect(client.body, <String, dynamic>{
          'username': 'listener',
          'password': 'secret',
        });
        expect(result.isSuccess, isTrue);
        expect(result.data?.token, 'jwt-token');
        expect(result.data?.userId, 'user-1');
        expect(result.data?.status, UserStatus.active);
      },
    );

    test(
      'login normalizes credential errors without leaking backend detail',
      () async {
        final _RecordingApiClient client = _RecordingApiClient(
          error: ApiException(
            const AppError(
              code: '401',
              message: 'Internal credential lookup detail',
              details: <String>['sensitive backend detail'],
            ),
          ),
        );
        final result = await AuthRepositoryImpl(
          client,
        ).login(username: 'listener', password: 'wrong');

        expect(result.isSuccess, isFalse);
        expect(result.error?.code, 'auth_invalid_credentials');
        expect(result.error?.details, isEmpty);
        expect(result.error?.message, isNot(contains('Internal')));
      },
    );

    test('login maps an empty backend message to a stable fallback', () async {
      final _RecordingApiClient client = _RecordingApiClient(
        error: ApiException(const AppError(code: '500', message: '  ')),
      );

      final result = await AuthRepositoryImpl(
        client,
      ).login(username: 'listener', password: 'secret');

      expect(result.error?.code, 'auth_login_failed');
      expect(result.error?.message, isNotEmpty);
    });

    test('login preserves a meaningful non-credential API error', () async {
      const AppError outage = AppError(
        code: '503',
        message: 'Service temporarily unavailable',
      );
      final result = await AuthRepositoryImpl(
        _RecordingApiClient(error: ApiException(outage)),
      ).login(username: 'listener', password: 'secret');

      expect(result.error, same(outage));
    });

    test(
      'login converts unexpected client failures to a stable error',
      () async {
        final result = await AuthRepositoryImpl(
          _RecordingApiClient(error: StateError('decoder failed')),
        ).login(username: 'listener', password: 'secret');

        expect(result.error?.code, 'auth_login_unknown');
      },
    );

    test(
      'register forwards all location fields and decodes response',
      () async {
        final _RecordingApiClient client = _RecordingApiClient(
          response: <String, dynamic>{
            'email': 'venue@example.com',
            'status': 'PENDING_VENUE_REQUEST',
            'otpTtlSeconds': 120,
            'mailQueued': true,
          },
        );

        final result = await AuthRepositoryImpl(client).register(
          username: 'venue',
          email: 'venue@example.com',
          password: 'password',
          rePassword: 'password',
          role: 'ROLE_VENUE',
          venueName: 'Venue',
          venueAddress: 'Address',
          phone: '5551112233',
          cityId: 'city-1',
          districtId: 'district-1',
          neighborhoodId: 'neighborhood-1',
        );

        expect(client.path, AuthEndpoints.register);
        expect(client.body, <String, dynamic>{
          'username': 'venue',
          'email': 'venue@example.com',
          'password': 'password',
          'rePassword': 'password',
          'role': 'ROLE_VENUE',
          'venueName': 'Venue',
          'venueAddress': 'Address',
          'phone': '5551112233',
          'cityId': 'city-1',
          'districtId': 'district-1',
          'neighborhoodId': 'neighborhood-1',
        });
        expect(result.data?.status, UserStatus.pendingVenueRequest);
        expect(result.data?.otpTtlSeconds, 120);
      },
    );

    test('register preserves typed API failures', () async {
      const AppError conflict = AppError(
        code: '409',
        message: 'Account already exists',
      );
      final result =
          await AuthRepositoryImpl(
            _RecordingApiClient(error: ApiException(conflict)),
          ).register(
            username: 'user',
            email: 'user@example.com',
            password: 'password',
            rePassword: 'password',
            role: 'ROLE_LISTENER',
          );

      expect(result.error, same(conflict));
    });

    test(
      'verify sends the code and treats an empty response as success',
      () async {
        final _RecordingApiClient client = _RecordingApiClient(response: null);

        final result = await AuthRepositoryImpl(
          client,
        ).verifyCode(email: 'user@example.com', code: '012345');

        expect(client.path, AuthEndpoints.verifyCode);
        expect(client.body, <String, dynamic>{
          'email': 'user@example.com',
          'code': '012345',
        });
        expect(result.isSuccess, isTrue);
      },
    );

    test('resend posts email and decodes cooldown information', () async {
      final _RecordingApiClient client = _RecordingApiClient(
        response: <String, dynamic>{
          'otpTtlSeconds': 90,
          'mailQueued': true,
          'cooldownSeconds': 30,
        },
      );

      final result = await AuthRepositoryImpl(
        client,
      ).resendCode(email: 'user@example.com');

      expect(client.path, AuthEndpoints.resendCode);
      expect(client.body, <String, dynamic>{'email': 'user@example.com'});
      expect(result.data?.otpTtlSeconds, 90);
      expect(result.data?.cooldownSeconds, 30);
    });

    test('verify and resend convert unexpected failures predictably', () async {
      final AuthRepositoryImpl repository = AuthRepositoryImpl(
        _RecordingApiClient(error: StateError('transport contract failed')),
      );

      final verify = await repository.verifyCode(
        email: 'user@example.com',
        code: '012345',
      );
      final resend = await repository.resendCode(email: 'user@example.com');

      expect(verify.error?.code, 'auth_verify_unknown');
      expect(resend.error?.code, 'auth_resend_unknown');
    });
  });
}

class _RecordingApiClient extends ApiClient {
  _RecordingApiClient({this.response, this.error});

  final Object? response;
  final Object? error;
  String? path;
  Object? body;

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) async {
    this.path = path;
    this.body = body;
    final Object? pendingError = error;
    if (pendingError != null) throw pendingError;
    if (decoder != null) return decoder(response);
    return response as T;
  }

  @override
  Future<T> delete<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => _unsupported<T>();

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
  }) => _unsupported<T>();

  @override
  Future<T> patch<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => _unsupported<T>();

  @override
  Future<T> put<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => _unsupported<T>();

  Future<T> _unsupported<T>() async {
    throw UnsupportedError('Only POST is expected by the auth repository');
  }
}
