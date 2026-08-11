import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../../../core/state/copy_with.dart';
import '../../domain/collab_page.dart';
import 'collab_async_state.dart';

class CollabPagedState<T> {
  const CollabPagedState({
    this.status = CollabLoadStatus.initial,
    this.items = const [],
    this.page = 0,
    this.hasNext = false,
    this.totalElements = 0,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.actionIds = const <String>{},
    this.error,
    this.loadMoreError,
    this.actionError,
  });

  final CollabLoadStatus status;
  final List<T> items;
  final int page;
  final bool hasNext;
  final int totalElements;
  final bool isRefreshing;
  final bool isLoadingMore;
  final Set<String> actionIds;
  final AppError? error;
  final AppError? loadMoreError;
  final AppError? actionError;

  CollabPagedState<T> copyWith({
    CollabLoadStatus? status,
    List<T>? items,
    int? page,
    bool? hasNext,
    int? totalElements,
    bool? isRefreshing,
    bool? isLoadingMore,
    Set<String>? actionIds,
    Object? error = copyWithUnset,
    Object? loadMoreError = copyWithUnset,
    Object? actionError = copyWithUnset,
  }) => CollabPagedState<T>(
    status: status ?? this.status,
    items: items ?? this.items,
    page: page ?? this.page,
    hasNext: hasNext ?? this.hasNext,
    totalElements: totalElements ?? this.totalElements,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    actionIds: actionIds ?? this.actionIds,
    error: identical(error, copyWithUnset) ? this.error : error as AppError?,
    loadMoreError: identical(loadMoreError, copyWithUnset)
        ? this.loadMoreError
        : loadMoreError as AppError?,
    actionError: identical(actionError, copyWithUnset)
        ? this.actionError
        : actionError as AppError?,
  );
}

abstract class CollabPagedCubit<T> extends Cubit<CollabPagedState<T>> {
  CollabPagedCubit({this.pageSize = 20})
    : assert(pageSize > 0 && pageSize <= 50),
      super(CollabPagedState<T>());

  final int pageSize;
  int _generation = 0;

  Future<Result<CollabPage<T>>> fetchPage(int page, int size);
  String itemId(T item);

  Future<void> loadInitial() async {
    if (state.status == CollabLoadStatus.loading) return;
    await _loadFirst(refreshing: false);
  }

  Future<void> refresh() => _loadFirst(refreshing: state.items.isNotEmpty);

  Future<void> reloadForChangedFilter() =>
      _loadFirst(refreshing: false, clearExisting: true);

  Future<void> _loadFirst({
    required bool refreshing,
    bool clearExisting = false,
  }) async {
    final generation = ++_generation;
    emit(
      state.copyWith(
        status: refreshing ? state.status : CollabLoadStatus.loading,
        items: clearExisting ? List<T>.empty(growable: false) : state.items,
        page: clearExisting ? 0 : state.page,
        hasNext: clearExisting ? false : state.hasNext,
        totalElements: clearExisting ? 0 : state.totalElements,
        isRefreshing: refreshing,
        isLoadingMore: false,
        error: null,
        loadMoreError: null,
        actionError: null,
      ),
    );
    final result = await fetchPage(0, pageSize);
    if (isClosed || generation != _generation) return;
    if (result.isSuccess) {
      final page = result.data!;
      emit(
        state.copyWith(
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
    final requestedPage = state.page + 1;
    emit(state.copyWith(isLoadingMore: true, loadMoreError: null));
    final result = await fetchPage(requestedPage, pageSize);
    if (isClosed || generation != _generation) return;
    if (result.isSuccess) {
      final page = result.data!;
      emit(
        state.copyWith(
          items: _dedupe(<T>[...state.items, ...page.items]),
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

  List<T> _dedupe(Iterable<T> items) {
    final byId = <String, T>{};
    for (final item in items) {
      byId[itemId(item)] = item;
    }
    return List<T>.unmodifiable(byId.values);
  }

  void replaceItem(T replacement) {
    final replacementId = itemId(replacement);
    emit(
      state.copyWith(
        items: List<T>.unmodifiable(
          state.items.map(
            (item) => itemId(item) == replacementId ? replacement : item,
          ),
        ),
      ),
    );
  }

  void removeItem(String id) {
    emit(
      state.copyWith(
        items: List<T>.unmodifiable(
          state.items.where((item) => itemId(item) != id),
        ),
        totalElements: state.totalElements > 0 ? state.totalElements - 1 : 0,
      ),
    );
  }

  bool beginItemAction(String id) {
    if (state.actionIds.contains(id)) return false;
    emit(
      state.copyWith(
        actionIds: Set<String>.unmodifiable(<String>{...state.actionIds, id}),
        actionError: null,
      ),
    );
    return true;
  }

  void endItemAction(String id, {AppError? error}) {
    emit(
      state.copyWith(
        actionIds: Set<String>.unmodifiable(
          state.actionIds.where((actionId) => actionId != id),
        ),
        actionError: error,
      ),
    );
  }
}
