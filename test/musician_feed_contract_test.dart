import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_types.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/domain/band_follow_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/domain/follow_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/presentation/widgets/analytics_exposure.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/data/musician_feed_preferences_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/data/musician_feed_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_models.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_mute_changes.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_preferences.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_preferences_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/cubit/musician_feed_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/cubit/musician_feed_state.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/navigation/musician_feed_navigation_coordinator.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/screens/musician_feed_view.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/widgets/musician_feed_content_cards.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/widgets/musician_feed_card_chrome.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/widgets/musician_feed_card_registry.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/widgets/musician_feed_opportunity_city_sheet.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/city.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/location_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/musician_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';
import 'support/announcement_fixtures.dart';

part 'musician_feed_contract_test_register_musician_feed_cubit1.dart';
part 'musician_feed_contract_test_register_musician_feed_cubit2.dart';
part 'musician_feed_contract_test_register_musician_feed_cubit3.dart';
part 'musician_feed_contract_test_register_musician_feed_contract4.dart';
part 'musician_feed_contract_test_register_musician_feed_contract5.dart';

void main() {
  _registerMusicianFeedContract4();
  _registerMusicianFeedContract5();
}

MusicianFeedCardRegistry _stubCardRegistry() => MusicianFeedCardRegistry({
  for (final type in MusicianFeedItemType.values)
    type: MusicianFeedCardRegistration.presentationOnly(
      (_, item, _) =>
          SizedBox(height: 180, child: Center(child: Text(item.id))),
    ),
});

MusicianFeedCardRegistry _completionLauncherRegistry(
  MusicianFeedCompletionTask task,
) => MusicianFeedCardRegistry({
  for (final type in MusicianFeedItemType.values)
    type: MusicianFeedCardRegistration.presentationOnly(
      (_, item, actions) => type == MusicianFeedItemType.profileCompletion
          ? TextButton(
              key: const Key('open-completion-editor'),
              onPressed: () => actions.openCompletionTask(task),
              child: const Text('Düzenle'),
            )
          : SizedBox(height: 180, child: Center(child: Text(item.id))),
    ),
});

MusicianFeedItem _completionItem(MusicianFeedCompletionTask task) =>
    MusicianFeedItem(
      id: 'completion-${task.code}',
      type: MusicianFeedItemType.profileCompletion,
      payloadVersion: 1,
      occurredAt: DateTime.utc(2026, 9, 11),
      position: 0,
      impressionToken: 'delivery-token-completion-${task.code}',
      reason: const MusicianFeedReason(
        code: 'PROFILE_INCOMPLETE',
        actors: [],
        secondaryActorCount: 0,
      ),
      author: null,
      target: null,
      engagement: null,
      promotion: null,
      feedbackCapabilities: const {},
      payload: CompletionFeedPayload(completed: 0, total: 1, tasks: [task]),
    );

Map<String, dynamic> _pageJson(List<Map<String, dynamic>> items) => {
  'schemaVersion': 1,
  'algorithmVersion': 'musician-v1',
  'feedSessionId': 'session-id',
  'generatedAt': '2026-09-11T10:00:00Z',
  'items': items,
  'nextCursor': null,
  'hasMore': false,
};

Map<String, dynamic> _itemJson(
  String id,
  String type,
  Map<String, dynamic> payload, {
  bool promotion = false,
}) => {
  'id': id,
  'type': type,
  'payloadVersion': 1,
  'occurredAt': '2026-09-11T09:00:00Z',
  'position': 0,
  'impressionToken': 'delivery-token-$id',
  'reason': {
    'code': promotion ? 'SPONSORED' : 'DISCOVERY',
    'actors': const [],
    'secondaryActorCount': 0,
  },
  'author': type == 'PROFILE_COMPLETION' ? null : _authorJson(),
  'target': null,
  'engagement': null,
  'promotion': promotion
      ? {
          'campaignId': 'campaign-id',
          'disclosure': 'SPONSORED',
          'ctaLabel': 'İncele',
          'ctaUrl': '/collab',
        }
      : null,
  'feedbackCapabilities': const ['HIDE', 'SHOW_LESS', 'REPORT'],
  'payload': payload,
};

