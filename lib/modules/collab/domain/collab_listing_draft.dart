import 'collab_discovery_models.dart';

enum CollabFeeMode { paid, unspecified }

class CollabClockTime {
  const CollabClockTime({required this.hour, required this.minute});

  final int hour;
  final int minute;

  String get label =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class CollabPublisherProfile {
  const CollabPublisherProfile({
    required this.id,
    required this.name,
    required this.initials,
    required this.profileKind,
    required this.subtitle,
    required this.rating,
    required this.reviewCount,
    required this.completedJobs,
    this.avatarAsset,
  });

  final String id;
  final String name;
  final String initials;
  final CollabProfileKind profileKind;
  final String subtitle;
  final double rating;
  final int reviewCount;
  final int completedJobs;
  final String? avatarAsset;
}

class CollabListingDraft {
  const CollabListingDraft({
    required this.cadence,
    required this.direction,
    required this.title,
    required this.description,
    required this.location,
    required this.city,
    required this.role,
    required this.genres,
    required this.occurrenceDate,
    required this.occurrenceTime,
    required this.feeMode,
    required this.feeAmount,
    required this.publisher,
  });

  final CollabCadence cadence;
  final CollabDirection direction;
  final String title;
  final String description;
  final String? location;
  final String? city;
  final String? role;
  final Set<String> genres;
  final DateTime? occurrenceDate;
  final CollabClockTime? occurrenceTime;
  final CollabFeeMode feeMode;
  final int? feeAmount;
  final CollabPublisherProfile? publisher;

  CollabProfileKind get wantedKind => _wantedKindForRole(role ?? '');

  String get wantedSummary {
    final label = wantedKind.wantedLabel;
    final specialty = role?.trim() ?? '';
    if (wantedKind != CollabProfileKind.musician || specialty.isEmpty) {
      return label;
    }
    return '$label: $specialty';
  }

  CollabListingDraft copyWith({
    CollabCadence? cadence,
    CollabDirection? direction,
    String? title,
    String? description,
    String? location,
    String? city,
    String? role,
    Set<String>? genres,
    DateTime? occurrenceDate,
    bool clearOccurrenceDate = false,
    CollabClockTime? occurrenceTime,
    bool clearOccurrenceTime = false,
    CollabFeeMode? feeMode,
    int? feeAmount,
    bool clearFeeAmount = false,
    CollabPublisherProfile? publisher,
  }) {
    return CollabListingDraft(
      cadence: cadence ?? this.cadence,
      direction: direction ?? this.direction,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      city: city ?? this.city,
      role: role ?? this.role,
      genres: genres ?? this.genres,
      occurrenceDate: clearOccurrenceDate
          ? null
          : occurrenceDate ?? this.occurrenceDate,
      occurrenceTime: clearOccurrenceTime
          ? null
          : occurrenceTime ?? this.occurrenceTime,
      feeMode: feeMode ?? this.feeMode,
      feeAmount: clearFeeAmount ? null : feeAmount ?? this.feeAmount,
      publisher: publisher ?? this.publisher,
    );
  }

  CollabDiscoveryListing toListing(String id) {
    final selectedPublisher = publisher;
    if (selectedPublisher == null ||
        location == null ||
        city == null ||
        role == null) {
      throw StateError('Eksik Collab ilan taslağı yayınlanamaz.');
    }
    final isScheduledExtra = cadence == CollabCadence.extra;
    if (isScheduledExtra &&
        (occurrenceDate == null || occurrenceTime == null)) {
      throw StateError('Ekstra sahne ilanı için tarih ve saat zorunludur.');
    }
    final supportsFee =
        cadence == CollabCadence.extra ||
        selectedPublisher.profileKind == CollabProfileKind.venue;
    if (supportsFee &&
        feeMode == CollabFeeMode.paid &&
        (feeAmount == null || feeAmount! <= 0)) {
      throw StateError('Ücretli Collab ilanı için geçerli ücret zorunludur.');
    }
    final date = isScheduledExtra ? occurrenceDate : null;
    final time = isScheduledExtra ? occurrenceTime : null;
    return CollabDiscoveryListing(
      id: id,
      ownerName: selectedPublisher.name,
      ownerInitials: selectedPublisher.initials,
      profileKind: selectedPublisher.profileKind,
      wantedKind: wantedKind,
      ownerSpecialty: _publisherSpecialty(selectedPublisher),
      avatarAsset: selectedPublisher.avatarAsset,
      title: title.trim(),
      cadence: cadence,
      direction: direction,
      location: location!,
      city: city!,
      scheduleLabel: isScheduledExtra && date != null
          ? _shortDate(date)
          : cadence == CollabCadence.regular
          ? 'Düzenli'
          : 'Esnek',
      timeLabel: time?.label,
      timeWindow: time == null
          ? CollabTimeWindow.flexible
          : time.hour < 18
          ? CollabTimeWindow.daytime
          : CollabTimeWindow.evening,
      feeAmount: supportsFee && feeMode == CollabFeeMode.paid
          ? feeAmount
          : null,
      role: role!,
      description: description.trim(),
      rating: selectedPublisher.rating,
      reviewCount: selectedPublisher.reviewCount,
      completedJobs: selectedPublisher.completedJobs,
      publishedAt: DateTime.now(),
      genres: Set.unmodifiable(genres),
      occurrenceDate: date,
      isHighlighted: false,
    );
  }
}

CollabProfileKind _wantedKindForRole(String role) {
  final normalized = role.trim().toLowerCase();
  if (normalized.contains('stüdyo')) return CollabProfileKind.studio;
  if (normalized.contains('mekan')) return CollabProfileKind.venue;
  if (normalized.contains('grup') || normalized.contains('ekip')) {
    return CollabProfileKind.band;
  }
  return CollabProfileKind.musician;
}

String? _publisherSpecialty(CollabPublisherProfile profile) {
  final kindLabel = profile.profileKind.label;
  final subtitle = profile.subtitle.trim();
  if (subtitle.isEmpty || subtitle == kindLabel) return null;
  final prefix = '$kindLabel · ';
  return subtitle.startsWith(prefix)
      ? subtitle.substring(prefix.length)
      : subtitle;
}

String _shortDate(DateTime date) {
  const months = <String>[
    'Oca',
    'Şub',
    'Mar',
    'Nis',
    'May',
    'Haz',
    'Tem',
    'Ağu',
    'Eyl',
    'Eki',
    'Kas',
    'Ara',
  ];
  const weekdays = <String>['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  return '${date.day} ${months[date.month - 1]} ${weekdays[date.weekday - 1]}';
}
