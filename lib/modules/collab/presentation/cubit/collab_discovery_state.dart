import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';
import '../../domain/collab_commands.dart';
import '../../domain/entities/collab_listing.dart';
import 'collab_async_state.dart';

class CollabDiscoveryState {
  const CollabDiscoveryState({
    this.query = const CollabDiscoveryQuery(),
    this.status = CollabLoadStatus.initial,
    this.items = const <CollabListing>[],
    this.page = 0,
    this.hasNext = false,
    this.totalElements = 0,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.savingListingIds = const <String>{},
    this.error,
    this.loadMoreError,
    this.actionError,
  });

  final CollabDiscoveryQuery query;
  final CollabLoadStatus status;
  final List<CollabListing> items;
  final int page;
  final bool hasNext;
  final int totalElements;
  final bool isRefreshing;
  final bool isLoadingMore;
  final Set<String> savingListingIds;
  final AppError? error;
  final AppError? loadMoreError;
  final AppError? actionError;

  CollabDiscoveryState copyWith({
    CollabDiscoveryQuery? query,
    CollabLoadStatus? status,
    List<CollabListing>? items,
    int? page,
    bool? hasNext,
    int? totalElements,
    bool? isRefreshing,
    bool? isLoadingMore,
    Set<String>? savingListingIds,
    Object? error = copyWithUnset,
    Object? loadMoreError = copyWithUnset,
    Object? actionError = copyWithUnset,
  }) => CollabDiscoveryState(
    query: query ?? this.query,
    status: status ?? this.status,
    items: items ?? this.items,
    page: page ?? this.page,
    hasNext: hasNext ?? this.hasNext,
    totalElements: totalElements ?? this.totalElements,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    savingListingIds: savingListingIds ?? this.savingListingIds,
    error: identical(error, copyWithUnset) ? this.error : error as AppError?,
    loadMoreError: identical(loadMoreError, copyWithUnset)
        ? this.loadMoreError
        : loadMoreError as AppError?,
    actionError: identical(actionError, copyWithUnset)
        ? this.actionError
        : actionError as AppError?,
  );
}
