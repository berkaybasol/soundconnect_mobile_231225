import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/collab_commands.dart';
import '../../domain/collab_repository.dart';
import '../../domain/collab_types.dart';
import '../../domain/entities/collab_listing.dart';
import 'collab_async_state.dart';
import 'collab_discovery_state.dart';

class CollabDiscoveryCubit extends Cubit<CollabDiscoveryState> {
  CollabDiscoveryCubit(
    this._repository, {
    this.searchDebounce = const Duration(milliseconds: 350),
  }) : super(const CollabDiscoveryState());

  final CollabRepository _repository;
  final Duration searchDebounce;
  Timer? _searchTimer;
  int _generation = 0;

  Future<void> loadInitial() async {
    if (state.status != CollabLoadStatus.initial) return;
    await _loadFirst(state.query, keepItems: false);
  }

  Future<void> setFilters(CollabDiscoveryQuery query) {
    _searchTimer?.cancel();
    final normalized = query.copyWith(
      search: state.query.search,
      clearSearch: state.query.search == null,
      page: 0,
      size: state.query.size,
    );
    return _loadFirst(normalized, keepItems: false);
  }

  void setSearchQuery(String value) {
    _searchTimer?.cancel();
    final normalized = value.trim();
    final next = state.query.copyWith(
      search: normalized.isEmpty ? null : normalized,
      clearSearch: normalized.isEmpty,
      page: 0,
    );
    final generation = ++_generation;
    emit(
      state.copyWith(
        query: next,
        status: CollabLoadStatus.loading,
        items: const <CollabListing>[],
        page: 0,
        hasNext: false,
        totalElements: 0,
        isRefreshing: false,
        isLoadingMore: false,
        error: null,
        loadMoreError: null,
        actionError: null,
      ),
    );
    _searchTimer = Timer(searchDebounce, () {
      if (isClosed || generation != _generation) return;
      _loadFirst(next, keepItems: false, generation: generation);
    });
  }

  Future<void> refresh() {
    _searchTimer?.cancel();
    return _loadFirst(
      state.query.firstPage(),
      keepItems: state.items.isNotEmpty,
    );
  }

