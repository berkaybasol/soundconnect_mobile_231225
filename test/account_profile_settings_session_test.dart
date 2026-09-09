import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/musician_profile_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/listener_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/account_profile_settings_section.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

void main() {
  late AudienceTestSessions sessions;
  late _Profiles repository;
  setUp(() async {
    await serviceLocator.reset();
    sessions = AudienceTestSessions(audienceSession(user: 'first'));
    repository = _Profiles(sessions);
    serviceLocator.registerSingleton<AuthSessionManager>(sessions);
    serviceLocator.registerSingleton<ListenerProfileRepository>(repository);
  });
  tearDown(() async {
    await serviceLocator.reset();
    sessions.dispose();
  });

  testWidgets(
    'musician settings bio write carries the original account to transport',
    (tester) async {
      sessions.replace(audienceSession(user: 'first', role: 'ROLE_MUSICIAN'));
      final api = RecordingApiClient(
        (_) => {
          'id': 'musician-first',
          'userId': 'first',
          'username': 'first',
          'description': 'Bio first',
        },
      );
      serviceLocator.registerSingleton<MusicianProfileRepository>(
        MusicianProfileRepositoryImpl(api),
      );
      await _mount(tester);
      await tester.pumpAndSettle();
      await _edit(tester);
      await tester.tap(
        find.byKey(const Key('account-settings-save-description-button')),
      );
      await tester.pumpAndSettle();

      expect(api.lastRequest.body, {'description': 'old private draft'});
      expect(api.lastRequest.requestContext?.expectedSessionKey, 'first');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account switch clears private settings and discards old profile load',
    (tester) async {
      final old = Completer<Result<ListenerProfile>>();
      repository.nextLoad = old;
      await _mount(tester);
      sessions.replace(audienceSession(user: 'second', token: 'second'));
      await tester.pumpAndSettle();
      expect(find.text('Bio second'), findsOneWidget);
      old.complete(Result.success(_profile('first')));
      await tester.pumpAndSettle();
      expect(find.text('Bio first'), findsNothing);
      expect(find.text('Bio second'), findsOneWidget);
      expect(repository.loads, ['first', 'second']);
      expect(tester.takeException(), isNull);
    },
  );

  for (final change in ['logout', 'account', 'same-user token']) {
    testWidgets('retained save callback cannot write old draft after $change', (
      tester,
    ) async {
      await _mount(tester);
      await tester.pumpAndSettle();
      await _edit(tester);
      final oldSave = tester
          .widget<GradientOutlineButton>(
            find.byKey(const Key('account-settings-save-description-button')),
          )
          .onPressed!;
      sessions.replace(switch (change) {
        'logout' => const AuthSession.guest(),
        'account' => audienceSession(user: 'second', token: 'second'),
        _ => audienceSession(user: 'first', token: 'renewed'),
      });
      await tester.pumpAndSettle();
      oldSave();
      await tester.pumpAndSettle();
      expect(repository.descriptions, isEmpty);
      expect(find.text('old private draft'), findsNothing);
      expect(
        find.byKey(const Key('account-settings-description-field')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'late saved profile cannot overwrite new account or display old success message',
    (tester) async {
      await _mount(tester);
      await tester.pumpAndSettle();
      await _edit(tester);
      final mutation = Completer<Result<ListenerProfile>>();
      repository.save = mutation;
      await tester.tap(
        find.byKey(const Key('account-settings-save-description-button')),
      );
      await tester.pump();
      expect(repository.descriptions, ['old private draft']);
      sessions.replace(audienceSession(user: 'second', token: 'second'));
      await tester.pumpAndSettle();
      mutation.complete(
        Result.success(_profile('first', bio: 'old saved draft')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bio second'), findsOneWidget);
      expect(find.text('old saved draft'), findsNothing);
      expect(find.text('Açıklaman güncellendi.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account change during ghost confirmation cannot mutate new listener account',
    (tester) async {
      await _mount(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('listener-ghost-profile-switch')));
      await tester.pumpAndSettle();
      final confirm = tester
          .widget<FilledButton>(
            find.byKey(const Key('confirm-enable-ghost-profile')),
          )
          .onPressed!;
      sessions.replace(audienceSession(user: 'second', token: 'second'));
      // Retained callback can still run before the scheduled dialog removal.
      confirm();
      await tester.pumpAndSettle();
      expect(repository.visibilityWrites, 0);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Bio second'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'logout dismisses only the owned confirmation and removes cached profile',
    (tester) async {
      await _mount(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('listener-ghost-profile-switch')));
      await tester.pumpAndSettle();
      sessions.replace(const AuthSession.guest());
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Bio first'), findsNothing);
      expect(
        find.byKey(const Key('account-settings-profile-photo')),
        findsNothing,
      );
      expect(repository.visibilityWrites, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _mount(WidgetTester tester) => tester.pumpWidget(
  const MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: AccountProfileSettingsSection()),
    ),
  ),
);
Future<void> _edit(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const Key('account-settings-profile-description')),
  );
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('account-settings-description-field')),
    'old private draft',
  );
  await tester.ensureVisible(
    find.byKey(const Key('account-settings-save-description-button')),
  );
  await tester.pumpAndSettle();
}

ListenerProfile _profile(String user, {String? bio}) => ListenerProfile(
  id: 'profile-$user',
  userId: user,
  username: user,
  bio: bio ?? 'Bio $user',
  profilePictureMediaId: null,
  profilePictureUrl: null,
  followerCount: 0,
  followingCount: 0,
  visibilityMode: ListenerVisibilityMode.standard,
  version: 2,
  profileContentVisible: true,
  profileContentEditable: true,
  avatarEditable: true,
  canReceiveFollowers: true,
);

class _Profiles extends ListenerProfileRepository {
  _Profiles(this.sessions);
  final AudienceTestSessions sessions;
  Completer<Result<ListenerProfile>>? nextLoad;
  Completer<Result<ListenerProfile>>? save;
  final loads = <String>[];
  final descriptions = <String?>[];
  int visibilityWrites = 0;
  @override
  Future<Result<ListenerProfile>> getMyProfile() {
    final user = sessions.session.userId!;
    loads.add(user);
    final pending = nextLoad;
    nextLoad = null;
    return pending?.future ?? Future.value(Result.success(_profile(user)));
  }

  @override
  Future<Result<ListenerProfile>> updateMyProfile(
    ListenerProfileSaveRequest request,
  ) {
    descriptions.add(request.description);
    return save?.future ??
        Future.value(
          Result.success(
            _profile(sessions.session.userId!, bio: request.description),
          ),
        );
  }

  @override
  Future<Result<ListenerProfile>> updateVisibility(
    ListenerVisibilityUpdateRequest request,
  ) async {
    visibilityWrites++;
    return Result.success(_profile(sessions.session.userId!));
  }
}
