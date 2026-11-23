import '../../../core/error/app_error.dart';
import '../../collab/domain/collab_types.dart';
import '../../collab/domain/entities/collab_actor.dart';

enum CollabReportStatus {
  open('OPEN', 'Açık'),
  dismissed('DISMISSED', 'Kapatıldı'),
  actioned('ACTIONED', 'İlan kaldırıldı');

  const CollabReportStatus(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

enum CollabReportDecision {
  dismiss('DISMISS', 'Şikâyeti kapat', CollabReportStatus.dismissed),
  removeListing('REMOVE_LISTING', 'İlanı kaldır', CollabReportStatus.actioned);

  const CollabReportDecision(this.apiValue, this.label, this.resultingStatus);
  final String apiValue;
  final String label;
  final CollabReportStatus resultingStatus;
}

bool isValidCollabResolutionNote(String note) {
  final length = note.trim().runes.length;
  return length >= 5 && length <= 500;
}

bool isCollabReportConflict(AppError? error) => const {
  '409',
  '9317',
  '9324',
  'COLLAB_STALE_UPDATE',
  'COLLAB_REPORT_STATUS_INVALID',
}.contains(error?.code.toUpperCase());

bool isCollabReportAccessError(AppError? error) => const {
  '401',
  '403',
  '1008',
  '1101',
  '1102',
  '1103',
  '9301',
  'COLLAB_FORBIDDEN',
  'COLLAB_REPORT_ACCESS_CHANGED',
  'API_SESSION_FENCE',
}.contains(error?.code.toUpperCase());

class CollabAdminReport {
  const CollabAdminReport({
    required this.id,
    required this.version,
    required this.status,
    required this.reason,
    this.details,
    required this.reportedAt,
    required this.listingId,
    required this.listingTitle,
    required this.listingDescription,
    required this.listingStatus,
    required this.listingStatusAtReport,
    required this.hasListingEvidence,
    required this.publisherActorId,
    required this.publisherDisplayName,
    required this.cadence,
    required this.wantedType,
    this.instrument,
    this.branch,
    this.customSpecialty,
    required this.city,
    required this.listingGenres,
    this.scheduledAt,
    this.feeAmountMinor,
    this.currency,
    required this.reporterUserId,
    this.reporterUsername,
    this.reviewDecision,
    this.reviewedByUserId,
    this.reviewedByUsername,
    this.reviewedAt,
    this.resolutionNote,
  });

  final String id;
  final int version;
  final CollabReportStatus status;
  final CollabReportReason reason;
  final String? details;
  final DateTime reportedAt;
  final String listingId;
  final String listingTitle;
  final String listingDescription;
  final CollabListingStatus listingStatus;
  final CollabListingStatus listingStatusAtReport;
  final bool hasListingEvidence;
  final String publisherActorId;
  final String publisherDisplayName;
  final CollabCadence cadence;
  final CollabProfileKind wantedType;
  final CollabInstrumentSummary? instrument;
  final CollabBranch? branch;
  final String? customSpecialty;
  final CollabCitySummary city;
  final List<String> listingGenres;
  final DateTime? scheduledAt;
  final int? feeAmountMinor;
  final String? currency;
  final String reporterUserId;
  final String? reporterUsername;
  final CollabReportDecision? reviewDecision;
  final String? reviewedByUserId;
  final String? reviewedByUsername;
  final DateTime? reviewedAt;
  final String? resolutionNote;

  factory CollabAdminReport.fromJson(Object? data) {
    final json = data as Map<String, dynamic>;
    final version = json['version'];
    if (version is! int || version < 0) {
      throw const FormatException('Invalid report version');
    }
    final city = json['city'] as Map;
    final instrument = json['instrument'] as Map?;
    T parse<T extends Enum>(
      String key,
      Iterable<T> values,
      String Function(T) apiValue,
    ) => values.firstWhere(
      (value) => apiValue(value) == json[key],
      orElse: () => throw FormatException('Invalid $key'),
    );

    return CollabAdminReport(
      id: json['id'] as String,
      version: version,
      status: parse('status', CollabReportStatus.values, (s) => s.apiValue),
      reason: parse('reason', CollabReportReason.values, (r) => r.apiValue),
      details: json['details'] as String?,
      reportedAt: DateTime.parse(json['reportedAt'] as String),
      listingId: json['listingId'] as String,
      listingTitle: json['listingTitle'] as String,
      listingDescription: json['listingDescription'] as String,
      listingStatus: parse(
        'listingStatus',
        CollabListingStatus.values,
        (s) => s.apiValue,
      ),
      listingStatusAtReport: parse(
        'listingStatusAtReport',
        CollabListingStatus.values,
        (s) => s.apiValue,
      ),
      hasListingEvidence: json['hasListingEvidence'] as bool? ?? false,
      publisherActorId: json['publisherActorId'] as String,
      publisherDisplayName: json['publisherDisplayName'] as String,
      cadence: parse('cadence', CollabCadence.values, (c) => c.apiValue),
      wantedType: parse(
        'wantedType',
        CollabProfileKind.values,
        (t) => t.apiValue,
      ),
      instrument: instrument == null
          ? null
          : CollabInstrumentSummary(
              id: instrument['id'] as String,
              name: instrument['name'] as String,
            ),
      branch: json['branch'] == null
          ? null
          : parse('branch', CollabBranch.values, (b) => b.apiValue),
      customSpecialty: json['customSpecialty'] as String?,
      city: CollabCitySummary(
        id: city['id'] as String,
        name: city['name'] as String,
      ),
      listingGenres: List.unmodifiable(
        (json['listingGenres'] as List).cast<String>(),
      ),
      scheduledAt: _optionalDate(json['scheduledAt']),
      feeAmountMinor: json['feeAmountMinor'] as int?,
      currency: json['currency'] as String?,
      reporterUserId: json['reporterUserId'] as String,
      reporterUsername: json['reporterUsername'] as String?,
      reviewDecision: json['reviewDecision'] == null
          ? null
          : parse(
              'reviewDecision',
              CollabReportDecision.values,
              (d) => d.apiValue,
            ),
      reviewedByUserId: json['reviewedByUserId'] as String?,
      reviewedByUsername: json['reviewedByUsername'] as String?,
      reviewedAt: _optionalDate(json['reviewedAt']),
      resolutionNote: json['resolutionNote'] as String?,
    );
  }

  static DateTime? _optionalDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}
