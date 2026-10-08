import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/marketplace/domain/marketplace_models.dart';
import 'package:soundconnect_23_12_25codx/modules/marketplace/presentation/marketplace_browse_controller.dart';
import 'marketplace_test_support.dart';

void main() {
  test(
    'late old search cannot replace newer search or its pagination',
    () async {
      final repo = _PendingRepository();
      final controller = MarketplaceBrowseController(repo);
      addTearDown(controller.dispose);
      final first = controller.refresh();
      controller.query = const MarketplaceQuery(search: 'yeni');
      final second = controller.refresh();
      repo.calls[1].complete(
        Result.success(marketPage([marketListing(id: 'new')])),
      );
      await second;
      repo.calls[0].complete(
        Result.success(marketPage([marketListing(id: 'old')], hasNext: true)),
      );
      await first;
      expect(controller.items.single.id, 'new');
      expect(controller.hasNext, isFalse);
    },
  );
  test(
    'load more deduplicates and only one pagination request is in flight',
    () async {
      final repo = _PendingRepository();
      final controller = MarketplaceBrowseController(repo);
      addTearDown(controller.dispose);
      final first = controller.refresh();
      repo.calls[0].complete(
        Result.success(marketPage([marketListing(id: 'one')], hasNext: true)),
      );
      await first;
      final more = controller.loadMore();
      await controller.loadMore();
      expect(repo.calls.length, 2);
      repo.calls[1].complete(
        Result.success(
          marketPage([
            marketListing(id: 'one'),
            marketListing(id: 'two'),
          ], page: 1),
        ),
      );
      await more;
      expect(controller.items.map((item) => item.id), ['one', 'two']);
    },
  );
  test(
    'revoked screen cannot start new request and pending response is discarded',
    () async {
      var allowed = true;
      final repo = _PendingRepository();
      final controller = MarketplaceBrowseController(
        repo,
        canAct: () => allowed,
      );
      addTearDown(controller.dispose);
      final request = controller.refresh();
      allowed = false;
      repo.calls.single.complete(Result.success(marketPage([marketListing()])));
      await request;
      await controller.refresh();
      expect(repo.calls.length, 1);
      expect(controller.items, isEmpty);
    },
  );
}

class _PendingRepository extends MarketplaceFakeRepository {
  final calls = <Completer<Result<MarketplacePage>>>[];
  @override
  Future<Result<MarketplacePage>> discover(
    MarketplaceQuery query, {
    int page = 0,
  }) {
    final call = Completer<Result<MarketplacePage>>();
    calls.add(call);
    return call.future;
  }
}