  Future<void> _loadFirst(
    CollabDiscoveryQuery query, {
    required bool keepItems,
    int? generation,
  }) async {
    final requestGeneration = generation ?? ++_generation;
    emit(
      state.copyWith(
        query: query.firstPage(),
        status: keepItems ? state.status : CollabLoadStatus.loading,
        items: keepItems ? state.items : const <CollabListing>[],
        page: keepItems ? state.page : 0,
        hasNext: keepItems ? state.hasNext : false,
        totalElements: keepItems ? state.totalElements : 0,
        isRefreshing: keepItems,
        isLoadingMore: false,
        error: null,
        loadMoreError: null,
        actionError: null,
      ),
    );
    final result = await _repository.discover(query.firstPage());
    if (isClosed || requestGeneration != _generation) return;
    if (result.isSuccess) {
      final page = result.data!;
      emit(
        state.copyWith(
          query: query.copyWith(page: page.page),
          status: CollabLoadStatus.success,
          items: _dedupe(page.items),
          page: page.page,
          hasNext: page.hasNext,
          totalElements: page.totalElements,
          isRefreshing: false,
          error: null,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: state.items.isEmpty
            ? CollabLoadStatus.failure
            : CollabLoadStatus.success,
        isRefreshing: false,
        error: result.error,
      ),
    );
  }

  Future<void> loadMore() async {
    if (!state.hasNext ||
        state.isLoadingMore ||
        state.status != CollabLoadStatus.success) {
      return;
    }
    final generation = _generation;
    final nextQuery = state.query.copyWith(page: state.page + 1);
    emit(state.copyWith(isLoadingMore: true, loadMoreError: null));
    final result = await _repository.discover(nextQuery);
    if (isClosed || generation != _generation) return;
    if (result.isSuccess) {
      final page = result.data!;
      emit(
        state.copyWith(
          query: nextQuery.copyWith(page: page.page),
          items: _dedupe(<CollabListing>[...state.items, ...page.items]),
          page: page.page,
          hasNext: page.hasNext,
          totalElements: page.totalElements,
          isLoadingMore: false,
          loadMoreError: null,
        ),
      );
      return;
    }
    emit(state.copyWith(isLoadingMore: false, loadMoreError: result.error));
  }

  Future<void> toggleSaved(String listingId) async {
    if (state.savingListingIds.contains(listingId)) return;
    final index = state.items.indexWhere((item) => item.id == listingId);
    if (index < 0) return;
    final previous = state.items[index];
    final nextSaved = !previous.savedByMe;
    final optimistic = previous.copyWith(savedByMe: nextSaved);
    _replaceListing(optimistic);
    emit(
      state.copyWith(
        savingListingIds: Set<String>.unmodifiable(<String>{
          ...state.savingListingIds,
          listingId,
        }),
        actionError: null,
      ),
    );
    final result = nextSaved
        ? await _repository.saveListing(listingId)
        : await _repository.unsaveListing(listingId);
    if (isClosed) return;
    if (!result.isSuccess) _replaceListing(previous);
    emit(
      state.copyWith(
        savingListingIds: Set<String>.unmodifiable(
          state.savingListingIds.where((id) => id != listingId),
        ),
        actionError: result.error,
      ),
    );
  }

  void upsertListing(CollabListing listing) {
    final exists = state.items.any((item) => item.id == listing.id);
    if (exists) {
      if (_matchesCurrentQuery(listing)) {
        _replaceListing(listing);
      } else {
        _removeListing(listing.id);
      }
    } else if (_matchesCurrentQuery(listing)) {
      emit(
        state.copyWith(
          items: List<CollabListing>.unmodifiable(<CollabListing>[
            listing,
            ...state.items,
          ]),
          totalElements: state.totalElements + 1,
        ),
      );
    }
  }

  bool _matchesCurrentQuery(CollabListing listing) {
    final query = state.query;
    if (!listing.isOpen || listing.cadence != query.cadence) return false;
    final expiresAt = listing.expiresAt;
    if (expiresAt != null && !expiresAt.isAfter(DateTime.now())) return false;
    if (query.cityId != null && listing.city.id != query.cityId) return false;
    if (query.wantedType != null && listing.wantedType != query.wantedType) {
      return false;
    }
    if (query.publisherTypes.isNotEmpty &&
        !query.publisherTypes.contains(listing.publisher.profileType)) {
      return false;
    }
    if (query.instrumentIds.isNotEmpty || query.branches.isNotEmpty) {
      final instrumentMatches =
          listing.instrument != null &&
          query.instrumentIds.contains(listing.instrument!.id);
      final branchMatches =
          listing.branch != null && query.branches.contains(listing.branch);
      if (!instrumentMatches && !branchMatches) return false;
    }
    if (!query.publishedWithin.includes(listing.publishedAt)) return false;

    final search = query.search?.trim().toLowerCase();
    if (search != null && search.isNotEmpty) {
      final searchable = <String?>[
        listing.title,
        listing.description,
        listing.customSpecialty,
        listing.instrument?.name,
        listing.publisher.displayName,
        listing.city.name,
      ];
      if (!searchable.any(
        (value) => value?.toLowerCase().contains(search) == true,
      )) {
        return false;
      }
    }
    return true;
  }

  void _replaceListing(CollabListing listing) {
    emit(
      state.copyWith(
        items: List<CollabListing>.unmodifiable(
          state.items.map((item) => item.id == listing.id ? listing : item),
        ),
      ),
    );
  }

  void _removeListing(String listingId) {
    emit(
      state.copyWith(
        items: List<CollabListing>.unmodifiable(
          state.items.where((item) => item.id != listingId),
        ),
        totalElements: state.totalElements > 0 ? state.totalElements - 1 : 0,
      ),
    );
  }

  List<CollabListing> _dedupe(Iterable<CollabListing> listings) {
    final byId = <String, CollabListing>{};
    for (final listing in listings) {
      byId[listing.id] = listing;
    }
    return List<CollabListing>.unmodifiable(byId.values);
  }

  @override
  Future<void> close() {
    _searchTimer?.cancel();
    return super.close();
  }
}
