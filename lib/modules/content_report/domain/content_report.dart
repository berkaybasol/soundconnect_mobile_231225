enum ContentReportKind {
  listenerProfile('LISTENER_PROFILE', 'Dinleyici profili'),
  musicianProfile('MUSICIAN_PROFILE', 'Müzisyen profili'),
  venueProfile('VENUE_PROFILE', 'Mekân profili'),
  studioProfile('STUDIO_PROFILE', 'Stüdyo profili'),
  overthinkingPost('OVERTHINKING_POST', 'Overthinking yazısı'),
  eventProfileShare('EVENT_PROFILE_SHARE', 'Etkinlik paylaşımı'),
  overthinkingProfileShare(
    'OVERTHINKING_PROFILE_SHARE',
    'Overthinking paylaşımı',
  ),
  tableGroupProfileShare('TABLEGROUP_PROFILE_SHARE', 'Masa paylaşımı'),
  comment('COMMENT', 'Yorum veya yanıt');

  const ContentReportKind(this.wire, this.label);
  final String wire;
  final String label;

  static ContentReportKind fromWire(String wire) => values.firstWhere(
    (kind) => kind.wire == wire,
    orElse: () => throw const FormatException('Geçersiz şikâyet hedefi.'),
  );
}

enum ContentReportReason {
  impersonation('IMPERSONATION', 'Başkasını taklit etme'),
  harassment('HARASSMENT', 'Taciz veya hakaret'),
  inappropriate('INAPPROPRIATE', 'Uygunsuz içerik'),
  privacy('PRIVACY', 'Özel bilgilerin paylaşılması'),
  spam('SPAM', 'Spam'),
  other('OTHER', 'Diğer');

  const ContentReportReason(this.wire, this.label);
  final String wire;
  final String label;

  static ContentReportReason fromWire(String wire) => values.firstWhere(
    (reason) => reason.wire == wire,
    orElse: () => throw const FormatException('Geçersiz bildirim nedeni.'),
  );
}
