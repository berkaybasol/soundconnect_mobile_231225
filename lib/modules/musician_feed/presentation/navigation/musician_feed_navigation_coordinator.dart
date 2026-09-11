import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/policy/stage_mode.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../collab/domain/entities/collab_listing.dart';
import '../../../collab/presentation/screens/collab_listing_detail_screen.dart';
import '../../../collab/presentation/theme/collab_visual_theme.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../engagement/presentation/cubit/interaction_stats_cubit.dart';
import '../../../event/data/models/discovery_event_model.dart';
import '../../../location/domain/location_repository.dart';
import '../../../overthinking/presentation/screens/overthinking_feed_screen.dart';
import '../../../overthinking/presentation/screens/overthinking_open_source.dart';
import '../../../profile/presentation/navigation/profile_route_resolver.dart';
import '../../../profile/presentation/screens/media_detail_screen.dart';
import '../../../profile/presentation/screens/musician_profile_screen.dart';
import '../../../profile/presentation/screens/video_reel_screen.dart';
import '../../../profile/presentation/screens/weekly_event_detail_screen.dart';
import '../../../tablegroup/presentation/screens/table_group_detail_screen.dart';
import '../../../tablegroup/presentation/screens/table_group_route_args.dart';
import '../../domain/musician_feed_models.dart';
import '../../domain/musician_feed_preferences_repository.dart';
import '../cubit/musician_feed_cubit.dart';
import '../widgets/musician_feed_card_registry.dart';
import '../widgets/musician_feed_content_cards.dart';
import '../widgets/musician_feed_opportunity_city_sheet.dart';

typedef MusicianFeedCollabRouteLauncher =
    Future<void> Function(
      BuildContext context, {
      required String listingId,
      required ValueChanged<CollabListing> onListingChanged,
      required VoidCallback onApplied,
    });

typedef MusicianFeedEventRouteLauncher =
    Future<void> Function(
      BuildContext context, {
      required WeeklyCalendarEvent event,
      required VoidCallback onEngagementChanged,
    });

class MusicianFeedNavigationCoordinator implements MusicianFeedNavigation {
  MusicianFeedNavigationCoordinator({
    required this.context,
    required this.cubit,
    MusicianFeedCollabRouteLauncher? collabRouteLauncher,
    MusicianFeedEventRouteLauncher? eventRouteLauncher,
  }) : _sessionFence = cubit.captureSessionFence(),
       _collabRouteLauncher = collabRouteLauncher ?? _pushCollabDetailRoute,
       _eventRouteLauncher = eventRouteLauncher ?? _pushEventDetailRoute;

  final BuildContext context;
  final MusicianFeedCubit cubit;
  final Object? _sessionFence;
  final MusicianFeedCollabRouteLauncher _collabRouteLauncher;
  final MusicianFeedEventRouteLauncher _eventRouteLauncher;

  bool get _isCurrentFeed {
    if (!context.mounted || !cubit.acceptsSessionFence(_sessionFence)) {
      return false;
    }
    try {
      return identical(context.read<MusicianFeedCubit>(), cubit);
    } catch (_) {
      return false;
    }
  }

  @override
  void recordOpen(MusicianFeedItem item) {
    if (!_isCurrentFeed) return;
    unawaited(cubit.recordEvent(item, MusicianFeedTelemetryEventType.open));
  }

  Future<void> openAuthor(
    MusicianFeedItem item,
    MusicianFeedActor author,
  ) async {
    recordOpen(item);
    await _openProfile(
      profileId: author.profileId,
      profileType: author.profileType,
    );
  }

