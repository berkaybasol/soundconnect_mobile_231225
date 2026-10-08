import 'package:flutter/foundation.dart';
import '../../../core/error/result.dart';
import '../domain/marketplace_models.dart';
import '../domain/marketplace_repository.dart';

enum MarketplaceCollection { discovery, mine, saved }

class MarketplaceBrowseController extends ChangeNotifier {
  MarketplaceBrowseController(
    this.repository, {
    this.collection = MarketplaceCollection.discovery,
    bool Function()? canAct,
  }) : _canAct = canAct ?? _alwaysAllowed;
  static bool _alwaysAllowed() => true;
  final bool Function() _canAct;
  final MarketplaceRepository repository;
  final MarketplaceCollection collection;
  MarketplaceQuery query = const MarketplaceQuery();
  MarketplaceStatus? status;
  List<MarketplaceListing> items = const [];
  bool loading = false, loadingMore = false, hasNext = false;
  String? error;
  int totalElements = 0, _page = 0, _epoch = 0;
  bool _disposed = false;
  Future<Result<MarketplacePage>> _fetch(int page) => switch (collection) {
    MarketplaceCollection.discovery => repository.discover(query, page: page),
    MarketplaceCollection.mine => repository.getMyListings(
      status: status,
      page: page,
    ),
    MarketplaceCollection.saved => repository.getSavedListings(page: page),
  };
  Future<void> refresh() async {
    if (_disposed || !_canAct()) return;
    final epoch = ++_epoch;
    loading = true;
    loadingMore = false;
    error = null;
    // Filters never show records from an older query while a request is pending.
    items = const [];
    hasNext = false;
    totalElements = 0;
    notifyListeners();
    final result = await _fetch(0);
    if (_disposed || !_canAct() || epoch != _epoch) return;
    loading = false;
    if (!result.isSuccess || result.data == null) {
      error = result.error?.message ?? 'İlanlar yüklenemedi.';
    } else {
      final page = result.data!;
      items = page.items;
      _page = page.page;
      hasNext = page.hasNext;
      totalElements = page.totalElements;
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_disposed ||
        !_canAct() ||
        loading ||
        loadingMore ||
        !hasNext ||
        _page >= 1000) {
      return;
    }
    final epoch = _epoch;
    loadingMore = true;
    error = null;
    notifyListeners();
    final result = await _fetch(_page + 1);
    if (_disposed || !_canAct() || epoch != _epoch) return;
    loadingMore = false;
    if (!result.isSuccess || result.data == null) {
      error = result.error?.message ?? 'Diğer ilanlar yüklenemedi.';
    } else {
      final page = result.data!;
      final merged = {for (final listing in items) listing.id: listing};
      for (final listing in page.items) {
        merged[listing.id] = listing;
      }
      items = List.unmodifiable(merged.values);
      _page = page.page;
      hasNext = page.hasNext;
      totalElements = page.totalElements;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    super.dispose();
  }
}
