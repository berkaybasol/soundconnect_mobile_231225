import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../../analytics/data/analytics_tracker.dart';
import '../../../analytics/presentation/widgets/analytics_exposure.dart';
import '../../../engagement/data/engagement_repository_impl.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../engagement/presentation/cubit/interaction_stats_cubit.dart';
import '../../../engagement/presentation/cubit/interaction_stats_state.dart';
import '../../../engagement/presentation/widgets/comment_thread_view.dart';
import '../../../engagement/presentation/widgets/like_users_sheet.dart';
import '../../../musician_feed/presentation/musician_feed_visual_theme.dart';
import '../../../profile/domain/media_gallery_repository.dart';
import '../../../profile/presentation/screens/video_reel_screen.dart';
import '../../domain/announcement_access.dart';
import '../../domain/entities/announcement.dart';
import '../../domain/promotion_repository.dart';
import '../widgets/announcement_content.dart';

class AnnouncementDetailScreen extends StatefulWidget {
  const AnnouncementDetailScreen({
    super.key,
    required this.id,
    this.source = 'DIRECTORY',
    this.impressionToken,
    this.repository,
    this.sessions,
    this.videoDataSourceFactory,
  });
  final String id;
  final String source;
  final String? impressionToken;
  final PromotionRepository? repository;
  final AuthSessionManager? sessions;
  final VideoReelDataSourceFactory? videoDataSourceFactory;
  @override
  State<AnnouncementDetailScreen> createState() =>
      _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  late final _sessions =
      widget.sessions ?? serviceLocator<AuthSessionManager>();
  late final AnnouncementSessionIdentity? _identity;
  late final _engagement = EngagementRepositoryImpl(
    serviceLocator<ApiClient>(),
    sessions: _sessions,
    announcementSource: widget.source,
  );
  late final _stats = InteractionStatsCubit(_engagement, sessions: _sessions);
  late final _comments = CommentThreadCubit(_engagement, sessions: _sessions);
  Announcement? _item;
  String? _error;
  bool _loading = true;
  bool _revoked = false;
  bool _openingVideo = false;
  int _epoch = 0;
  bool get _current =>
      mounted &&
      !_revoked &&
      _identity != null &&
      _identity == announcementSessionIdentity(_sessions.session);
  @override
  void initState() {
    super.initState();
    _identity = announcementSessionIdentity(_sessions.session);
    _sessions.addListener(_sessionChanged);
    unawaited(_load());
  }

  void _sessionChanged() {
    if (_identity != announcementSessionIdentity(_sessions.session)) {
      _revoked = true;
      _epoch++;
      if (mounted) {
        setState(() {
          _item = null;
          _loading = false;
          _error = 'Oturumun değişti. Sayfayı yeniden aç.';
        });
      }
    }
  }

