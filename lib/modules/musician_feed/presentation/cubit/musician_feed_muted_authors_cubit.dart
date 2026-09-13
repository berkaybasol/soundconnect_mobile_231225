import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../../../core/state/copy_with.dart';
import '../../domain/musician_feed_models.dart';
import '../../domain/musician_feed_muted_authors.dart';
import '../../domain/musician_feed_muted_authors_repository.dart';

enum MusicianFeedMutedAuthorsStatus { initial, loading, ready, failure }

class MusicianFeedMutedAuthorsState {
  const MusicianFeedMutedAuthorsState({
    this.status = MusicianFeedMutedAuthorsStatus.initial,
    this.items = const [],
    this.nextCursor,
    this.hasMore = false,
    this.refreshing = false,
    this.loadingMore = false,
    this.pendingAuthors = const {},
    this.error,
    this.pagingError,
    this.actionError,
    this.noticeSerial = 0,
  });

  final MusicianFeedMutedAuthorsStatus status;
  final List<MusicianFeedMutedAuthor> items;
  final String? nextCursor;
  final bool hasMore;
  final bool refreshing;
  final bool loadingMore;
  final Set<MusicianFeedAuthorProfileIdentity> pendingAuthors;
  final AppError? error;
  final AppError? pagingError;
  final AppError? actionError;
  final int noticeSerial;

  MusicianFeedMutedAuthorsState copyWith({
    MusicianFeedMutedAuthorsStatus? status,
    List<MusicianFeedMutedAuthor>? items,
    Object? nextCursor = copyWithUnset,
    bool? hasMore,
    bool? refreshing,
    bool? loadingMore,
    Set<MusicianFeedAuthorProfileIdentity>? pendingAuthors,
    Object? error = copyWithUnset,
    Object? pagingError = copyWithUnset,
    Object? actionError = copyWithUnset,
    int? noticeSerial,
  }) => MusicianFeedMutedAuthorsState(
    status: status ?? this.status,
    items: items ?? this.items,
    nextCursor: identical(nextCursor, copyWithUnset)
        ? this.nextCursor
        : nextCursor as String?,
    hasMore: hasMore ?? this.hasMore,
    refreshing: refreshing ?? this.refreshing,
    loadingMore: loadingMore ?? this.loadingMore,
    pendingAuthors: pendingAuthors ?? this.pendingAuthors,
    error: identical(error, copyWithUnset) ? this.error : error as AppError?,
    pagingError: identical(pagingError, copyWithUnset)
        ? this.pagingError
        : pagingError as AppError?,
    actionError: identical(actionError, copyWithUnset)
        ? this.actionError
        : actionError as AppError?,
    noticeSerial: noticeSerial ?? this.noticeSerial,
  );
}

