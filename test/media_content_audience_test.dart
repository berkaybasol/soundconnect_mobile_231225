import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/media_content_audience_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/media_asset_model.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/track_model.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/profile_media_upload_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/media_content_audience.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_upload_result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_upload_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/media_content_audience_controls.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

const assetId = '74396f02-82a2-4718-880e-1f542366436a';

Map<String, dynamic> mediaResponse({
  String id = assetId,
  String audience = 'BACKSTAGE',
}) => {
  'uuid': id,
  'kind': 'VIDEO',
  'contentAudience': audience,
  'ownerType': 'MUSICIAN_PROFILE',
  'sourceUrl': 'https://example.test/video.mp4',
};

void main() {
  test('media, track and upload responses retain explicit audience metadata', () {
    expect(
      MediaAssetModel.fromJson(mediaResponse()).contentAudience,
      'BACKSTAGE',
    );
    expect(
      TrackModel.fromJson({
        'id': 'track',
        'mediaAssetId': assetId,
        'contentAudience': 'BACKSTAGE',
      }).contentAudience,
      'BACKSTAGE',
    );
    expect(
      ProfileUploadedMedia.fromJson(mediaResponse()).contentAudience,
      'BACKSTAGE',
    );
    expect(
      MediaAssetModel.fromJson({'uuid': assetId}).contentAudience,
      'MAINSTAGE',
    );
    expect(
      MediaAssetModel.fromJson({
        'uuid': assetId,
        'ownerType': 'STUDIO_PROFILE',
      }).contentAudience,
      'BACKSTAGE',
    );
    expect(TrackModel.fromJson({'id': 'legacy'}).contentAudience, 'MAINSTAGE');
    // Unknown wire values remain unknown; they are never interpreted as MAINSTAGE.
    expect(
      MediaAssetModel.fromJson(
        mediaResponse(audience: 'FUTURE'),
      ).contentAudience,
      'FUTURE',
    );
  });

  for (final owner in ['MUSICIAN_PROFILE', 'VENUE_PROFILE', 'BAND']) {
    for (final visibility in ['PUBLIC', 'PRIVATE']) {
      test(
        '$owner init preserves $visibility independently from BACKSTAGE',
        () async {
          final api = RecordingApiClient(
            (_) => throw ApiException(
              const AppError(code: 'stop', message: 'Stop after init'),
            ),
          );
          final repository = ProfileMediaUploadRepositoryImpl(
            api,
            sessionKeyProvider: () => 'owner',
            tokenProvider: () => 'token',
          );
          await repository.uploadAsset(
            source: ProfileUploadSource.bytes([1, 2, 3]),
            ownerType: owner,
            ownerId: assetId,
            mediaKind: 'VIDEO',
            mimeType: 'video/mp4',
            originalFileName: 'video.mp4',
            visibility: visibility,
            contentAudience: 'BACKSTAGE',
          );
          expect(api.requests.single.path, '/api/v1/user/media/init-upload');
          expect(api.lastRequest.method, RecordedHttpMethod.post);
          expect((api.lastRequest.body as Map)['contentAudience'], 'BACKSTAGE');
          expect((api.lastRequest.body as Map)['visibility'], visibility);
          expect(api.lastRequest.requestContext?.expectedToken, 'token');
        },
      );
    }
  }

  for (final choice in [
    (owner: 'STUDIO_PROFILE', requested: 'MAINSTAGE', expected: 'BACKSTAGE'),
    (owner: 'LISTENER_PROFILE', requested: 'BACKSTAGE', expected: 'MAINSTAGE'),
  ]) {
    test('${choice.owner} upload normalizes its fixed audience', () async {
      final api = RecordingApiClient(
        (_) => throw ApiException(
          const AppError(code: 'stop', message: 'Stop after init'),
        ),
      );
      final repository = ProfileMediaUploadRepositoryImpl(api);
      await repository.uploadAsset(
        source: ProfileUploadSource.bytes([1]),
        ownerType: choice.owner,
        ownerId: assetId,
        mediaKind: 'IMAGE',
        mimeType: 'image/jpeg',
        originalFileName: 'image.jpg',
        contentAudience: choice.requested,
      );
      expect((api.lastRequest.body as Map)['contentAudience'], choice.expected);
    });
  }

  test('invalid audience fails before any upload is initialized', () async {
    final api = RecordingApiClient((_) => null);
    final result = await ProfileMediaUploadRepositoryImpl(api).uploadAsset(
      source: ProfileUploadSource.bytes([1]),
      ownerType: 'MUSICIAN_PROFILE',
      ownerId: assetId,
      mediaKind: 'IMAGE',
      mimeType: 'image/jpeg',
      originalFileName: 'image.jpg',
      contentAudience: 'PUBLIC',
    );
    expect(result.error?.code, 'profile_upload_audience');
    expect(api.requests, isEmpty);
  });

  test(
    'owner edit uses exact PATCH contract, asset identity and session fence',
    () async {
      final api = RecordingApiClient((_) => mediaResponse());
      final sessions = AudienceTestSessions(
        audienceSession(user: 'owner', role: 'ROLE_MUSICIAN'),
      );
      addTearDown(sessions.dispose);
      final result = await MediaContentAudienceRepository(api, sessions).update(
        assetId: assetId,
        ownerType: 'MUSICIAN_PROFILE',
        contentAudience: 'BACKSTAGE',
      );
      expect(result.isSuccess, isTrue);
      expect(result.data?.contentAudience, 'BACKSTAGE');
      expect(api.lastRequest.method, RecordedHttpMethod.patch);
      expect(
        api.lastRequest.path,
        '/api/v1/user/media/$assetId/content-audience',
      );
      expect(api.lastRequest.body, {'contentAudience': 'BACKSTAGE'});
      expect(api.lastRequest.requestContext?.expectedSessionKey, 'owner');
      expect(api.lastRequest.requestContext?.expectedToken, 'token');
    },
  );

  for (final response in [
    mediaResponse(id: audienceEventId),
    mediaResponse(audience: 'MAINSTAGE'),
    {...mediaResponse(), 'ownerType': 'BAND'},
    {'uuid': assetId},
  ]) {
    test(
      'edit rejects unexpected server identity or audience: $response',
      () async {
        final sessions = AudienceTestSessions(
          audienceSession(role: 'ROLE_MUSICIAN'),
        );
        addTearDown(sessions.dispose);
        final result =
            await MediaContentAudienceRepository(
              RecordingApiClient((_) => response),
              sessions,
            ).update(
              assetId: assetId,
              ownerType: 'MUSICIAN_PROFILE',
              contentAudience: 'BACKSTAGE',
            );
        expect(result.error?.code, 'media_audience_invalid');
      },
    );
  }

  test(
    'listener and studio cannot access the owner audience edit API from this control',
    () async {
      final api = RecordingApiClient((_) => null);
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      for (final ownerType in ['LISTENER_PROFILE', 'STUDIO_PROFILE']) {
        final result = await MediaContentAudienceRepository(api, sessions)
            .update(
              assetId: assetId,
              ownerType: ownerType,
              contentAudience: 'BACKSTAGE',
            );
        expect(result.isSuccess, isFalse);
      }
      expect(api.requests, isEmpty);
    },
  );

  test('guest cannot update audience', () async {
    final api = RecordingApiClient((_) => null);
    final sessions = AudienceTestSessions(const AuthSession.guest());
    addTearDown(sessions.dispose);
    final result = await MediaContentAudienceRepository(api, sessions).update(
      assetId: assetId,
      ownerType: 'MUSICIAN_PROFILE',
      contentAudience: 'BACKSTAGE',
    );
    expect(result.error?.code, 'media_audience_session');
    expect(api.requests, isEmpty);
  });

  test(
    'late edit completion cannot be adopted after account replacement and restoration',
    () async {
      final pending = Completer<Object?>();
      final api = RecordingApiClient((_) => pending.future);
      final original = audienceSession(role: 'ROLE_MUSICIAN');
      final sessions = AudienceTestSessions(original);
      addTearDown(sessions.dispose);
      final result = MediaContentAudienceRepository(api, sessions).update(
        assetId: assetId,
        ownerType: 'MUSICIAN_PROFILE',
        contentAudience: 'BACKSTAGE',
      );
      sessions.replace(audienceSession(user: 'replacement'));
      sessions.replace(original);
      pending.complete(mediaResponse());
      expect((await result).error?.code, 'media_audience_session');
    },
  );

  for (final owner in ['MUSICIAN_PROFILE', 'VENUE_PROFILE', 'BAND']) {
    testWidgets('$owner audience selector uses the two approved labels', (
      tester,
    ) async {
      String selected = MediaContentAudience.mainstage;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => MediaContentAudienceField(
                ownerType: owner,
                value: selected,
                onChanged: (value) => setState(() => selected = value),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Hedef kitle'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Dinleyiciler dahil herkes'), findsWidgets);
      await tester.tap(find.text('Yalnız sektör içi').last);
      await tester.pumpAndSettle();
      expect(selected, 'BACKSTAGE');
      expect(tester.takeException(), isNull);
    });
  }

  for (final owner in ['LISTENER_PROFILE', 'STUDIO_PROFILE']) {
    testWidgets('$owner does not receive an audience selector', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaContentAudienceField(
              ownerType: owner,
              value: 'MAINSTAGE',
              onChanged: (_) => fail('Audience must be fixed'),
            ),
          ),
        ),
      );
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    });
  }

  testWidgets(
    'audience dialog and dropdown fit 320 pixels at 200 percent text scale',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => chooseMediaContentAudience(
                  context,
                  ownerType: 'MUSICIAN_PROFILE',
                ),
                child: const Text('Düzenle'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Düzenle'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Yalnız sektör içi').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  Future<void> openEdit(
    WidgetTester tester,
    MediaContentAudienceRepository repository,
    List<bool> results, {
    bool Function()? isCurrent,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                results.add(
                  await editMediaContentAudience(
                    context,
                    assetId: assetId,
                    ownerType: 'MUSICIAN_PROFILE',
                    currentAudience: 'MAINSTAGE',
                    repository: repository,
                    isCurrent: isCurrent,
                  ),
                );
              },
              child: const Text('Düzenle'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Düzenle'));
    await tester.pumpAndSettle();
  }

  Future<void> chooseBackstage(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yalnız sektör içi').last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'existing MAINSTAGE media can be changed to BACKSTAGE and refreshed',
    (tester) async {
      final api = RecordingApiClient((_) => mediaResponse());
      final sessions = AudienceTestSessions(
        audienceSession(role: 'ROLE_MUSICIAN'),
      );
      addTearDown(sessions.dispose);
      final results = <bool>[];
      await openEdit(
        tester,
        MediaContentAudienceRepository(api, sessions),
        results,
      );
      await chooseBackstage(tester);
      await tester.tap(find.text('Devam'));
      await tester.pumpAndSettle();
      expect(results, [true]);
      expect(api.requests, hasLength(1));
      expect(find.text('Hedef kitle güncellendi.'), findsOneWidget);
    },
  );

  testWidgets('unchanged audience does not send an edit request', (
    tester,
  ) async {
    final api = RecordingApiClient((_) => null);
    final sessions = AudienceTestSessions(
      audienceSession(role: 'ROLE_MUSICIAN'),
    );
    addTearDown(sessions.dispose);
    final results = <bool>[];
    await openEdit(
      tester,
      MediaContentAudienceRepository(api, sessions),
      results,
    );
    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    expect(results, [false]);
    expect(api.requests, isEmpty);
  });

  testWidgets(
    'changing accounts during the dialog permanently revokes the pending edit',
    (tester) async {
      final api = RecordingApiClient((_) => mediaResponse());
      final original = audienceSession(role: 'ROLE_MUSICIAN');
      final sessions = AudienceTestSessions(original);
      addTearDown(sessions.dispose);
      final results = <bool>[];
      await openEdit(
        tester,
        MediaContentAudienceRepository(api, sessions),
        results,
      );
      await chooseBackstage(tester);
      sessions.replace(audienceSession(user: 'other'));
      sessions.replace(original);
      await tester.tap(find.text('Devam'));
      await tester.pumpAndSettle();
      expect(results, [false]);
      expect(api.requests, isEmpty);
    },
  );

  testWidgets('replacement card cannot receive a late edit result', (
    tester,
  ) async {
    final pending = Completer<Object?>();
    final api = RecordingApiClient((_) => pending.future);
    final sessions = AudienceTestSessions(
      audienceSession(role: 'ROLE_MUSICIAN'),
    );
    addTearDown(sessions.dispose);
    final results = <bool>[];
    var current = true;
    await openEdit(
      tester,
      MediaContentAudienceRepository(api, sessions),
      results,
      isCurrent: () => current,
    );
    await chooseBackstage(tester);
    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    current = false;
    pending.complete(mediaResponse());
    await tester.pumpAndSettle();
    expect(results, [false]);
    expect(find.text('Hedef kitle güncellendi.'), findsNothing);
  });
}