Map<String, dynamic> _authorJson() => {
  'userId': 'user-id',
  'profileId': 'profile-id',
  'profileType': 'MUSICIAN',
  'username': 'deniz',
  'displayName': 'Kullanılmayan Sahne Adı',
  'avatarUrl': null,
  'followedByViewer': true,
};

MusicianFeedPage _page(String id, {bool collab = false}) => MusicianFeedPage(
  schemaVersion: 1,
  algorithmVersion: 'musician-v1',
  feedSessionId: 'session-id',
  generatedAt: DateTime.utc(2026, 9, 11),
  items: [
    MusicianFeedItem(
      id: id,
      type: collab ? MusicianFeedItemType.collab : MusicianFeedItemType.track,
      payloadVersion: 1,
      occurredAt: DateTime.utc(2026, 9, 11),
      position: 0,
      impressionToken: 'delivery-token-$id',
      reason: const MusicianFeedReason(
        code: 'DISCOVERY',
        actors: [],
        secondaryActorCount: 0,
      ),
      author: null,
      target: null,
      engagement: collab
          ? null
          : const MusicianFeedEngagement(
              targetType: 'MEDIA',
              targetId: 'media-id',
              likeCount: 2,
              commentCount: 1,
              likedByMe: false,
              likable: true,
              commentable: true,
            ),
      promotion: null,
      feedbackCapabilities: const {
        MusicianFeedFeedbackAction.hide,
        MusicianFeedFeedbackAction.showLess,
      },
      payload: collab
          ? const CollabFeedPayload(
              listing: {'id': 'listing-id', 'savedByMe': false},
            )
          : const TrackFeedPayload(
              trackId: 'track-id',
              mediaAssetId: 'media-id',
              title: 'Parça',
              playbackUrl: null,
              durationSeconds: 120,
              bpm: null,
            ),
    ),
  ],
  nextCursor: null,
  hasMore: false,
);

MusicianFeedPage _itemsPage(
  List<MusicianFeedItem> items, {
  bool hasMore = false,
  String? nextCursor,
}) => MusicianFeedPage(
  schemaVersion: 1,
  algorithmVersion: 'musician-v1',
  feedSessionId: 'session-id',
  generatedAt: DateTime.utc(2026, 9, 11),
  items: items,
  nextCursor: nextCursor,
  hasMore: hasMore,
);

MusicianFeedItem _commentActivityItem(String id, MusicianFeedItem target) =>
    MusicianFeedItem(
      id: id,
      type: MusicianFeedItemType.activityComment,
      payloadVersion: 1,
      occurredAt: target.occurredAt,
      position: target.position + 1,
      impressionToken: 'delivery-token-$id',
      reason: target.reason,
      author: target.author,
      target: target.target,
      engagement: target.engagement,
      promotion: null,
      feedbackCapabilities: target.feedbackCapabilities,
      payload: ActivityFeedPayload(
        action: 'COMMENT',
        actor: const MusicianFeedActor(
          userId: 'commenter-user',
          profileId: 'commenter-profile',
          profileType: 'MUSICIAN',
          username: 'commenter',
          displayName: 'Commenter',
          avatarUrl: null,
          followedByViewer: true,
        ),
        targetItemType: target.type,
        targetPayload: target.payload,
      ),
    );

