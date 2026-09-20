import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/marketplace/data/marketplace_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/marketplace/domain/marketplace_models.dart';
import 'marketplace_test_support.dart';

void main() {
  test('Turkish price input converts exactly to integer kuruş', () {
    expect(parseMarketplacePriceMinor('28.500,50'), 2850050);
    expect(parseMarketplacePriceMinor('0,01'), 1);
    expect(parseMarketplacePriceMinor('12500.5'), 1250050);
    expect(parseMarketplacePriceMinor('1.234'), 123400);
    expect(parseMarketplacePriceMinor('12,345'), isNull);
    expect(parseMarketplacePriceMinor('1e6'), isNull);
    expect(parseMarketplacePriceMinor('-100'), isNull);
  });
  test('only NEW and USED condition values are accepted', () {
    final invalid = marketListingJson()..['condition'] = 'LIKE_NEW';
    expect(() => MarketplaceListing.fromJson(invalid), throwsFormatException);
  });
  test('listener and mixed professional identities never dispatch', () async {
    for (final roles in [
      ['ROLE_LISTENER'],
      ['ROLE_LISTENER', 'ROLE_MUSICIAN'],
      ['ROLE_MUSICIAN', 'ROLE_STUDIO'],
      ['ROLE_ADMIN'],
    ]) {
      final sessions = MarketplaceTestSessions(marketSession(roles: roles));
      final api = _Api([]);
      expect(
        (await MarketplaceRepositoryImpl(
          api,
          sessions,
        ).getCategories()).isSuccess,
        isFalse,
      );
      expect(api.calls, 0);
      sessions.dispose();
    }
  });
  test(
    'query uses exact minor prices, pagination and session/token fence',
    () async {
      final sessions = MarketplaceTestSessions(marketSession());
      addTearDown(sessions.dispose);
      final api = _Api({
        'content': [marketListingJson()],
        'page': 2,
        'last': false,
        'totalElements': 70,
      });
      final result = await MarketplaceRepositoryImpl(api, sessions).discover(
        const MarketplaceQuery(
          search: '  Fender  ',
          categoryId: marketRootId,
          cityId: marketCityId,
          districtId: marketDistrictId,
          condition: MarketplaceCondition.used,
          minPriceMinor: 1,
          maxPriceMinor: 250050,
          sort: MarketplaceSort.priceAscending,
        ),
        page: 2,
      );
      expect(result.isSuccess, isTrue);
      expect(result.data!.hasNext, isTrue);
      expect(api.path, '/api/v1/user/marketplace/listings');
      expect(api.query, {
        'q': 'Fender',
        'categoryId': marketRootId,
        'cityId': marketCityId,
        'districtId': marketDistrictId,
        'condition': 'USED',
        'minPriceMinor': 1,
        'maxPriceMinor': 250050,
        'sort': 'PRICE_ASC',
        'page': 2,
        'size': 20,
      });
      expect(api.context!.expectedSessionKey, marketSellerId);
      expect(api.context!.expectedToken, sessions.session.token);
    },
  );
  test(
    'A to B to A session switch rejects late response even when A returns',
    () async {
      final original = marketSession();
      final sessions = MarketplaceTestSessions(original);
      addTearDown(sessions.dispose);
      final pending = Completer<Object?>();
      final api = _Api(null)..pending = pending.future;
      final request = MarketplaceRepositoryImpl(
        api,
        sessions,
      ).getListing(marketListingId);
      sessions.replace(marketSession(roles: ['ROLE_LISTENER']));
      sessions.replace(original);
      pending.complete(marketListingJson());
      expect((await request).error?.code, 'marketplace_session_changed');
    },
  );
  test(
    'draft writes include version and immutable photo IDs rather than URLs',
    () async {
      final sessions = MarketplaceTestSessions(marketSession());
      addTearDown(sessions.dispose);
      final api = _Api(marketListingJson(status: 'DRAFT', isOwner: true));
      final result = await MarketplaceRepositoryImpl(api, sessions)
          .updateListing(
            marketListingId,
            const MarketplaceListingInput(
              title: '  Test ilan  ',
              description: 'Açıklama',
              photoIds: [marketAssetId],
              condition: MarketplaceCondition.fresh,
              priceMinor: 1,
            ),
            expectedVersion: 2,
          );
      expect(result.isSuccess, isTrue);
      expect(api.body, containsPair('expectedVersion', 2));
      expect(api.body, containsPair('condition', 'NEW'));
      expect(api.body, containsPair('photoIds', [marketAssetId]));
      expect(api.body, containsPair('title', 'Test ilan'));
    },
  );
}

class _Api extends ApiClient {
  _Api(this.value);
  final Object? value;
  Future<Object?>? pending;
  int calls = 0;
  String? path;
  Object? body;
  Map<String, dynamic>? query;
  ApiRequestContext? context;
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    calls++;
    this.path = path;
    this.body = body;
    this.query = query;
    context = requestContext;
    final response = pending == null ? value : await pending;
    return decoder!(response);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
