/// Stable Collab domain values shared by the API, repositories and UI state.
///
/// Enum names deliberately follow Dart conventions while [apiValue] exposes
/// the uppercase values used by the backend contract. Never send `.name`
/// directly over the wire; several values are multi-word.
enum CollabCadence { regular, extra }

extension CollabCadenceX on CollabCadence {
  String get apiValue => switch (this) {
    CollabCadence.regular => 'REGULAR',
    CollabCadence.extra => 'EXTRA',
  };

  String get label => switch (this) {
    CollabCadence.regular => 'Düzenli',
    CollabCadence.extra => 'Ekstra',
  };
}

enum CollabProfileKind { musician, band, venue, studio }

extension CollabProfileKindX on CollabProfileKind {
  String get apiValue => switch (this) {
    CollabProfileKind.musician => 'MUSICIAN',
    CollabProfileKind.band => 'BAND',
    CollabProfileKind.venue => 'VENUE',
    CollabProfileKind.studio => 'STUDIO',
  };

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

  String get missingApplicationProfileMessage => switch (this) {
    CollabProfileKind.band =>
      'Henüz grubunuz yok. Profil → Yönetim Paneli → Bandlerim bölümünden '
          'grubunuzu oluşturabilirsiniz.',
    _ =>
      'Bu ilana başvurabilecek bir ${label.toLowerCase()} profilin bulunmuyor.',
  };
}

enum CollabPublishedWithin {
  all,
  last24Hours,
  last3Days,
  last7Days,
  last30Days,
  olderThan30Days,
}

extension CollabPublishedWithinX on CollabPublishedWithin {
  String? get apiValue => switch (this) {
    CollabPublishedWithin.all => null,
    CollabPublishedWithin.last24Hours => 'LAST_24_HOURS',
    CollabPublishedWithin.last3Days => 'LAST_3_DAYS',
    CollabPublishedWithin.last7Days => 'LAST_7_DAYS',
    CollabPublishedWithin.last30Days => 'LAST_30_DAYS',
    CollabPublishedWithin.olderThan30Days => 'OLDER_THAN_30_DAYS',
  };

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

enum CollabListingStatus { draft, open, closed, expired }

extension CollabListingStatusX on CollabListingStatus {
  String get apiValue => switch (this) {
    CollabListingStatus.draft => 'DRAFT',
    CollabListingStatus.open => 'OPEN',
    CollabListingStatus.closed => 'CLOSED',
    CollabListingStatus.expired => 'EXPIRED',
  };
}

enum CollabClosureReason { matched, ownerClosed, expired, adminRemoved }

extension CollabClosureReasonX on CollabClosureReason {
  String get apiValue => switch (this) {
    CollabClosureReason.matched => 'MATCHED',
    CollabClosureReason.ownerClosed => 'OWNER_CLOSED',
    CollabClosureReason.expired => 'EXPIRED',
    CollabClosureReason.adminRemoved => 'ADMIN_REMOVED',
  };
}

/// A structured non-instrument musician specialty.
enum CollabBranch { vocal, soundEngineer, producer, dj, other }

extension CollabBranchX on CollabBranch {
  String get apiValue => switch (this) {
    CollabBranch.vocal => 'VOCAL',
    CollabBranch.soundEngineer => 'SOUND_ENGINEER',
    CollabBranch.producer => 'PRODUCER',
    CollabBranch.dj => 'DJ',
    CollabBranch.other => 'OTHER',
  };

  String get label => switch (this) {
    CollabBranch.vocal => 'Vokal',
    CollabBranch.soundEngineer => 'Ses mühendisi',
    CollabBranch.producer => 'Prodüktör',
    CollabBranch.dj => 'DJ',
    CollabBranch.other => 'Diğer',
  };
}

enum CollabFeeStatus { specified, unspecified, notApplicable }

enum CollabApplicationStatus {
  pending,
  accepted,
  rejected,
  withdrawnByApplicant,
  invalidatedByListingClosure,
}

extension CollabApplicationStatusX on CollabApplicationStatus {
  String get apiValue => switch (this) {
    CollabApplicationStatus.pending => 'PENDING',
    CollabApplicationStatus.accepted => 'ACCEPTED',
    CollabApplicationStatus.rejected => 'REJECTED',
    CollabApplicationStatus.withdrawnByApplicant => 'WITHDRAWN_BY_APPLICANT',
    CollabApplicationStatus.invalidatedByListingClosure =>
      'INVALIDATED_BY_LISTING_CLOSURE',
  };

  String get label => switch (this) {
    CollabApplicationStatus.pending => 'Bekliyor',
    CollabApplicationStatus.accepted => 'Kabul edildi',
    CollabApplicationStatus.rejected => 'Reddedildi',
    CollabApplicationStatus.withdrawnByApplicant => 'Başvuran geri çekti',
    CollabApplicationStatus.invalidatedByListingClosure =>
      'İlan kapanınca geçersizleşti',
  };
}

enum CollabJobStatus { active, completed }

extension CollabJobStatusX on CollabJobStatus {
  String get apiValue => switch (this) {
    CollabJobStatus.active => 'ACTIVE',
    CollabJobStatus.completed => 'COMPLETED',
  };
}

enum CollabReportReason { spam, inappropriate, misleading, other }

extension CollabReportReasonX on CollabReportReason {
  String get apiValue => switch (this) {
    CollabReportReason.spam => 'SPAM',
    CollabReportReason.inappropriate => 'INAPPROPRIATE',
    CollabReportReason.misleading => 'MISLEADING',
    CollabReportReason.other => 'OTHER',
  };
}
