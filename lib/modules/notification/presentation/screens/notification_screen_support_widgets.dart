part of 'notification_screen.dart';

class _NotificationTypeIcon extends StatelessWidget {
  final AppNotification notification;
  final bool unread;

  const _NotificationTypeIcon({
    required this.notification,
    required this.unread,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _notificationAvatarUrl;
    if ((_isDmNotification ||
            _isSocialNotification ||
            _isArtistVenueNotification ||
            _isEventPerformerNotification) &&
        avatarUrl.isNotEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: unread
              ? LinearGradient(colors: AppColors.brandGradient)
              : null,
        ),
        padding: unread ? const EdgeInsets.all(2) : EdgeInsets.zero,
        child: ClipOval(
          child: Image.network(
            avatarUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallbackIcon(context),
          ),
        ),
      );
    }
    return _iconContainer(context, _iconForType);
  }

  bool get _isDmNotification {
    final module = notification.payload['module']?.toString().trim() ?? '';
    return module == 'DM' || notification.type.startsWith('DM');
  }

  bool get _isSocialNotification {
    final module = notification.payload['module']?.toString().trim() ?? '';
    return module == 'SOCIAL' || notification.type.startsWith('SOCIAL');
  }

  bool get _isArtistVenueNotification {
    final module = notification.payload['module']?.toString().trim() ?? '';
    return module == 'ARTIST_VENUE' ||
        notification.type.startsWith('ARTIST_VENUE');
  }

  bool get _isEventPerformerNotification {
    final module = notification.payload['module']?.toString().trim() ?? '';
    return module == 'EVENT_PERFORMER' ||
        notification.type.startsWith('EVENT_PERFORMER_') ||
        module == 'EVENT_VENUE' ||
        notification.type.startsWith('EVENT_VENUE_');
  }

  String get type => notification.type;

  String get _notificationAvatarUrl {
    for (final key in const [
      'actorAvatarUrl',
      'musicianProfilePictureUrl',
      'actorProfilePictureUrl',
      'actorProfilePicture',
      'senderAvatarUrl',
      'senderProfilePictureUrl',
      'senderProfilePicture',
      'applicantAvatarUrl',
      'applicantProfilePictureUrl',
      'applicantProfilePicture',
      'venueAvatarUrl',
      'venueProfilePictureUrl',
      'venueProfilePicture',
      'followerAvatarUrl',
      'followerProfilePictureUrl',
      'followerProfilePicture',
      'profilePictureUrl',
      'avatarUrl',
    ]) {
      final value = notification.payload[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  Widget _fallbackIcon(BuildContext context) {
    return _iconContainer(context, _iconForType);
  }

  IconData get _iconForType {
    return switch (type) {
      final value when value.startsWith('OVERTHINKING') =>
        Icons.psychology_alt_outlined,
      final value when value.startsWith('BAND') => Icons.album_outlined,
      final value when value.startsWith('TABLE') => Icons.groups_2_outlined,
      final value when value.startsWith('MEDIA') => Icons.play_circle_outline,
      final value when value.startsWith('DM') => Icons.forum_outlined,
      final value when value.startsWith('STUDIO') =>
        Icons.calendar_month_outlined,
      final value when value.startsWith('COLLAB') => Icons.handshake_outlined,
      final value when value.startsWith('ARTIST_VENUE') =>
        Icons.handshake_outlined,
      final value when value.startsWith('EVENT_PERFORMER') =>
        Icons.event_available_outlined,
      final value when value.startsWith('EVENT_VENUE') =>
        Icons.event_available_outlined,
      final value when value.startsWith('SOCIAL') =>
        Icons.person_add_alt_outlined,
      _ => Icons.notifications_none_outlined,
    };
  }

  Widget _iconContainer(BuildContext context, IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: unread
            ? LinearGradient(colors: AppColors.brandGradient)
            : null,
        color: unread
            ? null
            : Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Icon(
        icon,
        color: unread ? Colors.white : Theme.of(context).colorScheme.onSurface,
        size: 21,
      ),
    );
  }
}

class _SocialProfileTargetSheet extends StatelessWidget {
  final List<DmProfileTarget> items;

  const _SocialProfileTargetSheet({required this.items});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundImage: _hasImage(item.imageUrl)
                  ? NetworkImage(item.imageUrl!.trim())
                  : null,
              child: _hasImage(item.imageUrl)
                  ? null
                  : Icon(switch (item.type) {
                      DmProfileTargetType.musician =>
                        Icons.person_outline_rounded,
                      DmProfileTargetType.venue => Icons.storefront_outlined,
                      DmProfileTargetType.studio => Icons.graphic_eq_outlined,
                      DmProfileTargetType.listener => Icons.headphones_outlined,
                    }),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    item.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.isGhostListener) ...[
                  const SizedBox(width: 7),
                  GhostProfileBadge(
                    key: ValueKey('social-target-ghost-badge-${item.id}'),
                  ),
                ],
              ],
            ),
            subtitle: Text(item.type.displayLabel),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).pop(item),
          );
        },
      ),
    );
  }

  bool _hasImage(String? value) {
    final url = value?.trim() ?? '';
    return url.startsWith('http://') || url.startsWith('https://');
  }
}

class _NotificationLoadingList extends StatelessWidget {
  const _NotificationLoadingList();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
      children: [
        Icon(
          Icons.notifications_none_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 14),
        Text(
          'Bildirim yok',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
