import '../collab_types.dart';
import 'collab_actor.dart';

class CollabListing {
  const CollabListing({
    required this.id,
    required this.version,
    required this.status,
    required this.cadence,
    required this.wantedType,
    required this.title,
    required this.description,
    required this.city,
    required this.genres,
    required this.feeStatus,
    required this.publisher,
    required this.ownedByMe,
    required this.appliedByMe,
    required this.savedByMe,
    this.closureReason,
    this.instrument,
    this.branch,
    this.customSpecialty,
    this.scheduledAt,
    this.expiresAt,
    this.feeAmountMinor,
    this.currency,
    this.publishedAt,
    this.createdAt,
    this.closedAt,
    this.applicationCount = 0,
  });

  final String id;
  final int version;
  final CollabListingStatus status;
  final CollabClosureReason? closureReason;
  final CollabCadence cadence;
  final CollabProfileKind wantedType;
  final CollabInstrumentSummary? instrument;
  final CollabBranch? branch;
  final String? customSpecialty;
  final String title;
  final String description;
  final CollabCitySummary city;
  final List<String> genres;
  final DateTime? scheduledAt;
  final DateTime? expiresAt;
  final int? feeAmountMinor;
  final String? currency;
  final CollabFeeStatus feeStatus;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final DateTime? closedAt;
  final CollabActor publisher;
  final bool ownedByMe;
  final bool appliedByMe;
  final bool savedByMe;
  final int applicationCount;

  bool get isDraft => status == CollabListingStatus.draft;
  bool get isOpen => status == CollabListingStatus.open;
  bool get canApply => isOpen && !ownedByMe && !appliedByMe;

  String? get specialtyLabel {
    final instrumentName = instrument?.name.trim();
    if (instrumentName != null && instrumentName.isNotEmpty) {
      return instrumentName;
    }
    if (branch == CollabBranch.other) {
      final custom = customSpecialty?.trim();
      if (custom != null && custom.isNotEmpty) return custom;
    }
    return branch?.label;
  }

  double? get feeMajor => feeAmountMinor == null ? null : feeAmountMinor! / 100;

  CollabListing copyWith({
    int? version,
    CollabListingStatus? status,
    CollabClosureReason? closureReason,
    bool clearClosureReason = false,
    bool? savedByMe,
    bool? appliedByMe,
    int? applicationCount,
  }) => CollabListing(
    id: id,
    version: version ?? this.version,
    status: status ?? this.status,
    closureReason: clearClosureReason
        ? null
        : closureReason ?? this.closureReason,
    cadence: cadence,
    wantedType: wantedType,
    instrument: instrument,
    branch: branch,
    customSpecialty: customSpecialty,
    title: title,
    description: description,
    city: city,
    genres: genres,
    scheduledAt: scheduledAt,
    expiresAt: expiresAt,
    feeAmountMinor: feeAmountMinor,
    currency: currency,
    feeStatus: feeStatus,
    publishedAt: publishedAt,
    createdAt: createdAt,
    closedAt: closedAt,
    publisher: publisher,
    ownedByMe: ownedByMe,
    appliedByMe: appliedByMe ?? this.appliedByMe,
    savedByMe: savedByMe ?? this.savedByMe,
    applicationCount: applicationCount ?? this.applicationCount,
  );
}
