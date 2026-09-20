import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/marketplace/domain/marketplace_models.dart';
import 'package:soundconnect_23_12_25codx/modules/marketplace/presentation/marketplace_browse_controller.dart';
import 'package:soundconnect_23_12_25codx/modules/marketplace/presentation/screens/marketplace_screen.dart';

import 'marketplace_test_support.dart';

const _error = AppError(code: 'network_timeout', message: 'Bağlantı kesildi.');

void main() {
  test(
    'failed second page preserves 20 items and retries the same page without duplicates',
    () async {
      final repository = _Pages();
      final controller = MarketplaceBrowseController(repository);
      addTearDown(controller.dispose);
      await controller.refresh();
      await controller.loadMore();
      expect(controller.items, hasLength(20));
      expect(controller.error, 'Bağlantı kesildi.');
      expect(controller.hasNext, isTrue);
      await controller.loadMore();
      expect(repository.pages, [0, 1, 1]);
      expect(controller.items, hasLength(39));
      expect(controller.items.map((item) => item.id).toSet(), hasLength(39));
      expect(controller.error, isNull);
      await controller.loadMore();
      expect(controller.items, hasLength(41));
      expect(controller.hasNext, isFalse);
      await controller.loadMore();
      expect(repository.pages, [0, 1, 1, 2]);
    },
  );

  test(
    'late failed page does not replace a refreshed filter or attach an old error',
    () async {
      final repository = _Pages();
      final controller = MarketplaceBrowseController(repository);
      addTearDown(controller.dispose);
      await controller.refresh();
      final old = Completer<Result<MarketplacePage>>();
      repository.more = old.future;
      final pending = controller.loadMore();
      controller.query = const MarketplaceQuery(search: 'yeni');
      await controller.refresh();
      old.complete(const Result.failure(_error));
      await pending;
      expect(controller.items.single.title, 'Yeni sorgu sonucu');
      expect(controller.error, isNull);
      expect(controller.loadingMore, isFalse);
      expect(controller.hasNext, isFalse);
    },
  );

  test('my-listings status switches discard previous status results', () async {
    final repository = _PendingCollections();
    final controller = MarketplaceBrowseController(
      repository,
      collection: MarketplaceCollection.mine,
    );
    addTearDown(controller.dispose);
    controller.status = MarketplaceStatus.draft;
    final drafts = controller.refresh();
    controller.status = MarketplaceStatus.sold;
    final sold = controller.refresh();
    repository.calls[1].complete(
      Result.success(marketPage([marketListing(status: 'SOLD')])),
    );
    await sold;
    repository.calls[0].complete(
      Result.success(
        marketPage([marketListing(status: 'DRAFT')], hasNext: true),
      ),
    );
    await drafts;
    expect(repository.statuses, [
      MarketplaceStatus.draft,
      MarketplaceStatus.sold,
    ]);
    expect(controller.items.single.status, MarketplaceStatus.sold);
    expect(controller.hasNext, isFalse);
  });

  test(
    'saved-list first-page error can be retried and empty is distinct from failure',
    () async {
      final repository = _PendingCollections();
      final controller = MarketplaceBrowseController(
        repository,
        collection: MarketplaceCollection.saved,
      );
      addTearDown(controller.dispose);
      final first = controller.refresh();
      repository.calls.single.complete(const Result.failure(_error));
      await first;
      expect(controller.error, isNotNull);
      final retry = controller.refresh();
      repository.calls.last.complete(Result.success(marketPage([])));
      await retry;
      expect(controller.error, isNull);
      expect(controller.items, isEmpty);
      expect(controller.hasNext, isFalse);
    },
  );

  testWidgets(
    '41-record screen retries failed next page and reaches the final listing',
    (tester) async {
      await serviceLocator.reset();
      final sessions = MarketplaceTestSessions(marketSession());
      serviceLocator.registerSingleton<AuthSessionManager>(
        sessions,
        dispose: (value) => value.dispose(),
      );
      addTearDown(serviceLocator.reset);
      final repository = _Pages();
      await tester.pumpWidget(
        MaterialApp(
          home: MarketplaceScreen(
            repository: repository,
            locationRepository: MarketplaceFakeLocations(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final vertical = find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Daha fazla ilan'),
        600,
        scrollable: vertical,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Daha fazla ilan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Daha fazla ilan'));
      await tester.pumpAndSettle();
      expect(find.text('Bağlantı kesildi.'), findsOneWidget);
      await tester.ensureVisible(find.text('Tekrar dene'));
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Daha fazla ilan'),
        600,
        scrollable: vertical,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Daha fazla ilan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Daha fazla ilan'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Ekipman 41'),
        500,
        scrollable: vertical,
      );
      expect(find.text('Ekipman 41'), findsOneWidget);
      expect(find.text('Daha fazla ilan'), findsNothing);
      expect(repository.pages, [0, 1, 1, 2]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

MarketplaceListing _item(int index, {String? title}) =>
    MarketplaceListing.fromJson(
      marketListingJson(id: 'listing-$index')
        ..['title'] = title ?? 'Ekipman $index',
    );

class _Pages extends MarketplaceFakeRepository {
  final pages = <int>[];
  Future<Result<MarketplacePage>>? more;
  bool failed = false;
  @override
  Future<Result<MarketplacePage>> discover(
    MarketplaceQuery query, {
    int page = 0,
  }) async {
    pages.add(page);
    if (query.search.isNotEmpty) {
      return Result.success(
        marketPage([_item(100, title: 'Yeni sorgu sonucu')]),
      );
    }
    if (page > 0 && more != null) return more!;
    if (page == 1 && !failed) {
      failed = true;
      return const Result.failure(_error);
    }
    final items = page == 0
        ? [for (var i = 1; i <= 20; i++) _item(i)]
        : page == 1
        ? [for (var i = 20; i <= 39; i++) _item(i)]
        : [_item(40), _item(41)];
    return Result.success(
      MarketplacePage(
        items: items,
        page: page,
        hasNext: page < 2,
        totalElements: 41,
      ),
    );
  }
}

class _PendingCollections extends MarketplaceFakeRepository {
  final calls = <Completer<Result<MarketplacePage>>>[];
  final statuses = <MarketplaceStatus?>[];
  @override
  Future<Result<MarketplacePage>> getMyListings({
    MarketplaceStatus? status,
    int page = 0,
  }) {
    statuses.add(status);
    final call = Completer<Result<MarketplacePage>>();
    calls.add(call);
    return call.future;
  }

  @override
  Future<Result<MarketplacePage>> getSavedListings({int page = 0}) {
    final call = Completer<Result<MarketplacePage>>();
    calls.add(call);
    return call.future;
  }
}
