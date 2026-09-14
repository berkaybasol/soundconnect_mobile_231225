import 'backstage_feed_session.dart';
import 'musician_feed_models.dart';

bool feedSupportsItemType(
  BackstageFeedAudience audience,
  MusicianFeedItemType type,
) {
  if (!audience.supportsProfileCompletion &&
      type == MusicianFeedItemType.profileCompletion) {
    return false;
  }
  return audience != BackstageFeedAudience.listener ||
      !const {
        MusicianFeedItemType.collab,
        MusicianFeedItemType.sponsored,
      }.contains(type);
}

/// A defense for mixed/old projections. Server source eligibility remains
/// authoritative, including privacy, moderation and professional publications.
bool feedCanShowItem(BackstageFeedAudience audience, MusicianFeedItem item) {
  if (!feedSupportsItemType(audience, item.type)) return false;
  if (audience != BackstageFeedAudience.listener) return true;
  return item.promotion == null &&
      _listenerProfileType(item.author?.profileType) &&
      item.reason.actors.every(
        (actor) => _listenerProfileType(actor.profileType),
      ) &&
      _listenerPayload(item.payload);
}

bool _listenerProfileType(String? type) =>
    type == null ||
    const {
      'MUSICIAN',
      'BAND',
      'VENUE',
      'LISTENER',
    }.contains(type.trim().toUpperCase());

bool _listenerPayload(MusicianFeedPayload payload) => switch (payload) {
  CollabFeedPayload() ||
  CompletionFeedPayload() ||
  SponsoredFeedPayload() => false,
  TrackFeedPayload() => payload.contentAudience == 'MAINSTAGE',
  ProfileMediaFeedPayload() => payload.contentAudience == 'MAINSTAGE',
  ProfileFeedPayload() => _listenerProfileType(payload.profileType),
  ActivityFeedPayload() =>
    _listenerProfileType(payload.actor.profileType) &&
        feedSupportsItemType(
          BackstageFeedAudience.listener,
          payload.targetItemType,
        ) &&
        _listenerPayload(payload.targetPayload),
  ProfileShareFeedPayload() => _listenerSource(payload.source),
  EventFeedPayload() => _listenerSource(payload.event),
  AnnouncementFeedPayload() => payload.announcement.targetProfiles.contains(
    'LISTENER',
  ),
};

bool _listenerSource(Object? value) {
  if (value is List) return value.every(_listenerSource);
  if (value is! Map) return true;
  for (final entry in value.entries) {
    final field = entry.key;
    final data = entry.value;
    if (field == 'contentAudience' && data != 'MAINSTAGE') {
      return false;
    }
    if (const {
          'profileType',
          'publisherProfileType',
          'ownerProfileType',
        }.contains(field) &&
        data is String &&
        !_listenerProfileType(data)) {
      return false;
    }
    if (const {
          'type',
          'targetType',
          'targetItemType',
          'ownerType',
        }.contains(field) &&
        data is String &&
        const {
          'COLLAB',
          'COLLAB_LISTING',
          'STUDIO',
          'STUDIO_PROFILE',
          'SPONSORED',
          'PROFILE_COMPLETION',
        }.contains(data.toUpperCase())) {
      return false;
    }
    if (!_listenerSource(data)) return false;
  }
  return true;
}
