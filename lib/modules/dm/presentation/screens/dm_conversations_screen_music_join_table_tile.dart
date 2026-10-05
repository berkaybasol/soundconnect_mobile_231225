part of 'dm_conversations_screen.dart';

class _MusicJoinTableTile extends StatelessWidget {
  final TableGroup table;
  final VoidCallback onTap;

  const _MusicJoinTableTile({required this.table, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette colors when the theme changes.
    final ownerName = (table.ownerUsername ?? '').trim();
    final subtitle = ownerName.isNotEmpty ? ownerName : 'Masa sahibi';
    final avatar = table.ownerProfileImageUrl?.trim();
    final hasAvatar =
        avatar != null &&
        (avatar.startsWith('http://') || avatar.startsWith('https://'));
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.outline),
          ),
          child: Row(
            children: [
              DmAvatar(
                size: 50,
                imageUrl: hasAvatar ? avatar : null,
                fallbackText: ownerName,
                fallbackIcon: Icons.groups_2_outlined,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dmMusicJoinTableTitle(table),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ),
                        if (table.isOwnerGhost) ...[
                          const SizedBox(width: 7),
                          const GhostProfileBadge(),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _participantSummary(table),
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.outline),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _participantSummary(TableGroup table) {
    final accepted = table.participants
        .where((p) => p.status == TableGroupParticipantStatus.accepted)
        .length;
    return '$accepted/${table.maxPersonCount} kisi';
  }
}

class _FailureState extends StatelessWidget {
  _FailureState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.outline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DmGradientIconPanel(icon: Icons.wifi_off_rounded, size: 62),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DmGradientIconPanel(icon: Icons.forum_outlined),
          const SizedBox(height: 18),
          const Text(
            'Henüz konuşma yok',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yukarıdaki aramadan bağlantı kurmak istediğin kişiyi bul ve ilk mesajını gönder.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _MusicJoinEmptyState extends StatelessWidget {
  const _MusicJoinEmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DmGradientIconPanel(icon: Icons.groups_2_outlined),
          const SizedBox(height: 18),
          const Text(
            'Şimdilik aktif masa yok',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yeni bir Müzik Birleştirir! masası açıldığında burada göreceksin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.45),
          ),
        ],
      ),
    );
  }
}

enum _DmSearchEntryType { musician, venue }

class _DmSearchEntry {
  final _DmSearchEntryType type;
  final String referenceId;
  final String title;
  final String subtitle;
  final String? imageUrl;

  _DmSearchEntry({
    required this.type,
    required this.referenceId,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
  });

  _DmSearchEntry copyWith({String? imageUrl, String? subtitle}) {
    return _DmSearchEntry(
      type: type,
      referenceId: referenceId,
      title: title,
      subtitle: subtitle ?? this.subtitle,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  factory _DmSearchEntry.fromMusician(MusicianSearchOption item) {
    final title = item.displayName.trim().isNotEmpty
        ? item.displayName.trim()
        : 'Muzisyen';
    final rawSecondary = (item.secondaryLabel ?? '').trim();
    return _DmSearchEntry(
      type: _DmSearchEntryType.musician,
      referenceId: item.profileId,
      title: title,
      subtitle: rawSecondary.isNotEmpty ? rawSecondary : 'Muzisyen',
      imageUrl: item.profilePictureUrl,
    );
  }

  factory _DmSearchEntry.fromVenue(VenueOption item, {String? imageOverride}) {
    final title = item.name.trim().isNotEmpty ? item.name.trim() : 'Mekan';
    final city = (item.cityName ?? '').trim();
    final district = (item.districtName ?? '').trim();
    final location = [
      district,
      city,
    ].where((part) => part.isNotEmpty).join(', ');
    return _DmSearchEntry(
      type: _DmSearchEntryType.venue,
      referenceId: item.id,
      title: title,
      subtitle: location.isNotEmpty ? 'Mekan - $location' : 'Mekan',
      imageUrl: imageOverride,
    );
  }
}
