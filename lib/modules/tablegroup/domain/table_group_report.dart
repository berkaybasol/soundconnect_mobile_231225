enum TableGroupReportReason {
  inappropriate('INAPPROPRIATE', 'Uygunsuz içerik'),
  misleading('MISLEADING', 'Yanıltıcı bilgi'),
  moneyRequest('MONEY_REQUEST', 'Para talebi'),
  harassment('HARASSMENT', 'Taciz veya tehdit'),
  spam('SPAM', 'Spam'),
  safety('SAFETY', 'Güvenlik sorunu'),
  other('OTHER', 'Diğer');

  const TableGroupReportReason(this.wire, this.label);
  final String wire;
  final String label;

  static TableGroupReportReason fromWire(Object? value) => values.firstWhere(
    (reason) => reason.wire == value,
    orElse: () => throw const FormatException('Geçersiz şikâyet nedeni'),
  );
}

enum TableGroupReportKind {
  listing('LISTING', 'Masa ilanı', [
    TableGroupReportReason.inappropriate,
    TableGroupReportReason.misleading,
    TableGroupReportReason.moneyRequest,
    TableGroupReportReason.other,
  ]),
  message('MESSAGE', 'Mesaj', [
    TableGroupReportReason.moneyRequest,
    TableGroupReportReason.harassment,
    TableGroupReportReason.spam,
    TableGroupReportReason.other,
  ]),
  incident('INCIDENT', 'Olay', [
    TableGroupReportReason.harassment,
    TableGroupReportReason.moneyRequest,
    TableGroupReportReason.safety,
    TableGroupReportReason.other,
  ]);

  const TableGroupReportKind(this.wire, this.label, this.reasons);
  final String wire;
  final String label;
  final List<TableGroupReportReason> reasons;

  static TableGroupReportKind fromWire(Object? value) => values.firstWhere(
    (kind) => kind.wire == value,
    orElse: () => throw const FormatException('Geçersiz şikâyet türü'),
  );
}

class RecentReportableTable {
  const RecentReportableTable({
    required this.tableGroupId,
    required this.title,
    required this.location,
    required this.meetingAt,
    required this.endLabel,
    required this.reportUntil,
  });

  final String tableGroupId;
  final String title;
  final String? location;
  final DateTime? meetingAt;
  final String endLabel;
  final DateTime reportUntil;
}
