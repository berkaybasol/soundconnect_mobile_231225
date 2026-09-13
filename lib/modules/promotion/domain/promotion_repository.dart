import '../../../core/error/result.dart';
import 'entities/promotion_item.dart';
import 'entities/announcement.dart';
import 'entities/announcement_statistics.dart';

abstract class PromotionRepository {
  Future<Result<AnnouncementStatistics>> announcementStatistics(
    String id, {
    String? from,
    String? to,
    String? profileType,
    String? source,
  });
  Future<Result<List<PromotionItem>>> getDisplayableByPlacement(
    String placement,
  );

  Future<Result<AnnouncementPage>> announcements({
    String? cursor,
    int limit = 20,
    bool admin = false,
    AnnouncementStatus? status,
  });
  Future<Result<Announcement>> announcement(String id, {bool admin = false});
  Future<Result<Announcement>> createAnnouncement(AnnouncementWrite input);
  Future<Result<Announcement>> updateAnnouncement(
    String id,
    AnnouncementWrite input, {
    required int expectedVersion,
  });
  Future<Result<Announcement>> publishAnnouncement(
    String id, {
    required int expectedVersion,
    DateTime? startsAt,
    DateTime? endsAt,
  });
  Future<Result<Announcement>> endAnnouncement(
    String id, {
    required int expectedVersion,
  });
  Future<Result<Announcement>> archiveAnnouncement(
    String id, {
    required int expectedVersion,
  });
  Future<Result<void>> deleteAnnouncement(
    String id, {
    required int expectedVersion,
  });
}
