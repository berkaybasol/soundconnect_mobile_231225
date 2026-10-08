part of 'feed_preview_screen.dart';

extension _PreviewActions on _FeedPreviewScreenState {
  bool _isLoaded(MusicianFeedItem item) =>
      _cubit.state.items.any((row) => row.id == item.id);

  MusicianFeedCardActions _actions(
    BuildContext context,
    MusicianFeedCubit cubit,
    MusicianFeedCardRegistry registry,
  ) {
    final navigation = _PreviewNavigation(this, context, registry);
    return MusicianFeedCardActions(
      openItem: (item) => unawaited(registry.open(navigation, item)),
      openAuthor: (item, author) => _showAuthor(author),
      toggleLike: (item) => unawaited(_toggleLike(item)),
      openComments: (item) => unawaited(_openComments(item)),
      openLikes: (item) => unawaited(_openLikes(item)),
      feedback: (item, action) => unawaited(_feedback(item, action)),
      muteAuthor: (item, author) => unawaited(_mute(item, author)),
      openCompletionTask: (task) =>
          unawaited(navigation.openCompletionTask(task)),
      openPromotion: (item) =>
          unawaited(registry.openPromotion(navigation, item)),
      toggleCollabSaved: (item, saved) => unawaited(_save(item, saved)),
      followProfile: (item) => unawaited(_follow(item)),
    );
  }

  Future<void> _toggleLike(MusicianFeedItem item) async {
    if (_isLoaded(item)) {
      await _cubit.toggleLike(item.id);
      return;
    }
    final current = _services.store.itemById(item.id) ?? item;
    final engagement = current.engagement;
    if (engagement == null || !engagement.likable) return;
    final result = engagement.likedByMe
        ? await _services.engagement.unlike(
            targetType: engagement.targetType,
            targetId: engagement.targetId,
          )
        : await _services.engagement.like(
            targetType: engagement.targetType,
            targetId: engagement.targetId,
          );
    if (!result.isSuccess) _notice(result.error!.message);
  }

  Future<void> _save(MusicianFeedItem item, bool saved) async {
    if (_isLoaded(item)) {
      await _cubit.toggleCollabSaved(item.id, saved);
      return;
    }
    final payload = item.payload;
    if (payload is! CollabFeedPayload) return;
    final id = payload.listing['id'] as String;
    final result = saved
        ? await _services.collab.saveListing(id)
        : await _services.collab.unsaveListing(id);
    if (!result.isSuccess) _notice(result.error!.message);
  }

  Future<void> _follow(MusicianFeedItem item) async {
    if (_isLoaded(item)) {
      await _cubit.followProfile(item.id);
      return;
    }
    final payload = item.payload;
    if (payload is! ProfileFeedPayload) return;
    final result = payload.profileType == 'BAND'
        ? await _services.bandFollow.followBand(payload.profileId)
        : await _services.follow.follow(
            followerId: _services.sessions.session.userId!,
            followingId: payload.userId!,
          );
    if (!result.isSuccess) _notice(result.error!.message);
  }

  Future<void> _feedback(
    MusicianFeedItem item,
    MusicianFeedFeedbackAction action,
  ) async {
    if (action == MusicianFeedFeedbackAction.report) {
      _notice(
        'Bildirimi önizlemede denedin. Gerçek bir bildirim gönderilmedi.',
      );
      return;
    }
    if (_isLoaded(item)) {
      await _cubit.dismiss(item.id, action);
    } else {
      await _services.feed.sendFeedback(
        itemId: item.id,
        impressionToken: item.impressionToken,
        action: action,
      );
    }
    _notice(
      item.type == MusicianFeedItemType.announcement
          ? 'Duyuru akışta gizlendi. Tüm duyurular içinde duruyor.'
          : 'Kart akışta gizlendi. Katalogdan incelemeye devam edebilirsin.',
    );
  }

  Future<void> _mute(MusicianFeedItem item, MusicianFeedActor author) async {
    final id = author.profileId;
    if (id == null) return;
    if (_isLoaded(item)) {
      await _cubit.muteAuthor(
        sourceItemId: item.id,
        profileType: author.profileType,
        profileId: id,
      );
    } else {
      await _services.feed.muteAuthor(
        profileType: author.profileType,
        profileId: id,
      );
    }
    _notice('${author.visibleName} akışta sessize alındı.');
  }

  Future<void> _openComments(MusicianFeedItem item) async {
    final engagement = item.engagement;
    if (engagement == null || !engagement.commentable) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => MusicianFeedThemeScope(
        child: BlocProvider(
          create: (_) => _services.createCommentsCubit(),
          child: CommentThreadSheet(
            targetType: engagement.targetType,
            targetId: engagement.targetId,
            onCommentCreated: () => _cubit.adjustCommentCount(item.id, 1),
            onCommentDeleted: () => _cubit.adjustCommentCount(item.id, -1),
          ),
        ),
      ),
    );
  }

  Future<void> _openLikes(MusicianFeedItem item) async {
    final target = musicianFeedLikeUsersTarget(item);
    if (target == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => MusicianFeedThemeScope(
        child: FractionallySizedBox(
          heightFactor: .75,
          child: LikeUsersSheet(
            targetType: target.targetType,
            targetId: target.targetId,
            repository: _services.engagement,
            sessions: _services.sessions,
          ),
        ),
      ),
    );
  }

  void _showAuthor(MusicianFeedActor author) {
    final match = _services.store.catalogue.where((scenario) {
      final payload = scenario.item.payload;
      return payload is ProfileFeedPayload &&
          payload.profileId == author.profileId &&
          payload.profileType == author.profileType;
    }).firstOrNull;
    _showCatalogue(type: 'PROFILE', query: match?.id);
  }

  Future<void> _openAnnouncements() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AnnouncementDirectoryScreen(
          repository: _services.promotions,
          sessions: _services.sessions,
          videoDataSourceFactory: widget.videoDataSourceFactory,
        ),
      ),
    );
  }
}
