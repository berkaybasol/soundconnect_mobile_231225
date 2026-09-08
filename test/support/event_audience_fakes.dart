import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/domain/event_audience_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';

const audienceEventId = 'c0890d3f-805d-4808-b123-abb9a9c79666';
const audienceVenueId = '58e05c32-bd79-4823-bbc0-58c53ea5aeea';

AuthSession audienceSession({
  String user = 'listener',
  String token = 'token',
  String role = 'ROLE_LISTENER',
  List<String>? roles,
  String status = 'ACTIVE',
  bool isAdmin = false,
}) => AuthSession.authenticated(
  token: token,
  userId: user,
  username: user,
  accountStatus: status,
  roles: roles ?? [role],
  permissions: const [],
  expiresAt: DateTime.utc(2100),
  isAdmin: isAdmin,
);

class AudienceTestSessions extends Fake
    with ChangeNotifier
    implements AuthSessionManager {
  AudienceTestSessions(this.current);
  AuthSession current;
  @override
  AuthSession get session => current;
  void replace(AuthSession next) {
    current = next;
    notifyListeners();
  }
}

EventAudienceState audienceState({
  String eventId = audienceEventId,
  EventAudienceStatus intent = EventAudienceStatus.none,
  bool published = false,
  String? note,
  int version = 0,
  bool ended = false,
  bool available = true,
  bool canPublish = true,
}) => EventAudienceState(
  eventId: eventId,
  intent: intent,
  publishedOnProfile: published,
  note: note,
  version: version,
  updatedAt: version == 0 ? null : DateTime.utc(2026, 9, 8),
  eventAvailable: available,
  eventEnded: ended,
  canSetIntent: available && !ended,
  canPublish: canPublish && available && !ended,
  publicationVisible: published && available,
  event: available
      ? VenueEventDetail(
          id: eventId,
          shareUrl: null,
          posterImage: null,
          performerName: 'Sanatçı',
          musicianProfileId: null,
          venueId: audienceVenueId,
          title: 'Canlı müzik akşamı',
          venueName: 'SoundConnect Ankara',
          eventDate: DateTime.utc(2026, 9, 9),
        )
      : null,
);

typedef AudienceWrite = ({
  EventAudienceStatus intent,
  bool published,
  String? note,
  int version,
  String user,
});

class AudienceTestRepository extends Fake implements EventAudienceRepository {
  final signal = ValueNotifier(0);
  @override
  ValueListenable<int> get changes => signal;
  final reads = <String>[];
  final writes = <AudienceWrite>[];
  EventAudienceState current = audienceState();
  Future<Result<EventAudienceState>> Function()? onRead;
  Future<Result<EventAudienceState>> Function(AudienceWrite)? onWrite;

  @override
  Future<Result<EventAudienceState>> getIntent({
    required String eventId,
    required String expectedSessionKey,
  }) {
    reads.add(expectedSessionKey);
    return onRead?.call() ?? Future.value(Result.success(current));
  }

  @override
  Future<Result<EventAudienceState>> setIntent({
    required String eventId,
    required EventAudienceStatus intent,
    required bool publishedOnProfile,
    required String? note,
    required int expectedVersion,
    required String expectedSessionKey,
  }) async {
    final request = (
      intent: intent,
      published: publishedOnProfile,
      note: note,
      version: expectedVersion,
      user: expectedSessionKey,
    );
    writes.add(request);
    if (onWrite != null) return onWrite!(request);
    current = audienceState(
      eventId: eventId,
      intent: intent,
      published: publishedOnProfile,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      version: expectedVersion + 1,
      canPublish: current.canPublish,
      ended: current.eventEnded,
      available: current.eventAvailable,
    );
    signal.value++;
    return Result.success(current);
  }
}
