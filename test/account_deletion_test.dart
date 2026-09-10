import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/data/account_deletion_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/account_deletion_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/listener_account_deletion_dialog.dart';

import 'support/event_audience_fakes.dart';

void main() {
  test(
    'erasure sends explicit confirmation with exact password and token fence',
    () async {
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      final api = _Api();
      final result = await AccountDeletionRepositoryImpl(api, sessions)
          .deleteListenerAccount(
            expectedSession: sessions.session,
            currentPassword: ' exact password ',
          );
      expect(result.isSuccess, isTrue);
      expect(api.method, ApiHttpMethod.delete);
      expect(api.path, '/api/v1/users/me/account');
      expect(api.body, {
        'confirmation': 'DELETE',
        'currentPassword': ' exact password ',
      });
      expect(api.context!.expectedSessionKey, sessions.session.userId);
      expect(api.context!.expectedToken, sessions.session.token);
    },
  );

  test(
    'account or token replacement blocks deletion before dispatch and late success',
    () async {
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      final api = _Api();
      final repository = AccountDeletionRepositoryImpl(api, sessions);
      final old = sessions.session;
      sessions.replace(audienceSession(token: 'new'));
      expect(
        (await repository.deleteListenerAccount(
          expectedSession: old,
          currentPassword: 'pw',
        )).isSuccess,
        isFalse,
      );
      expect(api.calls, 0);
      api.pending = Completer<Object?>();
      final deleting = repository.deleteListenerAccount(
        expectedSession: sessions.session,
        currentPassword: 'pw',
      );
      sessions.replace(audienceSession(user: 'other'));
      api.pending!.complete(true);
      expect((await deleting).isSuccess, isFalse);
    },
  );

  test('unconfirmed server result never becomes successful erasure', () async {
    final sessions = AudienceTestSessions(audienceSession());
    addTearDown(sessions.dispose);
    for (final response in [
      false,
      null,
      {'success': true},
    ]) {
      final api = _Api()..response = response;
      final result = await AccountDeletionRepositoryImpl(api, sessions)
          .deleteListenerAccount(
            expectedSession: sessions.session,
            currentPassword: 'pw',
          );
      expect(result.isSuccess, isFalse);
      expect(result.error!.code, 'account_deletion_uncertain');
    }
  });

  testWidgets('cancel and unacknowledged confirmation never delete', (
    tester,
  ) async {
    final sessions = AudienceTestSessions(audienceSession());
    final repository = _Repository();
    addTearDown(sessions.dispose);
    await _open(tester, repository, sessions);
    await tester.enterText(
      find.byKey(const Key('account-delete-password')),
      'pw',
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('account-delete-confirm')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('account-delete-cancel')));
    await tester.pumpAndSettle();
    expect(repository.calls, 0);
    expect(find.byType(ListenerAccountDeletionDialog), findsNothing);
  });

  testWidgets(
    'confirmed deletion runs once, clears password, and closes only after success',
    (tester) async {
      final sessions = AudienceTestSessions(audienceSession());
      final repository = _Repository()..pending = Completer<Result<bool>>();
      addTearDown(sessions.dispose);
      await _open(tester, repository, sessions);
      await _confirm(tester);
      expect(repository.calls, 1);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('account-delete-password')))
            .controller!
            .text,
        isEmpty,
      );
      await tester.tap(find.byKey(const Key('account-delete-confirm')));
      await tester.pump();
      expect(repository.calls, 1);
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('account-delete-cancel')))
            .onPressed,
        isNull,
      );
      repository.pending!.complete(const Result.success(true));
      await tester.pumpAndSettle();
      expect(find.byType(ListenerAccountDeletionDialog), findsNothing);
      expect(find.text('Deleted: true'), findsOneWidget);
    },
  );

  testWidgets(
    'wrong password allows fresh credential retry without claiming success',
    (tester) async {
      final sessions = AudienceTestSessions(audienceSession());
      final repository = _Repository()
        ..result = const Result.failure(
          AppError(code: '1006', message: 'invalid'),
        );
      addTearDown(sessions.dispose);
      await _open(tester, repository, sessions);
      await _confirm(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('Şifren doğrulanamadı. Mevcut hesap şifreni yeniden gir.'),
        findsOneWidget,
      );
      expect(find.text('Deleted: true'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('account-delete-confirm')),
            )
            .onPressed,
        isNull,
      );
      repository.result = const Result.success(true);
      await tester.enterText(
        find.byKey(const Key('account-delete-password')),
        'correct',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('account-delete-confirm')));
      await tester.pumpAndSettle();
      expect(repository.calls, 2);
      expect(find.text('Deleted: true'), findsOneWidget);
    },
  );

  testWidgets(
    'session switch revokes pending deletion dialog and discards late success',
    (tester) async {
      final sessions = AudienceTestSessions(audienceSession());
      final repository = _Repository()..pending = Completer<Result<bool>>();
      addTearDown(sessions.dispose);
      await _open(tester, repository, sessions);
      await _confirm(tester);
      sessions.replace(audienceSession(user: 'other'));
      repository.pending!.complete(const Result.success(true));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Oturum kapandı veya değişti.'),
        findsOneWidget,
      );
      expect(find.text('Deleted: true'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('account-delete-confirm')),
            )
            .onPressed,
        isNull,
      );
    },
  );
}

Future<void> _open(
  WidgetTester tester,
  _Repository repository,
  AudienceTestSessions sessions,
) async {
  bool? deleted;
  await tester.pumpWidget(
    MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: Column(
            children: [
              Text('Deleted: $deleted'),
              TextButton(
                child: const Text('Delete'),
                onPressed: () async {
                  final result = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => ListenerAccountDeletionDialog(
                      repository: repository,
                      sessions: sessions,
                    ),
                  );
                  setState(() => deleted = result);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Delete'));
  await tester.pumpAndSettle();
}

Future<void> _confirm(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('account-delete-password')),
    'password',
  );
  await tester.tap(find.byKey(const Key('account-delete-acknowledge')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('account-delete-confirm')));
  await tester.pump();
}

class _Api extends Fake implements ApiClient {
  int calls = 0;
  Object? response = true;
  Completer<Object?>? pending;
  ApiHttpMethod? method;
  String? path;
  Object? body;
  ApiRequestContext? context;
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    calls++;
    this.method = method;
    this.path = path;
    this.body = body;
    context = requestContext;
    return decoder!(pending == null ? response : await pending!.future);
  }
}

class _Repository extends Fake implements AccountDeletionRepository {
  int calls = 0;
  Completer<Result<bool>>? pending;
  Result<bool> result = const Result.success(true);
  @override
  Future<Result<bool>> deleteListenerAccount({
    required AuthSession expectedSession,
    required String currentPassword,
  }) {
    calls++;
    return pending?.future ?? Future.value(result);
  }
}
