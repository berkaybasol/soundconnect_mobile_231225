import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_upload_result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_item.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_owner_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_upload_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_search_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/venue_weekly_calendar_editor_screen.dart';

void main() {
  const channel = MethodChannel('plugins.flutter.io/image_picker');
  late _Uploads uploads;
  VenueEventDraft? saved;

  setUp(() async {
    await serviceLocator.reset();
    uploads = _Uploads();
    saved = null;
    serviceLocator
      ..registerSingleton<ProfileMediaUploadRepository>(uploads)
      ..registerSingleton<ProfileSearchRepository>(_Search());
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await serviceLocator.reset();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showVenueEventDraft(
                context,
                ownerProfile: _owner,
                initialDraft: VenueEventDraft(
                  title: 'Mevcut etkinlik',
                  description: 'Mevcut açıklama',
                  eventDate: DateTime(2026, 9, 25),
                  startTime: const TimeOfDay(hour: 20, minute: 0),
                  endTime: const TimeOfDay(hour: 22, minute: 0),
                  posterImage: 'original-poster-asset',
                  musicianProfileId: null,
                  bandId: null,
                  manualPerformerName: null,
                ),
                onSave: (draft) async {
                  saved = draft;
                  return const Result.success(null);
                },
              ),
              child: const Text('Formu aç'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Formu aç'));
    await tester.pumpAndSettle();
  }

  VoidCallback picker(WidgetTester tester) => tester
      .widget<InkWell>(
        find
            .ancestor(
              of: find.text('Afiş görseli'),
              matching: find.byType(InkWell),
            )
            .first,
      )
      .onTap!;

  for (final failure in ['picker', 'upload', 'empty asset']) {
    testWidgets('$failure failure preserves the existing poster when saving', (
      tester,
    ) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        expect(call.method, 'pickImage');
        if (failure == 'picker') {
          throw PlatformException(code: 'photo_access_denied');
        }
        return File('assets/logo.png').absolute.path;
      });
      uploads.emptyAsset = failure == 'empty asset';
      await open(tester);
      final pick = picker(tester);
      await tester.runAsync(() => (pick as Future<void> Function())());
      await tester.pumpAndSettle();
      expect(find.text('Afiş yüklenemedi. Tekrar dene.'), findsOneWidget);
      expect(find.text('Değiştirmek için dokun'), findsOneWidget);
      expect(find.text('Yükleniyor...'), findsNothing);
      expect(uploads.calls, failure == 'picker' ? 0 : 1);
      final submit = find.byKey(const Key('venue-event-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(saved?.posterImage, 'original-poster-asset');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'pending gallery prevents duplicate pickers and cancel preserves the poster',
    (tester) async {
      final pending = Completer<String?>();
      var calls = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) {
        calls++;
        return pending.future;
      });
      await open(tester);
      final pick = picker(tester);
      pick();
      pick();
      await tester.pump();
      expect(calls, 1);
      expect(find.text('Yükleniyor...'), findsOneWidget);
      pending.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('Değiştirmek için dokun'), findsOneWidget);
      expect(find.text('Yükleniyor...'), findsNothing);
      expect(uploads.calls, 0);
      expect(saved, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Search extends Fake implements ProfileSearchRepository {}

class _Uploads extends Fake implements ProfileMediaUploadRepository {
  int calls = 0;
  bool emptyAsset = false;
  @override
  Future<Result<ProfileUploadedMedia>> uploadAsset({
    required ProfileUploadSource source,
    required String ownerType,
    required String ownerId,
    required String mediaKind,
    required String mimeType,
    required String originalFileName,
    String visibility = 'PUBLIC',
    String contentAudience = 'MAINSTAGE',
    ProfileUploadAttachmentIntent attachmentIntent =
        const ProfileUploadAttachmentIntent.none(),
    ProfileUploadProgress? onProgress,
    ProfileUploadStageChanged? onStageChanged,
    ProfileUploadCancellation? cancellation,
  }) async {
    calls++;
    expect(ownerType, 'VENUE_PROFILE');
    expect(ownerId, 'venue-profile');
    if (emptyAsset) {
      return const Result.success(
        ProfileUploadedMedia(uuid: ' ', sourceUrl: null, playbackUrl: null),
      );
    }
    return const Result.failure(
      AppError(code: 'network', message: 'Upload failed'),
    );
  }
}

const _owner = VenueOwnerProfile(
  venueProfileId: 'venue-profile',
  venueId: 'venue',
  ownerUserId: 'owner',
  venueName: 'Ankara Sahne',
  bio: null,
  profilePictureUrl: null,
  instagramUrl: null,
  youtubeUrl: null,
  websiteUrl: null,
  address: null,
  phone: null,
  website: null,
  description: null,
  musicStartTime: null,
  cityId: null,
  cityName: 'Ankara',
  districtId: null,
  districtName: 'Çankaya',
  neighborhoodId: null,
  neighborhoodName: null,
  status: 'APPROVED',
  activeMusicians: [],
  activeBands: [],
  weeklyEvents: [],
);