MusicianFeedItem _trackItem(
  String id, {
  String? authorUserId,
  String authorProfileType = 'MUSICIAN',
  String? authorProfileId,
  Set<MusicianFeedFeedbackAction> feedbackCapabilities = const {
    MusicianFeedFeedbackAction.hide,
    MusicianFeedFeedbackAction.showLess,
  },
}) => MusicianFeedItem(
  id: id,
  type: MusicianFeedItemType.track,
  payloadVersion: 1,
  occurredAt: DateTime.utc(2026, 9, 11),
  position: 0,
  impressionToken: 'delivery-token-$id',
  reason: const MusicianFeedReason(
    code: 'DISCOVERY',
    actors: [],
    secondaryActorCount: 0,
  ),
  author: authorUserId == null
      ? null
      : MusicianFeedActor(
          userId: authorUserId,
          profileId: authorProfileId ?? 'profile-$authorUserId',
          profileType: authorProfileType,
          username: authorUserId,
          displayName: authorUserId,
          avatarUrl: null,
          followedByViewer: true,
        ),
  target: null,
  engagement: const MusicianFeedEngagement(
    targetType: 'MEDIA',
    targetId: 'media-id',
    likeCount: 2,
    commentCount: 1,
    likedByMe: false,
    likable: true,
    commentable: true,
  ),
  promotion: null,
  feedbackCapabilities: feedbackCapabilities,
  payload: TrackFeedPayload(
    trackId: 'track-$id',
    mediaAssetId: 'media-$id',
    title: 'Parça $id',
    playbackUrl: null,
    durationSeconds: 120,
    bpm: null,
  ),
);

MusicianFeedItem _profileItem(
  String id, {
  required String profileType,
  required String profileId,
  required String userId,
  bool followedByViewer = false,
}) => MusicianFeedItem(
  id: id,
  type: MusicianFeedItemType.profile,
  payloadVersion: 1,
  occurredAt: DateTime.utc(2026, 9, 11),
  position: 0,
  impressionToken: 'delivery-token-$id',
  reason: const MusicianFeedReason(
    code: 'DISCOVERY',
    actors: [],
    secondaryActorCount: 0,
  ),
  author: null,
  target: MusicianFeedTarget(type: 'PROFILE', id: profileId),
  engagement: null,
  promotion: null,
  feedbackCapabilities: const {
    MusicianFeedFeedbackAction.hide,
    MusicianFeedFeedbackAction.showLess,
  },
  payload: ProfileFeedPayload(
    profileId: profileId,
    profileType: profileType,
    userId: userId,
    username: 'profile-user',
    displayName: 'Profil',
    avatarUrl: null,
    bio: null,
    location: null,
    followedByViewer: followedByViewer,
  ),
);

AudienceTestSessions _musicianSessions() => AudienceTestSessions(
  audienceSession(
    user: 'viewer-id',
    token: 'viewer-token',
    role: 'ROLE_MUSICIAN',
  ),
);

class _RecordingFeedNavigation extends Fake implements MusicianFeedNavigation {
  final recordedOpenIds = <String>[];
  final opened = <String>[];
  final promotionPayloadUrls = <String?>[];

  @override
  void recordOpen(MusicianFeedItem item) => recordedOpenIds.add(item.id);

  @override
  Future<void> openCollab(
    MusicianFeedItem item,
    CollabFeedPayload payload,
  ) async {
    opened.add('collab');
  }

  @override
  Future<void> openEvent(
    MusicianFeedItem item,
    EventFeedPayload payload,
  ) async {
    opened.add('event');
  }

  @override
  Future<void> openPromotion(
    MusicianFeedItem item, {
    SponsoredFeedPayload? payload,
  }) async {
    opened.add('promotion');
    promotionPayloadUrls.add(payload?.ctaUrl);
  }

  @override
  Future<void> openProfileShare(
    MusicianFeedItem item,
    ProfileShareFeedPayload payload,
    MusicianFeedItemType type,
  ) async {
    opened.add('share:${type.name}');
  }
}

