import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/marketplace_models.dart';
import '../domain/marketplace_repository.dart';

class MarketplaceRepositoryImpl implements MarketplaceRepository {
  MarketplaceRepositoryImpl(this._api, this._sessions);
  final ApiClient _api;
  final AuthSessionManager _sessions;
  static const _base = '/api/v1/user/marketplace';
  static const _denied = AppError(
    code: 'marketplace_session_changed',
    message: 'Bu pazar mevcut oturumunda kullanılamıyor. Sayfayı yeniden aç.',
  );
  static const _invalid = AppError(
    code: 'marketplace_invalid',
    message: 'İlan bilgileri doğrulanamadı.',
  );
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  @override
  Future<Result<List<MarketplaceCategory>>> getCategories() => _request(
    ApiHttpMethod.get,
    '/categories',
    decoder: (value) {
      if (value is! List) throw const FormatException('Invalid categories');
      return List.unmodifiable(value.map(MarketplaceCategory.fromJson));
    },
  );
  @override
  Future<Result<MarketplacePage>> discover(
    MarketplaceQuery query, {
    int page = 0,
  }) {
    if (page < 0 ||
        page > 1000 ||
        marketplaceTextLength(query.search) > 100 ||
        (query.minPriceMinor != null && query.minPriceMinor! < 0) ||
        (query.maxPriceMinor != null && query.maxPriceMinor! < 0) ||
        (query.minPriceMinor != null &&
            query.maxPriceMinor != null &&
            query.minPriceMinor! > query.maxPriceMinor!)) {
      return Future.value(const Result.failure(_invalid));
    }
    return _request(
      ApiHttpMethod.get,
      '/listings',
      query: query.toJson(page: page),
      decoder: MarketplacePage.fromJson,
    );
  }

  @override
  Future<Result<MarketplacePage>> getMyListings({
    MarketplaceStatus? status,
    int page = 0,
  }) => _request(
    ApiHttpMethod.get,
    '/my-listings',
    query: {
      'page': page,
      'size': 20,
      if (status != null) 'status': status.apiValue,
    },
    decoder: MarketplacePage.fromJson,
  );
  @override
  Future<Result<MarketplacePage>> getSavedListings({int page = 0}) => _request(
    ApiHttpMethod.get,
    '/saved',
    query: {'page': page, 'size': 20},
    decoder: MarketplacePage.fromJson,
  );
  @override
  Future<Result<MarketplaceListing>> getListing(String id) =>
      _listing(id, ApiHttpMethod.get);
  @override
  Future<Result<MarketplaceListing>> createDraft(String clientRequestId) {
    if (!_uuid.hasMatch(clientRequestId)) {
      return Future.value(const Result.failure(_invalid));
    }
    return _request(
      ApiHttpMethod.post,
      '/drafts',
      body: {'clientRequestId': clientRequestId},
      decoder: MarketplaceListing.fromJson,
    );
  }

  @override
  Future<Result<MarketplaceListing>> updateListing(
    String id,
    MarketplaceListingInput input, {
    required int expectedVersion,
  }) {
    if (expectedVersion < 0 ||
        input.photoIds.length > 8 ||
        input.photoIds.toSet().length != input.photoIds.length) {
      return Future.value(const Result.failure(_invalid));
    }
    return _listing(id, ApiHttpMethod.put, body: input.toJson(expectedVersion));
  }

  @override
  Future<Result<MarketplaceListing>> transition(
    String id,
    String action, {
    required int expectedVersion,
  }) {
    if (!{'publish', 'sold', 'withdraw'}.contains(action) ||
        expectedVersion < 0) {
      return Future.value(const Result.failure(_invalid));
    }
    return _listing(
      id,
      ApiHttpMethod.post,
      suffix: '/$action',
      body: {'expectedVersion': expectedVersion},
    );
  }

  @override
  Future<Result<void>> deleteDraft(String id, {required int expectedVersion}) =>
      _void(
        id,
        ApiHttpMethod.delete,
        query: {'expectedVersion': expectedVersion},
      );
  @override
  Future<Result<void>> setSaved(String id, bool saved) => _void(
    id,
    saved ? ApiHttpMethod.put : ApiHttpMethod.delete,
    suffix: '/saved',
  );
  @override
  Future<Result<void>> report(
    String id, {
    required String reason,
    required String description,
    required String clientRequestId,
  }) {
    if (!{
          'SCAM',
          'MISLEADING',
          'PROHIBITED',
          'SPAM',
          'OTHER',
        }.contains(reason) ||
        !_uuid.hasMatch(clientRequestId)) {
      return Future.value(const Result.failure(_invalid));
    }
    return _void(
      id,
      ApiHttpMethod.post,
      suffix: '/reports',
      body: {
        'reason': reason,
        'description': description.trim(),
        'clientRequestId': clientRequestId,
      },
    );
  }

  Future<Result<MarketplaceListing>> _listing(
    String id,
    ApiHttpMethod method, {
    String suffix = '',
    Object? body,
  }) {
    if (!_uuid.hasMatch(id)) {
      return Future.value(const Result.failure(_invalid));
    }
    return _request(
      method,
      '/listings/$id$suffix',
      body: body,
      decoder: (value) {
        final listing = MarketplaceListing.fromJson(value);
        if (listing.id != id) {
          throw const FormatException('Listing identity mismatch');
        }
        return listing;
      },
    );
  }

  Future<Result<void>> _void(
    String id,
    ApiHttpMethod method, {
    String suffix = '',
    Object? body,
    Map<String, dynamic>? query,
  }) {
    if (!_uuid.hasMatch(id)) {
      return Future.value(const Result.failure(_invalid));
    }
    return _request<void>(
      method,
      '/listings/$id$suffix',
      query: query,
      body: body,
      decoder: (_) {},
    );
  }

  Future<Result<T>> _request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    required T Function(Object?) decoder,
  }) async {
    final session = _sessions.session;
    if (!canUseMarketplace(session)) return const Result.failure(_denied);
    var revoked = false;
    void observe() {
      if (!identical(session, _sessions.session)) revoked = true;
    }

    _sessions.addListener(observe);
    try {
      final data = await _api.request<T>(
        method,
        '$_base$path',
        body: body,
        query: query,
        decoder: decoder,
        requestContext: ApiRequestContext(
          expectedSessionKey: session.userId,
          expectedToken: session.token,
        ),
      );
      return revoked ? const Result.failure(_denied) : Result.success(data);
    } on ApiException catch (error) {
      return Result.failure(revoked ? _denied : error.error);
    } on FormatException {
      return Result.failure(revoked ? _denied : _invalid);
    } catch (_) {
      return Result.failure(
        revoked
            ? _denied
            : const AppError(
                code: 'marketplace_unavailable',
                message: 'İşlem tamamlanamadı. Lütfen tekrar dene.',
              ),
      );
    } finally {
      _sessions.removeListener(observe);
    }
  }
}
