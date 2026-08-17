enum AdminCollabReportStatus {
  open('OPEN', 'Bekleyen'),
  dismissed('DISMISSED', 'İhlal yok'),
  actioned('ACTIONED', 'İşlem yapıldı');

  const AdminCollabReportStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

enum AdminCollabReportReason {
  spam('SPAM', 'Spam'),
  inappropriate('INAPPROPRIATE', 'Uygunsuz içerik'),
  misleading('MISLEADING', 'Yanıltıcı ilan'),
  other('OTHER', 'Diğer');

  const AdminCollabReportReason(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

enum AdminCollabReportDecision {
  dismiss('DISMISS'),
  removeListing('REMOVE_LISTING');

  const AdminCollabReportDecision(this.apiValue);

  final String apiValue;
}

class AdminCollabReport {
  const AdminCollabReport({
    required this.id,
    required this.version,
    required this.status,
    required this.reason,
    required this.details,
    required this.reportedAt,
    required this.listingId,
    required this.listingTitle,
    required this.listingDescription,
    required this.listingStatusAtReport,
    required this.listingStatus,
    required this.publisherActorId,
    required this.publisherDisplayName,
    required this.cadence,
    required this.wantedType,
    required this.instrumentName,
    required this.branch,
    required this.customSpecialty,
    required this.cityName,
    required this.listingGenres,
    required this.scheduledAt,
    required this.feeAmountMinor,
    required this.currency,
    required this.reporterUserId,
    required this.reviewDecision,
    required this.reviewedByUserId,
    required this.reviewedAt,
    required this.resolutionNote,
  });

  final String id;
  final int version;
  final AdminCollabReportStatus status;
  final AdminCollabReportReason reason;
  final String? details;
  final DateTime reportedAt;
  final String listingId;
  final String listingTitle;
  final String listingDescription;
  final String listingStatusAtReport;
  final String listingStatus;
  final String publisherActorId;
  final String publisherDisplayName;
  final String cadence;
  final String wantedType;
  final String? instrumentName;
  final String? branch;
  final String? customSpecialty;
  final String cityName;
  final List<String> listingGenres;
  final DateTime? scheduledAt;
  final int? feeAmountMinor;
  final String? currency;
  final String reporterUserId;
  final AdminCollabReportDecision? reviewDecision;
  final String? reviewedByUserId;
  final DateTime? reviewedAt;
  final String? resolutionNote;
}
