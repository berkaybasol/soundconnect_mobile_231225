import '../../../core/error/result.dart';
import 'musician_feed_report_admin.dart';

abstract interface class MusicianFeedReportAdminRepository {
  Future<Result<MusicianFeedReportAdminPage>> load({
    MusicianFeedReportStatus status = MusicianFeedReportStatus.fresh,
    String? itemType,
    int limit = 20,
    String? cursor,
  });
  Future<Result<MusicianFeedReportDetail>> detail(String reportId);
  Future<Result<MusicianFeedReportDetail>> review(
    String reportId, {
    required String clientRequestId,
    required int expectedVersion,
    required MusicianFeedReportDecision decision,
    required String resolutionNote,
  });
  Future<Result<MusicianFeedOrphanRestrictionsPage>> restrictions({
    int limit = 20,
    String? cursor,
  });
  Future<Result<MusicianFeedRestrictionRestored>> restoreRestriction(
    String reportId, {
    required String clientRequestId,
    required DateTime expectedUpdatedAt,
    required String resolutionNote,
  });
}
