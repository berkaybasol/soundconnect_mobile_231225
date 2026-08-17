import '../../domain/collab_page.dart';
import '../../domain/collab_types.dart';
import '../../domain/entities/collab_actor.dart';
import '../../domain/entities/collab_application.dart';
import '../../domain/entities/collab_job.dart';
import '../../domain/entities/collab_listing.dart';
import '../../domain/entities/collab_review.dart';

class CollabContractFormatException implements FormatException {
  const CollabContractFormatException(this.message, [this.source, this.offset]);

  @override
  final String message;
  @override
  final Object? source;
  @override
  final int? offset;

  @override
  String toString() => 'CollabContractFormatException: $message';
}

class CollabActorModel extends CollabActor {
  const CollabActorModel({
    required super.actorId,
    required super.profileType,
    required super.sourceProfileId,
    required super.contactUserId,
    super.contactUsername,
    required super.displayName,
    required super.rating,
    required super.reviewCount,
    required super.completedJobCount,
    super.avatarUrl,
  });

  factory CollabActorModel.fromJson(Map<String, dynamic> json) =>
      CollabActorModel(
        actorId: _requiredString(json, 'actorId'),
        profileType: _profileKind(json['profileType'], 'profileType'),
        sourceProfileId: _requiredString(json, 'sourceProfileId'),
        contactUserId: _nullableString(json['contactUserId']) ?? '',
        contactUsername: _nullableString(json['contactUsername']) ?? '',
        displayName: _requiredString(json, 'displayName'),
        avatarUrl: _nullableString(json['avatarUrl']),
        rating: _requiredRating(json['rating']),
        reviewCount: _requiredNonNegativeInt(json, 'reviewCount'),
        completedJobCount: _requiredNonNegativeInt(json, 'completedJobCount'),
      );
}

class CollabListingModel extends CollabListing {
  const CollabListingModel({
    required super.id,
    required super.version,
    required super.status,
    required super.cadence,
    required super.wantedType,
    required super.title,
    required super.description,
    required super.city,
    required super.genres,
    required super.feeStatus,
    required super.publisher,
    required super.ownedByMe,
    required super.appliedByMe,
    required super.savedByMe,
    super.closureReason,
    super.instrument,
    super.branch,
    super.customSpecialty,
    super.scheduledAt,
    super.expiresAt,
    super.feeAmountMinor,
    super.currency,
    super.publishedAt,
    super.createdAt,
    super.closedAt,
    super.applicationCount,
  });

  factory CollabListingModel.fromJson(Map<String, dynamic> json) {
    final cadence = _cadence(json['cadence']);
    final publisher = CollabActorModel.fromJson(
      _requiredMap(json, 'publisher'),
    );
    final feeAmountMinor = _nullableInt(json['feeAmountMinor']);
    final instrumentJson = _nullableMap(json['instrument']);
    final instrument = instrumentJson == null
        ? null
        : CollabInstrumentSummary(
            id: _requiredString(instrumentJson, 'id'),
            name: _requiredString(instrumentJson, 'name'),
          );
    return CollabListingModel(
      id: _requiredString(json, 'id'),
      version: _requiredNonNegativeInt(json, 'version'),
      status: _listingStatus(json['status']),
      closureReason: _nullableClosureReason(json['closureReason']),
      cadence: cadence,
      wantedType: _profileKind(json['wantedType'], 'wantedType'),
      instrument: instrument,
      branch: _nullableBranch(json['branch']),
      customSpecialty: _nullableString(json['customSpecialty']),
      title: _requiredString(json, 'title'),
      description: _string(json['description']),
      city: CollabCitySummary(
        id: _requiredString(_requiredMap(json, 'city'), 'id'),
        name: _requiredString(_requiredMap(json, 'city'), 'name'),
      ),
      genres: _stringList(json['genres']),
      scheduledAt: _nullableDate(json['scheduledAt'], 'scheduledAt'),
      expiresAt: _nullableDate(json['expiresAt'], 'expiresAt'),
      feeAmountMinor: feeAmountMinor,
      currency: _nullableString(json['currency']),
      feeStatus: _feeStatus(
        json['feeStatus'],
        cadence: cadence,
        publisherType: publisher.profileType,
        feeAmountMinor: feeAmountMinor,
      ),
      publishedAt: _nullableDate(json['publishedAt'], 'publishedAt'),
      createdAt: _nullableDate(json['createdAt'], 'createdAt'),
      closedAt: _nullableDate(json['closedAt'], 'closedAt'),
      publisher: publisher,
      ownedByMe: _requiredBool(json, 'ownedByMe'),
      appliedByMe: _requiredBool(json, 'appliedByMe'),
      savedByMe: _requiredBool(json, 'savedByMe'),
      applicationCount: _requiredNonNegativeInt(json, 'applicationCount'),
    );
  }
}

