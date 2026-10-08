part of 'feed_preview_screen.dart';

/// Registry dispatch is shared with production; only route destinations and
/// infrastructure are supplied by the isolated preview shell.
class _PreviewNavigation implements MusicianFeedNavigation {
  _PreviewNavigation(this.owner, this.context, this.registry);
  final _FeedPreviewScreenState owner;
  final BuildContext context;
  final MusicianFeedCardRegistry registry;

  @override
  void recordOpen(MusicianFeedItem item) {
    unawaited(
      owner._cubit.recordEvent(item, MusicianFeedTelemetryEventType.open),
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
    final engagement = item.engagement;
    final services = owner._services;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => services.createStatsCubit()),
            BlocProvider(create: (_) => services.createCommentsCubit()),
          ],
          child: isVideo && playbackUrl != null
              ? VideoReelScreen(
                  title: title,
                  playbackUrl: playbackUrl,
                  thumbnailUrl: thumbnailUrl,
                  targetType: engagement?.targetType ?? 'MEDIA',
                  targetId: engagement?.targetId ?? mediaId,
                  initialLikeCount: engagement?.likeCount,
                  initialCommentCount: engagement?.commentCount,
                  dataSourceFactory: owner.widget.videoDataSourceFactory,
                )
              : MediaDetailScreen(
                  title: title,
                  isVideo: false,
                  isImage: isImage,
                  playbackUrl: playbackUrl,
                  imageUrl: imageUrl,
                  thumbnailUrl: thumbnailUrl,
                  durationSeconds: durationSeconds,
                  targetType: engagement?.targetType,
                  targetId: engagement?.targetId,
                  likeCount: engagement?.likeCount,
                  commentCount: engagement?.commentCount,
                ),
        ),
      ),
    );
  }

  @override
  Future<void> openAnnouncement(
    MusicianFeedItem item,
    AnnouncementFeedPayload payload,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AnnouncementDetailScreen(
          id: payload.announcement.id,
          source: 'FEED',
          impressionToken: item.impressionToken,
          repository: owner._services.promotions,
          sessions: owner._services.sessions,
          videoDataSourceFactory: owner.widget.videoDataSourceFactory,
        ),
      ),
    );
  }

  @override
  Future<void> openProfile(ProfileFeedPayload payload) async {
    final match = owner._services.store.catalogue.where((scenario) {
      final candidate = scenario.item.payload;
      return candidate is ProfileFeedPayload &&
          candidate.profileId == payload.profileId;
    }).firstOrNull;
    owner._showCatalogue(type: 'PROFILE', query: match?.id);
  }

  @override
  Future<void> openCollab(MusicianFeedItem item, CollabFeedPayload payload) =>
      _inspect(item);
  @override
  Future<void> openEvent(MusicianFeedItem item, EventFeedPayload payload) =>
      _inspect(item);
  @override
  Future<void> openProfileShare(
    MusicianFeedItem item,
    ProfileShareFeedPayload payload,
    MusicianFeedItemType type,
  ) => _inspect(item);
  @override
  Future<void> openPromotion(
    MusicianFeedItem item, {
    SponsoredFeedPayload? payload,
  }) => _inspect(item);
  @override
  Future<void> openCompletionTask(MusicianFeedCompletionTask task) async {
    owner._showCatalogue(type: 'PROFILE_COMPLETION');
    owner._notice('Profil tamamlama kartının tüm durumları katalogda.');
  }

  Future<void> _inspect(MusicianFeedItem item) async {
    final scenario = owner._services.store.catalogue
        .where((scenario) => scenario.item.id == item.id)
        .firstOrNull;
    if (scenario == null) return;
    // Drill down to the canonical design specimen, without launching normal
    // event/collab/profile workflows backed by application data.
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (detailContext) => MusicianFeedThemeScope(
          child: Scaffold(
            appBar: AppBar(title: Text(scenario.label)),
            body: AnimatedBuilder(
              animation: owner._services.store,
              builder: (context, _) {
                final current = owner._services.store.itemById(item.id) ?? item;
                final actions = owner._actions(context, owner._cubit, registry);
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      scenario.id,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 12),
                    registry.build(
                      context,
                      current,
                      MusicianFeedCardActions(
                        openItem: (_) => owner._notice(
                          'Bu kartın ayrıntılı önizlemesindesin.',
                        ),
                        openAuthor: actions.openAuthor,
                        toggleLike: actions.toggleLike,
                        openComments: actions.openComments,
                        openLikes: actions.openLikes,
                        feedback: actions.feedback,
                        muteAuthor: actions.muteAuthor,
                        openCompletionTask: actions.openCompletionTask,
                        openPromotion: (_) =>
                            owner._notice('Sponsorlu kartın önizlemesi açık.'),
                        toggleCollabSaved: actions.toggleCollabSaved,
                        followProfile: actions.followProfile,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
