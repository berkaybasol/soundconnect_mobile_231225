import '../../../core/auth/auth_session.dart';
import '../../marketplace/domain/marketplace_models.dart';

bool canManageMarketplaceReports(AuthSession session) =>
    session.isAuthenticated &&
    session.isActive &&
    session.userId?.trim().isNotEmpty == true &&
    !session.requiresListenerProfileChoice &&
    !session.hasAnyRole(const ['LISTENER', 'ROLE_LISTENER']) &&
    session.permissions.contains('MANAGE_MARKETPLACE_REPORTS');

class MarketplaceAdminReport {
  const MarketplaceAdminReport({
    required this.id,
    required this.version,
    required this.status,
    required this.reason,
    required this.description,
    required this.evidence,
    required this.reportedAt,
    this.resolutionNote,
  });

  final String id, status, reason, description;
  final int version;
  final MarketplaceListing evidence;
  final DateTime reportedAt;
  final String? resolutionNote;

  factory MarketplaceAdminReport.fromJson(Object? value) {
    final json = marketplaceMap(value);
    if (json['id'] is! String ||
        json['version'] is! int ||
        (json['version'] as int) < 0 ||
        !{'OPEN', 'DISMISSED', 'ACTIONED'}.contains(json['status'])) {
      throw const FormatException('Invalid marketplace report');
    }
    return MarketplaceAdminReport(
      id: json['id'] as String,
      version: json['version'] as int,
      status: json['status'] as String,
      reason: json['reason'] as String,
      description: json['description'] as String? ?? '',
      evidence: MarketplaceListing.fromJson(json['evidence']),
      reportedAt: DateTime.parse(json['reportedAt'] as String),
      resolutionNote: json['resolutionNote'] as String?,
    );
  }
}

class MarketplaceAdminReportPage {
  const MarketplaceAdminReportPage({required this.items, required this.last});
  final List<MarketplaceAdminReport> items;
  final bool last;
  factory MarketplaceAdminReportPage.fromJson(Object? value) {
    final json = marketplaceMap(value);
    return MarketplaceAdminReportPage(
      items: List.unmodifiable(
        (json['content'] as List).map(MarketplaceAdminReport.fromJson),
      ),
      last: json['last'] as bool,
    );
  }
}