class MusicianFeedMutedAuthorsCubit
    extends Cubit<MusicianFeedMutedAuthorsState> {
  MusicianFeedMutedAuthorsCubit(
    this._repository,
    this._sessions, {
    this.onUnmuted,
  }) : super(const MusicianFeedMutedAuthorsState()) {
    _owner = _identity;
    _sessions.addListener(_onSessionChanged);
  }

  final MusicianFeedMutedAuthorsRepository _repository;
  final AuthSessionManager _sessions;
  final void Function(MusicianFeedAuthorProfileIdentity author)? onUnmuted;
  ({String userId, String token})? _owner;
  final _acceptedUnmuted = <MusicianFeedAuthorProfileIdentity>{};
  final _operations = <MusicianFeedAuthorProfileIdentity, Object>{};
  int _generation = 0;
  static const _unknown = AppError(
    code: 'musician_feed_muted_authors_failed',
    message: 'İşlem tamamlanamadı. Lütfen tekrar dene.',
  );
  static const _sessionChanged = AppError(
    code: 'musician_feed_muted_authors_session_changed',
    message: 'Hesabın değişti. Bu sayfayı yeniden aç.',
  );
  static const _invalidPage = AppError(
    code: 'musician_feed_muted_authors_invalid_page',
    message: 'Listenin devamı yüklenemedi. Lütfen tekrar dene.',
  );

  ({String userId, String token})? get _identity {
    final session = _sessions.session;
    final userId = session.userId?.trim() ?? '';
    final token = session.token?.trim() ?? '';
    if (!session.isAuthenticated ||
        !session.isActive ||
        session.requiresListenerProfileChoice ||
        !session.hasAnyRole(const ['ROLE_MUSICIAN', 'MUSICIAN']) ||
        userId.isEmpty ||
        token.isEmpty) {
      return null;
    }
    return (userId: userId, token: token);
  }

  Future<void> initialize() async {
    if (state.status == MusicianFeedMutedAuthorsStatus.initial) await refresh();
  }

  bool _current(int generation, ({String userId, String token}) identity) =>
      !isClosed && generation == _generation && identity == _identity;

  void _onSessionChanged() {
    if (isClosed || _owner == _identity) return;
    _owner = _identity;
    _generation++;
    _operations.clear();
    _acceptedUnmuted.clear();
    emit(
      const MusicianFeedMutedAuthorsState(
        status: MusicianFeedMutedAuthorsStatus.failure,
        error: _sessionChanged,
      ),
    );
  }

  Future<void> refresh() async {
    if (isClosed) return;
    final identity = _identity;
    if (identity == null) {
      emit(
        const MusicianFeedMutedAuthorsState(
          status: MusicianFeedMutedAuthorsStatus.failure,
          error: _sessionChanged,
        ),
      );
      return;
    }
    final generation = ++_generation;
    // A fresh read is authoritative, including profiles muted again elsewhere.
    // Successful deletes overlapping this read repopulate the suppression set.
    _acceptedUnmuted.clear();
    final keepItems = state.items.isNotEmpty;
    emit(
      state.copyWith(
        status: keepItems
            ? MusicianFeedMutedAuthorsStatus.ready
            : MusicianFeedMutedAuthorsStatus.loading,
        refreshing: keepItems,
        loadingMore: false,
        error: null,
        pagingError: null,
        actionError: null,
      ),
    );
    final result = await _load();
    if (!_current(generation, identity)) return;
    final page = result.data;
    if (!result.isSuccess || page == null) {
      emit(
        state.copyWith(
          status: keepItems
              ? MusicianFeedMutedAuthorsStatus.ready
              : MusicianFeedMutedAuthorsStatus.failure,
          refreshing: false,
          error: keepItems ? null : (result.error ?? _unknown),
          actionError: keepItems ? (result.error ?? _unknown) : null,
          noticeSerial: keepItems ? state.noticeSerial + 1 : state.noticeSerial,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: MusicianFeedMutedAuthorsStatus.ready,
        items: _merge([], page.items),
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        refreshing: false,
      ),
    );
  }

  Future<void> loadMore() async {
    if (isClosed ||
        state.loadingMore ||
        state.refreshing ||
        state.status != MusicianFeedMutedAuthorsStatus.ready ||
        !state.hasMore) {
      return;
    }
    final identity = _identity;
    final cursor = state.nextCursor;
    if (identity == null) return;
    if (cursor == null) {
      _pagingFailure(_invalidPage);
      return;
    }
    final generation = _generation;
    emit(state.copyWith(loadingMore: true, pagingError: null));
    final result = await _load(cursor: cursor);
    if (!_current(generation, identity)) return;
    final page = result.data;
    if (!result.isSuccess || page == null) {
      final code = result.error?.code.trim().toLowerCase();
      if (code == '1318' || code == 'musician_feed_cursor_invalid') {
        emit(
          state.copyWith(loadingMore: false, nextCursor: null, hasMore: false),
        );
        await refresh();
      } else {
        _pagingFailure(result.error ?? _unknown);
      }
      return;
    }
    if (page.hasMore &&
        (page.nextCursor == null || page.nextCursor == cursor)) {
      _pagingFailure(_invalidPage);
      return;
    }
    emit(
      state.copyWith(
        items: _merge(state.items, page.items),
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        loadingMore: false,
        pagingError: null,
      ),
    );
  }

  Future<Result<MusicianFeedMutedAuthorsPage>> _load({String? cursor}) async {
    try {
      return await _repository.load(limit: 30, cursor: cursor);
    } catch (_) {
      return const Result.failure(_unknown);
    }
  }

  List<MusicianFeedMutedAuthor> _merge(
    List<MusicianFeedMutedAuthor> first,
    List<MusicianFeedMutedAuthor> second,
  ) {
    final seen = <MusicianFeedAuthorProfileIdentity>{};
    return List.unmodifiable(
      [...first, ...second].where(
        (item) =>
            !_acceptedUnmuted.contains(item.identity) &&
            seen.add(item.identity),
      ),
    );
  }

  void _pagingFailure(AppError error) =>
      emit(state.copyWith(loadingMore: false, pagingError: error));

  Future<bool> unmute(MusicianFeedAuthorProfileIdentity author) async {
    final identity = _identity;
    if (isClosed ||
        identity == null ||
        identity != _owner ||
        _operations.containsKey(author) ||
        !state.items.any((item) => item.identity == author)) {
      return false;
    }
    final operation = Object();
    _operations[author] = operation;
    emit(
      state.copyWith(
        pendingAuthors: Set.unmodifiable(_operations.keys),
        actionError: null,
      ),
    );
    Result<void> result;
    try {
      result = await _repository.unmute(
        profileType: author.profileType,
        profileId: author.profileId,
      );
    } catch (_) {
      result = const Result.failure(_unknown);
    }
    if (isClosed ||
        identity != _identity ||
        !identical(_operations[author], operation)) {
      return false;
    }
    _operations.remove(author);
    if (!result.isSuccess) {
      emit(
        state.copyWith(
          pendingAuthors: Set.unmodifiable(_operations.keys),
          actionError: result.error ?? _unknown,
          noticeSerial: state.noticeSerial + 1,
        ),
      );
      return false;
    }
    _acceptedUnmuted.add(author);
    emit(
      state.copyWith(
        items: _merge(state.items, []),
        pendingAuthors: Set.unmodifiable(_operations.keys),
      ),
    );
    onUnmuted?.call(author);
    return true;
  }

  @override
  Future<void> close() {
    _sessions.removeListener(_onSessionChanged);
    _generation++;
    _operations.clear();
    return super.close();
  }
}
