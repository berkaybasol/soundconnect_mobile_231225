enum CollabCadence { extra, regular }

extension CollabCadenceLabel on CollabCadence {
  String get label => switch (this) {
    CollabCadence.extra => 'Ekstra',
    CollabCadence.regular => 'Düzenli',
  };
}

enum CollabDirection { seeking, available }

extension CollabDirectionLabel on CollabDirection {
  String get label => switch (this) {
    CollabDirection.seeking => 'İhtiyaç ilanı',
    CollabDirection.available => 'İş / proje ilanı',
  };
}

enum CollabProfileKind { musician, band, venue, studio }

extension CollabProfileKindLabel on CollabProfileKind {
  String get label => switch (this) {
    CollabProfileKind.musician => 'Müzisyen',
    CollabProfileKind.band => 'Grup',
    CollabProfileKind.venue => 'Mekan',
    CollabProfileKind.studio => 'Stüdyo',
  };

  String get publisherLabel => switch (this) {
    CollabProfileKind.musician => 'Müzisyenden',
    CollabProfileKind.band => 'Gruptan',
    CollabProfileKind.venue => 'Mekandan',
    CollabProfileKind.studio => 'Stüdyodan',
  };

  String get wantedLabel => '$label arayan';
}

enum CollabPublishedWithin {
  all,
  last24Hours,
  last3Days,
  last7Days,
  last30Days,
  olderThan30Days,
}

extension CollabPublishedWithinLabel on CollabPublishedWithin {
  String get label => switch (this) {
    CollabPublishedWithin.all => 'Tümü',
    CollabPublishedWithin.last24Hours => 'Son 24 saat',
    CollabPublishedWithin.last3Days => 'Son 3 gün',
    CollabPublishedWithin.last7Days => 'Son 7 gün',
    CollabPublishedWithin.last30Days => 'Son 30 gün',
    CollabPublishedWithin.olderThan30Days => '30 günden eski',
  };

  bool includes(DateTime? publishedAt, {DateTime? now}) {
    if (this == CollabPublishedWithin.all) return true;
    if (publishedAt == null) return false;

    final age = (now ?? DateTime.now()).difference(publishedAt);
    if (age.isNegative) return false;
    if (this == CollabPublishedWithin.olderThan30Days) {
      return age > const Duration(days: 30);
    }
    final limit = switch (this) {
      CollabPublishedWithin.last24Hours => const Duration(hours: 24),
      CollabPublishedWithin.last3Days => const Duration(days: 3),
      CollabPublishedWithin.last7Days => const Duration(days: 7),
      CollabPublishedWithin.last30Days => const Duration(days: 30),
      CollabPublishedWithin.all ||
      CollabPublishedWithin.olderThan30Days => Duration.zero,
    };
    return age <= limit;
  }
}

enum CollabTimeWindow { daytime, evening, flexible }

extension CollabTimeWindowLabel on CollabTimeWindow {
  String get label => switch (this) {
    CollabTimeWindow.daytime => 'Gündüz',
    CollabTimeWindow.evening => 'Akşam',
    CollabTimeWindow.flexible => 'Esnek',
  };
}

enum CollabFeeFilter { all, paid, unspecified }

class CollabDateRange {
  const CollabDateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool contains(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day);
    return !normalized.isBefore(normalizedStart) &&
        !normalized.isAfter(normalizedEnd);
  }
}

class CollabDiscoveryFilter {
  const CollabDiscoveryFilter({
    this.city,
    this.wantedKind,
    this.profileKinds = const <CollabProfileKind>{},
    this.specialties = const <String>{},
    this.publishedWithin = CollabPublishedWithin.all,
    this.genres = const <String>{},
    this.dateRange,
    this.timeWindows = const <CollabTimeWindow>{},
    this.fee = CollabFeeFilter.all,
  });

  final String? city;
  final CollabProfileKind? wantedKind;
  final Set<CollabProfileKind> profileKinds;
  final Set<String> specialties;
  final CollabPublishedWithin publishedWithin;
  final Set<String> genres;
  final CollabDateRange? dateRange;
  final Set<CollabTimeWindow> timeWindows;
  final CollabFeeFilter fee;

  bool get isEmpty =>
      city == null &&
      wantedKind == null &&
      profileKinds.isEmpty &&
      specialties.isEmpty &&
      publishedWithin == CollabPublishedWithin.all &&
      genres.isEmpty &&
      dateRange == null &&
      timeWindows.isEmpty &&
      fee == CollabFeeFilter.all;

  int get activeCount => <bool>[
    city != null,
    wantedKind != null,
    profileKinds.isNotEmpty,
    specialties.isNotEmpty,
    publishedWithin != CollabPublishedWithin.all,
    genres.isNotEmpty,
    dateRange != null,
    timeWindows.isNotEmpty,
    fee != CollabFeeFilter.all,
  ].where((active) => active).length;

