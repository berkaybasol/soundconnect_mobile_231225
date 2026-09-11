import 'package:flutter/material.dart';

import '../../domain/musician_feed_models.dart';
import 'musician_feed_content_cards.dart';
import 'musician_feed_system_cards.dart';

typedef MusicianFeedCardRenderer =
    Widget Function(
      BuildContext context,
      MusicianFeedItem item,
      MusicianFeedCardActions actions,
    );

typedef MusicianFeedItemOpenHandler =
    Future<void> Function(
      MusicianFeedCardRegistry registry,
      MusicianFeedNavigation navigation,
      MusicianFeedItem item,
      MusicianFeedPayload payload,
      MusicianFeedItemType contentType,
    );

class MusicianFeedCardRegistration {
  const MusicianFeedCardRegistration({
    required this.renderer,
    required this.open,
  });

  const MusicianFeedCardRegistration.presentationOnly(this.renderer)
    : open = _doNotOpenFeedItem;

  final MusicianFeedCardRenderer renderer;
  final MusicianFeedItemOpenHandler open;
}

/// Navigation capabilities used by registered item handlers. The feed screen
/// only forwards actions to the registry; type knowledge stays in a
/// registration and its coordinator implementation.
abstract interface class MusicianFeedNavigation {
  void recordOpen(MusicianFeedItem item);

  Future<void> openMedia(
    MusicianFeedItem item, {
    required String title,
    required String? playbackUrl,
    String? imageUrl,
    String? thumbnailUrl,
    required int? durationSeconds,
    required String mediaId,
    required bool isVideo,
    required bool isImage,
  });

  Future<void> openCollab(MusicianFeedItem item, CollabFeedPayload payload);

  Future<void> openEvent(MusicianFeedItem item, EventFeedPayload payload);

  Future<void> openProfileShare(
    MusicianFeedItem item,
    ProfileShareFeedPayload payload,
    MusicianFeedItemType type,
  );

  Future<void> openProfile(ProfileFeedPayload payload);

  Future<void> openPromotion(
    MusicianFeedItem item, {
    SponsoredFeedPayload? payload,
  });

  Future<void> openCompletionTask(MusicianFeedCompletionTask task);
}

class MusicianFeedCardActions {
  const MusicianFeedCardActions({
    required this.openItem,
    required this.openAuthor,
    required this.toggleLike,
    required this.openComments,
    required this.feedback,
    required this.muteAuthor,
    required this.openCompletionTask,
    required this.openPromotion,
    required this.toggleCollabSaved,
    required this.followProfile,
  });

  final void Function(MusicianFeedItem item) openItem;
  final void Function(MusicianFeedItem item, MusicianFeedActor author)
  openAuthor;
  final void Function(MusicianFeedItem item) toggleLike;
  final void Function(MusicianFeedItem item) openComments;
  final void Function(MusicianFeedItem item, MusicianFeedFeedbackAction action)
  feedback;
  final void Function(MusicianFeedItem item, MusicianFeedActor author)
  muteAuthor;
  final void Function(MusicianFeedCompletionTask task) openCompletionTask;
  final void Function(MusicianFeedItem item) openPromotion;
  final void Function(MusicianFeedItem item, bool saved) toggleCollabSaved;
  final void Function(MusicianFeedItem item) followProfile;
}

/// Central registration point for feed cards. Adding a backend item family
/// requires its parser plus one renderer/opener registration, never a
/// feed-screen edit.
class MusicianFeedCardRegistry {
  MusicianFeedCardRegistry(
    Map<MusicianFeedItemType, MusicianFeedCardRegistration> registrations,
  ) : _registrations = Map.unmodifiable(registrations) {
    final missing = MusicianFeedItemType.values.toSet().difference(
      _registrations.keys.toSet(),
    );
    if (missing.isNotEmpty) {
      throw StateError('Missing musician feed card registrations: $missing');
    }
  }

  factory MusicianFeedCardRegistry.standard() => MusicianFeedCardRegistry({
    MusicianFeedItemType.track: const MusicianFeedCardRegistration(
      renderer: buildTrackFeedCard,
      open: _openTrack,
    ),
    MusicianFeedItemType.profileMedia: const MusicianFeedCardRegistration(
      renderer: buildProfileMediaFeedCard,
      open: _openProfileMedia,
    ),
    MusicianFeedItemType.collab: const MusicianFeedCardRegistration(
      renderer: buildCollabFeedCard,
      open: _openCollab,
    ),
    MusicianFeedItemType.event: const MusicianFeedCardRegistration(
      renderer: buildEventFeedCard,
      open: _openEvent,
    ),
    MusicianFeedItemType.eventProfileShare: const MusicianFeedCardRegistration(
      renderer: buildEventFeedCard,
      open: _openEvent,
    ),
    MusicianFeedItemType.overthinkingProfileShare:
        const MusicianFeedCardRegistration(
          renderer: buildProfileShareFeedCard,
          open: _openProfileShare,
        ),
    MusicianFeedItemType.tableGroupProfileShare:
        const MusicianFeedCardRegistration(
          renderer: buildProfileShareFeedCard,
          open: _openProfileShare,
        ),
    MusicianFeedItemType.activityFollow: const MusicianFeedCardRegistration(
      renderer: buildActivityFeedCard,
      open: _openActivity,
    ),
    MusicianFeedItemType.activityLike: const MusicianFeedCardRegistration(
      renderer: buildActivityFeedCard,
      open: _openActivity,
    ),
    MusicianFeedItemType.activityComment: const MusicianFeedCardRegistration(
      renderer: buildActivityFeedCard,
      open: _openActivity,
    ),
    MusicianFeedItemType.profile: const MusicianFeedCardRegistration(
      renderer: buildProfileFeedCard,
      open: _openProfile,
    ),
    MusicianFeedItemType.profileCompletion: const MusicianFeedCardRegistration(
      renderer: buildCompletionFeedCard,
      open: _doNotOpenFeedItem,
    ),
    MusicianFeedItemType.sponsored: const MusicianFeedCardRegistration(
      renderer: buildSponsoredFeedCard,
      open: _openPromotion,
    ),
  });

