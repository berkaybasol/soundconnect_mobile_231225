import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../../../core/audio/audio_player_handler.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../../shared/widgets/brand_gradient_icon.dart';
import '../../../../shared/widgets/event_poster_fallback.dart';
import '../../../../shared/widgets/waveform_stub.dart';
import '../../../collab/data/models/collab_api_models.dart';
import '../../../collab/domain/collab_discovery_models.dart';
import '../../../collab/domain/entities/collab_listing.dart';
import '../../../collab/presentation/widgets/collab_discovery_widgets.dart';
import '../../../event/data/models/discovery_event_model.dart';
import '../../../event/domain/entities/discovery_event.dart';
import '../../domain/musician_feed_models.dart';
import 'musician_feed_card_chrome.dart';
import 'musician_feed_card_registry.dart';

Widget buildTrackFeedCard(
  BuildContext context,
  MusicianFeedItem item,
  MusicianFeedCardActions actions,
) {
  final payload = item.payload as TrackFeedPayload;
  return MusicianFeedSurface(
    item: item,
    actions: actions,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FeedTitle(title: payload.title),
        if (payload.bpm != null) ...[
          const SizedBox(height: 4),
          Text(
            '${payload.bpm} BPM',
            style: _mutedStyle(context, fontSize: 11.5),
          ),
        ],
        const SizedBox(height: 12),
        _FeedAudioPreview(
          mediaId: payload.mediaAssetId,
          title: payload.title,
          playbackUrl: payload.playbackUrl,
          durationSeconds: payload.durationSeconds,
        ),
      ],
    ),
  );
}

Widget buildProfileMediaFeedCard(
  BuildContext context,
  MusicianFeedItem item,
  MusicianFeedCardActions actions,
) {
  final payload = item.payload as ProfileMediaFeedPayload;
  final title = payload.title?.trim();
  final description = payload.description?.trim();
  final isAudio = payload.kind == 'AUDIO';
  final isVideo = payload.kind == 'VIDEO';
  return MusicianFeedSurface(
    item: item,
    actions: actions,
    onTap: isAudio ? null : () => actions.openItem(item),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null && title.isNotEmpty) ...[
          _FeedTitle(title: title),
          const SizedBox(height: 10),
        ],
        if (isAudio)
          _FeedAudioPreview(
            mediaId: payload.mediaAssetId,
            title: title?.isNotEmpty == true ? title! : 'Ses kaydı',
            playbackUrl: payload.playbackUrl,
            durationSeconds: payload.durationSeconds,
          )
        else
          _FeedVisualMedia(payload: payload, isVideo: isVideo),
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 11),
          Text(
            description,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, height: 1.42),
          ),
        ],
      ],
    ),
  );
}

Widget buildCollabFeedCard(
  BuildContext context,
  MusicianFeedItem item,
  MusicianFeedCardActions actions,
) {
  final payload = item.payload as CollabFeedPayload;
  final listing = tryParseMusicianFeedCollab(payload.listing);
  if (listing == null) {
    return _unavailableCard(context, item, actions, label: 'Collab ilanı');
  }
  final cardModel = _toDiscoveryListing(
    listing,
    highlighted: item.promotion?.disclosure.trim().toUpperCase() == 'FEATURED',
  );
  return MusicianFeedSurface(
    item: item,
    actions: actions,
    showAuthor: false,
    contentPadding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
    child: CollabListingCard(
      listing: cardModel,
      saved: listing.savedByMe,
      onTap: () => actions.openItem(item),
      onSave: () => actions.toggleCollabSaved(item, !listing.savedByMe),
    ),
  );
}

Widget buildEventFeedCard(
  BuildContext context,
  MusicianFeedItem item,
  MusicianFeedCardActions actions,
) {
  final payload = item.payload as EventFeedPayload;
  final event = tryParseMusicianFeedEvent(payload.event);
  if (event == null) {
    return _unavailableCard(context, item, actions, label: 'Etkinlik');
  }
  return MusicianFeedSurface(
    item: item,
    actions: actions,
    onTap: () => actions.openItem(item),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (payload.note?.trim().isNotEmpty == true) ...[
          Text(
            payload.note!.trim(),
            style: const TextStyle(fontSize: 13.5, height: 1.42),
          ),
          const SizedBox(height: 13),
        ],
        _EventPreview(event: event),
      ],
    ),
  );
}

