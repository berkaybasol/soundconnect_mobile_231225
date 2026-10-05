import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/event_performer_request_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/band_calendar_repository_factory.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/band_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_performer_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_calendar.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_calendar_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_item.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/event_performer_request_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_event_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_performer_requests_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_performer_request_card.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_invitation_rejection_dialog.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_route_args.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/weekly_event_carousel.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/weekly_event_detail_screen.dart';

import 'support/auth_widget_test_support.dart';

part 'event_performer_request_flow_test_support.dart';
part 'event_performer_request_publication_test_cases.dart';

part 'event_performer_request_flow_test_register_event_performer_request_flow1.dart';
part 'event_performer_request_flow_test_register_event_performer_request_flow2.dart';

void main() {
  _registerEventPerformerRequestFlow1();
  _registerEventPerformerRequestFlow2();
}

WeeklyCalendarEvent _pendingCarouselEvent(String id) {
  return WeeklyCalendarEvent(
    id: id,
    title: 'Etkinlik $id',
    artistName: 'Performer',
    artistProfileId: null,
    bandProfileId: null,
    performerType: 'MANUAL',
    venueName: 'Mekan',
    venueId: null,
    city: '-',
    district: '-',
    neighborhood: '-',
    eventDate: '08.09.2026',
    startTime: '21:00',
    endTime: '23:00',
    description: '',
  );
}

WeeklyCalendarEvent _acceptedCarouselEvent(int index) {
  return WeeklyCalendarEvent(
    id: 'cache-event-$index',
    title: 'Etkinlik $index',
    artistName: 'Sanatçı $index',
    artistProfileId: 'cache-musician-$index',
    bandProfileId: null,
    performerType: 'MUSICIAN',
    venueName: 'Mekan',
    venueId: null,
    city: '-',
    district: '-',
    neighborhood: '-',
    eventDate: '08.09.2026',
    startTime: '21:00',
    endTime: '23:00',
    description: '',
  );
}

Widget _eventNavigationApp({
  required WeeklyCalendarEvent event,
  required ValueChanged<RouteSettings> onRoute,
}) {
  return MaterialApp(
    home: WeeklyEventDetailScreen(event: event),
    onGenerateRoute: (settings) {
      onRoute(settings);
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const Scaffold(body: Text('profile destination')),
      );
    },
  );
}

WeeklyCalendarEvent _calendarEvent({
  String? artistProfileId,
  String? bandProfileId,
  String? performerType,
}) {
  return WeeklyCalendarEvent(
    id: 'event-1',
    title: 'Sahbaz Gecesi',
    artistName: 'Sahbaz',
    artistProfileId: artistProfileId,
    bandProfileId: bandProfileId,
    performerType:
        performerType ?? (bandProfileId == null ? 'MUSICIAN' : 'BAND'),
    venueName: 'SoundConnect Ankara',
    venueId: null,
    city: 'Ankara',
    district: 'Çankaya',
    neighborhood: 'Kızılay',
    eventDate: '08.09.2026',
    startTime: '21:00',
    endTime: '23:00',
    description: '',
  );
}

Map<String, dynamic> _requestJson({String requestId = 'request-1'}) {
  return <String, dynamic>{
    'id': requestId,
    'eventId': 'event-$requestId',
    'eventTitle': 'Sahbaz Gecesi',
    'eventDate': '2026-09-08',
    'startTime': '21:00:00',
    'venueId': 'venue-1',
    'venueName': 'SoundConnect Ankara',
    'performerType': 'BAND',
    'bandId': 'band-1',
    'performerName': 'Sahbaz',
    'status': 'PENDING',
  };
}

EventPerformerRequestPage _page(
  List<EventPerformerRequest> items, {
  int page = 0,
  bool hasNext = false,
}) {
  return EventPerformerRequestPage(
    items: items,
    page: page,
    size: 20,
    totalElements: items.length,
    totalPages: hasNext ? page + 2 : (items.isEmpty ? 0 : page + 1),
    hasNext: hasNext,
  );
}

EventPerformerRequest _request({
  String requestId = 'request-1',
  EventPerformerTargetType targetType = EventPerformerTargetType.band,
  String targetId = 'band-1',
  String performerName = 'Sahbaz',
  bool? profileCalendarApproved = false,
  bool decisionAllowed = true,
  EventPerformerRequestPurpose purpose =
      EventPerformerRequestPurpose.performerConsent,
}) {
  return EventPerformerRequest(
    requestPurpose: purpose,
    requestId: requestId,
    eventId: 'event-$requestId',
    eventTitle: 'Sahbaz Gecesi',
    eventDate: DateTime(2026, 9, 8),
    startTime: '21:00:00',
    endTime: '23:00:00',
    venueId: 'venue-1',
    venueName: 'SoundConnect Ankara',
    venueProfilePictureUrl: null,
    targetType: targetType,
    targetId: targetId,
    musicianProfileId: targetType == EventPerformerTargetType.musician
        ? targetId
        : null,
    bandId: targetType == EventPerformerTargetType.band ? targetId : null,
    performerName: performerName,
    status: EventPerformerRequestStatus.pending,
    profileCalendarApproved: profileCalendarApproved,
    decisionAllowed: decisionAllowed,
    canReconsider: false,
    expired: false,
    serverNow: DateTime.utc(2026, 9, 6),
    eventStartsAt: DateTime.utc(2026, 9, 8, 18),
    createdAt: DateTime(2026, 9, 4),
    decidedAt: null,
  );
}

Future<void> _tapRequestControl(
  WidgetTester tester,
  Finder target, {
  bool warnIfMissed = true,
}) async {
  // Poster-bearing cards may extend past a short viewport. Exercise the same
  // scroll-then-tap behavior as a user without weakening decision assertions.
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target, warnIfMissed: warnIfMissed);
}