  final Map<MusicianFeedItemType, MusicianFeedCardRegistration> _registrations;

  Widget build(
    BuildContext context,
    MusicianFeedItem item,
    MusicianFeedCardActions actions,
  ) {
    final registration = _registrations[item.type];
    if (registration == null) return const SizedBox.shrink();
    return KeyedSubtree(
      key: ValueKey('musician-feed-${item.id}'),
      child: registration.renderer(context, item, actions),
    );
  }

  Future<void> open(MusicianFeedNavigation navigation, MusicianFeedItem item) {
    if (item.type != MusicianFeedItemType.sponsored) {
      navigation.recordOpen(item);
    }
    return _openPayload(navigation, item, item.payload, item.type);
  }

  Future<void> openPromotion(
    MusicianFeedNavigation navigation,
    MusicianFeedItem item,
  ) {
    final payload = item.payload;
    return navigation.openPromotion(
      item,
      payload: payload is SponsoredFeedPayload ? payload : null,
    );
  }

  Future<void> openCompletionTask(
    MusicianFeedNavigation navigation,
    MusicianFeedCompletionTask task,
  ) => navigation.openCompletionTask(task);

  Future<void> _openPayload(
    MusicianFeedNavigation navigation,
    MusicianFeedItem item,
    MusicianFeedPayload payload,
    MusicianFeedItemType type,
  ) {
    final registration = _registrations[type];
    if (registration == null) return Future<void>.value();
    return registration.open(this, navigation, item, payload, type);
  }
}

Future<void> _openTrack(
  MusicianFeedCardRegistry _,
  MusicianFeedNavigation navigation,
  MusicianFeedItem item,
  MusicianFeedPayload payload,
  MusicianFeedItemType _,
) {
  final value = payload as TrackFeedPayload;
  return navigation.openMedia(
    item,
    title: value.title,
    playbackUrl: value.playbackUrl,
    durationSeconds: value.durationSeconds,
    mediaId: value.mediaAssetId,
    isVideo: false,
    isImage: false,
  );
}

Future<void> _openProfileMedia(
  MusicianFeedCardRegistry _,
  MusicianFeedNavigation navigation,
  MusicianFeedItem item,
  MusicianFeedPayload payload,
  MusicianFeedItemType _,
) {
  final value = payload as ProfileMediaFeedPayload;
  return navigation.openMedia(
    item,
    title: value.title ?? _mediaKindLabel(value.kind),
    playbackUrl: value.playbackUrl,
    imageUrl: value.displayUrl,
    thumbnailUrl: value.thumbnailUrl,
    durationSeconds: value.durationSeconds,
    mediaId: value.mediaAssetId,
    isVideo: value.kind == 'VIDEO',
    isImage: value.kind == 'IMAGE' || value.kind == 'PHOTO',
  );
}

Future<void> _openCollab(
  MusicianFeedCardRegistry _,
  MusicianFeedNavigation navigation,
  MusicianFeedItem item,
  MusicianFeedPayload payload,
  MusicianFeedItemType _,
) => navigation.openCollab(item, payload as CollabFeedPayload);

Future<void> _openEvent(
  MusicianFeedCardRegistry _,
  MusicianFeedNavigation navigation,
  MusicianFeedItem item,
  MusicianFeedPayload payload,
  MusicianFeedItemType _,
) => navigation.openEvent(item, payload as EventFeedPayload);

Future<void> _openProfileShare(
  MusicianFeedCardRegistry _,
  MusicianFeedNavigation navigation,
  MusicianFeedItem item,
  MusicianFeedPayload payload,
  MusicianFeedItemType contentType,
) => navigation.openProfileShare(
  item,
  payload as ProfileShareFeedPayload,
  contentType,
);

Future<void> _openActivity(
  MusicianFeedCardRegistry registry,
  MusicianFeedNavigation navigation,
  MusicianFeedItem item,
  MusicianFeedPayload payload,
  MusicianFeedItemType _,
) {
  final value = payload as ActivityFeedPayload;
  return registry._openPayload(
    navigation,
    item,
    value.targetPayload,
    value.targetItemType,
  );
}

Future<void> _openProfile(
  MusicianFeedCardRegistry _,
  MusicianFeedNavigation navigation,
  MusicianFeedItem __,
  MusicianFeedPayload payload,
  MusicianFeedItemType ___,
) => navigation.openProfile(payload as ProfileFeedPayload);

Future<void> _openPromotion(
  MusicianFeedCardRegistry _,
  MusicianFeedNavigation navigation,
  MusicianFeedItem item,
  MusicianFeedPayload payload,
  MusicianFeedItemType ___,
) => navigation.openPromotion(
  item,
  payload: payload is SponsoredFeedPayload ? payload : null,
);

Future<void> _doNotOpenFeedItem(
  MusicianFeedCardRegistry _,
  MusicianFeedNavigation __,
  MusicianFeedItem ___,
  MusicianFeedPayload ____,
  MusicianFeedItemType _____,
) => Future<void>.value();

String _mediaKindLabel(String value) => switch (value.toUpperCase()) {
  'VIDEO' => 'Video',
  'IMAGE' || 'PHOTO' => 'Fotoğraf',
  'AUDIO' => 'Ses kaydı',
  _ => 'Medya',
};