class CollabApplicationModel extends CollabApplication {
  const CollabApplicationModel({
    required super.id,
    required super.version,
    required super.listing,
    required super.applicant,
    required super.message,
    required super.status,
    required super.submittedAt,
    required super.statusChangedAt,
    super.phone,
    super.decidedAt,
  });

  factory CollabApplicationModel.fromJson(Map<String, dynamic> json) {
    final submittedAt = _requiredDate(json['submittedAt'], 'submittedAt');
    return CollabApplicationModel(
      id: _requiredString(json, 'id'),
      version: _requiredNonNegativeInt(json, 'version'),
      listing: CollabListingModel.fromJson(_requiredMap(json, 'listing')),
      applicant: CollabActorModel.fromJson(_requiredMap(json, 'applicant')),
      phone: _nullableString(json['phoneNumber'] ?? json['phone']),
      message: _string(json['message']),
      status: _applicationStatus(json['status']),
      submittedAt: submittedAt,
      statusChangedAt:
          _nullableDate(json['statusChangedAt'], 'statusChangedAt') ??
          submittedAt,
      decidedAt: _nullableDate(json['decidedAt'], 'decidedAt'),
    );
  }
}

class CollabJobModel extends CollabJob {
  const CollabJobModel({
    required super.id,
    required super.version,
    required super.status,
    required super.listing,
    required super.publisher,
    required super.applicant,
    required super.publisherConfirmedCompletion,
    required super.applicantConfirmedCompletion,
    required super.confirmedByMe,
    required super.reviewedByMe,
    super.publisherConfirmedAt,
    super.applicantConfirmedAt,
    super.completedAt,
  });

  factory CollabJobModel.fromJson(Map<String, dynamic> json) => CollabJobModel(
    id: _requiredString(json, 'id'),
    version: _requiredNonNegativeInt(json, 'version'),
    status: _jobStatus(json['status']),
    listing: CollabListingModel.fromJson(_requiredMap(json, 'listing')),
    publisher: CollabActorModel.fromJson(_requiredMap(json, 'publisher')),
    applicant: CollabActorModel.fromJson(_requiredMap(json, 'applicant')),
    publisherConfirmedCompletion: _requiredAliasedBool(
      json,
      'publisherConfirmed',
      'publisherConfirmedCompletion',
    ),
    applicantConfirmedCompletion: _requiredAliasedBool(
      json,
      'applicantConfirmed',
      'applicantConfirmedCompletion',
    ),
    confirmedByMe: _requiredBool(json, 'confirmedByMe'),
    publisherConfirmedAt: _nullableDate(
      json['publisherConfirmedAt'],
      'publisherConfirmedAt',
    ),
    applicantConfirmedAt: _nullableDate(
      json['applicantConfirmedAt'],
      'applicantConfirmedAt',
    ),
    completedAt: _nullableDate(json['completedAt'], 'completedAt'),
    reviewedByMe: _requiredBool(json, 'reviewedByMe'),
  );
}

class CollabReviewModel extends CollabReview {
  const CollabReviewModel({
    required super.id,
    required super.jobId,
    required super.reviewer,
    required super.target,
    required super.rating,
    required super.createdAt,
    super.comment,
  });

  factory CollabReviewModel.fromJson(Map<String, dynamic> json) {
    final rating = _int(json['rating']);
    if (rating < 1 || rating > 5) {
      throw CollabContractFormatException(
        'rating must be between 1 and 5',
        json['rating'],
      );
    }
    return CollabReviewModel(
      id: _requiredString(json, 'id'),
      jobId: _requiredString(json, 'jobId'),
      reviewer: CollabActorModel.fromJson(_requiredMap(json, 'reviewer')),
      target: CollabActorModel.fromJson(_requiredMap(json, 'target')),
      rating: rating,
      comment: _nullableString(json['comment']),
      createdAt: _requiredDate(
        json['submittedAt'] ?? json['createdAt'],
        'submittedAt',
      ),
    );
  }
}

