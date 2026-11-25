import '../collab_types.dart';

class CollabActor {
  const CollabActor({
    required this.actorId,
    required this.profileType,
    required this.sourceProfileId,
    required this.contactUserId,
    this.contactUsername = '',
    required this.displayName,
    required this.rating,
    required this.reviewCount,
    required this.completedJobCount,
    this.avatarUrl,
    this.profileAvailable = true,
  });

  final String actorId;
  final CollabProfileKind profileType;
  final String sourceProfileId;

  /// Empty when the contact was deleted or omitted from a historical review.
  final String contactUserId;
  final String contactUsername;
  final String displayName;
  final String? avatarUrl;
  final double rating;
  final int reviewCount;
  final int completedJobCount;
  final bool profileAvailable;

  bool get canOpenProfile =>
      profileAvailable && sourceProfileId.trim().isNotEmpty;

  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2);
    return parts.map((part) => part[0].toUpperCase()).join();
  }
}

class CollabCitySummary {
  const CollabCitySummary({required this.id, required this.name});

  final String id;
  final String name;
}

class CollabInstrumentSummary {
  const CollabInstrumentSummary({required this.id, required this.name});

  final String id;
  final String name;
}
