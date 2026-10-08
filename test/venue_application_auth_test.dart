import 'dart:convert';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/user_status.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/data/auth_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/data/models/login_response.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/login_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/verify_code_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/cubit/auth_state.dart';
import 'support/auth_widget_test_support.dart';
import 'venue_application_session_test.dart'
    show applicantId, applicationId, applicantToken;

Map<String, dynamic> _response() => {
  'token': applicantToken(),
  'status': 'PENDING_VENUE_REQUEST',
  'userId': applicantId,
  'username': 'applicant',
  'roles': <String>[],
  'permissions': <String>[],
  'admin': false,
  'requiresListenerProfileChoice': false,
  'sessionScope': 'VENUE_APPLICATION',
  'applicationId': applicationId,
};

void main() {
  for (final action in ['login', 'otp']) {
    test(
      'late ordinary $action cannot overwrite a newer restricted session',
      () async {
        final sessions = AuthSessionManager(
          tokenStore: MemoryTokenStore(),
          sessionStore: MemoryAuthSessionStore(),
        );
        final repository = _Repository();
        final cubit = createAuthCubit(repository, sessionManager: sessions);
        addTearDown(cubit.close);
        addTearDown(sessions.dispose);
        final pending = action == 'login'
            ? cubit.login(username: 'ordinary', password: 'fictional')
            : cubit.verifyCode(
                email: 'ordinary@example.invalid',
                code: '123456',
              );
        await sessions.startSession(
          token: applicantToken(),
          username: 'applicant',
          accountStatus: 'PENDING_VENUE_REQUEST',
        );
        final expected = sessions.session;
        final role = action == 'otp' ? 'ROLE_LISTENER' : 'ROLE_VENUE';
        final token =
            'header.${base64Url.encode(utf8.encode(jsonEncode({
              'sub': applicantId,
              'roles': [role],
              'exp': DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000,
            })))}.signature';
        final ordinary = LoginResult(
          token: token,
          status: UserStatus.active,
          roles: [role],
          requiresListenerProfileChoice: action == 'otp',
        );
        if (action == 'login') {
          repository.loginReply.complete(Result.success(ordinary));
        } else {
          repository.verify.complete(
            Result.success(VerifyCodeResult(listenerSession: ordinary)),
          );
        }
        await pending;
        expect(sessions.session, same(expected));
        expect(sessions.session.isVenueApplicationSession, isTrue);
      },
    );
  }

  test(
    'real verification repository decodes a separate signed application session',
    () async {
      final result = await AuthRepositoryImpl(
        _Api(_response()),
      ).verifyCode(email: 'fixture@example.invalid', code: '123456');
      expect(result.isSuccess, isTrue);
      expect(result.data?.listenerSession, isNull);
      expect(result.data?.hasVenueApplicationSession, isTrue);
      expect(result.data?.session?.applicationId, applicationId);
    },
  );
  for (final wrong in <Map<String, dynamic>>[
    {'sessionScope': null},
    {'applicationId': applicantId},
    {'userId': applicationId},
    {
      'roles': ['ROLE_VENUE'],
    },
    {
      'permissions': ['MANAGE_USERS'],
    },
    {'admin': true},
    {'requiresListenerProfileChoice': true},
  ]) {
    test('scoped response cannot override signed credential with $wrong', () {
      expect(
        () => LoginResponse.fromJson(_response()..addAll(wrong)),
        throwsFormatException,
      );
    });
  }
  test(
    'verified applicant OTP persists limited session without listener onboarding',
    () async {
      final sessions = AuthSessionManager(
        tokenStore: MemoryTokenStore(),
        sessionStore: MemoryAuthSessionStore(),
      );
      final repository = _Repository();
      final cubit = createAuthCubit(repository, sessionManager: sessions);
      addTearDown(cubit.close);
      addTearDown(sessions.dispose);
      final pending = cubit.verifyCode(
        email: 'fixture@example.invalid',
        code: '123456',
      );
      repository.verify.complete(
        Result.success(
          VerifyCodeResult(
            venueApplicationSession: LoginResponse.fromJson(
              _response(),
            ).toEntity(),
          ),
        ),
      );
      await pending;
      expect(cubit.state.status, AuthStatus.success);
      expect(sessions.session.isVenueApplicationSession, isTrue);
      expect(sessions.session.isActive, isFalse);
      expect(sessions.session.roles, isEmpty);
    },
  );
  for (final action in ['login', 'otp']) {
    for (final change in ['guest-logout', 'account-switch', 'closed-screen']) {
      test(
        'late scoped $action after $change never commits credentials',
        () async {
          final tokens = MemoryTokenStore();
          final sessions = AuthSessionManager(
            tokenStore: tokens,
            sessionStore: MemoryAuthSessionStore(),
          );
          final repository = _Repository();
          final cubit = createAuthCubit(repository, sessionManager: sessions);
          addTearDown(() async {
            if (!cubit.isClosed) await cubit.close();
            sessions.dispose();
          });
          final pending = action == 'login'
              ? cubit.login(username: 'applicant', password: 'fictional')
              : cubit.verifyCode(
                  email: 'fixture@example.invalid',
                  code: '123456',
                );
          if (change == 'guest-logout') {
            await sessions.logout();
          }
          if (change == 'account-switch') {
            await sessions.startSession(
              token: applicantToken(appId: applicantId),
              username: 'other-application',
              accountStatus: 'PENDING_VENUE_REQUEST',
            );
          }
          if (change == 'closed-screen') {
            await cubit.close();
          }
          final expected = sessions.session;
          final login = LoginResponse.fromJson(_response()).toEntity();
          if (action == 'login') {
            repository.loginReply.complete(Result.success(login));
          } else {
            repository.verify.complete(
              Result.success(VerifyCodeResult(venueApplicationSession: login)),
            );
          }
          await pending;
          expect(sessions.session, same(expected));
          expect(tokens.token, expected.token);
        },
      );
    }
  }
}

class _Api extends Fake implements ApiClient {
  _Api(this.json);
  final Map<String, dynamic> json;
  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    T Function(Object?)? decoder,
  }) async => decoder!(json);
}

class _Repository extends RecordingAuthRepository {
  final loginReply = Completer<Result<LoginResult>>();
  final verify = Completer<Result<VerifyCodeResult>>();
  @override
  Future<Result<LoginResult>> login({
    required String username,
    required String password,
  }) => loginReply.future;
  @override
  Future<Result<VerifyCodeResult>> verifyCode({
    required String email,
    required String code,
  }) => verify.future;
}
