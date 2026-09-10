part of 'overthinking_feed_screen.dart';

class OverthinkingDetailScreen extends StatelessWidget {
  final OverthinkingPost post;
  final bool revealRequesting;
  const OverthinkingDetailScreen({
    super.key,
    required this.post,
    required this.revealRequesting,
  });

  Future<void> _requestReveal(
    BuildContext context,
    OverthinkingPost currentPost,
  ) async {
    final cubit = context.read<OverthinkingFeedCubit>();
    if (!cubit.canWrite ||
        cubit.state.revealRequestingIds.contains(currentPost.id)) {
      return;
    }
    var latestPost = currentPost;
    for (final item in cubit.state.posts) {
      if (item.id == currentPost.id) {
        latestPost = item;
        break;
      }
    }
    final wasPending = latestPost.revealRequestPending;
    final ok = await cubit.toggleReveal(latestPost);
    if (!context.mounted || !cubit.isSessionCurrent) return;
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        context,
        tone: ok ? AppSnackBarTone.success : AppSnackBarTone.error,
        content: Text(
          ok
              ? wasPending
                    ? 'Kimlik isteğin geri çekildi.'
                    : 'Kimlik isteğin gönderildi.'
              : cubit.state.error?.message ?? 'Kimlik isteği güncellenemedi.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: OverthinkingPalette.theme(context),
    child: Builder(
      builder: (context) => BlocBuilder<OverthinkingFeedCubit, OverthinkingFeedState>(
        builder: (context, state) {
          final cubit = context.read<OverthinkingFeedCubit>();
          if (!cubit.isSessionCurrent) {
            return const OverthinkingUnavailableScreen();
          }
          if (cubit.isPostUnavailable(post.id)) {
            return const OverthinkingUnavailableScreen(postMissing: true);
          }
          var current = post;
          for (final item in state.posts) {
            if (item.id == post.id) {
              current = item;
              break;
            }
          }
          final currentPost = current;
          final hidden = currentPost.anonymous && !currentPost.hasVisibleAuthor;
          final requesting = state.revealRequestingIds.contains(currentPost.id);
          return Scaffold(
            appBar: AppBar(
              title: const Text(
                'Overthinking',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              actions: [
                OverthinkingProfileShareButton(
                  post: currentPost,
                  enabled: cubit.canWrite,
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 20),
                  child: Icon(
                    Icons.all_inclusive_rounded,
                    color: OverthinkingPalette.lilac,
                  ),
                ),
              ],
            ),
            body: TableGroupOverviewBackdrop(
              child: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
                  children: [
                    const OverthinkingEyebrow(
                      'Overthinking',
                      color: OverthinkingPalette.accent,
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      currentPost.title,
                      style: const TextStyle(
                        fontSize: 28,
                        height: 1.18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.9,
                        color: OverthinkingPalette.text,
                      ),
                    ),
                    const SizedBox(height: 23),
                    _AuthorLine(post: currentPost),
                    const SizedBox(height: 24),
                    const Divider(height: 1, color: OverthinkingPalette.border),
                    if (_hasMusic(currentPost)) ...[
                      const SizedBox(height: 22),
                      const OverthinkingEyebrow('BU YAZIYA EŞLİK EDEN'),
                      const SizedBox(height: 12),
                      _MusicChip(
                        key: ValueKey('detail-music-${currentPost.id}'),
                        post: currentPost,
                      ),
                    ],
                    const SizedBox(height: 27),
                    SelectableText(
                      currentPost.content,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.9,
                        color: TableGroupOverviewStyle.bodyMuted,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _PostAction(
                        icon: currentPost.likedByMe
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        label: currentPost.likeCount == 0
                            ? 'İlk beğenen sen ol'
                            : '${currentPost.likeCount} beğeni',
                        tooltip: currentPost.likedByMe
                            ? 'Beğeniyi kaldır'
                            : 'Beğen',
                        active: currentPost.likedByMe,
                        onTap: () => context
                            .read<OverthinkingFeedCubit>()
                            .toggleLike(currentPost),
                      ),
                    ),
                    if (hidden) ...[
                      const SizedBox(height: 20),
                      OverthinkingSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.lock_outline_rounded,
                              color: OverthinkingPalette.lilac,
                              size: 23,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Bu satırların arkasında kim var?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: OverthinkingPalette.text,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              currentPost.revealRequestPending
                                  ? 'Yanıt bekleniyor. İsteğini geri çekmek için butona yeniden dokunabilirsin.'
                                  : 'Yazara bir kimlik isteği gönderebilirsin. İsteklerini Overthinking ana sayfasından takip et.',
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.6,
                                color: OverthinkingPalette.muted,
                              ),
                            ),
                            const SizedBox(height: 13),
                            OutlinedButton.icon(
                              key: const ValueKey('overthinking-reveal-toggle'),
                              onPressed: requesting || !cubit.canWrite
                                  ? null
                                  : () => _requestReveal(context, currentPost),
                              icon: Icon(
                                requesting
                                    ? Icons.hourglass_top_rounded
                                    : currentPost.revealRequestPending
                                    ? Icons.check_rounded
                                    : Icons.person_search_outlined,
                                size: 17,
                              ),
                              label: Text(
                                requesting
                                    ? currentPost.revealRequestPending
                                          ? 'Geri çekiliyor...'
                                          : 'Gönderiliyor...'
                                    : currentPost.revealRequestPending
                                    ? 'Kimlik isteği gönderildi'
                                    : 'Kimlik isteği gönder',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 30),
                    const Divider(height: 1, color: OverthinkingPalette.border),
                    const SizedBox(height: 25),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Yorumlar',
                            style: TextStyle(
                              color: OverthinkingPalette.text,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${currentPost.commentCount}',
                          style: const TextStyle(
                            color: OverthinkingPalette.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    CommentThreadView(
                      targetType: OverthinkingFeedCubit.targetType,
                      targetId: currentPost.id,
                      autoLoad: false,
                      onCommentCreated: () => context
                          .read<OverthinkingFeedCubit>()
                          .incrementCommentCount(currentPost.id),
                      onCommentDeleted: () => context
                          .read<OverthinkingFeedCubit>()
                          .refreshPost(currentPost.id),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