  @override
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
  }) async {
    if (isVideo && (playbackUrl?.trim().isEmpty ?? true)) {
      _showInfo('Video şu anda oynatılamıyor.');
      return;
    }
    if (isImage && (imageUrl?.trim().isEmpty ?? true)) {
      _showInfo('Görsel şu anda açılamıyor.');
      return;
    }
    if (!_isCurrentFeed) return;
    final engagement = item.engagement;
    final targetType = engagement?.targetType ?? 'MEDIA';
    final targetId = engagement?.targetId ?? mediaId;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => serviceLocator<InteractionStatsCubit>(),
            ),
            BlocProvider(create: (_) => serviceLocator<CommentThreadCubit>()),
          ],
          child: isVideo
              ? VideoReelScreen(
                  title: title,
                  playbackUrl: playbackUrl!.trim(),
                  sourceUrl: imageUrl,
                  thumbnailUrl: thumbnailUrl,
                  targetType: targetType,
                  targetId: targetId,
                  initialLikeCount: engagement?.likeCount,
                  initialCommentCount: engagement?.commentCount,
                )
              : MediaDetailScreen(
                  title: title,
                  isVideo: false,
                  isImage: isImage,
                  playbackUrl: playbackUrl,
                  imageUrl: imageUrl,
                  thumbnailUrl: thumbnailUrl,
                  durationSeconds: durationSeconds,
                  targetType: targetType,
                  targetId: targetId,
                  likeCount: engagement?.likeCount,
                  commentCount: engagement?.commentCount,
                ),
        ),
      ),
    );
    if (_isCurrentFeed) await cubit.refresh();
  }

  @override
  Future<void> openCollab(
    MusicianFeedItem item,
    CollabFeedPayload payload,
  ) async {
    final snapshot = tryParseMusicianFeedCollab(payload.listing);
    if (snapshot == null || snapshot.id.trim().isEmpty) {
      _showInfo('Collab ilanı açılamadı.');
      return;
    }
    if (!_isCurrentFeed) return;
    CollabListing? latestAuthoritativeListing;
    await _collabRouteLauncher(
      context,
      listingId: snapshot.id,
      onListingChanged: (listing) {
        if (listing.id == snapshot.id) latestAuthoritativeListing = listing;
      },
      onApplied: () {
        if (!_isCurrentFeed) return;
        unawaited(
          cubit.recordEvent(item, MusicianFeedTelemetryEventType.apply),
        );
      },
    );
    final latest = latestAuthoritativeListing;
    if (_isCurrentFeed &&
        latest != null &&
        musicianFeedCollabStateChanged(snapshot, latest)) {
      await cubit.refresh();
    }
  }

  @override
  Future<void> openEvent(
    MusicianFeedItem item,
    EventFeedPayload payload,
  ) async {
    final event = tryParseMusicianFeedEvent(payload.event);
    if (event == null) {
      _showInfo('Etkinlik şu anda görüntülenemiyor.');
      return;
    }
    if (!_isCurrentFeed) return;
    var engagementChanged = false;
    await _eventRouteLauncher(
      context,
      event: _toWeeklyEvent(event),
      onEngagementChanged: () => engagementChanged = true,
    );
    if (_isCurrentFeed && engagementChanged) await cubit.refresh();
  }

  @override
  Future<void> openProfileShare(
    MusicianFeedItem item,
    ProfileShareFeedPayload payload,
    MusicianFeedItemType type,
  ) async {
    if (!_isCurrentFeed) return;
    if (type == MusicianFeedItemType.overthinkingProfileShare) {
      final sourceId = musicianFeedOverthinkingSourceId(payload);
      if (sourceId != null) {
        await openOverthinkingSource(context, sourceId);
        return;
      }
      await Navigator.of(context).pushNamed(
        AppRoutes.overthinkingFeed,
        arguments: const OverthinkingFeedArgs(
          bottomBarStageMode: StageMode.backstage,
        ),
      );
      return;
    }
    final tableId = _firstIdentifier(payload.source, const [
      'tableGroupId',
      'id',
    ]);
    if (tableId != null) {
      await Navigator.of(context).pushNamed(
        AppRoutes.tableGroupDetail,
        arguments: TableGroupDetailArgs(
          tableGroupId: tableId,
          bottomBarStageMode: StageMode.backstage,
        ),
      );
    } else {
      await Navigator.of(context).pushNamed(
        AppRoutes.tableGroupList,
        arguments: const TableGroupListArgs(
          bottomBarStageMode: StageMode.backstage,
        ),
      );
    }
  }

  @override
  Future<void> openProfile(ProfileFeedPayload payload) => _openProfile(
    profileId: payload.profileId,
    profileType: payload.profileType,
  );

  Future<void> _openProfile({
    required String? profileId,
    required String profileType,
  }) async {
    final id = profileId?.trim() ?? '';
    final kind = _profileKind(profileType);
    if (id.isEmpty || kind == null) {
      _showInfo('Bu profil şu anda açılamıyor.');
      return;
    }
    if (!_isCurrentFeed) return;
    final target = ProfileRouteTarget(kind: kind, id: id);
    await Navigator.of(
      context,
    ).pushNamed(target.publicRoute, arguments: target.publicArguments);
  }

  @override
  Future<void> openCompletionTask(MusicianFeedCompletionTask task) async {
    if (!_isCurrentFeed) return;
    if (task.code == 'OPPORTUNITY_CITY') {
      final changed = await showMusicianFeedOpportunityCitySheet(
        context,
        preferencesRepository:
            serviceLocator<MusicianFeedPreferencesRepository>(),
        locationRepository: serviceLocator<LocationRepository>(),
      );
      if (changed && _isCurrentFeed) await cubit.refresh();
      return;
    }
    if (musicianProfileCompletionEditorForCode(task.code) == null) {
      _showInfo('Bu profil adımı şu anda açılamıyor.');
      return;
    }
    await Navigator.of(context).pushNamed(
      AppRoutes.musicianProfile,
      arguments: MusicianProfileScreenArgs(completionTaskCode: task.code),
    );
    if (_isCurrentFeed) await cubit.refresh();
  }

  @override
  Future<void> openPromotion(
    MusicianFeedItem item, {
    SponsoredFeedPayload? payload,
  }) async {
    if (!_isCurrentFeed) return;
    final raw = payload?.ctaUrl ?? item.promotion?.ctaUrl;
    if (raw?.startsWith('/') == true) {
      final uri = Uri.tryParse(raw!);
      if (uri == null || uri.queryParameters.isNotEmpty) {
        _showInfo('Bağlantı şu anda açılamıyor.');
        return;
      }
      switch (uri.path) {
        case AppRoutes.collabDiscovery:
        case AppRoutes.eventDiscovery:
          _recordPromotionCta(item);
          await Navigator.of(context).pushNamed(uri.path);
          return;
        case AppRoutes.tableGroupList:
          _recordPromotionCta(item);
          await Navigator.of(context).pushNamed(
            AppRoutes.tableGroupList,
            arguments: const TableGroupListArgs(
              bottomBarStageMode: StageMode.backstage,
            ),
          );
          return;
        default:
          _showInfo('Bağlantı şu anda açılamıyor.');
          return;
      }
    }
    final uri = parseMusicianFeedExternalPromotionUri(raw);
    if (uri == null) {
      _showInfo('Bağlantı şu anda açılamıyor.');
      return;
    }
    _recordPromotionCta(item);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && _isCurrentFeed) _showInfo('Bağlantı açılamadı.');
    } catch (_) {
      if (_isCurrentFeed) _showInfo('Bağlantı açılamadı.');
    }
  }

  void _recordPromotionCta(MusicianFeedItem item) {
    if (!_isCurrentFeed ||
        item.promotion?.campaignId?.trim().isEmpty != false) {
      return;
    }
    unawaited(cubit.recordEvent(item, MusicianFeedTelemetryEventType.cta));
  }

  void _showInfo(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.info,
          content: Text(message),
        ),
      );
  }
}

