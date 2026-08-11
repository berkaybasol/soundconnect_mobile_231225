import 'collab_types.dart';

class CollabDiscoveryQuery {
  const CollabDiscoveryQuery({
    this.search,
    this.cityId,
    this.wantedType,
    this.instrumentIds = const <String>{},
    this.branches = const <CollabBranch>{},
    this.publisherTypes = const <CollabProfileKind>{},
    this.publishedWithin = CollabPublishedWithin.all,
    this.cadence = CollabCadence.regular,
    this.page = 0,
    this.size = 20,
  });

  final String? search;
  final String? cityId;
  final CollabProfileKind? wantedType;
  final Set<String> instrumentIds;
  final Set<CollabBranch> branches;
  final Set<CollabProfileKind> publisherTypes;
  final CollabPublishedWithin publishedWithin;
  final CollabCadence cadence;
  final int page;
  final int size;

  CollabDiscoveryQuery copyWith({
    String? search,
    bool clearSearch = false,
    String? cityId,
    bool clearCityId = false,
    CollabProfileKind? wantedType,
    bool clearWantedType = false,
    Set<String>? instrumentIds,
    Set<CollabBranch>? branches,
    Set<CollabProfileKind>? publisherTypes,
    CollabPublishedWithin? publishedWithin,
    CollabCadence? cadence,
    int? page,
    int? size,
  }) {
    final nextWantedType = clearWantedType
        ? null
        : wantedType ?? this.wantedType;
    final musicianWanted = nextWantedType == CollabProfileKind.musician;
    final nextCadence = cadence ?? this.cadence;
    final nextPublishedWithin = publishedWithin ?? this.publishedWithin;
    return CollabDiscoveryQuery(
      search: clearSearch ? null : search ?? this.search,
      cityId: clearCityId ? null : cityId ?? this.cityId,
      wantedType: nextWantedType,
      instrumentIds: musicianWanted
          ? Set<String>.unmodifiable(instrumentIds ?? this.instrumentIds)
          : const <String>{},
      branches: musicianWanted
          ? Set<CollabBranch>.unmodifiable(branches ?? this.branches)
          : const <CollabBranch>{},
      publisherTypes: Set<CollabProfileKind>.unmodifiable(
        publisherTypes ?? this.publisherTypes,
      ),
      publishedWithin:
          nextCadence == CollabCadence.extra &&
              (nextPublishedWithin == CollabPublishedWithin.last30Days ||
                  nextPublishedWithin == CollabPublishedWithin.olderThan30Days)
          ? CollabPublishedWithin.all
          : nextPublishedWithin,
      cadence: nextCadence,
      page: page ?? this.page,
      size: size ?? this.size,
    );
  }

  CollabDiscoveryQuery firstPage() => copyWith(page: 0);
  CollabDiscoveryQuery nextPage() => copyWith(page: page + 1);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollabDiscoveryQuery &&
          other.search == search &&
          other.cityId == cityId &&
          other.wantedType == wantedType &&
          _setEquals(other.instrumentIds, instrumentIds) &&
          _setEquals(other.branches, branches) &&
          _setEquals(other.publisherTypes, publisherTypes) &&
          other.publishedWithin == publishedWithin &&
          other.cadence == cadence &&
          other.page == page &&
          other.size == size;

  @override
  int get hashCode => Object.hash(
    search,
    cityId,
    wantedType,
    Object.hashAll(instrumentIds.toList()..sort()),
    Object.hashAll(branches.map((item) => item.apiValue).toList()..sort()),
    Object.hashAll(
      publisherTypes.map((item) => item.apiValue).toList()..sort(),
    ),
    publishedWithin,
    cadence,
    page,
    size,
  );
}

class CollabListingInput {
  const CollabListingInput({
    required this.publisherActorId,
    required this.cadence,
    required this.wantedType,
    required this.title,
    required this.description,
    required this.cityId,
    this.instrumentId,
    this.branch,
    this.customSpecialty,
    this.genres = const <String>[],
    this.scheduledAt,
    this.feeAmountMinor,
    this.currency,
  });

  final String publisherActorId;
  final CollabCadence cadence;
  final CollabProfileKind wantedType;
  final String? instrumentId;
  final CollabBranch? branch;
  final String? customSpecialty;
  final String title;
  final String description;
  final String cityId;
  final List<String> genres;
  final DateTime? scheduledAt;
  final int? feeAmountMinor;
  final String? currency;

