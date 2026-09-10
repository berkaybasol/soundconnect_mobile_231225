part of 'overthinking_manage_screen.dart';

const _manageHeading = TextStyle(
  color: OverthinkingPalette.text,
  fontSize: 22,
  fontWeight: FontWeight.w800,
  height: 1.2,
  letterSpacing: -0.5,
);
const _manageBody = TextStyle(
  color: OverthinkingPalette.muted,
  fontSize: 13,
  height: 1.5,
);
const _manageEyebrow = TextStyle(
  color: TableGroupOverviewStyle.headingMuted,
  fontSize: 13,
  fontWeight: FontWeight.w800,
  letterSpacing: 0,
);
const _manageSheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
);

ButtonStyle _managePrimaryButton(BuildContext context) =>
    FilledButton.styleFrom(
      backgroundColor: AppColors.tableGroupApplyGreen,
      foregroundColor: AppColors.white,
      disabledBackgroundColor: OverthinkingPalette.surfaceRaised,
      disabledForegroundColor: OverthinkingPalette.muted,
      minimumSize: const Size(0, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );

ButtonStyle _manageSecondaryButton(BuildContext context) =>
    OutlinedButton.styleFrom(
      foregroundColor: OverthinkingPalette.text,
      disabledForegroundColor: OverthinkingPalette.muted,
      side: const BorderSide(color: OverthinkingPalette.border),
      minimumSize: const Size(0, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );

BoxDecoration _manageCardDecoration() => BoxDecoration(
  gradient: TableGroupOverviewStyle.cardGradient,
  borderRadius: BorderRadius.circular(12),
  border: Border.all(color: TableGroupOverviewStyle.cardBorder),
  boxShadow: TableGroupOverviewStyle.cardShadows,
);

class _ManageMetric extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final int value;
  final String label;
  const _ManageMetric({
    required this.icon,
    this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$value $label',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: iconColor ?? OverthinkingPalette.muted),
        const SizedBox(width: 5),
        Text(
          '$value',
          style: const TextStyle(
            color: OverthinkingPalette.muted,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

class _RevealRequestCard extends StatelessWidget {
  final OverthinkingRevealRequest request;
  final bool incoming;
  final bool busy;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _RevealRequestCard({
    required this.request,
    required this.incoming,
    this.busy = false,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final pending = request.status == 'PENDING';
    final date = request.createdAt?.toLocal();
    return Container(
      key: ValueKey('manage-reveal-${request.id}'),
      padding: const EdgeInsets.all(18),
      decoration: _manageCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (incoming)
            OverthinkingProfileLink(
              userId: request.requesterId,
              semanticsLabel: 'İstek gönderenin profilini görüntüle',
              child: Row(
                children: [
                  _RevealRequesterAvatar(request: request),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '@${request.requesterUsername}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: OverthinkingPalette.text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (request.isRequesterGhost) ...[
                              const SizedBox(width: 7),
                              GhostProfileBadge(
                                key: ValueKey<String>(
                                  'reveal-requester-ghost-${request.id}',
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          pending
                              ? 'Yazının ardındaki kişiyi merak ediyor.'
                              : 'Kimlik görüntüleme isteği',
                          style: _manageBody.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: OverthinkingPalette.lilac.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.north_east_rounded,
                    size: 18,
                    color: OverthinkingPalette.lilac,
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Text(
                    'Gönderdiğin kimlik isteği',
                    style: TextStyle(
                      color: OverthinkingPalette.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
            decoration: BoxDecoration(
              color: OverthinkingPalette.background.withValues(alpha: 0.6),
              border: Border(
                left: BorderSide(
                  color: OverthinkingPalette.lilac.withValues(alpha: 0.6),
                  width: 2,
                ),
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  incoming ? 'BU YAZIN İÇİN' : 'BU YAZI İÇİN',
                  style: _manageEyebrow.copyWith(
                    color: OverthinkingPalette.muted,
                    fontSize: 9,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  request.postTitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: OverthinkingPalette.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (incoming && pending) ...[
            Text(
              'Kabul ettiğinde bu kişi, bu yazıda profilini görebilir.',
              style: _manageBody.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onReject,
                    style: _manageSecondaryButton(context),
                    child: const Text('Reddet'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : onApprove,
                    style: _managePrimaryButton(context),
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: OverthinkingPalette.muted,
                            ),
                          )
                        : const Text('Kabul et'),
                  ),
                ),
              ],
            ),
          ] else ...[
            if (!incoming) ...[
              Text(switch (request.status) {
                'APPROVED' =>
                  'İsteğin kabul edildi. Yazının sahibini artık görebilirsin.',
                'REJECTED' => 'Yazının sahibi kimliğini paylaşmamayı seçti.',
                'PENDING' => 'Yazının sahibinden yanıt bekleniyor.',
                _ => 'İsteğinin durumunu buradan takip edebilirsin.',
              }, style: _manageBody.copyWith(fontSize: 12)),
              const SizedBox(height: 12),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: _StatusPill(status: request.status),
            ),
          ],
          if (date != null) ...[
            const SizedBox(height: 12),
            Text(
              '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}',
              style: const TextStyle(
                color: OverthinkingPalette.muted,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RevealRequesterAvatar extends StatelessWidget {
  final OverthinkingRevealRequest request;
  const _RevealRequesterAvatar({required this.request});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = request.requesterAvatarUrl?.trim();
    final fallback = Text(
      request.requesterUsername.trim().isEmpty
          ? '?'
          : request.requesterUsername.trim().characters.first.toUpperCase(),
      style: const TextStyle(
        color: OverthinkingPalette.lilac,
        fontWeight: FontWeight.w800,
      ),
    );
    return Container(
      key: ValueKey<String>('reveal-requester-avatar-${request.id}'),
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: OverthinkingPalette.lilac.withValues(alpha: 0.13),
        border: Border.all(
          color: OverthinkingPalette.lilac.withValues(alpha: 0.2),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: avatarUrl == null || avatarUrl.isEmpty
          ? fallback
          : Image.network(
              avatarUrl,
              width: 42,
              height: 42,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}

class _ManageMusicStrip extends StatelessWidget {
  final OverthinkingPost post;
  const _ManageMusicStrip({required this.post});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      gradient: TableGroupOverviewStyle.insetGradient,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: TableGroupOverviewStyle.insetBorder),
    ),
    child: Row(
      children: [
        _MusicThumb(post: post),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.spotifyTrackName?.trim().isNotEmpty == true
                    ? post.spotifyTrackName!
                    : 'Yazıya eşlik eden parça',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: OverthinkingPalette.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                post.spotifyArtistName?.trim().isNotEmpty == true
                    ? post.spotifyArtistName!
                    : 'Bu düşüncenin müziği',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _manageBody.copyWith(fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(
          Icons.graphic_eq_rounded,
          color: OverthinkingPalette.lilac,
          size: 20,
        ),
      ],
    ),
  );
}

class _MusicThumb extends StatelessWidget {
  final OverthinkingPost post;
  const _MusicThumb({required this.post});

  @override
  Widget build(BuildContext context) {
    final imageUrl = trustedSpotifyArtworkUrl(post.spotifyAlbumImageUrl);
    const fallback = Icon(
      Icons.music_note_rounded,
      color: OverthinkingPalette.lilac,
      size: 19,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        color: OverthinkingPalette.background,
        child: imageUrl == null || imageUrl.isEmpty
            ? fallback
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                cacheWidth: (36 * MediaQuery.devicePixelRatioOf(context))
                    .ceil(),
                cacheHeight: (36 * MediaQuery.devicePixelRatioOf(context))
                    .ceil(),
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

class _VisibilityPill extends StatelessWidget {
  final OverthinkingPost post;
  const _VisibilityPill({required this.post});
  @override
  Widget build(BuildContext context) => _ManagePill(
    icon: post.anonymous
        ? Icons.lock_outline_rounded
        : Icons.person_outline_rounded,
    text: post.anonymous ? 'Anonim' : 'Profilinle',
    color: post.anonymous
        ? OverthinkingPalette.lilac
        : OverthinkingPalette.muted,
  );
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});
  @override
  Widget build(BuildContext context) => _ManagePill(
    text: switch (status) {
      'APPROVED' => 'Kabul edildi',
      'REJECTED' => 'Reddedildi',
      'PENDING' => 'Yanıt bekliyor',
      _ => 'Durum bilinmiyor',
    },
    icon: switch (status) {
      'APPROVED' => Icons.check_rounded,
      'REJECTED' => Icons.close_rounded,
      _ => Icons.schedule_rounded,
    },
    color: switch (status) {
      'APPROVED' => AppColors.tableGroupApplyGreen,
      'REJECTED' => OverthinkingPalette.muted,
      _ => OverthinkingPalette.lilac,
    },
  );
}

class _ManagePill extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const _ManagePill({
    required this.text,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _ManageEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;
  const _ManageEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: OverthinkingPalette.surfaceRaised,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 28, color: OverthinkingPalette.lilac),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: _manageHeading.copyWith(fontSize: 21),
            ),
            const SizedBox(height: 9),
            Text(message, textAlign: TextAlign.center, style: _manageBody),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onRetry,
                style: _manageSecondaryButton(context),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Tekrar dene'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
