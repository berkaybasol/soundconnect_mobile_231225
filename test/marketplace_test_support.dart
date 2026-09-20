import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/city.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/district.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/neighborhood.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/location_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/marketplace/domain/marketplace_models.dart';
import 'package:soundconnect_23_12_25codx/modules/marketplace/domain/marketplace_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_upload_repository.dart';

const marketListingId = '11111111-1111-4111-8111-111111111111';
const marketSellerId = '22222222-2222-4222-8222-222222222222';
const marketAssetId = '33333333-3333-4333-8333-333333333333';
const marketRootId = '44444444-4444-4444-8444-444444444444';
const marketLeafId = '55555555-5555-4555-8555-555555555555';
const marketCityId = '66666666-6666-4666-8666-666666666666';
const marketDistrictId = '77777777-7777-4777-8777-777777777777';

AuthSession marketSession({
  String userId = marketSellerId,
  List<String> roles = const ['ROLE_MUSICIAN'],
}) => AuthSession.authenticated(
  token: 'token-$userId',
  userId: userId,
  username: 'muzisyen',
  accountStatus: 'ACTIVE',
  roles: roles,
  permissions: const [],
  expiresAt: DateTime.now().add(const Duration(hours: 2)),
  isAdmin: false,
);

class MarketplaceTestSessions extends AuthSessionManager {
  MarketplaceTestSessions(this.current)
    : super(tokenStore: _Tokens(), sessionStore: _Sessions());
  AuthSession current;
  @override
  AuthSession get session => current;
  void replace(AuthSession value) {
    current = value;
    notifyListeners();
  }
}

class _Tokens implements TokenStore {
  @override
  Future<String?> readToken() async => null;
  @override
  Future<void> writeToken(String token) async {}
  @override
  Future<void> clear() async {}
}

class _Sessions implements AuthSessionStore {
  @override
  Future<AuthSessionMetadata?> read() async => null;
  @override
  Future<void> write(AuthSessionMetadata metadata) async {}
  @override
  Future<void> clear() async {}
}

Map<String, dynamic> marketListingJson({
  String id = marketListingId,
  String status = 'PUBLISHED',
  bool isOwner = false,
  bool photo = false,
}) => {
  'id': id,
  'version': 2,
  'status': status,
  'title': 'Fender Player Stratocaster',
  'description': 'Ev stüdyosunda kullanıldı. Kılıfı dahildir.',
  'category': {
    'id': marketLeafId,
    'code': 'electric-guitars',
    'name': 'Elektro Gitarlar',
    'rootId': marketRootId,
    'rootCode': 'guitars',
    'rootName': 'Gitarlar',
  },
  'brand': 'Fender',
  'model': 'Player',
  'condition': 'USED',
  'priceMinor': 2850050,
  'currency': 'TRY',
  'negotiable': true,
  'deliveryMethod': 'PICKUP',
  'city': {'id': marketCityId, 'name': 'İstanbul'},
  'district': {'id': marketDistrictId, 'name': 'Kadıköy'},
  'photos': [
    if (photo) {'assetId': marketAssetId},
  ],
  'seller': {
    'userId': marketSellerId,
    'username': 'deniz',
    'profileType': 'MUSICIAN',
    'profileId': marketSellerId,
    'displayName': 'Deniz',
    'avatarUrl': null,
  },
  'isOwner': isOwner,
  'saved': false,
  'createdAt': '2026-09-20T10:00:00Z',
  'publishedAt': status == 'DRAFT' ? null : '2026-09-20T10:00:00Z',
};
MarketplaceListing marketListing({
  String id = marketListingId,
  String status = 'PUBLISHED',
  bool isOwner = false,
  bool photo = false,
}) => MarketplaceListing.fromJson(
  marketListingJson(id: id, status: status, isOwner: isOwner, photo: photo),
);
const marketCategories = [
  MarketplaceCategory(
    id: marketRootId,
    code: 'guitars',
    name: 'Gitarlar',
    children: [
      MarketplaceCategory(
        id: marketLeafId,
        code: 'electric-guitars',
        name: 'Elektro Gitarlar',
      ),
    ],
  ),
];
MarketplacePage marketPage(
  List<MarketplaceListing> items, {
  int page = 0,
  bool hasNext = false,
}) => MarketplacePage(
  items: items,
  page: page,
  hasNext: hasNext,
  totalElements: items.length,
);

class MarketplaceFakeRepository implements MarketplaceRepository {
  List<MarketplaceListing> listings = [];
  int discoverCalls = 0, creates = 0, updates = 0, reports = 0;
  MarketplaceQuery? lastQuery;
  MarketplaceListingInput? lastInput;
  MarketplaceListing current = marketListing(isOwner: true);
  @override
  Future<Result<List<MarketplaceCategory>>> getCategories() async =>
      const Result.success(marketCategories);
  @override
  Future<Result<MarketplacePage>> discover(
    MarketplaceQuery query, {
    int page = 0,
  }) async {
    discoverCalls++;
    lastQuery = query;
    return Result.success(marketPage(listings, page: page));
  }

  @override
  Future<Result<MarketplacePage>> getMyListings({
    MarketplaceStatus? status,
    int page = 0,
  }) async => Result.success(marketPage([current], page: page));
  @override
  Future<Result<MarketplacePage>> getSavedListings({int page = 0}) async =>
      Result.success(marketPage(listings, page: page));
  @override
  Future<Result<MarketplaceListing>> getListing(String id) async =>
      Result.success(current);
  @override
  Future<Result<MarketplaceListing>> createDraft(String clientRequestId) async {
    creates++;
    current = marketListing(status: 'DRAFT', isOwner: true);
    return Result.success(current);
  }

  @override
  Future<Result<MarketplaceListing>> updateListing(
    String id,
    MarketplaceListingInput input, {
    required int expectedVersion,
  }) async {
    updates++;
    lastInput = input;
    return Result.success(current);
  }

  @override
  Future<Result<MarketplaceListing>> transition(
    String id,
    String action, {
    required int expectedVersion,
  }) async => Result.success(current);
  @override
  Future<Result<void>> deleteDraft(
    String id, {
    required int expectedVersion,
  }) async => const Result.success(null);
  @override
  Future<Result<void>> setSaved(String id, bool saved) async =>
      const Result.success(null);
  @override
  Future<Result<void>> report(
    String id, {
    required String reason,
    required String description,
    required String clientRequestId,
  }) async {
    reports++;
    return const Result.success(null);
  }
}

class MarketplaceFakeLocations implements LocationRepository {
  @override
  Future<Result<List<City>>> getCities() async =>
      const Result.success([City(id: marketCityId, name: 'İstanbul')]);
  @override
  Future<Result<List<District>>> getDistricts(String cityId) async =>
      const Result.success([
        District(id: marketDistrictId, name: 'Kadıköy', cityId: marketCityId),
      ]);
  @override
  Future<Result<List<Neighborhood>>> getNeighborhoods(
    String districtId,
  ) async => const Result.success([]);
}

class MarketplaceFakeUploads implements ProfileMediaUploadRepository {
  @override
  Future<Result<void>> clearDraftCleanupIntents(
    Iterable<String> assetIds,
  ) async => const Result.success(null);
  @override
  Future<Result<void>> persistDraftCleanupIntent({
    required String assetId,
    required String ownerType,
    required String ownerId,
  }) async => const Result.success(null);
  @override
  Future<Result<void>> deleteOwnedAsset({
    required String assetId,
    required String ownerType,
    required String ownerId,
  }) async => const Result.success(null);
  @override
  void releaseDraftCleanupLeases(Iterable<String> assetIds) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
