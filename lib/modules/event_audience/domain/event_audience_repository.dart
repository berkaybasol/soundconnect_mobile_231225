import 'package:flutter/foundation.dart';

import '../../../core/error/result.dart';
import '../../profile/domain/entities/venue_event_detail.dart';

enum EventAudienceStatus {
  none('NONE', 'Seçim yok'),
  thinking('THINKING', 'Düşünüyorum'),
  going('GOING', 'Gidiyorum');

  const EventAudienceStatus(this.wireValue, this.label);
  final String wireValue;
  final String label;
}

enum EventAudiencePeriod { upcoming, past, all }

extension EventAudiencePeriodWire on EventAudiencePeriod {
  String get wireValue => name.toUpperCase();
}

class EventAudienceState {
  const EventAudienceState({
    required this.eventId,
    this.postId,
    required this.intent,
    required this.publishedOnProfile,
    required this.note,
    required this.version,
    required this.updatedAt,
    required this.eventAvailable,
    required this.eventEnded,
    required this.canSetIntent,
    required this.canPublish,
    required this.publicationVisible,
    required this.event,
  });

  final String eventId;

  /// Identity of this publication, independent of the underlying event.
  /// Unpublishing clears it; a later publication receives a new identity.
  final String? postId;
  final EventAudienceStatus intent;
  final bool publishedOnProfile;
  final String? note;
  final int version;
  final DateTime? updatedAt;
  final bool eventAvailable;
  final bool eventEnded;
  final bool canSetIntent;
  final bool canPublish;
  final bool publicationVisible;
  final VenueEventDetail? event;
}

class EventAudiencePost {
  const EventAudiencePost({
    required this.eventId,
    required this.postId,
    required this.intent,
    required this.note,
    required this.publishedAt,
    required this.eventEnded,
    required this.event,
  });
  final String eventId;
  final String postId;
  final EventAudienceStatus intent;
  final String? note;
  final DateTime publishedAt;
  final bool eventEnded;
  final VenueEventDetail event;
}

class EventAudiencePage<T> {
  const EventAudiencePage({
    required this.items,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.hasNext,
  });
  final List<T> items;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool hasNext;
}

abstract class EventAudienceRepository {
  ValueListenable<int> get changes;

  Future<Result<EventAudienceState>> getIntent({
    required String eventId,
    required String expectedSessionKey,
  });

  Future<Result<EventAudienceState>> setIntent({
    required String eventId,
    required EventAudienceStatus intent,
    required bool publishedOnProfile,
    required String? note,
    required int expectedVersion,
    required String expectedSessionKey,
  });

  /// Removes the publication and its note while retaining the private plan.
  Future<Result<EventAudienceState>> deletePost({
    required String postId,
    required String expectedSessionKey,
  });

  Future<Result<EventAudiencePage<EventAudienceState>>> listMine({
    required String expectedSessionKey,
    EventAudiencePeriod period = EventAudiencePeriod.upcoming,
    int page = 0,
    int size = 20,
  });

  Future<Result<EventAudiencePage<EventAudiencePost>>> listPublic(
    String listenerProfileId, {
    String? expectedSessionKey,
    EventAudiencePeriod period = EventAudiencePeriod.all,
    int page = 0,
    int size = 20,
  });
}
