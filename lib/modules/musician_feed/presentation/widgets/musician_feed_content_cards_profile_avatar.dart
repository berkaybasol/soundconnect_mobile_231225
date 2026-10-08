part of 'musician_feed_content_cards.dart';

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
    Theme.of(context); // Rebuild palette colors when the theme changes.
    Widget fallback() => ColoredBox(
      color: AppColors.isLight
          ? AppColors.avatarBackground
          : Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Center(
        child: Text(
          displayName.trim().isEmpty
              ? '?'
              : displayName.trim().characters.first.toUpperCase(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.isLight ? AppColors.avatarForeground : null,
          ),
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.isLight ? AppColors.avatarBackground : null,
        gradient: AppColors.isLight
            ? null
            : LinearGradient(colors: AppColors.brandGradient),
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
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette colors when the theme changes.
    return Text(
      title,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 18,
        height: 1.25,
        fontWeight: FontWeight.w800,
        letterSpacing: -.3,
      ),
    );
  }
}

class _IconMeta extends StatelessWidget {
  const _IconMeta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette colors when the theme changes.
    return Row(
      children: [
        BrandGradientIcon.social(icon, size: 17),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text.trim().isEmpty ? 'Belirtilmemiş' : text.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _MediaFallback extends StatelessWidget {
  const _MediaFallback();

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette colors when the theme changes.
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: const Center(
        child: BrandGradientIcon.social(Icons.image_outlined, size: 38),
      ),
    );
  }
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
  ownerName: _collabPublisherVisibleName(listing),
  ownerInitials: _collabPublisherVisibleInitials(listing),
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

String _collabPublisherVisibleName(CollabListing listing) {
  final publisher = listing.publisher;
  final username = publisher.contactUsername.trim();
  if (publisher.profileType == CollabProfileKind.musician) {
    return username.isNotEmpty ? username : 'Müzisyen';
  }
  return publisher.displayName;
}

String _collabPublisherVisibleInitials(CollabListing listing) =>
    _collabPublisherVisibleName(listing)
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();

double _safeAspectRatio(int? width, int? height) {
  if (width == null || height == null || width <= 0 || height <= 0) {
    return 16 / 10;
  }
  return (width / height).clamp(.8, 1.8);
}

String _durationLabel(Duration value, {bool unknownWhenZero = true}) {
  if (value <= Duration.zero) return unknownWhenZero ? '--:--' : '0:00';
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