MusicianFeedItem _registryItem({
  required String id,
  required MusicianFeedItemType type,
  required MusicianFeedPayload payload,
  MusicianFeedPromotion? promotion,
}) => MusicianFeedItem(
  id: id,
  type: type,
  payloadVersion: 1,
  occurredAt: DateTime.utc(2026, 9, 11),
  position: 0,
  impressionToken: 'delivery-token-$id',
  reason: const MusicianFeedReason(
    code: 'DISCOVERY',
    actors: [],
    secondaryActorCount: 0,
  ),
  author: null,
  target: null,
  engagement: null,
  promotion: promotion,
  feedbackCapabilities: const {},
  payload: payload,
);

MusicianFeedItem _validCollabFeedItem() => _registryItem(
  id: 'collab',
  type: MusicianFeedItemType.collab,
  payload: const CollabFeedPayload(
    listing: {
      'id': 'listing-id',
      'version': 1,
      'status': 'OPEN',
      'closureReason': null,
      'cadence': 'REGULAR',
      'wantedType': 'MUSICIAN',
      'instrument': {'id': 'bass-id', 'name': 'Bas Gitar'},
      'branch': null,
      'customSpecialty': null,
      'title': 'Bas gitarist aranıyor',
      'description': 'Haftalık sahne programı için ekip arkadaşı arıyoruz.',
      'city': {'id': 'istanbul-id', 'name': 'İstanbul'},
      'genres': ['Rock'],
      'scheduledAt': null,
      'expiresAt': '2026-10-01T12:00:00Z',
      'feeAmountMinor': null,
      'currency': null,
      'feeStatus': 'UNSPECIFIED',
      'publishedAt': '2026-09-11T10:00:00Z',
      'createdAt': '2026-09-11T09:55:00Z',
      'closedAt': null,
      'publisher': {
        'actorId': 'venue-actor-id',
        'profileType': 'VENUE',
        'sourceProfileId': 'venue-profile-id',
        'contactUserId': 'venue-user-id',
        'displayName': 'Kadıköy Sahne',
        'avatarUrl': null,
        'rating': 4.8,
        'reviewCount': 12,
        'completedJobCount': 31,
      },
      'ownedByMe': false,
      'appliedByMe': false,
      'savedByMe': false,
      'applicationCount': 2,
    },
  ),
);

class _FeedRepository extends Fake implements MusicianFeedRepository {
  final responses = <Future<Result<MusicianFeedPage>>>[];
  final loadCursors = <String?>[];
  Result<void> feedbackResult = const Result.success(null);
  Future<Result<void>>? feedbackFuture;
  Future<Result<void>>? muteFuture;
  Result<void> unmuteResult = const Result.success(null);
  final muteCalls = <MusicianFeedAuthorProfileIdentity>[];
  final unmuteCalls = <MusicianFeedAuthorProfileIdentity>[];
  final feedbackCalls =
      <
        ({
          String itemId,
          String impressionToken,
          MusicianFeedFeedbackAction action,
          String? reason,
        })
      >[];

  @override
  Future<Result<MusicianFeedPage>> load({required int limit, String? cursor}) {
    loadCursors.add(cursor);
    return responses.removeAt(0);
  }

  @override
  Future<Result<void>> sendFeedback({
    required String itemId,
    required String impressionToken,
    required MusicianFeedFeedbackAction action,
    String? reason,
  }) {
    feedbackCalls.add((
      itemId: itemId,
      impressionToken: impressionToken,
      action: action,
      reason: reason,
    ));
    return feedbackFuture ?? Future.value(feedbackResult);
  }

  final eventCalls = <({String token, MusicianFeedTelemetryEventType type})>[];

  @override
  Future<Result<void>> recordEvent({
    required String clientEventId,
    required String impressionToken,
    required MusicianFeedTelemetryEventType eventType,
    DateTime? occurredAt,
  }) async {
    eventCalls.add((token: impressionToken, type: eventType));
    return const Result.success(null);
  }

  @override
  Future<Result<void>> muteAuthor({
    required String profileType,
    required String profileId,
  }) {
    muteCalls.add((profileType: profileType, profileId: profileId));
    return muteFuture ?? Future.value(const Result.success(null));
  }

