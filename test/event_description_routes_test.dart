import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_item.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_owner_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_public_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_event_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/venue_weekly_calendar_editor_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/weekly_event_detail_screen.dart';

void main() {
  for (final description in <String?>[
    null,
    '   ',
    '  Kapılar 19.30’da açılır.  ',
    'MANUAL performansı',
  ]) {
    testWidgets(
      'venue event management preserves only authored description: $description',
      (tester) async {
        await serviceLocator.reset();
        addTearDown(serviceLocator.reset);
        serviceLocator
          ..registerSingleton<VenueEventRepository>(
            _DescriptionEventRepository(description),
          )
          ..registerSingleton<EngagementRepository>(_Comments())
          ..registerSingleton<VenueProfileRepository>(_VenueProfiles());

        await tester.pumpWidget(
          MaterialApp(
            home: VenueWeeklyCalendarEditorScreen(ownerProfile: _venue),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('M-T1 — Katıl, gösterme'));
        await tester.pumpAndSettle();

        final event = tester
            .widget<WeeklyEventDetailScreen>(
              find.byType(WeeklyEventDetailScreen),
            )
            .event;
        expect(event.description, description?.trim() ?? '');
        expect(event.description, isNot('bugrasahin performansı'));
        expect(event.description, isNot('Mekan açıklaması'));
        expect(event.performerType, 'MANUAL');
        expect(event.hasLinkedPerformerProfile, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

const _venue = VenueOwnerProfile(
  venueProfileId: 'venue-profile-id',
  venueId: 'venue-id',
  ownerUserId: 'owner-id',
  venueName: 'soundconnectankara',
  bio: null,
  profilePictureUrl: null,
  instagramUrl: null,
  youtubeUrl: null,
  websiteUrl: null,
  address: null,
  phone: null,
  website: null,
  description: 'Mekan açıklaması',
  musicStartTime: null,
  cityId: 'city-id',
  cityName: 'Ankara',
  districtId: 'district-id',
  districtName: 'Çankaya',
  neighborhoodId: null,
  neighborhoodName: null,
  status: 'APPROVED',
  activeMusicians: [],
  activeBands: [],
  weeklyEvents: [],
);

class _DescriptionEventRepository implements VenueEventRepository {
  _DescriptionEventRepository(this.description);

  final String? description;

  @override
  Future<Result<List<VenueOwnerEventItem>>> listByVenue(String venueId) async {
    return Result.success([
      VenueOwnerEventItem(
        id: 'event-1',
        title: 'M-T1 — Katıl, gösterme',
        posterImage: null,
        performerName: 'bugrasahin',
        musicianProfileId: null,
        performerType: 'MANUAL',
        eventDate: DateTime.now().add(const Duration(days: 1)),
        startTime: '20:00:00',
        endTime: '22:00:00',
        description: description,
      ),
    ]);
  }

  @override
  Future<Result<VenueEventDetail>> getDetail(String eventId) async =>
      const Result.failure(
        AppError(code: 'unavailable', message: 'Use the event route data.'),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Comments implements EngagementRepository {
  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async => const Result.success(CommentPage(items: [], totalElements: 0));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _VenueProfiles implements VenueProfileRepository {
  @override
  Future<Result<VenuePublicProfile>> getPublicVenueProfile({
    String? venueId,
  }) async => const Result.failure(
    AppError(code: 'unavailable', message: 'Use the event route data.'),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
