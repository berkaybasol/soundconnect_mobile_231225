import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/profile_track_deletion_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_track_delete_menu.dart';
import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

void main() {
  Future<void> mountMenu(
    WidgetTester tester,
    ProfileTrackDeletionRepository repository,
    ValueNotifier<String?> target,
    List<String> callbacks,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<String?>(
            valueListenable: target,
            builder: (_, id, _) => id == null
                ? const SizedBox.shrink()
                : ProfileTrackDeleteMenu(
                    ownerType: 'MUSICIAN_PROFILE',
                    ownerId: 'profile',
                    trackId: id,
                    repository: repository,
                    onDeleted: () async {
                      callbacks.add(id);
                    },
                  ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Ses seçenekleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
  }

  testWidgets('removed card closes confirmation without deleting', (
    tester,
  ) async {
    final api = RecordingApiClient((_) => null);
    final target = ValueNotifier<String?>('original');
    addTearDown(target.dispose);
    await mountMenu(
      tester,
      ProfileTrackDeletionRepository(
        api,
        AudienceTestSessions(audienceSession()),
      ),
      target,
      [],
    );
    target.value = null;
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(api.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('late deletion does not refresh a replacement track', (
    tester,
  ) async {
    final pending = Completer<Object?>();
    final api = RecordingApiClient((_) => pending.future);
    final target = ValueNotifier<String?>('original');
    final callbacks = <String>[];
    addTearDown(target.dispose);
    await mountMenu(
      tester,
      ProfileTrackDeletionRepository(
        api,
        AudienceTestSessions(audienceSession()),
      ),
      target,
      callbacks,
    );
    await tester.tap(find.text('Sil'));
    await tester.pump();
    expect(api.requests.single.path, endsWith('/tracks/original'));
    target.value = 'replacement';
    await tester.pumpAndSettle();
    pending.complete(null);
    await tester.pumpAndSettle();
    expect(callbacks, isEmpty);
    expect(find.byTooltip('Ses seçenekleri'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('account replacement while confirming does not delete', (
    tester,
  ) async {
    final api = RecordingApiClient((_) => null);
    final sessions = AudienceTestSessions(audienceSession());
    final target = ValueNotifier<String?>('original');
    addTearDown(target.dispose);
    await mountMenu(
      tester,
      ProfileTrackDeletionRepository(api, sessions),
      target,
      [],
    );
    sessions.replace(audienceSession(user: 'another'));
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    expect(api.requests, isEmpty);
    expect(find.byTooltip('Ses seçenekleri'), findsOneWidget);
  });
  testWidgets(
    'replacing the track dismisses its pending deletion confirmation',
    (tester) async {
      final api = RecordingApiClient((_) => null);
      final target = ValueNotifier('original');
      final repository = ProfileTrackDeletionRepository(
        api,
        AudienceTestSessions(audienceSession()),
      );
      addTearDown(target.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: target,
              builder: (_, id, _) => ProfileTrackDeleteMenu(
                ownerType: 'MUSICIAN_PROFILE',
                ownerId: 'profile',
                trackId: id,
                repository: repository,
                onDeleted: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Ses seçenekleri'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();
      expect(find.text('Ses silinsin mi?'), findsOneWidget);
      target.value = 'replacement';
      await tester.pumpAndSettle();
      expect(find.text('Ses silinsin mi?'), findsNothing);
      expect(api.requests, isEmpty);
      expect(find.byTooltip('Ses seçenekleri'), findsOneWidget);
    },
  );
  for (final entry in {
    'MUSICIAN_PROFILE': 'musician-profiles',
    'BAND': 'bands',
    'STUDIO_PROFILE': 'studio-profiles',
  }.entries) {
    test(
      '${entry.key} deletion uses track ID and account-bound endpoint',
      () async {
        final api = RecordingApiClient((_) => null);
        final repository = ProfileTrackDeletionRepository(
          api,
          AudienceTestSessions(audienceSession(user: 'owner')),
        );
        final result = await repository.delete(
          ownerType: entry.key,
          ownerId: 'profile/1',
          trackId: 'track/1',
        );
        expect(result.isSuccess, isTrue);
        expect(api.lastRequest.method, RecordedHttpMethod.delete);
        expect(
          api.lastRequest.path,
          '/api/v1/${entry.value}/profile%2F1/tracks/track%2F1',
        );
        expect(api.lastRequest.requestContext?.expectedSessionKey, 'owner');
      },
    );
  }
  test('guest and unsupported owner never dispatch deletion', () async {
    final api = RecordingApiClient((_) => null);
    final sessions = AudienceTestSessions(const AuthSession.guest());
    final repository = ProfileTrackDeletionRepository(api, sessions);
    expect(
      (await repository.delete(
        ownerType: 'MUSICIAN_PROFILE',
        ownerId: 'p',
        trackId: 't',
      )).isSuccess,
      isFalse,
    );
    sessions.replace(audienceSession());
    expect(
      (await repository.delete(
        ownerType: 'VENUE',
        ownerId: 'p',
        trackId: 't',
      )).isSuccess,
      isFalse,
    );
    expect(api.requests, isEmpty);
  });

  for (final confirm in [false, true]) {
    testWidgets('delete confirmation $confirm controls server mutation', (
      tester,
    ) async {
      final api = RecordingApiClient((_) => null);
      var deleted = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileTrackDeleteMenu(
              ownerType: 'MUSICIAN_PROFILE',
              ownerId: 'profile',
              trackId: 'track',
              repository: ProfileTrackDeletionRepository(
                api,
                AudienceTestSessions(audienceSession()),
              ),
              onDeleted: () async {
                deleted++;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Ses seçenekleri'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();
      expect(api.requests, isEmpty);
      await tester.tap(find.text(confirm ? 'Sil' : 'Vazgeç'));
      await tester.pumpAndSettle();
      expect(api.requests.length, confirm ? 1 : 0);
      expect(deleted, confirm ? 1 : 0);
    });
  }

  testWidgets('failed delete leaves item and offers retry', (tester) async {
    final api = RecordingApiClient((_) => throw StateError('offline'));
    var deleted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileTrackDeleteMenu(
            ownerType: 'MUSICIAN_PROFILE',
            ownerId: 'profile',
            trackId: 'track',
            repository: ProfileTrackDeletionRepository(
              api,
              AudienceTestSessions(audienceSession()),
            ),
            onDeleted: () async {
              deleted = true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Ses seçenekleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    expect(deleted, isFalse);
    expect(find.byTooltip('Ses seçenekleri'), findsOneWidget);
    expect(find.text('Ses silinemedi. Lütfen tekrar dene.'), findsOneWidget);
  });

  test('late deletion response cannot update a different account', () async {
    final pending = Completer<Object?>();
    final sessions = AudienceTestSessions(audienceSession());
    final repository = ProfileTrackDeletionRepository(
      RecordingApiClient((_) => pending.future),
      sessions,
    );
    final request = repository.delete(
      ownerType: 'MUSICIAN_PROFILE',
      ownerId: 'p',
      trackId: 't',
    );
    sessions.replace(audienceSession(user: 'another'));
    pending.complete(null);
    expect((await request).isSuccess, isFalse);
  });
}