  @override
  Future<Result<void>> unmuteAuthor({
    required String profileType,
    required String profileId,
  }) async {
    unmuteCalls.add((profileType: profileType, profileId: profileId));
    return unmuteResult;
  }
}

class _EngagementRepository extends Fake implements EngagementRepository {
  Result<void> likeResult = const Result.success(null);
  Future<Result<void>>? likeFuture;
  Future<Result<void>>? unlikeFuture;
  final likeCalls = <(String, String)>[];

  @override
  Future<Result<void>> like({
    required String targetType,
    required String targetId,
  }) {
    likeCalls.add((targetType, targetId));
    return likeFuture ?? Future.value(likeResult);
  }

  @override
  Future<Result<void>> unlike({
    required String targetType,
    required String targetId,
  }) => unlikeFuture ?? Future.value(const Result.success(null));
}

class _CollabRepository extends Fake implements CollabRepository {
  Result<void> saveResult = const Result.success(null);
  Future<Result<void>>? saveFuture;
  final savedIds = <String>[];

  @override
  Future<Result<void>> saveListing(String listingId) {
    savedIds.add(listingId);
    return saveFuture ?? Future.value(saveResult);
  }

  @override
  Future<Result<void>> unsaveListing(String listingId) async =>
      const Result.success(null);
}

class _FollowRepository extends Fake implements FollowRepository {
  Future<Result<void>>? followFuture;
  Result<void> followResult = const Result.success(null);
  final followCalls = <(String, String)>[];

  @override
  Future<Result<void>> follow({
    required String followerId,
    required String followingId,
  }) {
    followCalls.add((followerId, followingId));
    return followFuture ?? Future.value(followResult);
  }
}

class _BandFollowRepository extends Fake implements BandFollowRepository {
  Future<Result<void>>? followFuture;
  Result<void> followResult = const Result.success(null);
  final followedBandIds = <String>[];

  @override
  Future<Result<void>> followBand(String bandId) {
    followedBandIds.add(bandId);
    return followFuture ?? Future.value(followResult);
  }
}

MusicianFeedPreferences _feedPreferences({
  required int version,
  required String cityId,
}) => MusicianFeedPreferences(
  contractVersion: 1,
  version: version,
  opportunityCity: MusicianFeedPreferenceCity(
    id: cityId,
    name: switch (cityId) {
      'ankara' => 'Ankara',
      'izmir' => 'İzmir',
      _ => 'İstanbul',
    },
  ),
  instruments: const [],
);

class _OpportunityCityPreferencesRepository extends Fake
    implements MusicianFeedPreferencesRepository {
  _OpportunityCityPreferencesRepository({
    required List<Result<MusicianFeedPreferences>> getResults,
    required List<Result<MusicianFeedPreferences>> updateResults,
  }) : _getResults = List.of(getResults),
       _updateResults = List.of(updateResults);

  final List<Result<MusicianFeedPreferences>> _getResults;
  final List<Result<MusicianFeedPreferences>> _updateResults;
  final updateCalls = <({String? cityId, int expectedVersion})>[];
  int getCallCount = 0;

  @override
  Future<Result<MusicianFeedPreferences>> get() async {
    getCallCount += 1;
    return _getResults.removeAt(0);
  }

  @override
  Future<Result<MusicianFeedPreferences>> updateOpportunityCity({
    required String? cityId,
    required int expectedVersion,
  }) async {
    updateCalls.add((cityId: cityId, expectedVersion: expectedVersion));
    return _updateResults.removeAt(0);
  }
}

class _OpportunityCityLocationRepository extends Fake
    implements LocationRepository {
  @override
  Future<Result<List<City>>> getCities() async => const Result.success([
    City(id: 'istanbul', name: 'İstanbul'),
    City(id: 'ankara', name: 'Ankara'),
    City(id: 'izmir', name: 'İzmir'),
  ]);
}