  List<String> validate({
    required CollabProfileKind publisherType,
    DateTime? now,
  }) {
    final errors = <String>[];
    final normalizedTitle = title.trim();
    final normalizedDescription = description.trim();
    final normalizedInstrument = instrumentId?.trim() ?? '';
    final normalizedCustom = customSpecialty?.trim() ?? '';
    final normalizedCurrency = currency?.trim() ?? '';

    if (publisherActorId.trim().isEmpty) {
      errors.add('İlanı yayınlayacak profil seçilmelidir.');
    }
    if (normalizedTitle.length < 5 || normalizedTitle.length > 100) {
      errors.add('Başlık 5-100 karakter arasında olmalıdır.');
    }
    if (normalizedDescription.length < 20 ||
        normalizedDescription.length > 500) {
      errors.add('Açıklama 20-500 karakter arasında olmalıdır.');
    }
    if (cityId.trim().isEmpty) errors.add('Şehir seçilmelidir.');
    if (genres.length > 3) errors.add('En fazla 3 tarz seçilebilir.');
    if (genres.any(
      (genre) => genre.trim().isEmpty || genre.trim().length > 40,
    )) {
      errors.add('Tarz adları 1-40 karakter arasında olmalıdır.');
    }

    if (wantedType == CollabProfileKind.musician) {
      final hasInstrument = normalizedInstrument.isNotEmpty;
      final hasBranch = branch != null;
      if (hasInstrument == hasBranch) {
        errors.add('Bir enstrüman veya branş seçilmelidir.');
      }
      if (branch == CollabBranch.other &&
          (normalizedCustom.isEmpty || normalizedCustom.length > 80)) {
        errors.add('Diğer branş 1-80 karakter arasında olmalıdır.');
      }
      if (branch != CollabBranch.other && normalizedCustom.isNotEmpty) {
        errors.add('Özel branş yalnız Diğer seçeneğinde kullanılabilir.');
      }
    } else if (normalizedInstrument.isNotEmpty ||
        branch != null ||
        normalizedCustom.isNotEmpty) {
      errors.add(
        'Enstrüman/branş yalnız müzisyen arayan ilanda kullanılabilir.',
      );
    }

    final clock = now ?? DateTime.now();
    if (cadence == CollabCadence.extra) {
      final occurrence = scheduledAt;
      if (occurrence == null) {
        errors.add('Ekstra ilan için sahne tarihi ve saati zorunludur.');
      } else {
        if (!occurrence.isAfter(clock)) {
          errors.add('Sahne tarihi gelecekte olmalıdır.');
        }
        if (occurrence.isAfter(clock.add(const Duration(days: 7)))) {
          errors.add('Ekstra ilan en fazla 7 gün sonrası için açılabilir.');
        }
      }
    } else if (scheduledAt != null) {
      errors.add('Düzenli ilanda tarih ve saat kullanılmaz.');
    }

    final hasFee = feeAmountMinor != null || normalizedCurrency.isNotEmpty;
    if (hasFee) {
      if ((feeAmountMinor ?? 0) <= 0 ||
          (feeAmountMinor ?? 0) > collabMaxFeeAmountMinor ||
          normalizedCurrency.toUpperCase() != 'TRY') {
        errors.add('Ücret 1-1.000.000 TRY arasında olmalıdır.');
      }
      if (cadence == CollabCadence.regular &&
          publisherType != CollabProfileKind.venue) {
        errors.add('Düzenli ilanda ücreti yalnız mekan profili belirtebilir.');
      }
    }
    return List<String>.unmodifiable(errors);
  }

  CollabListingInput copyWith({
    String? publisherActorId,
    CollabCadence? cadence,
    CollabProfileKind? wantedType,
    String? instrumentId,
    bool clearInstrumentId = false,
    CollabBranch? branch,
    bool clearBranch = false,
    String? customSpecialty,
    bool clearCustomSpecialty = false,
    String? title,
    String? description,
    String? cityId,
    List<String>? genres,
    DateTime? scheduledAt,
    bool clearScheduledAt = false,
    int? feeAmountMinor,
    bool clearFeeAmount = false,
    String? currency,
    bool clearCurrency = false,
  }) => CollabListingInput(
    publisherActorId: publisherActorId ?? this.publisherActorId,
    cadence: cadence ?? this.cadence,
    wantedType: wantedType ?? this.wantedType,
    instrumentId: clearInstrumentId ? null : instrumentId ?? this.instrumentId,
    branch: clearBranch ? null : branch ?? this.branch,
    customSpecialty: clearCustomSpecialty
        ? null
        : customSpecialty ?? this.customSpecialty,
    title: title ?? this.title,
    description: description ?? this.description,
    cityId: cityId ?? this.cityId,
    genres: genres ?? this.genres,
    scheduledAt: clearScheduledAt ? null : scheduledAt ?? this.scheduledAt,
    feeAmountMinor: clearFeeAmount
        ? null
        : feeAmountMinor ?? this.feeAmountMinor,
    currency: clearCurrency ? null : currency ?? this.currency,
  );
}

class CollabApplicationInput {
  const CollabApplicationInput({
    required this.applicantActorId,
    required this.phone,
    required this.message,
  });

  final String applicantActorId;
  final String phone;
  final String message;

  List<String> validate() {
    final errors = <String>[];
    if (applicantActorId.trim().isEmpty) {
      errors.add('Başvuru profili seçilmelidir.');
    }
    final normalizedPhone = phone.trim();
    final validCharacters = RegExp(r'^[+0-9() .-]+$').hasMatch(normalizedPhone);
    final plusCount = '+'.allMatches(normalizedPhone).length;
    final validPlus =
        plusCount == 0 || (plusCount == 1 && normalizedPhone.startsWith('+'));
    final digitCount = RegExp(r'\d').allMatches(normalizedPhone).length;
    if (normalizedPhone.length > 32 ||
        !validCharacters ||
        !validPlus ||
        digitCount < 7 ||
        digitCount > 15) {
      errors.add('Telefon numarası 7-15 rakam içermelidir.');
    }
    if (message.trim().length > 500) {
      errors.add('Başvuru mesajı en fazla 500 karakter olabilir.');
    }
    return List<String>.unmodifiable(errors);
  }
}

class CollabReviewInput {
  const CollabReviewInput({required this.rating, this.comment});

  final int rating;
  final String? comment;

  bool get isValid =>
      rating >= 1 && rating <= 5 && (comment?.trim().length ?? 0) <= 500;
}

class CollabReportInput {
  const CollabReportInput({required this.reason, this.details});

  final CollabReportReason reason;
  final String? details;

  bool get isValid {
    final normalized = details?.trim() ?? '';
    return normalized.length <= 500 &&
        (reason != CollabReportReason.other || normalized.isNotEmpty);
  }
}

bool _setEquals<T>(Set<T> left, Set<T> right) =>
    left.length == right.length && left.containsAll(right);

/// Backend abuse guard expressed in minor TRY units (1.000.000,00 TRY).
const int collabMaxFeeAmountMinor = 100000000;