CollabPage<T> decodeCollabPage<T>(
  Object? json,
  T Function(Map<String, dynamic> json) decodeItem, {
  required int fallbackPage,
  required int fallbackSize,
}) {
  if (json is! Map) {
    throw CollabContractFormatException(
      'Page response must be an object',
      json,
    );
  }
  final map = json.cast<String, dynamic>();
  final rawContent = map['content'] ?? map['items'];
  if (rawContent is! List) {
    throw CollabContractFormatException(
      'Page response content must be a list',
      rawContent,
    );
  }
  final items = rawContent
      .map((item) {
        if (item is! Map) {
          throw CollabContractFormatException(
            'Page item must be an object',
            item,
          );
        }
        return decodeItem(item.cast<String, dynamic>());
      })
      .toList(growable: false);
  final page = _nullableInt(map['page'] ?? map['number']) ?? fallbackPage;
  final size = _nullableInt(map['size']) ?? fallbackSize;
  final totalElements =
      _nullableInt(map['totalElements']) ?? (page * size) + items.length;
  final totalPages =
      _nullableInt(map['totalPages']) ??
      (size <= 0 ? 0 : (totalElements / size).ceil());
  final first = map['first'] is bool ? map['first'] as bool : page == 0;
  final last = map['last'] is bool
      ? map['last'] as bool
      : totalPages == 0 || page >= totalPages - 1;
  return CollabPage<T>(
    items: items,
    page: page,
    size: size,
    totalElements: totalElements,
    totalPages: totalPages,
    first: first,
    last: last,
  );
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map) return value.cast<String, dynamic>();
  throw CollabContractFormatException('$key must be an object', value);
}

Map<String, dynamic>? _nullableMap(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : null;

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _nullableString(json[key]);
  if (value == null) {
    throw CollabContractFormatException('$key is required', json[key]);
  }
  return value;
}

String _string(Object? value) => value?.toString() ?? '';