  Future<void> _load() async {
    if (!_current) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Duyuru erişimi doğrulanamadı.';
        });
      }
      return;
    }
    final epoch = ++_epoch;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result =
        await (widget.repository ?? serviceLocator<PromotionRepository>())
            .announcement(widget.id);
    if (!_current || epoch != _epoch) return;
    final item = result.data;
    if (item != null && result.isSuccess) {
      _stats.seed(
        targetType: 'ANNOUNCEMENT',
        targetId: item.id,
        item: InteractionStatsItemState(
          loading: false,
          likeCount: item.engagement.likeCount,
          commentCount: item.engagement.commentCount,
          isLiked: item.engagement.likedByMe,
        ),
      );
    }
    setState(() {
      _loading = false;
      _item = item;
      _error = result.error?.message;
    });
  }

  void _refreshStats() => unawaited(
    _stats.load(targetType: 'ANNOUNCEMENT', targetId: widget.id, force: true),
  );
  Future<void> _openComments() async {
    if (!mounted || !_current) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(
        value: _comments,
        child: CommentThreadSheet(
          targetType: 'ANNOUNCEMENT',
          targetId: widget.id,
          onCommentCreated: _refreshStats,
          onCommentDeleted: _refreshStats,
        ),
      ),
    );
  }

  Future<void> _openLikes() async {
    if (!mounted || !_current) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: .75,
        child: LikeUsersSheet(
          targetType: 'ANNOUNCEMENT',
          targetId: widget.id,
          repository: _engagement,
          sessions: _sessions,
          isCurrent: () => _current,
        ),
      ),
    );
  }

  Future<void> _video() async {
    final item = _item;
    final media = item?.media;
    if (!_current ||
        _openingVideo ||
        item == null ||
        media == null ||
        !media.isVideo) {
      return;
    }
    setState(() => _openingVideo = true);
    try {
      final result = await serviceLocator<MediaGalleryRepository>().getAccess(
        media.assetId,
      );
      if (!mounted || !_current) return;
      final access = result.data;
      if (!result.isSuccess || access == null) {
        setState(() => _error = result.error?.message ?? 'Video açılamadı.');
        return;
      }
      final playbackId = const Uuid().v4();
      AnalyticsTracker? tracker() =>
          serviceLocator.isRegistered<AnalyticsTracker>()
          ? serviceLocator<AnalyticsTracker>()
          : null;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: _stats),
              BlocProvider.value(value: _comments),
            ],
            child: VideoReelScreen(
              looping: false,
              dataSourceFactory: widget.videoDataSourceFactory,
              title: item.title,
              playbackUrl: access.accessUrl,
              thumbnailUrl: access.thumbnailAccessUrl,
              targetType: 'ANNOUNCEMENT',
              targetId: item.id,
              initialLikeCount: item.engagement.likeCount,
              initialCommentCount: item.engagement.commentCount,
              accessChanges: _sessions,
              isPlaybackAllowed: () => _current,
              refreshPlaybackUrl: () async {
                if (!_current) return null;
                final result = await serviceLocator<MediaGalleryRepository>()
                    .getAccess(media.assetId);
                return _current && result.isSuccess
                    ? result.data?.accessUrl
                    : null;
              },
              onPlaybackStarted: () {
                if (_current) {
                  tracker()?.recordAnnouncementVideoStart(
                    announcementId: item.id,
                    source: widget.source,
                    impressionToken: widget.impressionToken,
                    playbackId: playbackId,
                  );
                }
              },
              onPlaybackCompleted: () {
                if (_current) {
                  tracker()?.recordAnnouncementVideoComplete(
                    announcementId: item.id,
                    source: widget.source,
                    impressionToken: widget.impressionToken,
                    playbackId: playbackId,
                  );
                }
              },
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingVideo = false);
    }
  }

  @override
  void dispose() {
    _epoch++;
    _sessions.removeListener(_sessionChanged);
    unawaited(_stats.close());
    unawaited(_comments.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MusicianFeedThemeScope(
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Duyuru')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _item == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error ?? 'Duyuru bulunamadı.'),
                    if (!_revoked)
                      TextButton(
                        onPressed: _load,
                        child: const Text('Yeniden dene'),
                      ),
                  ],
                ),
              )
            : AnalyticsExposure(
                key: ValueKey('announcement-detail-${widget.id}'),
                minimumVisibleDuration: Duration.zero,
                onExposed: () {
                  if (_current &&
                      serviceLocator.isRegistered<AnalyticsTracker>()) {
                    serviceLocator<AnalyticsTracker>()
                        .recordAnnouncementDetailView(
                          announcementId: widget.id,
                          source: widget.source,
                          impressionToken: widget.impressionToken,
                        );
                  }
                },
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      AnnouncementContent(
                        announcement: _item!,
                        expanded: true,
                        onPlay: _openingVideo ? null : _video,
                      ),
                      if (_openingVideo) const LinearProgressIndicator(),
                      if (_error != null) Text(_error!),
                      BlocBuilder<InteractionStatsCubit, InteractionStatsState>(
                        bloc: _stats,
                        builder: (context, state) {
                          final stats =
                              state.items['ANNOUNCEMENT:${widget.id}'];
                          return Column(
                            children: [
                              Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  IconButton(
                                    tooltip: stats?.isLiked == true
                                        ? 'Beğeniyi kaldır'
                                        : 'Beğen',
                                    onPressed:
                                        stats?.loading == true || !_current
                                        ? null
                                        : () => _stats.toggleLike(
                                            targetType: 'ANNOUNCEMENT',
                                            targetId: widget.id,
                                          ),
                                    icon: Icon(
                                      stats?.isLiked == true
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _openLikes,
                                    child: Text(
                                      '${stats?.visibleLikeCount ?? '—'} beğeni',
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _openComments,
                                    icon: const Icon(Icons.chat_bubble_outline),
                                    label: Text(
                                      '${stats?.visibleCommentCount ?? '—'} yorum',
                                    ),
                                  ),
                                ],
                              ),
                              if (stats?.error != null)
                                Text(stats!.error!.message),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
      ),
    ),
  );
}
