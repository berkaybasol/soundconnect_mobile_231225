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
    CollabDirection.seeking => 'Arıyorum',
    CollabDirection.available => 'Müsaitim',
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
    this.profileKinds = const <CollabProfileKind>{},
    this.role,
    this.genres = const <String>{},
    this.dateRange,
    this.timeWindows = const <CollabTimeWindow>{},
    this.fee = CollabFeeFilter.all,
  });

  final String? city;
  final Set<CollabProfileKind> profileKinds;
  final String? role;
  final Set<String> genres;
  final CollabDateRange? dateRange;
  final Set<CollabTimeWindow> timeWindows;
  final CollabFeeFilter fee;

  bool get isEmpty =>
      city == null &&
      profileKinds.isEmpty &&
      role == null &&
      genres.isEmpty &&
      dateRange == null &&
      timeWindows.isEmpty &&
      fee == CollabFeeFilter.all;

  int get activeCount => <bool>[
    city != null,
    profileKinds.isNotEmpty,
    role != null,
    genres.isNotEmpty,
    dateRange != null,
    timeWindows.isNotEmpty,
    fee != CollabFeeFilter.all,
  ].where((active) => active).length;

  CollabDiscoveryFilter copyWith({
    String? city,
    bool clearCity = false,
    Set<CollabProfileKind>? profileKinds,
    String? role,
    bool clearRole = false,
    Set<String>? genres,
    CollabDateRange? dateRange,
    bool clearDateRange = false,
    Set<CollabTimeWindow>? timeWindows,
    CollabFeeFilter? fee,
  }) {
    return CollabDiscoveryFilter(
      city: clearCity ? null : city ?? this.city,
      profileKinds: profileKinds ?? this.profileKinds,
      role: clearRole ? null : role ?? this.role,
      genres: genres ?? this.genres,
      dateRange: clearDateRange ? null : dateRange ?? this.dateRange,
      timeWindows: timeWindows ?? this.timeWindows,
      fee: fee ?? this.fee,
    );
  }

  bool matches(CollabDiscoveryListing listing) {
    if (city != null && listing.city != city) return false;
    if (profileKinds.isNotEmpty &&
        !profileKinds.contains(listing.profileKind)) {
      return false;
    }
    if (role != null && listing.role.toLowerCase() != role!.toLowerCase()) {
      return false;
    }
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
    this.genres = const <String>{},
    this.occurrenceDate,
    this.ownerSpecialty,
    this.avatarAsset,
    this.timeLabel,
    this.remainingPositions,
    this.totalPositions,
    this.isHighlighted = false,
  });

  final String id;
  final String ownerName;
  final String ownerInitials;
  final CollabProfileKind profileKind;
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
  final Set<String> genres;
  final DateTime? occurrenceDate;
  final int? remainingPositions;
  final int? totalPositions;
  final bool isHighlighted;

  CollabDiscoveryListing copyWith({
    int? remainingPositions,
    bool clearRemainingPositions = false,
    int? totalPositions,
    bool clearTotalPositions = false,
    bool? isHighlighted,
  }) {
    return CollabDiscoveryListing(
      id: id,
      ownerName: ownerName,
      ownerInitials: ownerInitials,
      profileKind: profileKind,
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
      feeAmount: feeAmount,
      role: role,
      description: description,
      rating: rating,
      reviewCount: reviewCount,
      completedJobs: completedJobs,
      genres: genres,
      occurrenceDate: occurrenceDate,
      remainingPositions: clearRemainingPositions
          ? null
          : remainingPositions ?? this.remainingPositions,
      totalPositions: clearTotalPositions
          ? null
          : totalPositions ?? this.totalPositions,
      isHighlighted: isHighlighted ?? this.isHighlighted,
    );
  }

  String get ownerSubtitle {
    final specialty = ownerSpecialty?.trim();
    if (specialty == null || specialty.isEmpty) return profileKind.label;
    return '${profileKind.label} · $specialty';
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