bool musicianFeedCollabStateChanged(
  CollabListing snapshot,
  CollabListing authoritative,
) =>
    snapshot.id != authoritative.id ||
    snapshot.version != authoritative.version ||
    snapshot.status != authoritative.status ||
    snapshot.savedByMe != authoritative.savedByMe ||
    snapshot.appliedByMe != authoritative.appliedByMe ||
    snapshot.applicationCount != authoritative.applicationCount;

Uri? parseMusicianFeedExternalPromotionUri(String? raw) {
  if (raw == null) return null;
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  return uri;
}

String? musicianFeedOverthinkingSourceId(ProfileShareFeedPayload payload) =>
    _firstIdentifier(payload.source, const ['id', 'postId']);

String? _firstIdentifier(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value.length <= 128) return value;
  }
  return null;
}

ProfileRouteKind? _profileKind(String value) => switch (value.toUpperCase()) {
  'MUSICIAN' => ProfileRouteKind.musician,
  'BAND' => ProfileRouteKind.band,
  'VENUE' => ProfileRouteKind.venue,
  'STUDIO' => ProfileRouteKind.studio,
  'LISTENER' => ProfileRouteKind.listener,
  _ => null,
};

WeeklyCalendarEvent _toWeeklyEvent(DiscoveryEventModel event) {
  final date = event.eventDate?.toLocal();
  String timeLabel(TimeOfDay? time) => time == null
      ? '-'
      : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  return WeeklyCalendarEvent(
    id: event.id,
    title: event.title,
    artistName: event.performerName,
    artistProfileId: event.musicianProfileId,
    bandProfileId: event.bandId,
    performerType: event.performerType,
    venueName: event.venueName,
    venueId: event.venueId,
    city: event.venueCity ?? '',
    district: event.venueDistrict ?? '',
    neighborhood: event.venueNeighborhood ?? '',
    eventDate: date == null
        ? '-'
        : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}',
    startTime: timeLabel(event.startTime),
    endTime: timeLabel(event.endTime),
    imageAssetPath: event.posterImageUrl,
    description: event.description,
  );
}

Future<void> _pushCollabDetailRoute(
  BuildContext context, {
  required String listingId,
  required ValueChanged<CollabListing> onListingChanged,
  required VoidCallback onApplied,
}) => Navigator.of(context).push<void>(
  collabPageRoute(
    builder: (_) => CollabListingDetailScreen(
      listingId: listingId,
      showBottomNavigation: false,
      onListingChanged: onListingChanged,
      onApplied: onApplied,
    ),
  ),
);

Future<void> _pushEventDetailRoute(
  BuildContext context, {
  required WeeklyCalendarEvent event,
  required VoidCallback onEngagementChanged,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => WeeklyEventDetailScreen(
      event: event,
      onEngagementChanged: onEngagementChanged,
    ),
  ),
);
