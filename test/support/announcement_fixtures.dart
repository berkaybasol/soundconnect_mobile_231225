import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/promotion/domain/entities/announcement.dart';
import 'package:soundconnect_23_12_25codx/modules/promotion/domain/promotion_repository.dart';

const announcementFixtureId = 'b5a6b667-9b55-4672-861a-f348c22f4e80';
const announcementFixtureSecondId = 'b5a6b667-9b55-4672-861a-f348c22f4e81';
const announcementFixtureAssetId = '71c6ba99-7c50-4a8f-94ef-6a009054bb46';
Map<String, dynamic> announcementFixture({
  String id = announcementFixtureId,
  String status = 'PUBLISHED',
  bool hidden = false,
  bool media = false,
  int version = 2,
}) => {
  'id': id,
  'version': version,
  'title': 'SoundConnect yenilikleri',
  'body': 'Müzisyenler için yeni duyuru alanı. Ayrıntılar burada.',
  'targetProfiles': ['MUSICIAN', 'LISTENER'],
  'status': status,
  'createdAt': '2026-09-13T09:00:00Z',
  'updatedAt': '2026-09-13T09:05:00Z',
  'startsAt': status == 'PUBLISHED' ? '2026-09-13T09:05:00Z' : null,
  'endsAt': null,
  'firstPublishedAt': status == 'PUBLISHED' ? '2026-09-13T09:05:00Z' : null,
  'media': media
      ? {
          'assetId': announcementFixtureAssetId,
          'kind': 'IMAGE',
          'status': 'READY',
          'streamingProtocol': null,
          'width': 1200,
          'height': 800,
          'durationSeconds': null,
        }
      : null,
  'engagement': {'likeCount': 7, 'commentCount': 3, 'likedByMe': false},
  'feedHidden': hidden,
};
AuthSession announcementAdminSession({
  String token = 'admin-token',
  bool permitted = true,
}) => AuthSession.authenticated(
  token: token,
  userId: 'admin',
  username: 'admin',
  accountStatus: 'ACTIVE',
  roles: const ['ROLE_ADMIN'],
  permissions: permitted ? const ['MANAGE_PROMOTIONS'] : const [],
  expiresAt: DateTime.utc(2100),
  isAdmin: true,
);

class AnnouncementTestRepository extends Fake implements PromotionRepository {
  final reads = <({bool admin, String? cursor, AnnouncementStatus? status})>[];
  Future<Result<AnnouncementPage>> Function(String? cursor)? onPage;
  Future<Result<Announcement>> Function(String id, bool admin)? onRead;
  int creates = 0;
  int updates = 0;
  int publishes = 0;
  Announcement current = Announcement.fromJson(
    announcementFixture(status: 'DRAFT'),
  );
  @override
  Future<Result<AnnouncementPage>> announcements({
    String? cursor,
    int limit = 20,
    bool admin = false,
    AnnouncementStatus? status,
  }) {
    reads.add((admin: admin, cursor: cursor, status: status));
    return onPage?.call(cursor) ??
        Future.value(
          Result.success(AnnouncementPage(items: [current], hasMore: false)),
        );
  }

  @override
  Future<Result<Announcement>> announcement(String id, {bool admin = false}) =>
      onRead?.call(id, admin) ?? Future.value(Result.success(current));
  @override
  Future<Result<Announcement>> createAnnouncement(
    AnnouncementWrite input,
  ) async {
    creates++;
    return Result.success(current);
  }

  @override
  Future<Result<Announcement>> updateAnnouncement(
    String id,
    AnnouncementWrite input, {
    required int expectedVersion,
  }) async {
    updates++;
    return Result.success(current);
  }

  @override
  Future<Result<Announcement>> publishAnnouncement(
    String id, {
    required int expectedVersion,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    publishes++;
    return Result.success(current);
  }
}