  CollabDiscoveryFilter copyWith({
    String? city,
    bool clearCity = false,
    CollabProfileKind? wantedKind,
    bool clearWantedKind = false,
    Set<CollabProfileKind>? profileKinds,
    Set<String>? specialties,
    CollabPublishedWithin? publishedWithin,
    Set<String>? genres,
    CollabDateRange? dateRange,
    bool clearDateRange = false,
    Set<CollabTimeWindow>? timeWindows,
    CollabFeeFilter? fee,
  }) {
    final nextWantedKind = clearWantedKind
        ? null
        : wantedKind ?? this.wantedKind;
    return CollabDiscoveryFilter(
      city: clearCity ? null : city ?? this.city,
      wantedKind: nextWantedKind,
      profileKinds: profileKinds ?? this.profileKinds,
      specialties: nextWantedKind == CollabProfileKind.musician
          ? specialties ?? this.specialties
          : const <String>{},
      publishedWithin: publishedWithin ?? this.publishedWithin,
      genres: genres ?? this.genres,
      dateRange: clearDateRange ? null : dateRange ?? this.dateRange,
      timeWindows: timeWindows ?? this.timeWindows,
      fee: fee ?? this.fee,
    );
  }

  bool matches(CollabDiscoveryListing listing) {
    if (city != null && listing.city != city) return false;
    if (wantedKind != null && listing.wantedKind != wantedKind) return false;
    if (profileKinds.isNotEmpty &&
        !profileKinds.contains(listing.profileKind)) {
      return false;
    }
    if (specialties.isNotEmpty &&
        !specialties.any(
          (specialty) => listing.role.toLowerCase() == specialty.toLowerCase(),
        )) {
      return false;
    }
    if (!publishedWithin.includes(listing.publishedAt)) return false;
    if (genres.isNotEmpty && !genres.any(listing.genres.contains)) return false;
    if (dateRange != null) {
      final date = listing.occurrenceDate;
      if (date == null || !dateRange!.contains(date)) return false;
    }
    if (timeWindows.isNotEmpty && !timeWindows.contains(listing.timeWindow)) {
      return false;
    }
    if (fee == CollabFeeFilter.paid && listing.feeAmount == null) return false;
    if (fee == CollabFeeFilter.unspecified && listing.feeAmount != null) {
      return false;
    }
    return true;
  }
}

class CollabDiscoveryListing {
  const CollabDiscoveryListing({
    required this.id,
    required this.ownerName,
    required this.ownerInitials,
    required this.profileKind,
    required this.wantedKind,
    required this.title,
    required this.cadence,
    required this.direction,
    required this.location,
    required this.city,
    required this.scheduleLabel,
    required this.timeWindow,
    required this.feeAmount,
    required this.role,
    required this.description,
    required this.rating,
    required this.reviewCount,
    required this.completedJobs,
    this.publishedAt,
    this.genres = const <String>{},
    this.occurrenceDate,
    this.ownerSpecialty,
    this.avatarAsset,
    this.timeLabel,
    this.isHighlighted = false,
  });

  final String id;
  final String ownerName;
  final String ownerInitials;
  final CollabProfileKind profileKind;
  final CollabProfileKind wantedKind;
  final String? ownerSpecialty;
  final String? avatarAsset;
  final String title;
  final CollabCadence cadence;
  final CollabDirection direction;
  final String location;
  final String city;
  final String scheduleLabel;
  final String? timeLabel;
  final CollabTimeWindow timeWindow;
  final int? feeAmount;
  final String role;
  final String description;
  final double rating;
  final int reviewCount;
  final int completedJobs;
  final DateTime? publishedAt;
  final Set<String> genres;
  final DateTime? occurrenceDate;
  final bool isHighlighted;

  CollabDiscoveryListing copyWith({
    int? feeAmount,
    bool clearFeeAmount = false,
    bool? isHighlighted,
  }) {
    return CollabDiscoveryListing(
      id: id,
      ownerName: ownerName,
      ownerInitials: ownerInitials,
      profileKind: profileKind,
      wantedKind: wantedKind,
      ownerSpecialty: ownerSpecialty,
      avatarAsset: avatarAsset,
      title: title,
      cadence: cadence,
      direction: direction,
      location: location,
      city: city,
      scheduleLabel: scheduleLabel,
      timeLabel: timeLabel,
      timeWindow: timeWindow,
      feeAmount: clearFeeAmount ? null : feeAmount ?? this.feeAmount,
      role: role,
      description: description,
      rating: rating,
      reviewCount: reviewCount,
      completedJobs: completedJobs,
      publishedAt: publishedAt,
      genres: genres,
      occurrenceDate: occurrenceDate,
      isHighlighted: isHighlighted ?? this.isHighlighted,
    );
  }

  String get ownerSubtitle {
    final specialty = ownerSpecialty?.trim();
    if (specialty == null || specialty.isEmpty) return profileKind.label;
    return '${profileKind.label} · $specialty';
  }

  String get wantedSummary {
    final label = wantedKind.wantedLabel;
    final specialty = role.trim();
    if (wantedKind != CollabProfileKind.musician || specialty.isEmpty) {
      return label;
    }
    return '$label: $specialty';
  }

  bool matches(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;
    return <String>[
      ownerName,
      ownerSubtitle,
      title,
      description,
      location,
      role,
      ...genres,
      cadence.label,
      direction.label,
    ].any((value) => value.toLowerCase().contains(normalizedQuery));
  }
}
