class OverthinkingIncomingUnreadStatus {
  const OverthinkingIncomingUnreadStatus({
    required this.hasUnread,
    required this.revision,
  });

  final bool hasUnread;

  /// Server-issued inbox revision; acknowledging it cannot consume later arrivals.
  final int revision;
}