String? _nullableString(Object? value) {
  final normalized = value?.toString().trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

List<String> _stringList(Object? value) {
  if (value == null) return const <String>[];
  if (value is! Iterable) {
    throw CollabContractFormatException('Expected a list of strings', value);
  }
  return List<String>.unmodifiable(
    value.map(_nullableString).whereType<String>().toSet(),
  );
}

int _int(Object? value) {
  final parsed = _nullableInt(value);
  if (parsed == null) {
    throw CollabContractFormatException('Expected an integer', value);
  }
  return parsed;
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

int _requiredNonNegativeInt(Map<String, dynamic> json, String key) {
  final parsed = _nullableInt(json[key]);
  if (parsed == null || parsed < 0) {
    throw CollabContractFormatException(
      '$key must be a non-negative integer',
      json[key],
    );
  }
  return parsed;
}

double _requiredRating(Object? value) {
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
  if (parsed == null || !parsed.isFinite || parsed < 0 || parsed > 5) {
    throw CollabContractFormatException(
      'rating must be between 0 and 5',
      value,
    );
  }
  return parsed;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw CollabContractFormatException('$key must be a boolean', value);
}

bool _requiredAliasedBool(
  Map<String, dynamic> json,
  String primaryKey,
  String compatibilityKey,
) {
  final key = json.containsKey(primaryKey) ? primaryKey : compatibilityKey;
  return _requiredBool(json, key);
}

DateTime _requiredDate(Object? value, String field) {
  final parsed = _nullableDate(value, field);
  if (parsed == null) {
    throw CollabContractFormatException('$field is required', value);
  }
  return parsed;
}

DateTime? _nullableDate(Object? value, String field) {
  if (value == null) return null;
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) {
    throw CollabContractFormatException('$field must be ISO-8601', value);
  }
  return parsed;
}

String _wire(Object? value, String field) {
  final normalized = _nullableString(value)?.toUpperCase();
  if (normalized == null) {
    throw CollabContractFormatException('$field is required', value);
  }
  return normalized;
}

CollabProfileKind _profileKind(Object? value, String field) =>
    switch (_wire(value, field)) {
      'MUSICIAN' => CollabProfileKind.musician,
      'BAND' => CollabProfileKind.band,
      'VENUE' => CollabProfileKind.venue,
      'STUDIO' => CollabProfileKind.studio,
      final unknown => throw CollabContractFormatException(
        'Unknown $field value: $unknown',
        value,
      ),
    };

CollabCadence _cadence(Object? value) => switch (_wire(value, 'cadence')) {
  'REGULAR' => CollabCadence.regular,
  'EXTRA' => CollabCadence.extra,
  final unknown => throw CollabContractFormatException(
    'Unknown cadence value: $unknown',
    value,
  ),
};

CollabListingStatus _listingStatus(Object? value) =>
    switch (_wire(value, 'status')) {
      'DRAFT' => CollabListingStatus.draft,
      'OPEN' => CollabListingStatus.open,
      'CLOSED' => CollabListingStatus.closed,
      'EXPIRED' => CollabListingStatus.expired,
      final unknown => throw CollabContractFormatException(
        'Unknown listing status: $unknown',
        value,
      ),
    };

CollabClosureReason? _nullableClosureReason(Object? value) {
  if (_nullableString(value) == null) return null;
  return switch (_wire(value, 'closureReason')) {
    'MATCHED' => CollabClosureReason.matched,
    'OWNER_CLOSED' => CollabClosureReason.ownerClosed,
    'EXPIRED' => CollabClosureReason.expired,
    'ADMIN_REMOVED' => CollabClosureReason.adminRemoved,
    final unknown => throw CollabContractFormatException(
      'Unknown closure reason: $unknown',
      value,
    ),
  };
}

CollabBranch? _nullableBranch(Object? value) {
  if (_nullableString(value) == null) return null;
  return switch (_wire(value, 'branch')) {
    'VOCAL' => CollabBranch.vocal,
    'SOUND_ENGINEER' => CollabBranch.soundEngineer,
    'PRODUCER' => CollabBranch.producer,
    'DJ' => CollabBranch.dj,
    'OTHER' => CollabBranch.other,
    final unknown => throw CollabContractFormatException(
      'Unknown branch value: $unknown',
      value,
    ),
  };
}

CollabFeeStatus _feeStatus(
  Object? value, {
  required CollabCadence cadence,
  required CollabProfileKind publisherType,
  required int? feeAmountMinor,
}) {
  final normalized = _nullableString(value)?.toUpperCase();
  if (normalized == null) {
    if (feeAmountMinor != null) return CollabFeeStatus.specified;
    return cadence == CollabCadence.extra ||
            publisherType == CollabProfileKind.venue
        ? CollabFeeStatus.unspecified
        : CollabFeeStatus.notApplicable;
  }
  return switch (normalized) {
    'SPECIFIED' => CollabFeeStatus.specified,
    'UNSPECIFIED' => CollabFeeStatus.unspecified,
    'NOT_APPLICABLE' => CollabFeeStatus.notApplicable,
    final unknown => throw CollabContractFormatException(
      'Unknown fee status: $unknown',
      value,
    ),
  };
}

CollabApplicationStatus _applicationStatus(Object? value) =>
    switch (_wire(value, 'application status')) {
      'PENDING' => CollabApplicationStatus.pending,
      'ACCEPTED' => CollabApplicationStatus.accepted,
      'REJECTED' => CollabApplicationStatus.rejected,
      'WITHDRAWN_BY_APPLICANT' => CollabApplicationStatus.withdrawnByApplicant,
      'INVALIDATED_BY_LISTING_CLOSURE' =>
        CollabApplicationStatus.invalidatedByListingClosure,
      final unknown => throw CollabContractFormatException(
        'Unknown application status: $unknown',
        value,
      ),
    };

CollabJobStatus _jobStatus(Object? value) =>
    switch (_wire(value, 'job status')) {
      'ACTIVE' => CollabJobStatus.active,
      'COMPLETED' => CollabJobStatus.completed,
      final unknown => throw CollabContractFormatException(
        'Unknown job status: $unknown',
        value,
      ),
    };
