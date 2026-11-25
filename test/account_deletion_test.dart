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
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

import 'support/event_audience_fakes.dart';

void main() {
  test(
    'musician band choices load with session fencing and submit atomically with erasure',
    () async {
      final owner = audienceSession(role: 'ROLE_MUSICIAN');
      final sessions = _DeletionSessions(owner);
      addTearDown(sessions.dispose);
      final api = _Api()
        ..response = [
          {
            'bandId': 'b1',
            'bandName': 'Prova',
            'successors': [
              {'userId': 'u2', 'username': 'bas'},
            ],
          },
          {'bandId': 'b2', 'bandName': 'Solo', 'successors': []},
        ];
      final repo = AccountDeletionRepositoryImpl(api, sessions);
      final options = await repo.getBandOptions(owner);
      expect(options.data!.first.successors.single.userId, 'u2');
      expect(api.method, ApiHttpMethod.get);
      expect(api.path, '/api/v1/user/bands/account-deletion-options');
      expect(api.context!.expectedToken, owner.token);
      api.response = true;
      expect(
        (await repo.deleteAccount(
          expectedSession: owner,
          currentPassword: 'pw',
          bandDecisions: const [
            (bandId: 'b1', successorUserId: 'u2'),
            (bandId: 'b2', successorUserId: null),
          ],
        )).isSuccess,
        isTrue,
      );
      expect((api.body as Map)['bandDecisions'], [
        {'bandId': 'b1', 'action': 'TRANSFER', 'successorUserId': 'u2'},
        {'bandId': 'b2', 'action': 'CLOSE'},
      ]);
    },
  );

  testWidgets(
    'last founder explicitly selects each successor or closure and reviews again after conflict',
    (tester) async {
      final sessions = AudienceTestSessions(
        audienceSession(role: 'ROLE_MUSICIAN'),
      );
      addTearDown(sessions.dispose);
      final repository = _Repository()
        ..options = [
          (
            bandId: 'b1',
            bandName: 'Prova',
            successors: [(userId: 'u2', username: 'bas')],
          ),
          (bandId: 'b2', bandName: 'Solo', successors: []),
        ];
      await _open(tester, repository, sessions);
      final next = find.byKey(const Key('account-delete-next'));
      expect(tester.widget<OutlinedButton>(next).onPressed, isNull);
      for (final (id, label) in [
        ('b1', '@bas kullanıcısına devret'),
        ('b2', 'Bandı kalıcı olarak kapat'),
      ]) {
        final menu = find.byKey(ValueKey('band-decision-$id'));
        await tester.ensureVisible(menu);
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }
      await _next(tester);
      expect(
        find.text('Prova kuruculuğu @bas kullanıcısına devredilecek.'),
        findsOneWidget,
      );
      expect(find.text('Solo kapatılacak.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('account-delete-password')),
        'pw',
      );
      final ack = find.byKey(const Key('account-delete-acknowledge'));
      await tester.ensureVisible(ack);
      await tester.tap(ack);
      await tester.pump();
      repository.result = const Result.failure(
        AppError(code: '9223', message: 'Conflict'),
      );
      final confirm = find.byKey(const Key('account-delete-confirm'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(repository.calls, 1);
      expect(repository.optionCalls, 2);
      expect(repository.lastDecisions, [
        (bandId: 'b1', successorUserId: 'u2'),
        (bandId: 'b2', successorUserId: null),
      ]);
      expect(tester.widget<OutlinedButton>(next).onPressed, isNull);
      expect(find.textContaining('üyelikleri değişti'), findsOneWidget);
    },
  );

  for (final (role, effect) in [
    ('ROLE_VENUE', 'Mekânın programı kapanır'),
    ('ROLE_STUDIO', 'Stüdyonun odaları kapanır'),
  ]) {
    testWidgets('$role shows its effect and uses existing reauthentication', (
      tester,
    ) async {
      final sessions = AudienceTestSessions(audienceSession(role: role));
      addTearDown(sessions.dispose);
      final repository = _Repository();
      await _open(tester, repository, sessions);
      expect(find.text(effect), findsOneWidget);
      await _confirm(tester);
      expect(repository.calls, 1);
      expect(repository.optionCalls, 0);
    });
  }
  test(
    'erasure sends explicit confirmation with exact password and token fence',
    () async {
      final owner = audienceSession();
      final sessions = _DeletionSessions(owner);
      final revision = sessions.credentialRevision;
      addTearDown(sessions.dispose);
      final api = _Api();
      final result = await AccountDeletionRepositoryImpl(api, sessions)
          .deleteAccount(
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
      expect(api.context!.expectedSessionKey, owner.userId);
      expect(api.context!.expectedToken, owner.token);
      expect(api.context!.expectedCredentialRevision, revision);
      expect(sessions.session.isAuthenticated, isFalse);
    },
  );

  test(
    'exactly one supported profile can delete, with optional technical USER',
    () {
      for (final roles in [
        ['ROLE_LISTENER'],
        ['ROLE_USER', 'ROLE_LISTENER'],
        ['listener', 'user'],
        ['ROLE_MUSICIAN', 'ROLE_USER'],
        ['ROLE_STUDIO'],
        ['VENUE'],
      ]) {
        expect(
          accountDeletionProfile(audienceSession(roles: roles)),
          isNotNull,
        );
      }
      for (final session in [
        const AuthSession.guest(),
        const AuthSession.suspended(),
        audienceSession(status: 'INACTIVE'),
        audienceSession(isAdmin: true),
        audienceSession(user: ''),
        for (final role in ['USER', 'ADMIN', 'OWNER'])
          audienceSession(role: role),
        for (final role in [
          'MUSICIAN',
          'VENUE',
          'STUDIO',
          'ADMIN',
          'OWNER',
          'UNKNOWN',
        ])
          audienceSession(roles: ['ROLE_LISTENER', role]),
      ]) {
        expect(accountDeletionProfile(session), isNull);
      }
      for (final permission in [
        'READ_USER',
        'READ_LOCATION',
        'READ_USERS',
        'MANAGE_USERS',
        'ADMIN_PANEL_ACCESS',
      ]) {
        final session = AuthSession.authenticated(
          token: 'token',
          userId: 'uid',
          username: 'listener',
          accountStatus: 'ACTIVE',
          roles: const ['ROLE_LISTENER'],
          permissions: [permission],
          expiresAt: DateTime.utc(2100),
          isAdmin: false,
        );
        expect(
          accountDeletionProfile(session) != null,
          ['READ_USER', 'READ_LOCATION'].contains(permission),
        );
      }
    },
  );

  test(
    'Google deletion sends only the selected credential and rejects ambiguous credentials',
    () async {
      final owner = audienceSession(roles: ['ROLE_LISTENER', 'ROLE_USER']);
      final sessions = _DeletionSessions(owner);
      addTearDown(sessions.dispose);
      final api = _Api();
      final repository = AccountDeletionRepositoryImpl(api, sessions);
      for (final (password, google) in [
        (null, null),
        ('pw', 'token'),
        (null, '  '),
        ('', null),
      ]) {
        final result = await repository.deleteAccount(
          expectedSession: sessions.session,
          currentPassword: password,
          googleIdToken: google,
        );
        expect(result.error?.code, '1006');
      }
      expect(api.calls, 0);
      final result = await repository.deleteAccount(
        expectedSession: sessions.session,
        googleIdToken: 'google-identity',
      );
      expect(result.isSuccess, isTrue);
      expect(api.body, {
        'confirmation': 'DELETE',
        'googleIdToken': 'google-identity',
      });
      expect(api.context!.expectedSessionKey, owner.userId);
      expect(api.context!.expectedToken, owner.token);
      expect(sessions.session.isAuthenticated, isFalse);
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
        (await repository.deleteAccount(
          expectedSession: old,
          currentPassword: 'pw',
        )).isSuccess,
        isFalse,
      );
      expect(api.calls, 0);
      api.pending = Completer<Object?>();
      final deleting = repository.deleteAccount(
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
      final result = await AccountDeletionRepositoryImpl(
        api,
        sessions,
      ).deleteAccount(expectedSession: sessions.session, currentPassword: 'pw');
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
    expect(find.text('Hesabını sil'), findsOneWidget);
    expect(find.byKey(const Key('account-delete-password')), findsNothing);
    expect(find.byKey(const Key('account-delete-confirm')), findsNothing);
    await tester.tap(find.byKey(const Key('account-delete-cancel')));
    await tester.pumpAndSettle();
    expect(repository.calls, 0);
    expect(find.byType(AccountDeletionDialog), findsNothing);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await _next(tester);
    await tester.enterText(
      find.byKey(const Key('account-delete-password')),
      'pw',
    );
    expect(
      tester
          .widget<GradientOutlineButton>(
            find.byKey(const Key('account-delete-confirm')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('account-delete-cancel')));
    await tester.pumpAndSettle();
    expect(repository.calls, 0);
    expect(find.byType(AccountDeletionDialog), findsNothing);
  });

  testWidgets(
    'system back clears verification and a second back dismisses without deleting',
    (tester) async {
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      final repository = _Repository();
      await _open(tester, repository, sessions);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('Mesaj geçmişi karşı tarafta kalır'), findsOneWidget);
      await _next(tester);
      final password = find.byKey(const Key('account-delete-password'));
      final acknowledge = find.byKey(const Key('account-delete-acknowledge'));
      await tester.enterText(password, 'discard-on-back');
      await tester.tap(acknowledge);
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);
      expect(password, findsNothing);
      await _next(tester);
      expect(find.text('2 / 2'), findsOneWidget);
      expect(tester.widget<TextField>(password).controller!.text, isEmpty);
      expect(tester.widget<CheckboxListTile>(acknowledge).value, isFalse);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AccountDeletionDialog), findsNothing);
      expect(repository.calls, 0);
    },
  );

  testWidgets('first step refuses to advance after a session change', (
    tester,
  ) async {
    final sessions = AudienceTestSessions(audienceSession());
    addTearDown(sessions.dispose);
    final repository = _Repository();
    await _open(tester, repository, sessions);
    final next = find.byKey(const Key('account-delete-next'));
    final oldAction = tester.widget<OutlinedButton>(next).onPressed!;
    sessions.replace(audienceSession(user: 'other'));
    oldAction();
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(next).onPressed, isNull);
    expect(find.textContaining('Oturum kapandı veya değişti.'), findsOneWidget);
    expect(find.byKey(const Key('account-delete-password')), findsNothing);
    expect(repository.calls, 0);
  });

  testWidgets(
    'large text and the keyboard leave both steps reachable on a narrow phone',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      final repository = _Repository();
      await _open(
        tester,
        repository,
        sessions,
        chooseGoogleAccount: () async => null,
      );
      expect(tester.takeException(), isNull);
      expect(
        find.bySemanticsLabel('İlk adım, toplam iki adım'),
        findsOneWidget,
      );
      await _next(tester);
      expect(
        find.bySemanticsLabel('İkinci adım, toplam iki adım'),
        findsOneWidget,
      );
      final password = find.byKey(const Key('account-delete-password'));
      await tester.ensureVisible(password);
      await tester.enterText(password, 'untested-password');
      tester.view.viewInsets = const FakeViewPadding(bottom: 244);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.widget<TextField>(password).obscureText, isTrue);
      final cancel = find.byKey(const Key('account-delete-cancel'));
      await tester.ensureVisible(cancel);
      await tester.pumpAndSettle();
      expect(tester.getRect(cancel).bottom, lessThanOrEqualTo(324));
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.byType(AccountDeletionDialog), findsNothing);
      expect(repository.calls, 0);
    },
  );

  testWidgets(
    'thin confirmation frame reflects availability, labels and one in-flight request',
    (tester) async {
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      final repository = _Repository()..pending = Completer<Result<bool>>();
      await _open(
        tester,
        repository,
        sessions,
        chooseGoogleAccount: () async => null,
      );
      await _next(tester);
      final confirm = find.byKey(const Key('account-delete-confirm'));
      GradientOutlineButton button() =>
          tester.widget<GradientOutlineButton>(confirm);
      GradientOutline outline() => tester.widget<GradientOutline>(
        find.descendant(of: confirm, matching: find.byType(GradientOutline)),
      );
      expect(button().label, 'Hesabımı kalıcı olarak sil');
      expect(button().onPressed, isNull);
      expect(button().loading, isFalse);
      expect(outline().colors!.toSet(), hasLength(1));
      expect(tester.getSize(confirm).height, greaterThanOrEqualTo(48));
      await tester.tap(confirm);
      expect(repository.calls, 0);
      await tester.tap(find.text('Google'));
      await tester.pumpAndSettle();
      expect(button().label, 'Google ile doğrula ve sil');
      await tester.tap(find.text('Şifre'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('account-delete-password')),
        'password',
      );
      await tester.tap(find.byKey(const Key('account-delete-acknowledge')));
      await tester.pump();
      expect(button().onPressed, isNotNull);
      expect(button().maxLines, isNull);
      expect(outline().strokeWidth, 1);
      expect(outline().colors!.toSet().length, greaterThan(1));
      final material = find.descendant(
        of: confirm,
        matching: find.byType(Material),
      );
      expect(tester.widget<Material>(material).color, Colors.transparent);
      await tester.tap(confirm);
      await tester.tap(confirm);
      await tester.pump();
      expect(repository.calls, 1);
      expect(button().onPressed, isNull);
      expect(button().loading, isTrue);
      expect(button().label, 'İşlem sürüyor');
      expect(
        find.descendant(
          of: confirm,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      repository.pending!.complete(const Result.success(true));
      await tester.pumpAndSettle();
      expect(find.text('Deleted: true'), findsOneWidget);
    },
  );

  testWidgets(
    'confirmed deletion runs once, clears password, and closes only after success',
    (tester) async {
      final sessions = AudienceTestSessions(audienceSession());
      final repository = _Repository()..pending = Completer<Result<bool>>();
      addTearDown(sessions.dispose);
      await _open(tester, repository, sessions);
      await _confirm(tester);
      expect(repository.calls, 1);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Kimliğini doğrula'), findsOneWidget);
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
      expect(find.byType(AccountDeletionDialog), findsNothing);
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
            .widget<GradientOutlineButton>(
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
            .widget<GradientOutlineButton>(
              find.byKey(const Key('account-delete-confirm')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'Google selection requires consent, cancel never sends, and retry uses a fresh account',
    (tester) async {
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      final repository = _Repository()
        ..result = const Result.failure(AppError(code: '1006', message: ''));
      final choices = <String?>[null, 'wrong-identity', 'correct-identity'];
      await _open(
        tester,
        repository,
        sessions,
        chooseGoogleAccount: () async => choices.removeAt(0),
      );
      await _next(tester);
      await tester.enterText(
        find.byKey(const Key('account-delete-password')),
        'unused',
      );
      await tester.tap(find.text('Google'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-delete-password')), findsNothing);
      final confirm = find.byKey(const Key('account-delete-confirm'));
      expect(tester.widget<GradientOutlineButton>(confirm).onPressed, isNull);
      await tester.tap(find.byKey(const Key('account-delete-acknowledge')));
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(repository.calls, 0);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(repository.calls, 1);
      expect(repository.google, 'wrong-identity');
      expect(repository.password, isNull);
      expect(
        find.textContaining(
          'SoundConnect hesabını açtığın Google hesabını seç.',
        ),
        findsOneWidget,
      );
      expect(find.text('Deleted: true'), findsNothing);
      repository.result = const Result.success(true);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(repository.calls, 2);
      expect(repository.google, 'correct-identity');
      expect(find.text('Deleted: true'), findsOneWidget);
    },
  );

  testWidgets(
    'pending Google chooser starts once and ignores the credential after account switch',
    (tester) async {
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      final repository = _Repository();
      final picker = Completer<String?>();
      var selections = 0;
      await _open(
        tester,
        repository,
        sessions,
        chooseGoogleAccount: () {
          selections++;
          return picker.future;
        },
      );
      await _next(tester);
      await tester.tap(find.text('Google'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account-delete-acknowledge')));
      await tester.pump();
      final confirm = find.byKey(const Key('account-delete-confirm'));
      await tester.tap(confirm);
      await tester.tap(confirm);
      await tester.pump();
      expect(selections, 1);
      sessions.replace(audienceSession(user: 'other'));
      picker.complete('old-identity');
      await tester.pumpAndSettle();
      expect(repository.calls, 0);
      expect(
        find.textContaining('Oturum kapandı veya değişti.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'confirmed request closes only its own dialog under another route',
    (tester) async {
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      final repository = _Repository()..pending = Completer<Result<bool>>();
      await _open(tester, repository, sessions);
      await _confirm(tester);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Other screen')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      repository.pending!.complete(const Result.success(true));
      await tester.pumpAndSettle();
      expect(find.text('Other screen'), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('Deleted: true'), findsOneWidget);
      expect(find.byType(AccountDeletionDialog), findsNothing);
    },
  );
}

Future<void> _open(
  WidgetTester tester,
  _Repository repository,
  AudienceTestSessions sessions, {
  Future<String?> Function()? chooseGoogleAccount,
}) async {
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
                  final expected = sessions.session;
                  final revision = sessions.credentialRevision;
                  final result = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    isDismissible: false,
                    enableDrag: false,
                    useSafeArea: true,
                    builder: (_) => AccountDeletionDialog(
                      repository: repository,
                      sessions: sessions,
                      expectedSession: expected,
                      expectedRevision: revision,
                      chooseGoogleAccount: chooseGoogleAccount,
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

Future<void> _next(WidgetTester tester) async {
  final next = find.byKey(const Key('account-delete-next'));
  await tester.ensureVisible(next);
  await tester.tap(next);
  await tester.pumpAndSettle();
  expect(find.text('Kimliğini doğrula'), findsOneWidget);
}

Future<void> _confirm(WidgetTester tester) async {
  await _next(tester);
  await tester.enterText(
    find.byKey(const Key('account-delete-password')),
    'password',
  );
  await tester.tap(find.byKey(const Key('account-delete-acknowledge')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('account-delete-confirm')));
  await tester.pump();
}

class _DeletionSessions extends AudienceTestSessions {
  _DeletionSessions(super.current);

  @override
  Future<void> logout() async => replace(const AuthSession.guest());
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
  String? password;
  String? google;
  Completer<Result<bool>>? pending;
  Result<bool> result = const Result.success(true);
  List<BandDeletionOption> options = [];
  List<BandDeletionDecision> lastDecisions = [];
  int optionCalls = 0;
  @override
  Future<Result<List<BandDeletionOption>>> getBandOptions(
    AuthSession expectedSession,
  ) async {
    optionCalls++;
    return Result.success(options);
  }

  @override
  Future<Result<bool>> deleteAccount({
    required AuthSession expectedSession,
    String? currentPassword,
    String? googleIdToken,
    List<BandDeletionDecision> bandDecisions = const [],
  }) {
    calls++;
    password = currentPassword;
    google = googleIdToken;
    lastDecisions = bandDecisions;
    return pending?.future ?? Future.value(result);
  }
}