/// Feed envelopes are versioned independently from their reused module
/// payloads. A stale or malformed nested projection must disable only that
/// card, never the entire infinite list.
CollabListing? tryParseMusicianFeedCollab(Object? json) {
  if (json is! Map) return null;
  try {
    return CollabListingModel.fromJson(Map<String, dynamic>.from(json));
  } catch (_) {
    return null;
  }
}

/// See [tryParseMusicianFeedCollab]. Event discovery's legacy decoder is
/// intentionally tolerant, so validate the identity and time fields that its
/// fallbacks would otherwise turn into a misleading, tappable card.
DiscoveryEventModel? tryParseMusicianFeedEvent(Object? json) {
  if (json is! Map) return null;
  try {
    final map = Map<String, dynamic>.from(json);
    if (!_nonBlankWireText(map['id']) ||
        !_nonBlankWireText(map['title']) ||
        !_validWireTime(map['startTime']) ||
        !_validWireTime(map['endTime'])) {
      return null;
    }
    final event = DiscoveryEventModel.fromJson(map);
    return event.id.trim().isEmpty || event.title.trim().isEmpty ? null : event;
  } catch (_) {
    return null;
  }
}

Widget buildProfileShareFeedCard(
  BuildContext context,
  MusicianFeedItem item,
  MusicianFeedCardActions actions,
) {
  final payload = item.payload as ProfileShareFeedPayload;
  final overthinking =
      item.type == MusicianFeedItemType.overthinkingProfileShare;
  final source = payload.source;
  final title = _firstText(source, const [
    'title',
    'topic',
    'name',
    'venueName',
  ]);
  final body = _firstText(source, const [
    'content',
    'text',
    'body',
    'description',
    'message',
    'note',
  ]);
  return MusicianFeedSurface(
    item: item,
    actions: actions,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (payload.note?.trim().isNotEmpty == true) ...[
          Text(
            payload.note!.trim(),
            style: const TextStyle(fontSize: 13.5, height: 1.42),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  BrandGradientIcon.social(
                    overthinking
                        ? Icons.psychology_alt_outlined
                        : Icons.table_restaurant_outlined,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      overthinking ? 'Overthinking' : 'TableGroup',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (title != null) ...[
                const SizedBox(height: 11),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              if (body != null) ...[
                const SizedBox(height: 8),
                Text(
                  body,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    height: 1.42,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => actions.openItem(item),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          overthinking ? 'Overthinking’e git' : 'Masaya git',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget buildProfileFeedCard(
  BuildContext context,
  MusicianFeedItem item,
  MusicianFeedCardActions actions,
) {
  final payload = item.payload as ProfileFeedPayload;
  return MusicianFeedSurface(
    item: item,
    actions: actions,
    showAuthor: false,
    onTap: () => actions.openItem(item),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _ProfileAvatar(
              imageUrl: payload.avatarUrl,
              displayName: payload.displayName,
              size: 60,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payload.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _profileTypeLabel(payload.profileType),
                    style: _mutedStyle(context, fontSize: 11.5),
                  ),
                  if (payload.location?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 15),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            payload.location!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _mutedStyle(context, fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (payload.bio?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 7),
                    Text(
                      payload.bio!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, height: 1.35),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const BrandGradientIcon.social(
              Icons.chevron_right_rounded,
              size: 25,
            ),
          ],
        ),
        if (_supportsProfileFollow(payload)) ...[
          const SizedBox(height: 9),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: payload.followedByViewer
                  ? null
                  : () => actions.followProfile(item),
              icon: Icon(
                payload.followedByViewer
                    ? Icons.check_rounded
                    : Icons.person_add_alt_1_rounded,
                size: 18,
              ),
              label: Text(
                payload.followedByViewer ? 'Takip ediliyor' : 'Takip et',
              ),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

Widget buildActivityFeedCard(
  BuildContext context,
  MusicianFeedItem item,
  MusicianFeedCardActions actions,
) {
  final payload = item.payload as ActivityFeedPayload;
  return MusicianFeedSurface(
    item: item,
    actions: actions,
    // Activity author is the social actor, not necessarily the owner of the
    // liked/commented target. The reason row identifies that actor safely.
    showAuthor: false,
    onTap: () => actions.openItem(item),
    child: _ActivityTargetPreview(payload: payload),
  );
}

class _FeedVisualMedia extends StatelessWidget {
  const _FeedVisualMedia({required this.payload, required this.isVideo});

  final ProfileMediaFeedPayload payload;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    final url = isVideo
        ? (payload.thumbnailUrl ?? payload.displayUrl)
        : (payload.displayUrl ?? payload.thumbnailUrl);
    final aspectRatio = _safeAspectRatio(payload.width, payload.height);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppCachedNetworkImage(
              imageUrl: url,
              cacheWidth: 1080,
              placeholderBuilder: (_) => const _MediaFallback(),
              errorBuilder: (_) => const _MediaFallback(),
            ),
            if (isVideo)
              ColoredBox(
                color: AppColors.pureBlack.withValues(alpha: .16),
                child: Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.navBlueDeep.withValues(alpha: .88),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Center(
                      child: BrandGradientIcon.social(
                        Icons.play_arrow_rounded,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeedAudioPreview extends StatelessWidget {
  const _FeedAudioPreview({
    required this.mediaId,
    required this.title,
    required this.playbackUrl,
    required this.durationSeconds,
  });

  final String mediaId;
  final String title;
  final String? playbackUrl;
  final int? durationSeconds;

  @override
  Widget build(BuildContext context) {
    final handler = serviceLocator<AudioHandler>();
    final positionStream = handler is AudioPlayerHandler
        ? handler.positionStream
        : const Stream<Duration>.empty();
    return StreamBuilder<MediaItem?>(
      stream: handler.mediaItem,
      initialData: handler.mediaItem.value,
      builder: (context, mediaSnapshot) {
        final current = mediaSnapshot.data;
        final isCurrent = current?.id == mediaId;
        return StreamBuilder<PlaybackState>(
          stream: handler.playbackState,
          initialData: handler.playbackState.value,
          builder: (context, playbackSnapshot) {
            final playing =
                isCurrent && (playbackSnapshot.data?.playing ?? false);
            return StreamBuilder<Duration>(
              stream: positionStream,
              builder: (context, positionSnapshot) {
                final duration = Duration(
                  seconds: durationSeconds ?? current?.duration?.inSeconds ?? 0,
                );
                final progress = isCurrent && duration.inMilliseconds > 0
                    ? (positionSnapshot.data?.inMilliseconds ?? 0) /
                          duration.inMilliseconds
                    : 0.0;
                return WaveformStub(
                  height: 78,
                  waveformHeight: 42,
                  leadingSize: 44,
                  samples: WaveformStub.samplesFromSeed(mediaId),
                  isPlaying: playing,
                  progress: progress.clamp(0.0, 1.0),
                  leading: IconButton(
                    onPressed: playbackUrl == null
                        ? null
                        : () => _toggleAudio(
                            context,
                            handler: handler,
                            isCurrent: isCurrent,
                            isPlaying: playing,
                          ),
                    tooltip: playing ? 'Duraklat' : 'Çal',
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 23,
                    ),
                  ),
                  onSeek: isCurrent && duration.inMilliseconds > 0
                      ? (ratio) => unawaited(
                          handler.seek(
                            Duration(
                              milliseconds: (duration.inMilliseconds * ratio)
                                  .round(),
                            ),
                          ),
                        )
                      : null,
                  footer: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        _durationLabel(duration),
                        style: _mutedStyle(context, fontSize: 10.5),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _toggleAudio(
    BuildContext context, {
    required AudioHandler handler,
    required bool isCurrent,
    required bool isPlaying,
  }) async {
    try {
      if (isCurrent) {
        await (isPlaying ? handler.pause() : handler.play());
        return;
      }
      if (handler is! AudioPlayerHandler || playbackUrl == null) return;
      await handler.playUrl(
        playbackUrl!,
        title: title,
        mediaId: mediaId,
        duration: durationSeconds == null
            ? null
            : Duration(seconds: durationSeconds!),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.error,
          content: const Text('Ses kaydı oynatılamadı.'),
        ),
      );
    }
  }
}

class _EventPreview extends StatelessWidget {
  const _EventPreview({required this.event});
  final DiscoveryEvent event;

  @override
  Widget build(BuildContext context) {
    final location = [
      event.venueDistrict,
      event.venueCity,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' · ');
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 154,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppCachedNetworkImage(
                  imageUrl: event.posterImageUrl,
                  cacheWidth: 1080,
                  placeholderBuilder: (_) =>
                      EventPosterFallback(title: event.title),
                  errorBuilder: (_) => EventPosterFallback(title: event.title),
                ),
                Positioned(
                  left: 12,
                  bottom: 11,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.navBlueDeep.withValues(alpha: .92),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _eventDateLabel(event),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _FeedTitle(title: event.title)),
                    const SizedBox(width: 8),
                    const BrandGradientIcon.social(
                      Icons.chevron_right_rounded,
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _IconMeta(
                  icon: Icons.music_note_rounded,
                  text: event.performerName,
                ),
                const SizedBox(height: 8),
                _IconMeta(
                  icon: Icons.location_on_outlined,
                  text: location.isEmpty
                      ? event.venueName
                      : '${event.venueName} · $location',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTargetPreview extends StatelessWidget {
  const _ActivityTargetPreview({required this.payload});
  final ActivityFeedPayload payload;

  @override
  Widget build(BuildContext context) {
    final target = payload.targetPayload;
    final (icon, eyebrow, title, subtitle) = switch (target) {
      TrackFeedPayload value => (
        Icons.graphic_eq_rounded,
        'Parça',
        value.title,
        value.bpm == null ? null : '${value.bpm} BPM',
      ),
      ProfileMediaFeedPayload value => (
        value.kind == 'VIDEO'
            ? Icons.play_circle_outline_rounded
            : Icons.photo_outlined,
        'Medya',
        value.title ?? 'Yeni paylaşım',
        value.description,
      ),
      CollabFeedPayload value => (
        Icons.handshake_outlined,
        'Collab',
        _nestedText(value.listing, 'title') ?? 'Collab ilanı',
        _nestedText(value.listing, 'description'),
      ),
      EventFeedPayload value => (
        Icons.event_outlined,
        'Etkinlik',
        _nestedText(value.event, 'title') ?? 'Etkinlik',
        _nestedText(value.event, 'venueName'),
      ),
      ProfileShareFeedPayload value => (
        Icons.forum_outlined,
        'Profil paylaşımı',
        _firstText(value.source, const ['title', 'topic', 'name']) ??
            'Yeni paylaşım',
        _firstText(value.source, const ['content', 'text', 'description']),
      ),
      ProfileFeedPayload value => (
        Icons.person_outline_rounded,
        _profileTypeLabel(value.profileType),
        value.displayName,
        value.bio ?? value.location,
      ),
      SponsoredFeedPayload value => (
        Icons.campaign_outlined,
        'Sponsorlu',
        value.title,
        value.body,
      ),
      _ => (Icons.auto_awesome_rounded, 'SoundConnect', 'Yeni aktivite', null),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.navBlue,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(child: BrandGradientIcon.social(icon, size: 21)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _mutedStyle(context, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 22),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.imageUrl,
    required this.displayName,
    required this.size,
  });
  final String? imageUrl;
  final String displayName;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => ColoredBox(
      color: AppColors.navBlueSoft,
      child: Center(
        child: Text(
          displayName.trim().isEmpty
              ? '?'
              : displayName.trim().characters.first.toUpperCase(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: AppColors.brandGradient),
      ),
      child: ClipOval(
        child: AppCachedNetworkImage(
          imageUrl: imageUrl,
          width: size,
          height: size,
          cacheWidth: (size * 3).round(),
          cacheHeight: (size * 3).round(),
          placeholderBuilder: (_) => fallback(),
          errorBuilder: (_) => fallback(),
        ),
      ),
    );
  }
}

class _FeedTitle extends StatelessWidget {
  const _FeedTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    maxLines: 3,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      fontSize: 18,
      height: 1.22,
      fontWeight: FontWeight.w900,
    ),
  );
}

class _IconMeta extends StatelessWidget {
  const _IconMeta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      BrandGradientIcon.social(icon, size: 17),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          text.trim().isEmpty ? 'Belirtilmemiş' : text.trim(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _MediaFallback extends StatelessWidget {
  const _MediaFallback();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.navBlueSoft,
    child: const Center(
      child: BrandGradientIcon.social(Icons.image_outlined, size: 38),
    ),
  );
}

Widget _unavailableCard(
  BuildContext context,
  MusicianFeedItem item,
  MusicianFeedCardActions actions, {
  required String label,
}) => MusicianFeedSurface(
  item: item,
  actions: actions,
  child: Row(
    children: [
      const Icon(Icons.info_outline_rounded),
      const SizedBox(width: 10),
      Expanded(child: Text('$label şu anda görüntülenemiyor.')),
    ],
  ),
);

CollabDiscoveryListing _toDiscoveryListing(
  CollabListing listing, {
  required bool highlighted,
}) => CollabDiscoveryListing(
  id: listing.id,
  ownerName: listing.publisher.displayName,
  ownerInitials: listing.publisher.initials,
  profileKind: listing.publisher.profileType,
  wantedKind: listing.wantedType,
  avatarUrl: listing.publisher.avatarUrl,
  title: listing.title,
  cadence: listing.cadence,
  location: listing.city.name,
  role: listing.specialtyLabel ?? '',
  scheduledAt: listing.scheduledAt,
  feeAmountMinor: listing.feeAmountMinor,
  feeCurrency: listing.currency,
  isHighlighted: highlighted,
);

double _safeAspectRatio(int? width, int? height) {
  if (width == null || height == null || width <= 0 || height <= 0) {
    return 16 / 10;
  }
  return (width / height).clamp(.8, 1.8);
}

String _durationLabel(Duration value) {
  if (value <= Duration.zero) return '--:--';
  final minutes = value.inMinutes;
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _eventDateLabel(DiscoveryEvent event) {
  final date = event.eventDate;
  final time = event.startTime;
  final parts = <String>[];
  if (date != null) {
    parts.add(
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}',
    );
  }
  if (time != null) {
    parts.add(
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
    );
  }
  return parts.isEmpty ? 'Tarih açıklamada' : parts.join(' · ');
}

String? _firstText(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

String? _nestedText(Map<String, dynamic> source, String key) {
  final value = source[key];
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

bool _nonBlankWireText(Object? value) =>
    value is String && value.trim().isNotEmpty;

bool _validWireTime(Object? value) {
  if (value == null) return true;
  if (value is! String) return false;
  final pieces = value.trim().split(':');
  if (pieces.length < 2) return false;
  final hour = int.tryParse(pieces[0]);
  final minute = int.tryParse(pieces[1]);
  return hour != null &&
      minute != null &&
      hour >= 0 &&
      hour <= 23 &&
      minute >= 0 &&
      minute <= 59;
}

TextStyle _mutedStyle(BuildContext context, {required double fontSize}) =>
    TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: fontSize,
      height: 1.35,
    );

String _profileTypeLabel(String value) => switch (value.toUpperCase()) {
  'MUSICIAN' => 'Müzisyen',
  'BAND' => 'Grup',
  'VENUE' => 'Mekân',
  'STUDIO' => 'Stüdyo',
  'LISTENER' => 'Dinleyici',
  _ => 'SoundConnect profili',
};

bool _supportsProfileFollow(ProfileFeedPayload payload) =>
    payload.profileType == 'BAND' ||
    (const {
          'MUSICIAN',
          'LISTENER',
          'STUDIO',
          'VENUE',
        }.contains(payload.profileType) &&
        payload.userId?.trim().isNotEmpty == true);
