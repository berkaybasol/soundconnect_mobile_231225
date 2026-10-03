import 'dart:async';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'support/auth_widget_test_support.dart';

const applicantId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const applicationId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
String applicantToken({
  String scope = 'VENUE_APPLICATION',
  String? appId = applicationId,
}) {
  final claims = <String, Object?>{
    'sub': applicantId,
    'exp':
        DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/
        1000,
    'scope': scope,
    if (appId != null) 'applicationId': appId,
  };
  return '${base64Url.encode(utf8.encode('{}'))}.${base64Url.encode(utf8.encode(jsonEncode(claims)))}.signature';
}

void main() {
  for (final stage in ['metadata', 'token']) {
    for (final replacement in ['logout', 'new-login']) {
      test(
        'promotion $stage write cannot resurrect after $replacement',
        () async {
          final tokens = _GateTokens();
          final metadata = _GateMetadata();
          final sessions = AuthSessionManager(
            tokenStore: tokens,
            sessionStore: metadata,
          );
          addTearDown(sessions.dispose);
          await sessions.startSession(
            token: applicantToken(),
            username: 'applicant',
            accountStatus: 'PENDING_VENUE_REQUEST',
          );
          final expected = sessions.session;
          final gate = Completer<void>();
          if (stage == 'metadata') {
            metadata.gate = gate;
          } else {
            tokens.gate = gate;
          }
          final promoted = sessions.promoteVenueApplication(
            expected: expected,
            token: _normalToken(),
            username: 'applicant',
          );
          await (stage == 'metadata'
              ? metadata.started.future
              : tokens.started.future);
          final replacing = replacement == 'logout'
              ? sessions.logout()
              : sessions.startSession(
                  token: _normalToken(
                    user: 'ffffffff-ffff-4fff-8fff-ffffffffffff',
                    roles: const ['ROLE_MUSICIAN'],
                  ),
                  username: 'next',
                  accountStatus: 'ACTIVE',
                );
          gate.complete();
          expect(await promoted, isFalse);
          await replacing;
          if (replacement == 'logout') {
            expect(sessions.session.isAuthenticated, isFalse);
            expect(tokens.token, isNull);
            expect(metadata.metadata, isNull);
          } else {
            expect(
              sessions.session.userId,
              'ffffffff-ffff-4fff-8fff-ffffffffffff',
            );
            expect(tokens.token, sessions.session.token);
            expect(metadata.metadata?.username, 'next');
          }
        },
      );
    }
  }
  test('normal login pending write cannot revive after logout', () async {
    final tokens = _GateTokens();
    final metadata = _GateMetadata()..gate = Completer<void>();
    final sessions = AuthSessionManager(
      tokenStore: tokens,
      sessionStore: metadata,
    );
    addTearDown(sessions.dispose);
    final login = sessions.startSession(
      token: _normalToken(),
      username: 'applicant',
      accountStatus: 'ACTIVE',
    );
    final failure = expectLater(login, throwsStateError);
    await metadata.started.future;
    final logout = sessions.logout();
    metadata.gate!.complete();
    await failure;
    await logout;
    expect(tokens.token, isNull);
    expect(sessions.session.isAuthenticated, isFalse);
  });

  test('approved exchange preserves server-assigned additional roles', () async {
    final sessions = AuthSessionManager(
      tokenStore: MemoryTokenStore(),
      sessionStore: MemoryAuthSessionStore(),
    );
    addTearDown(sessions.dispose);
    await sessions.startSession(
      token: applicantToken(),
      username: 'applicant',
      accountStatus: 'PENDING_VENUE_REQUEST',
    );
    final expected = sessions.session;
    final claims = {
      'sub': applicantId,
      'roles': ['ROLE_VENUE', 'ROLE_ADMIN'],
      'exp':
          DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/
          1000,
    };
    final token =
        'header.${base64Url.encode(utf8.encode(jsonEncode(claims)))}.signature';
    expect(
      await sessions.promoteVenueApplication(
        expected: expected,
        token: token,
        username: 'applicant',
      ),
      isTrue,
    );
    expect(sessions.session.roles, ['ROLE_VENUE', 'ROLE_ADMIN']);
    expect(sessions.session.isActive, isTrue);
  });

  test('admin token without venue role cannot promote an applicant', () async {
    final sessions = AuthSessionManager(
      tokenStore: MemoryTokenStore(),
      sessionStore: MemoryAuthSessionStore(),
    );
    addTearDown(sessions.dispose);
    await sessions.startSession(
      token: applicantToken(),
      username: 'applicant',
      accountStatus: 'PENDING_VENUE_REQUEST',
    );
    final expected = sessions.session;
    final claims = {
      'sub': applicantId,
      'roles': ['ROLE_ADMIN'],
      'exp':
          DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/
          1000,
    };
    final token =
        'header.${base64Url.encode(utf8.encode(jsonEncode(claims)))}.signature';
    await expectLater(
      sessions.promoteVenueApplication(
        expected: expected,
        token: token,
        username: 'applicant',
      ),
      throwsFormatException,
    );
    expect(sessions.session, same(expected));
  });

  test(
    'signed applicant scope cannot restore as ACTIVE from cached metadata',
    () async {
      final sessions = AuthSessionManager(
        tokenStore: MemoryTokenStore(),
        sessionStore: MemoryAuthSessionStore(),
      );
      addTearDown(sessions.dispose);
      await sessions.startSession(
        token: applicantToken(),
        username: 'applicant',
        accountStatus: 'ACTIVE',
      );
      expect(sessions.session.isAuthenticated, isTrue);
      expect(sessions.session.isActive, isFalse);
      expect(sessions.session.isPendingVenue, isTrue);
    },
  );

  test(
    'applicant credential without its signed application is rejected',
    () async {
      final sessions = AuthSessionManager(
        tokenStore: MemoryTokenStore(),
        sessionStore: MemoryAuthSessionStore(),
      );
      addTearDown(sessions.dispose);
      await expectLater(
        sessions.startSession(
          token: applicantToken(appId: null),
          username: 'applicant',
          accountStatus: 'PENDING_VENUE_REQUEST',
        ),
        throwsFormatException,
      );
      expect(sessions.session.isAuthenticated, isFalse);
    },
  );
}

String _normalToken({
  String user = applicantId,
  List<String> roles = const ['ROLE_VENUE'],
}) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': user, 'roles': roles, 'exp': DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000})))}.signature';

class _GateTokens extends MemoryTokenStore {
  Completer<void>? gate;
  final started = Completer<void>();
  @override
  Future<void> writeToken(String value) async {
    final pending = gate;
    if (pending != null && !pending.isCompleted) {
      if (!started.isCompleted) started.complete();
      await pending.future;
    }
    await super.writeToken(value);
  }
}

class _GateMetadata extends MemoryAuthSessionStore {
  Completer<void>? gate;
  final started = Completer<void>();
  @override
  Future<void> write(AuthSessionMetadata value) async {
    final pending = gate;
    if (pending != null && !pending.isCompleted) {
      if (!started.isCompleted) started.complete();
      await pending.future;
    }
    await super.write(value);
  }
}
